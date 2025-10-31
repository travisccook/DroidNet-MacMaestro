#!/bin/bash

###############################################################################
# Phase 4: Install Desktop Environment
# Installs XFCE, VNC server, and noVNC for web-based desktop access
###############################################################################

update_system() {
    print_step "Updating Ubuntu package lists..."

    multipass exec "$VM_NAME" -- sudo apt-get update -qq

    if [[ $? -ne 0 ]]; then
        print_error "Failed to update package lists"
        echo "This may be a temporary network issue. Please try again."
        exit 1
    fi

    print_success "Package lists updated"
}

install_desktop_packages() {
    print_step "Installing XFCE desktop environment and supporting packages..."
    echo ""
    echo "This will download and install approximately 500MB of packages."
    echo "Please be patient, this may take 5-10 minutes depending on your internet speed..."
    echo ""

    # Install all desktop-related packages
    multipass exec "$VM_NAME" -- sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xfce4 \
        xfce4-goodies \
        tightvncserver \
        novnc \
        websockify \
        python3-numpy \
        dbus-x11 \
        supervisor \
        firefox \
        xfce4-terminal

    if [[ $? -ne 0 ]]; then
        print_error "Failed to install desktop packages"
        echo ""
        echo "This may be due to:"
        echo "  1. Network connectivity issues"
        echo "  2. Ubuntu package repository problems"
        echo ""
        echo "Please check your internet connection and try again."
        exit 1
    fi

    print_success "Desktop packages installed"
}

configure_vnc_password() {
    print_step "Configuring VNC server password..."

    # Create VNC password file
    # Password: "maestro"
    multipass exec "$VM_NAME" -- bash <<'EOF'
mkdir -p /home/ubuntu/.vnc
echo "maestro" | vncpasswd -f > /home/ubuntu/.vnc/passwd
chmod 600 /home/ubuntu/.vnc/passwd
chown -R ubuntu:ubuntu /home/ubuntu/.vnc
EOF

    if [[ $? -ne 0 ]]; then
        print_error "Failed to configure VNC password"
        exit 1
    fi

    print_success "VNC password set to: maestro"
}

create_vnc_xstartup() {
    print_step "Creating VNC startup script..."

    # Create xstartup script to launch XFCE
    multipass exec "$VM_NAME" -- bash <<'EOF'
cat > /home/ubuntu/.vnc/xstartup << 'XSTARTUP'
#!/bin/bash

# Set up environment
export XKL_XMODMAP_DISABLE=1
export XDG_CURRENT_DESKTOP="XFCE"
export XDG_SESSION_TYPE="x11"

# Start D-Bus session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# Start XFCE desktop
startxfce4 &

# Keep the session alive
while true; do
    sleep 60
done
XSTARTUP

chmod +x /home/ubuntu/.vnc/xstartup
chown ubuntu:ubuntu /home/ubuntu/.vnc/xstartup
EOF

    if [[ $? -ne 0 ]]; then
        print_error "Failed to create VNC startup script"
        exit 1
    fi

    print_success "VNC startup script created"
}

test_vnc_start() {
    print_step "Testing VNC server startup..."

    # Start VNC server once to initialize
    multipass exec "$VM_NAME" -- sudo -u ubuntu vncserver :1 -geometry 1920x1080 -depth 24

    if [[ $? -ne 0 ]]; then
        print_warning "VNC server initial start had issues, but this may be normal"
        echo "Will configure supervisor to manage it automatically..."
    else
        print_success "VNC server started successfully"

        # Stop it so supervisor can manage it
        print_step "Stopping VNC for supervisor management..."
        multipass exec "$VM_NAME" -- sudo -u ubuntu vncserver -kill :1 || true
        sleep 2
    fi
}

install_rdp() {
    print_step "Installing RDP server (xrdp)..."

    multipass exec "$VM_NAME" -- sudo apt-get install -y xrdp

    if [[ $? -ne 0 ]]; then
        print_warning "Failed to install xrdp"
        echo "RDP access will not be available, but VNC will still work"
        return 1
    fi

    print_success "RDP server installed"
    return 0
}

configure_rdp() {
    print_step "Configuring RDP for XFCE..."

    # Set ubuntu user password for RDP login
    multipass exec "$VM_NAME" -- bash <<'EOF'
# Set password to 'maestro'
echo "ubuntu:maestro" | sudo chpasswd

# Configure XFCE session for RDP
echo "xfce4-session" > /home/ubuntu/.xsession
chown ubuntu:ubuntu /home/ubuntu/.xsession

# Restart xrdp service
sudo systemctl restart xrdp
sudo systemctl enable xrdp
EOF

    if [[ $? -ne 0 ]]; then
        print_warning "RDP configuration may be incomplete"
        return 1
    fi

    print_success "RDP configured (username: ubuntu, password: maestro)"
    return 0
}

verify_rdp() {
    print_step "Verifying RDP is running..."

    if multipass exec "$VM_NAME" -- sudo systemctl is-active --quiet xrdp; then
        print_success "RDP server is running on port 3389"
        return 0
    else
        print_warning "RDP server may not be running correctly"
        return 1
    fi
}

# Main execution
update_system
install_desktop_packages
configure_vnc_password
create_vnc_xstartup
test_vnc_start
install_rdp
configure_rdp
verify_rdp

print_success "Desktop environment installed and configured"
