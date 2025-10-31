#!/bin/bash

###############################################################################
# Phase 2: Detect Network
# Verifies WiFi interface (en0) is active and has connectivity
###############################################################################

NETWORK_INTERFACE="en0"

check_interface_exists() {
    print_step "Checking for WiFi interface ($NETWORK_INTERFACE)..."

    if ! ifconfig "$NETWORK_INTERFACE" &> /dev/null; then
        print_error "WiFi interface $NETWORK_INTERFACE not found"
        echo ""
        echo "This installer requires a WiFi connection."
        echo ""
        echo "Available network interfaces:"
        ifconfig | grep "^[a-z]" | cut -d: -f1
        echo ""
        echo "Please ensure your Mac has WiFi capability and try again."
        exit 1
    fi

    print_success "WiFi interface $NETWORK_INTERFACE found"
}

check_interface_active() {
    print_step "Checking if WiFi interface is active..."

    # Check if interface has an IP address
    local ip_address
    ip_address=$(ifconfig "$NETWORK_INTERFACE" | grep "inet " | awk '{print $2}' | head -1)

    if [[ -z "$ip_address" ]]; then
        print_error "WiFi interface $NETWORK_INTERFACE is not active or has no IP address"
        echo ""
        echo "Please:"
        echo "  1. Connect to your WiFi network"
        echo "  2. Verify you have internet access"
        echo "  3. Run this installer again"
        echo ""
        echo "To check your connection, run: ifconfig $NETWORK_INTERFACE"
        exit 1
    fi

    print_success "WiFi interface is active with IP: $ip_address"

    # Export for use in later phases
    export NETWORK_INTERFACE
    export HOST_IP="$ip_address"
}

check_internet_connectivity() {
    print_step "Verifying internet connectivity..."

    # Try to reach a reliable host
    if ! ping -c 1 -t 5 8.8.8.8 &> /dev/null; then
        print_warning "Could not reach internet (trying alternate method...)"

        # Try DNS resolution as fallback
        if ! host google.com &> /dev/null 2>&1; then
            print_error "No internet connectivity detected"
            echo ""
            echo "This installer requires internet access to:"
            echo "  • Download Ubuntu VM image"
            echo "  • Install software packages"
            echo "  • Download Maestro Control Center"
            echo ""
            echo "Please verify your internet connection and try again."
            exit 1
        fi
    fi

    print_success "Internet connectivity confirmed"
}

check_local_network() {
    print_step "Checking local network configuration..."

    # Verify we're on a 192.168.x.x or 10.x.x.x network
    local ip_address
    ip_address=$(ifconfig "$NETWORK_INTERFACE" | grep "inet " | awk '{print $2}' | head -1)

    if [[ "$ip_address" =~ ^192\.168\. ]] || [[ "$ip_address" =~ ^10\. ]] || [[ "$ip_address" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]]; then
        print_success "Local network detected: $ip_address"
    else
        print_warning "Unusual IP address: $ip_address"
        echo "This may indicate an issue with your network configuration."
        echo "The installer will continue, but please verify your network is configured correctly."
        echo ""
        read -p "Press Enter to continue or Ctrl+C to cancel..."
    fi
}

# Main execution
check_interface_exists
check_interface_active
check_internet_connectivity
check_local_network

print_success "Network configuration verified"
