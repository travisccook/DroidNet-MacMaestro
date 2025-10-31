#!/bin/bash

###############################################################################
# Phase 5: Install VirtualHere USB Client
# Downloads and installs VirtualHere client for remote USB access
###############################################################################

# Determine which binary to download based on mode
if [[ "$VIRTUALHERE_MODE" == "gui" ]]; then
    VIRTUALHERE_URL="https://www.virtualhere.com/sites/default/files/usbclient/vhuitarm64"
    VIRTUALHERE_BINARY="vhuitarm64"
    print_step "Installing VirtualHere GUI Client..."
else
    VIRTUALHERE_URL="https://www.virtualhere.com/sites/default/files/usbclient/vhclientarm64"
    VIRTUALHERE_BINARY="vhclientarm64"
    print_step "Installing VirtualHere CLI Daemon..."
fi

install_usbip_modules() {
    print_step "Installing USB/IP kernel modules..."

    multipass exec "$VM_NAME" -- bash -c 'sudo apt-get install -y linux-modules-extra-$(uname -r)'

    if [[ $? -ne 0 ]]; then
        print_warning "Could not install linux-modules-extra"
        echo "This may not be critical, continuing..."
        return 1
    else
        print_success "USB/IP kernel modules package installed"
        return 0
    fi
}

install_gui_dependencies() {
    print_step "Installing VirtualHere GUI dependencies..."

    multipass exec "$VM_NAME" -- sudo apt-get install -y libjpeg62

    if [[ $? -ne 0 ]]; then
        print_warning "Could not install libjpeg62"
        echo "VirtualHere GUI may not work without this library"
        return 1
    else
        print_success "GUI dependencies installed"
        return 0
    fi
}

download_virtualhere() {
    print_step "Downloading VirtualHere client..."

    # Determine installation path based on mode
    if [[ "$VIRTUALHERE_MODE" == "gui" ]]; then
        INSTALL_PATH="/usr/local/bin/vhui"
    else
        INSTALL_PATH="/usr/sbin/vhclientarm64"
    fi

    # Download VirtualHere client
    multipass exec "$VM_NAME" -- sudo wget -q -O "$INSTALL_PATH" "$VIRTUALHERE_URL"

    if [[ $? -ne 0 ]]; then
        print_error "Failed to download VirtualHere client"
        echo ""
        echo "Please check:"
        echo "  1. Internet connectivity in VM"
        echo "  2. VirtualHere website is accessible: $VIRTUALHERE_URL"
        echo ""
        echo "You can manually download and install later."
        exit 1
    fi

    print_success "VirtualHere client downloaded to $INSTALL_PATH"
    export VIRTUALHERE_INSTALL_PATH="$INSTALL_PATH"
}

configure_virtualhere() {
    print_step "Configuring VirtualHere client..."

    # Make executable
    multipass exec "$VM_NAME" -- sudo chmod +x "$VIRTUALHERE_INSTALL_PATH"

    # Verify it exists and is executable
    if ! multipass exec "$VM_NAME" -- test -x "$VIRTUALHERE_INSTALL_PATH"; then
        print_error "VirtualHere client is not executable"
        exit 1
    fi

    # If GUI mode, configure sudo access and create autostart entry
    if [[ "$VIRTUALHERE_MODE" == "gui" ]]; then
        print_step "Configuring passwordless sudo for VirtualHere GUI..."

        # VirtualHere GUI needs root privileges to manage USB devices
        multipass exec "$VM_NAME" -- bash <<'EOF'
# Allow ubuntu user to run vhui without password
echo "ubuntu ALL=(ALL) NOPASSWD: /usr/local/bin/vhui" | sudo tee /etc/sudoers.d/virtualhere > /dev/null
sudo chmod 440 /etc/sudoers.d/virtualhere
EOF

        print_step "Creating desktop autostart entry for VirtualHere GUI..."

        multipass exec "$VM_NAME" -- bash <<'EOF'
mkdir -p /home/ubuntu/.config/autostart
cat > /home/ubuntu/.config/autostart/virtualhere.desktop << 'AUTOSTART'
[Desktop Entry]
Type=Application
Name=VirtualHere USB Client
Exec=sudo /usr/local/bin/vhui
Icon=network-wireless
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
AUTOSTART

chown -R ubuntu:ubuntu /home/ubuntu/.config
EOF

        print_success "VirtualHere GUI configured with root privileges"
        print_success "VirtualHere GUI will start automatically with desktop"
    fi

    print_success "VirtualHere client configured"
}

load_usbip_modules() {
    print_step "Loading USB/IP kernel modules..."

    # Load required modules
    multipass exec "$VM_NAME" -- sudo modprobe usbip-core 2>/dev/null || true
    multipass exec "$VM_NAME" -- sudo modprobe vhci-hcd 2>/dev/null || true

    # Add to /etc/modules for persistence (load on boot)
    multipass exec "$VM_NAME" -- bash <<'EOF'
if ! grep -q "usbip-core" /etc/modules; then
    echo "usbip-core" | sudo tee -a /etc/modules > /dev/null
fi
if ! grep -q "vhci-hcd" /etc/modules; then
    echo "vhci-hcd" | sudo tee -a /etc/modules > /dev/null
fi
EOF

    # Verify modules are loaded
    if multipass exec "$VM_NAME" -- lsmod | grep -q vhci_hcd; then
        print_success "USB/IP modules loaded successfully"
        return 0
    else
        print_warning "USB/IP modules may not have loaded correctly"
        echo "VirtualHere may not work until modules are loaded"
        return 1
    fi
}

test_virtualhere() {
    print_step "Testing VirtualHere client..."

    # Verify the file exists and is executable
    if multipass exec "$VM_NAME" -- test -x "$VIRTUALHERE_INSTALL_PATH"; then
        print_success "VirtualHere client is installed and executable"
    else
        print_warning "VirtualHere client may not be properly installed"
        echo "Will be configured in the next step..."
    fi
}

# Main execution
install_usbip_modules

# Install GUI-specific dependencies if in GUI mode
if [[ "$VIRTUALHERE_MODE" == "gui" ]]; then
    install_gui_dependencies
fi

download_virtualhere
configure_virtualhere
load_usbip_modules
test_virtualhere

print_success "VirtualHere client installed successfully"
