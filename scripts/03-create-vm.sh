#!/bin/bash

###############################################################################
# Phase 3: Create VM
# Creates Multipass Ubuntu 22.04 VM with bridged networking
###############################################################################

delete_existing_vm() {
    print_step "Checking for existing VM..."

    if multipass list 2>/dev/null | grep -q "$VM_NAME"; then
        print_warning "Found existing $VM_NAME VM. Deleting to start fresh..."

        # Stop the VM if running
        multipass stop "$VM_NAME" 2>/dev/null || true

        # Delete and purge the VM
        multipass delete "$VM_NAME" 2>/dev/null || true
        multipass purge 2>/dev/null || true

        # Wait a moment for cleanup
        sleep 2

        print_success "Existing VM removed"
    else
        print_success "No existing VM found"
    fi
}

create_vm() {
    print_step "Creating Ubuntu 22.04 VM with bridged networking..."

    echo ""
    echo "VM Configuration:"
    echo "  Name: $VM_NAME"
    echo "  OS: Ubuntu 22.04 LTS"
    echo "  CPUs: 2"
    echo "  Memory: 4GB"
    echo "  Disk: 5GB"
    echo "  Network: Bridged to $NETWORK_INTERFACE"
    echo ""
    echo "This will download the Ubuntu image (~300MB) on first run."
    echo "Please be patient, this may take several minutes..."
    echo ""

    # Create the VM with bridged networking
    # Note: macOS may show a permission dialog for network access
    if ! multipass launch 22.04 \
        --name "$VM_NAME" \
        --cpus 2 \
        --memory 4G \
        --disk 5G \
        --network "$NETWORK_INTERFACE"; then

        print_error "Failed to create VM"
        echo ""
        echo "Common causes:"
        echo "  1. You denied the network permission dialog"
        echo "     Solution: Check System Settings > Privacy & Security > Network"
        echo ""
        echo "  2. Multipass daemon is not running"
        echo "     Solution: Try 'multipass version' to check status"
        echo ""
        echo "  3. Not enough system resources"
        echo "     Solution: Ensure you have 8GB+ RAM and 25GB+ free disk"
        echo ""
        echo "  4. Network interface $NETWORK_INTERFACE is not available"
        echo "     Solution: Verify WiFi is connected and try again"
        exit 1
    fi

    print_success "VM created successfully"
}

wait_for_vm() {
    print_step "Waiting for VM to be ready..."

    local max_attempts=60
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if multipass info "$VM_NAME" 2>/dev/null | grep -q "State.*Running"; then
            print_success "VM is running"
            return 0
        fi

        sleep 2
        ((attempt++))
    done

    print_error "VM failed to start within expected time"
    echo ""
    echo "Please check: multipass info $VM_NAME"
    exit 1
}

get_vm_ip() {
    print_step "Getting VM IP address..."

    local attempt=0
    local max_attempts=30

    # Extract subnet from host IP (e.g., 192.168.86.80 -> 192.168.86)
    local host_subnet=$(echo "$HOST_IP" | cut -d. -f1-3)

    while [[ $attempt -lt $max_attempts ]]; do
        # Get all IPs from multipass info
        # The output has "IPv4:" followed by IP, then indented continuation lines with more IPs
        # We need to capture both the labeled line and continuation lines
        local all_ips=$(multipass info "$VM_NAME" | awk '/IPv4:/ {print $2} /^[[:space:]]+[0-9]/ {print $1}')

        # Only accept IP matching host's subnet
        VM_IP=$(echo "$all_ips" | grep "^${host_subnet}\." | head -1)

        if [[ -n "$VM_IP" && "$VM_IP" != "N/A" ]]; then
            print_success "VM IP address: $VM_IP"
            print_success "VM is on local network: $VM_IP"
            export VM_IP
            return 0
        fi

        # If we didn't get the bridged IP yet, wait and retry
        if [[ $attempt -eq 0 ]]; then
            echo "Waiting for bridged IP address on subnet ${host_subnet}.x to appear..."
        fi

        sleep 2
        ((attempt++))
    done

    print_error "Could not get VM IP address"
    echo ""
    echo "Please run: multipass info $VM_NAME"
    echo "And verify the VM has an IP address."
    exit 1
}

verify_vm_connectivity() {
    print_step "Verifying VM connectivity..."

    # Try to execute a simple command in the VM with timeout
    local attempt=0
    local max_attempts=10

    while [[ $attempt -lt $max_attempts ]]; do
        if multipass exec "$VM_NAME" -- true; then
            print_success "VM is accessible and ready for configuration"
            return 0
        fi

        if [[ $attempt -eq 0 ]]; then
            echo "Waiting for VM SSH to be ready..."
        fi

        sleep 2
        ((attempt++))
    done

    print_error "Cannot connect to VM after multiple attempts"
    echo ""
    echo "Please check VM status: multipass info $VM_NAME"
    exit 1
}

# Main execution
delete_existing_vm
create_vm
wait_for_vm
get_vm_ip
verify_vm_connectivity

echo ""
print_success "VM created and configured successfully"
echo "VM IP: $VM_IP"
