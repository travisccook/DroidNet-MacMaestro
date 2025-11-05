#!/bin/bash

###############################################################################
# Droidnet Maestro Control Center Uninstaller
# Version: 1.0.0
#
# This script removes the Droidnet Maestro VM and optionally uninstalls
# Multipass for a complete clean slate.
#
# Usage: ./uninstall.sh [--full]
#   (no args) - Remove VM and desktop files only
#   --full    - Also uninstall Multipass
#
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
UNINSTALLER_VERSION="1.0.0"

# Parse command line arguments
FULL_UNINSTALL=false
if [[ "$1" == "--full" ]]; then
    FULL_UNINSTALL=true
fi

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

check_not_sudo() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This uninstaller should NOT be run with sudo"
        echo "Please run as your normal user: ./uninstall.sh"
        exit 1
    fi
}

###############################################################################
# Uninstallation Functions
###############################################################################

check_vm_exists() {
    print_step "Checking for VM..."

    if multipass list 2>/dev/null | grep -q "$VM_NAME"; then
        print_success "Found VM: $VM_NAME"
        return 0
    else
        print_warning "VM not found: $VM_NAME"
        return 1
    fi
}

stop_vm() {
    print_step "Stopping VM..."

    # Check if VM is running
    if multipass list | grep "$VM_NAME" | grep -q "Running"; then
        multipass stop "$VM_NAME" 2>/dev/null || true
        print_success "VM stopped"
    else
        print_step "VM is not running"
    fi
}

delete_vm() {
    print_step "Deleting VM..."

    multipass delete "$VM_NAME" 2>/dev/null || true
    print_success "VM deleted"
}

purge_vm() {
    print_step "Purging VM from system..."

    multipass purge 2>/dev/null || true
    print_success "VM purged"
}

clean_desktop_files() {
    print_step "Cleaning up Mac desktop files..."

    local cleaned=0

    # Remove NoVNC URL file
    if [[ -f "$HOME/Desktop/Droidnet-Maestro-URL.txt" ]]; then
        rm -f "$HOME/Desktop/Droidnet-Maestro-URL.txt"
        print_success "Removed: ~/Desktop/Droidnet-Maestro-URL.txt"
        cleaned=$((cleaned + 1))
    fi

    # Remove RDP connection file
    if [[ -f "$HOME/Desktop/Droidnet-Maestro-Connection.txt" ]]; then
        rm -f "$HOME/Desktop/Droidnet-Maestro-Connection.txt"
        print_success "Removed: ~/Desktop/Droidnet-Maestro-Connection.txt"
        cleaned=$((cleaned + 1))
    fi

    if [[ $cleaned -eq 0 ]]; then
        print_step "No desktop files to clean"
    else
        print_success "Cleaned $cleaned desktop file(s)"
    fi
}

check_multipass_installed() {
    if command -v multipass >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

uninstall_multipass() {
    print_step "Uninstalling Multipass..."

    if ! check_multipass_installed; then
        print_warning "Multipass is not installed"
        return 0
    fi

    # Stop multipassd service first
    print_step "Stopping Multipass service..."
    sudo launchctl stop com.canonical.multipassd 2>/dev/null || true

    # Uninstall via Homebrew
    print_step "Removing Multipass via Homebrew..."
    brew uninstall multipass 2>/dev/null || {
        print_warning "Could not uninstall via Homebrew (may not be installed via brew)"
        echo "You may need to manually remove Multipass if installed another way"
        return 1
    }

    print_success "Multipass uninstalled"
}

###############################################################################
# Main Uninstallation Flow
###############################################################################

main() {
    print_header "Droidnet Maestro Uninstaller v$UNINSTALLER_VERSION"

    # Pre-flight check
    check_not_sudo

    # Show what will be removed
    echo "This uninstaller will remove:"
    echo "  • Droidnet Maestro VM ($VM_NAME)"
    echo "  • Desktop connection files"

    if [[ "$FULL_UNINSTALL" == true ]]; then
        echo "  • Multipass (--full flag specified)"
    else
        echo ""
        echo "Note: Multipass will NOT be removed"
        echo "      Run with --full flag to also uninstall Multipass"
    fi

    echo ""
    echo "The following will NOT be removed:"
    echo "  • Homebrew"
    echo "  • Any other VMs you may have created"

    echo ""
    read -p "Continue with uninstallation? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled"
        exit 0
    fi

    echo ""
    print_header "Removing Droidnet Maestro"

    # Check if multipass is available
    if ! check_multipass_installed; then
        print_warning "Multipass is not installed or not in PATH"
        echo "Skipping VM removal (VM may have already been removed)"
    else
        # Remove VM if it exists
        if check_vm_exists; then
            stop_vm
            delete_vm
            purge_vm
            print_success "VM completely removed"
        else
            print_step "No VM to remove"
        fi
    fi

    # Clean up Mac desktop files
    clean_desktop_files

    # Optionally uninstall Multipass
    if [[ "$FULL_UNINSTALL" == true ]]; then
        echo ""
        print_header "Full Uninstallation"

        echo "This will uninstall Multipass completely."
        echo "All Multipass VMs will be removed (not just Droidnet Maestro)."
        echo ""
        read -p "Are you sure you want to uninstall Multipass? (y/N): " confirm_multipass

        if [[ "$confirm_multipass" =~ ^[Yy]$ ]]; then
            uninstall_multipass
        else
            print_step "Skipping Multipass uninstallation"
        fi
    fi

    # Final summary
    echo ""
    print_header "Uninstallation Complete"

    echo -e "${GREEN}Successfully removed:${NC}"
    echo "  ✓ Droidnet Maestro VM"
    echo "  ✓ Desktop connection files"

    if [[ "$FULL_UNINSTALL" == true ]] && [[ "$confirm_multipass" =~ ^[Yy]$ ]]; then
        echo "  ✓ Multipass"
    fi

    echo ""
    echo "Your Mac is now clean of Droidnet Maestro components."

    if [[ "$FULL_UNINSTALL" != true ]]; then
        echo ""
        echo "Note: Multipass is still installed and can be used for other VMs."
        echo "      Run './uninstall.sh --full' to also remove Multipass."
    fi

    echo ""
}

# Run main uninstallation
main
