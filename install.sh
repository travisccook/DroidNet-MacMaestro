#!/bin/bash

###############################################################################
# Droidnet Maestro Control Center Installer
# Version: 1.0.0
#
# This installer sets up a Multipass Ubuntu VM with:
# - XFCE Desktop Environment accessible via web browser (noVNC)
# - VirtualHere USB client for remote USB device access
# - Pololu Maestro Control Center pre-installed
#
# Usage: ./install.sh
# DO NOT run with sudo
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
INSTALLER_VERSION="1.0.0"

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

###############################################################################
# Helper Functions
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

# Cleanup function called on error
cleanup_on_error() {
    print_error "Installation failed. Cleaning up..."

    # Stop and delete VM if it exists
    if multipass list 2>/dev/null | grep -q "$VM_NAME"; then
        print_step "Removing incomplete VM..."
        multipass delete "$VM_NAME" --purge 2>/dev/null || true
    fi

    exit 1
}

# Set trap to cleanup on error
trap cleanup_on_error ERR

###############################################################################
# Pre-flight Checks
###############################################################################

check_not_sudo() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This installer should NOT be run with sudo"
        echo "Please run as your normal user: ./install.sh"
        exit 1
    fi
}

check_script_structure() {
    if [[ ! -d "$SCRIPTS_DIR" ]]; then
        print_error "Scripts directory not found: $SCRIPTS_DIR"
        echo "Please ensure the installer package is complete."
        exit 1
    fi
}

###############################################################################
# Installation Phases
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
# Main Installation Flow
###############################################################################

main() {
    print_header "Droidnet Maestro Control Center Installer v$INSTALLER_VERSION"

    echo "This installer will:"
    echo "  • Install Homebrew and Multipass (if needed)"
    echo "  • Create an Ubuntu VM with desktop environment"
    echo "  • Install VirtualHere USB client"
    echo "  • Install Maestro Control Center"
    echo "  • Set up web-based desktop access"
    echo ""
    echo "Estimated time: 10-15 minutes"
    echo "Network: Will use WiFi (en0) for bridged networking"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..."

    # Pre-flight checks
    print_step "Running pre-flight checks..."
    check_not_sudo
    check_script_structure
    print_success "Pre-flight checks passed"

    # Ask user about VirtualHere client preference
    print_header "VirtualHere Client Selection"
    echo ""
    echo "VirtualHere offers two client options:"
    echo ""
    echo "  1) GUI Client (Recommended)"
    echo "     - Visual interface with device management"
    echo "     - Automatically starts with desktop"
    echo "     - Easier to use for most users"
    echo ""
    echo "  2) CLI Daemon"
    echo "     - Background service (no GUI)"
    echo "     - Command-line control only"
    echo "     - Runs automatically on boot"
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
    echo ""

    # Export variables that will be used by phase scripts
    export VM_NAME
    export SCRIPT_DIR
    export SCRIPTS_DIR
    export VIRTUALHERE_MODE

    # Run installation phases
    run_phase 1 "01-check-prerequisites.sh" "Check Prerequisites"
    run_phase 2 "02-detect-network.sh" "Detect Network"
    run_phase 3 "03-create-vm.sh" "Create VM"
    run_phase 4 "04-install-desktop.sh" "Install Desktop Environment"
    run_phase 5 "05-install-virtualhere.sh" "Install VirtualHere"
    run_phase 6 "06-install-maestro.sh" "Install Maestro Control Center"
    run_phase 7 "07-configure-services.sh" "Configure Services"
    run_phase 8 "08-create-shortcuts.sh" "Create Desktop Shortcuts"

    # Display success message
    print_header "Installation Complete! 🎉"

    # Get VM IP address (bridged network on same subnet as host)
    local host_ip=$(ifconfig en0 | grep "inet " | awk '{print $2}' | head -1)
    local host_subnet=$(echo "$host_ip" | cut -d. -f1-3)
    local all_ips=$(multipass info "$VM_NAME" | awk '/IPv4:/ {print $2} /^[[:space:]]+[0-9]/ {print $1}')
    VM_IP=$(echo "$all_ips" | grep "^${host_subnet}\." | head -1)

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
    echo "Next steps:"
    echo "  1. Connect via web browser (noVNC) or RDP client (Microsoft Remote Desktop)"
    echo "  2. Use VirtualHere Control to connect USB devices"
    echo "  3. Launch Maestro Control Center from the desktop"
    echo ""
    echo "VM management commands:"
    echo -e "  ${BLUE}multipass start $VM_NAME${NC}   - Start the VM"
    echo -e "  ${BLUE}multipass stop $VM_NAME${NC}    - Stop the VM"
    echo -e "  ${BLUE}multipass info $VM_NAME${NC}    - Check VM status and IP"
    echo ""

    # Save URL to desktop
    echo "http://$VM_IP:6080/vnc.html" > "$HOME/Desktop/Droidnet-Maestro-URL.txt"
    print_success "Desktop URL saved to: ~/Desktop/Droidnet-Maestro-URL.txt"
    echo ""
}

# Run main installation
main
