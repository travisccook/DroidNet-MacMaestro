#!/bin/bash

###############################################################################
# Resume Droidnet Maestro Installation
# For development/debugging: Continue installation from a specific phase
###############################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VM_NAME="droidnet-maestro"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

###############################################################################
# Helper Functions (copied from install.sh)
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}▶ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

###############################################################################
# Pre-flight Checks
###############################################################################

check_vm_exists() {
    print_step "Checking for existing VM..."

    if ! multipass list 2>/dev/null | grep -q "$VM_NAME"; then
        print_error "VM '$VM_NAME' not found"
        echo ""
        echo "Please run the full installer first: ./install.sh"
        exit 1
    fi

    print_success "VM exists"
}

check_vm_running() {
    print_step "Checking if VM is running..."

    if ! multipass list 2>/dev/null | grep -q "$VM_NAME.*Running"; then
        print_warning "VM is not running. Starting it..."
        multipass start "$VM_NAME"
        sleep 3
    fi

    print_success "VM is running"
}

detect_network() {
    print_step "Detecting network configuration..."

    # Source the network detection script to get NETWORK_INTERFACE and HOST_IP
    source "$SCRIPTS_DIR/02-detect-network.sh"

    # These are exported by the detection script
    export NETWORK_INTERFACE
    export HOST_IP
}

get_vm_ip() {
    print_step "Getting VM IP address..."

    # Get all IPs and filter for bridged IP on host subnet
    local all_ips=$(multipass info "$VM_NAME" | awk '/IPv4:/ {print $2} /^[[:space:]]+[0-9]/ {print $1}')

    # Get host subnet from detected HOST_IP
    local host_subnet=$(echo "$HOST_IP" | cut -d. -f1-3)

    # Get IP matching host's subnet
    VM_IP=$(echo "$all_ips" | grep "^${host_subnet}\." | head -1)

    if [[ -z "$VM_IP" ]]; then
        print_error "Could not get VM IP address"
        echo ""
        echo "VM IPs found:"
        echo "$all_ips"
        echo ""
        echo "Expected subnet: ${host_subnet}.x"
        echo "Host interface: $NETWORK_INTERFACE ($HOST_IP)"
        echo ""
        echo "Please check: multipass info $VM_NAME"
        exit 1
    fi

    print_success "VM IP: $VM_IP"
    export VM_IP
}

###############################################################################
# Phase Runner
###############################################################################

run_phase() {
    local phase_number=$1
    local phase_script=$2
    local phase_description=$3

    print_header "Phase $phase_number: $phase_description"

    local script_path="$SCRIPTS_DIR/$phase_script"

    if [[ ! -f "$script_path" ]]; then
        print_error "Script not found: $phase_script"
        exit 1
    fi

    # Source the script to run it
    # shellcheck disable=SC1090
    source "$script_path"

    print_success "Phase $phase_number complete"
}

###############################################################################
# Main
###############################################################################

print_header "Resume Droidnet Maestro Installation"

echo "Available phases:"
echo "  4 - Install Desktop Environment (XFCE, VNC, noVNC)"
echo "  5 - Install VirtualHere"
echo "  6 - Install Maestro Control Center"
echo "  7 - Configure Services"
echo "  8 - Create Desktop Shortcuts"
echo ""
read -p "Enter phase number to start from (4-8): " START_PHASE

if [[ ! "$START_PHASE" =~ ^[4-8]$ ]]; then
    print_error "Invalid phase number. Must be 4-8."
    exit 1
fi

# If resuming from phase 5 or earlier, ask about VirtualHere mode
if [[ $START_PHASE -le 5 ]]; then
    echo ""
    echo "VirtualHere Client Selection:"
    echo "  1) GUI Client (Recommended)"
    echo "  2) CLI Daemon"
    echo ""
    while true; do
        read -p "Choose VirtualHere client type (1 for GUI, 2 for CLI) [1]: " vh_choice
        vh_choice=${vh_choice:-1}

        if [[ "$vh_choice" == "1" ]]; then
            VIRTUALHERE_MODE="gui"
            print_success "Selected: GUI Client"
            break
        elif [[ "$vh_choice" == "2" ]]; then
            VIRTUALHERE_MODE="cli"
            print_success "Selected: CLI Daemon"
            break
        else
            echo "Invalid choice. Please enter 1 or 2."
        fi
    done
else
    # Default to CLI if resuming from later phase (already installed)
    VIRTUALHERE_MODE="cli"
fi

echo ""
print_step "Will resume from Phase $START_PHASE"
echo ""

# Pre-flight checks
check_vm_exists
check_vm_running
detect_network
get_vm_ip

# Export variables that will be used by phase scripts
export VM_NAME
export SCRIPT_DIR
export SCRIPTS_DIR
export MAESTRO_INSTALLED=false
export VIRTUALHERE_MODE

# Run phases from START_PHASE onwards
if [[ $START_PHASE -le 4 ]]; then
    run_phase 4 "04-install-desktop.sh" "Install Desktop Environment"
fi

if [[ $START_PHASE -le 5 ]]; then
    run_phase 5 "05-install-virtualhere.sh" "Install VirtualHere"
fi

if [[ $START_PHASE -le 6 ]]; then
    run_phase 6 "06-install-maestro.sh" "Install Maestro Control Center"
fi

if [[ $START_PHASE -le 7 ]]; then
    run_phase 7 "07-configure-services.sh" "Configure Services"
fi

if [[ $START_PHASE -le 8 ]]; then
    run_phase 8 "08-create-shortcuts.sh" "Create Desktop Shortcuts"
fi

# Display success message
print_header "Installation Complete! 🎉"

echo ""
echo -e "${GREEN}Your Droidnet Maestro environment is ready!${NC}"
echo ""
echo "Desktop Access:"
echo -e "  Web (noVNC): ${BLUE}http://$VM_IP:6080/vnc.html${NC}"
echo -e "  VNC Password: ${YELLOW}maestro${NC}"
echo ""
echo -e "  RDP Client: ${BLUE}$VM_IP:3389${NC}"
echo -e "  Username: ${YELLOW}ubuntu${NC}  Password: ${YELLOW}maestro${NC}"
echo ""
echo "VM management commands:"
echo -e "  ${BLUE}multipass start $VM_NAME${NC}   - Start the VM"
echo -e "  ${BLUE}multipass stop $VM_NAME${NC}    - Stop the VM"
echo -e "  ${BLUE}multipass info $VM_NAME${NC}    - Check VM status and IP"
echo ""
