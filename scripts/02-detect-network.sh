#!/bin/bash

###############################################################################
# Phase 2: Detect Network
# Detects available network interfaces and prompts user to select one
# Validates the selected interface has both internet access and local network
###############################################################################

# Global arrays to store interface information
valid_interfaces=()
interface_details=()

detect_available_interfaces() {
    print_step "Detecting available network interfaces..."

    # Get interfaces from multipass networks (CSV format)
    local interfaces=$(multipass networks --format csv 2>/dev/null | tail -n +2 | cut -d',' -f1)

    if [ -z "$interfaces" ]; then
        print_error "No network interfaces available for bridged networking"
        echo ""
        echo "Troubleshooting:"
        echo "  1. Ensure your Mac has an active network connection"
        echo "  2. Check System Preferences → Network"
        echo "  3. Verify Multipass is installed correctly"
        echo ""
        exit 1
    fi

    # Clear arrays for this detection run
    valid_interfaces=()
    interface_details=()

    for iface in $interfaces; do
        # Get IP address
        local ip=$(ifconfig "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)

        # Skip if no IP
        if [ -z "$ip" ]; then
            continue
        fi

        # Determine interface type (Ethernet vs Wi-Fi)
        local iface_type="Unknown"

        # Get the hardware port type for this device from networksetup
        # Format: "Hardware Port: Wi-Fi" appears before "Device: en0"
        local port_info=$(networksetup -listallhardwareports 2>/dev/null | grep -B1 "Device: $iface" | grep "Hardware Port:" | sed 's/Hardware Port: //')

        if echo "$port_info" | grep -qi "Wi-Fi"; then
            iface_type="Wi-Fi"
        elif echo "$port_info" | grep -qi "Ethernet"; then
            iface_type="Ethernet"
        elif echo "$port_info" | grep -qi "Thunderbolt"; then
            iface_type="Ethernet"
        elif echo "$port_info" | grep -qi "USB"; then
            iface_type="Ethernet"
        else
            # Fallback: Unknown type
            iface_type="Network"
        fi

        # Check internet connectivity
        local has_internet="No"
        if ping -c 1 -t 2 8.8.8.8 > /dev/null 2>&1; then
            has_internet="Yes"
        elif ping -c 1 -t 2 1.1.1.1 > /dev/null 2>&1; then
            has_internet="Yes"
        fi

        # Store valid interface
        valid_interfaces+=("$iface")
        interface_details+=("$iface|$iface_type|$ip|$has_internet")
    done

    if [ ${#valid_interfaces[@]} -eq 0 ]; then
        print_error "No active network interfaces with IP addresses found"
        echo ""
        echo "Please ensure at least one network interface is:"
        echo "  • Connected to a network"
        echo "  • Has an assigned IP address"
        echo ""
        echo "Check: System Preferences → Network"
        exit 1
    fi

    print_success "Found ${#valid_interfaces[@]} active interface(s)"
}

select_network_interface() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Available Network Interfaces"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    local index=1
    for detail in "${interface_details[@]}"; do
        IFS='|' read -r iface type ip internet <<< "$detail"

        echo "  [$index] $iface ($type)"
        echo "      IP Address: $ip"
        echo "      Internet: $internet"
        echo ""

        ((index++))
    done

    # If only one interface, auto-select
    if [ ${#valid_interfaces[@]} -eq 1 ]; then
        NETWORK_INTERFACE="${valid_interfaces[0]}"
        IFS='|' read -r iface type ip internet <<< "${interface_details[0]}"

        print_success "Auto-selected: $NETWORK_INTERFACE ($type, $ip)"

        # Validate internet requirement
        if [ "$internet" != "Yes" ]; then
            print_error "Selected interface does not have internet access"
            echo ""
            echo "REQUIREMENT: The network interface must have BOTH:"
            echo "  1. Access to your VirtualHere server (same local network)"
            echo "  2. Internet access (to download packages during installation)"
            echo ""
            echo "Current status:"
            echo "  Interface: $NETWORK_INTERFACE"
            echo "  IP: $ip"
            echo "  Internet: ✗ Not detected"
            echo ""
            echo "Please connect $NETWORK_INTERFACE to a network with internet access and retry."
            exit 1
        fi

        HOST_IP="$ip"
        export NETWORK_INTERFACE
        export HOST_IP
        return 0
    fi

    # Multiple interfaces - prompt user
    echo "Select the interface connected to your VirtualHere server"
    echo "(This must be on the same network as your VirtualHere/droidnet server)"
    echo ""

    while true; do
        read -p "Enter selection [1-${#valid_interfaces[@]}]: " selection

        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#valid_interfaces[@]}" ]; then
            local array_index=$((selection - 1))
            NETWORK_INTERFACE="${valid_interfaces[$array_index]}"
            IFS='|' read -r iface type ip internet <<< "${interface_details[$array_index]}"

            echo ""
            print_success "Selected: $NETWORK_INTERFACE ($type, $ip)"

            # Validate internet requirement
            if [ "$internet" != "Yes" ]; then
                echo ""
                print_error "Selected interface does not have internet access"
                echo ""
                echo "REQUIREMENT: The network interface must have BOTH:"
                echo "  1. Access to your VirtualHere server (same local network)"
                echo "  2. Internet access (to download packages during installation)"
                echo ""
                echo "Current status:"
                echo "  Interface: $NETWORK_INTERFACE"
                echo "  IP: $ip"
                echo "  Internet: ✗ Not detected"
                echo ""
                echo "This interface does not meet requirement #2."
                echo ""
                echo "Please select a different interface or ensure this interface"
                echo "has internet access, then run the installer again."
                exit 1
            fi

            HOST_IP="$ip"
            export NETWORK_INTERFACE
            export HOST_IP
            return 0
        else
            echo "Invalid selection. Please enter a number between 1 and ${#valid_interfaces[@]}"
        fi
    done
}

validate_network_configuration() {
    print_step "Validating network configuration..."

    # Verify it's a private network range
    if [[ "$HOST_IP" =~ ^192\.168\. ]] || [[ "$HOST_IP" =~ ^10\. ]] || [[ "$HOST_IP" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]]; then
        print_success "Private network detected: $HOST_IP"
    else
        print_error "IP address $HOST_IP is not in a private network range"
        echo ""
        echo "Detected: $HOST_IP"
        echo "Expected: 192.168.x.x, 10.x.x.x, or 172.16-31.x.x"
        echo ""
        echo "This usually means:"
        echo "  • You're connected to a public network"
        echo "  • Your router may not be configured correctly"
        echo ""
        echo "Please connect to a private local network and retry."
        exit 1
    fi

    # Final summary
    echo ""
    print_success "Network interface: $NETWORK_INTERFACE"
    print_success "Host IP address: $HOST_IP"
}

# Main execution
detect_available_interfaces
select_network_interface
validate_network_configuration

print_success "Network configuration verified"
