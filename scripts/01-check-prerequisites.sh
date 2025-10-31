#!/bin/bash

###############################################################################
# Phase 1: Check Prerequisites
# Checks for and installs Homebrew and Multipass if needed
###############################################################################

check_homebrew() {
    print_step "Checking for Homebrew..."

    if command -v brew &> /dev/null; then
        print_success "Homebrew is installed"
        return 0
    fi

    print_warning "Homebrew not found. Installing Homebrew..."
    echo ""
    echo "You will be prompted for your password to install Homebrew."
    echo "This is normal and required."
    echo ""

    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ $? -ne 0 ]]; then
        print_error "Failed to install Homebrew"
        echo ""
        echo "Please install Homebrew manually from: https://brew.sh"
        echo "Then run this installer again."
        exit 1
    fi

    # Add Homebrew to PATH for ARM Macs
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    print_success "Homebrew installed successfully"
}

check_multipass() {
    print_step "Checking for Multipass..."

    if command -v multipass &> /dev/null; then
        print_success "Multipass is installed"

        # Check if multipass daemon is running
        if ! multipass version &> /dev/null; then
            print_warning "Multipass daemon is not running. Starting..."
            # On macOS, multipass should auto-start, but let's verify
            sleep 2
            if ! multipass version &> /dev/null; then
                print_error "Multipass daemon failed to start"
                echo ""
                echo "Please ensure Multipass is running:"
                echo "  1. Open System Settings > Privacy & Security"
                echo "  2. Allow 'multipassd' if prompted"
                echo "  3. Try running 'multipass version' in terminal"
                exit 1
            fi
        fi

        return 0
    fi

    print_warning "Multipass not found. Installing Multipass..."
    echo ""
    echo "Installing Multipass via Homebrew..."
    echo "This may take a few minutes..."
    echo ""

    # Install Multipass
    brew install --cask multipass

    if [[ $? -ne 0 ]]; then
        print_error "Failed to install Multipass"
        echo ""
        echo "Please install Multipass manually:"
        echo "  1. Download from: https://multipass.run"
        echo "  2. Or run: brew install --cask multipass"
        echo "Then run this installer again."
        exit 1
    fi

    print_success "Multipass installed successfully"

    # Wait for multipass daemon to start
    print_step "Waiting for Multipass daemon to start..."
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if multipass version &> /dev/null; then
            print_success "Multipass daemon is running"
            return 0
        fi
        sleep 2
        ((attempt++))
    done

    print_error "Multipass daemon failed to start after installation"
    echo ""
    echo "Please:"
    echo "  1. Check System Settings > Privacy & Security for Multipass permissions"
    echo "  2. Try restarting your Mac"
    echo "  3. Run 'multipass version' to verify it works"
    echo "  4. Then run this installer again"
    exit 1
}

# Main execution
check_homebrew
check_multipass

print_success "All prerequisites are installed and ready"
