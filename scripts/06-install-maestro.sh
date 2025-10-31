#!/bin/bash

###############################################################################
# Phase 6: Install Maestro Control Center
# Downloads and installs Pololu Maestro Control Center application
# NOTE: This phase continues even if it fails (graceful degradation)
###############################################################################

MAESTRO_URL="https://www.pololu.com/file/0J315/maestro-linux-241004.tar.gz"

install_dependencies() {
    print_step "Installing Maestro dependencies (Mono runtime and libusb)..."

    multipass exec "$VM_NAME" -- sudo apt-get install -y mono-complete libusb-1.0-0-dev

    if [[ $? -ne 0 ]]; then
        print_warning "Could not install Maestro dependencies"
        return 1
    else
        print_success "Maestro dependencies installed"
        return 0
    fi
}

download_maestro() {
    print_step "Downloading Maestro Control Center..."

    # Download to /tmp
    if ! multipass exec "$VM_NAME" -- wget -q --timeout=30 -O /tmp/maestro-linux.tar.gz "$MAESTRO_URL"; then
        print_warning "Failed to download Maestro Control Center"
        echo ""
        echo "This is not critical - you can install it manually later."
        echo "Download from: https://www.pololu.com/docs/0J40/3.a"
        echo ""
        return 1
    fi

    print_success "Maestro downloaded"
    return 0
}

extract_maestro() {
    print_step "Extracting Maestro package..."

    multipass exec "$VM_NAME" -- bash <<'EOF'
cd /tmp
tar -xzf maestro-linux.tar.gz 2>/dev/null
EOF

    if [[ $? -ne 0 ]]; then
        print_warning "Failed to extract Maestro package"
        multipass exec "$VM_NAME" -- rm -f /tmp/maestro-linux.tar.gz
        return 1
    fi

    print_success "Maestro extracted"
    return 0
}

install_maestro() {
    print_step "Installing Maestro Control Center..."

    # Install Maestro as a Mono application
    multipass exec "$VM_NAME" -- bash <<'EOF'
# Find the maestro directory
MAESTRO_DIR=$(find /tmp -type d -name "maestro-linux" 2>/dev/null | head -1)

if [ -z "$MAESTRO_DIR" ]; then
    echo "ERROR: Maestro directory not found"
    exit 1
fi

echo "Found Maestro in: $MAESTRO_DIR"

# Copy all Maestro files to /usr/local/lib/maestro
sudo mkdir -p /usr/local/lib/maestro
sudo cp -r "$MAESTRO_DIR"/* /usr/local/lib/maestro/

# Install udev rules for USB device permissions
if [ -f /usr/local/lib/maestro/99-pololu.rules ]; then
    sudo cp /usr/local/lib/maestro/99-pololu.rules /etc/udev/rules.d/
    sudo udevadm control --reload-rules
    echo "USB device permissions configured"
fi

# Create wrapper script to run through Mono
cat > /tmp/maestro-wrapper.sh << 'WRAPPER'
#!/bin/bash
exec mono /usr/local/lib/maestro/MaestroControlCenter "$@"
WRAPPER

sudo mv /tmp/maestro-wrapper.sh /usr/local/bin/MaestroControlCenter
sudo chmod +x /usr/local/bin/MaestroControlCenter

# Verify wrapper exists
if [ ! -x /usr/local/bin/MaestroControlCenter ]; then
    echo "ERROR: MaestroControlCenter wrapper is not executable"
    exit 1
fi

echo "SUCCESS"
EOF

    if [[ $? -ne 0 ]]; then
        print_warning "Failed to install Maestro Control Center"
        cleanup_maestro
        return 1
    fi

    print_success "Maestro Control Center installed to /usr/local/bin/MaestroControlCenter"
    cleanup_maestro
    return 0
}

cleanup_maestro() {
    # Clean up temporary files
    multipass exec "$VM_NAME" -- bash <<'EOF'
rm -rf /tmp/maestro-linux* 2>/dev/null
EOF
}

verify_maestro() {
    print_step "Verifying Maestro installation..."

    if multipass exec "$VM_NAME" -- test -x /usr/local/bin/MaestroControlCenter; then
        print_success "Maestro Control Center is ready"
        return 0
    else
        return 1
    fi
}

# Main execution
# Note: We don't exit on error here - this is optional software

if install_dependencies; then
    if download_maestro; then
        if extract_maestro; then
            if install_maestro; then
                verify_maestro
                MAESTRO_INSTALLED=true
            else
                print_warning "Maestro installation incomplete"
                MAESTRO_INSTALLED=false
            fi
        else
            print_warning "Maestro extraction failed"
            MAESTRO_INSTALLED=false
        fi
    else
        print_warning "Maestro download failed"
        MAESTRO_INSTALLED=false
    fi
else
    print_warning "Maestro dependencies installation failed"
    MAESTRO_INSTALLED=false
fi

if [[ "$MAESTRO_INSTALLED" == "true" ]]; then
    print_success "Maestro Control Center installation complete"
else
    print_warning "Maestro Control Center was not installed"
    echo ""
    echo "Manual installation instructions:"
    echo "  1. Visit: https://www.pololu.com/docs/0J40/3.a"
    echo "  2. Download the Linux version"
    echo "  3. Extract and copy MaestroControlCenter to /usr/local/bin/"
    echo ""
    echo "The installer will continue without it..."
    sleep 3
fi

# Export status for use in later phases
export MAESTRO_INSTALLED
