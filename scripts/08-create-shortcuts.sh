#!/bin/bash

###############################################################################
# Phase 8: Create Desktop Shortcuts
# Creates desktop shortcuts for VirtualHere Control and Maestro Control Center
###############################################################################

create_desktop_directory() {
    print_step "Creating Desktop directory..."

    multipass exec "$VM_NAME" -- mkdir -p /home/ubuntu/Desktop
    multipass exec "$VM_NAME" -- chown ubuntu:ubuntu /home/ubuntu/Desktop

    print_success "Desktop directory ready"
}

create_virtualhere_shortcut() {
    print_step "Creating VirtualHere shortcut..."

    if [[ "$VIRTUALHERE_MODE" == "gui" ]]; then
        # GUI mode - create shortcut to launch GUI client with sudo
        multipass exec "$VM_NAME" -- bash <<'EOF'
cat > /home/ubuntu/Desktop/virtualhere.desktop << 'VHDESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=VirtualHere USB Client
Comment=Manage USB devices from remote servers
Exec=sudo /usr/local/bin/vhui
Icon=network-wireless
Terminal=false
Categories=System;Network;
VHDESKTOP

chmod +x /home/ubuntu/Desktop/virtualhere.desktop
chown ubuntu:ubuntu /home/ubuntu/Desktop/virtualhere.desktop
EOF
        print_success "VirtualHere GUI shortcut created"

    else
        # CLI mode - create terminal-based control shortcut
        multipass exec "$VM_NAME" -- bash <<'EOF'
cat > /home/ubuntu/Desktop/virtualhere-control.desktop << 'VHDESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=VirtualHere Control
Comment=Connect USB devices from Droidnet server
Exec=xfce4-terminal --title="VirtualHere Control" --hold -e "bash -c '/usr/sbin/vhclientarm64 -t LIST; echo; echo \"Available commands:\"; echo \"  USE,<server.device> - Connect a device\"; echo \"  STOP USING,<server.device> - Disconnect a device\"; echo; echo \"Example: USE,myserver.114\"; echo \"Use the device addresses shown in the LIST output above.\"; echo; read -p \"Enter command (or press Enter to exit): \" cmd; if [ -n \"\$cmd\" ]; then /usr/sbin/vhclientarm64 -t \"\$cmd\"; echo; read -p \"Press Enter to close\"; fi'"
Icon=network-wireless
Terminal=false
Categories=System;Network;
VHDESKTOP

chmod +x /home/ubuntu/Desktop/virtualhere-control.desktop
chown ubuntu:ubuntu /home/ubuntu/Desktop/virtualhere-control.desktop
EOF
        print_success "VirtualHere CLI Control shortcut created"
    fi
}

create_maestro_shortcut() {
    print_step "Creating Maestro Control Center shortcut..."

    # Check if Maestro binary exists on the VM
    if multipass exec "$VM_NAME" -- test -x /usr/local/bin/MaestroControlCenter; then
        multipass exec "$VM_NAME" -- bash <<'EOF'
cat > /home/ubuntu/Desktop/maestro.desktop << 'MAESTRODESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=Maestro Control Center
Comment=Control Pololu Maestro servo controllers
Exec=/usr/local/bin/MaestroControlCenter
Icon=applications-electronics
Terminal=false
Categories=Development;Electronics;
MAESTRODESKTOP

chmod +x /home/ubuntu/Desktop/maestro.desktop
chown ubuntu:ubuntu /home/ubuntu/Desktop/maestro.desktop
EOF

        if [[ $? -ne 0 ]]; then
            print_warning "Failed to create Maestro shortcut"
        else
            print_success "Maestro Control Center shortcut created"
        fi
    else
        print_warning "Skipping Maestro shortcut (Maestro not installed)"
    fi
}

create_desktop_readme() {
    print_step "Creating desktop README file..."

    if [[ "$VIRTUALHERE_MODE" == "gui" ]]; then
        # GUI mode README
        if [[ "$DESKTOP_ACCESS_MODE" == "novnc" ]]; then
            # NoVNC access mode
            multipass exec "$VM_NAME" -- bash <<'EOF'
cat > /home/ubuntu/Desktop/README.txt << 'README'
========================================
Droidnet Maestro Control Center
========================================

Welcome! This Ubuntu desktop environment provides access to:
- VirtualHere USB device sharing (GUI Client)
- Pololu Maestro Control Center

REMOTE ACCESS
-------------
You are using Web Browser (NoVNC) access:
  - URL: http://[VM-IP]:6080/vnc.html
  - Password: maestro

To get VM IP: Open terminal and run: hostname -I

QUICK START
-----------

1. CONNECT USB DEVICES
   - Double-click "VirtualHere USB Client" icon (or it starts automatically)
   - Right-click on devices in the VirtualHere window to connect/disconnect
   - VirtualHere will auto-discover servers on your network

2. LAUNCH MAESTRO
   - Double-click "Maestro Control Center" icon
   - Your USB device should appear in the device list

TROUBLESHOOTING
---------------

Device not showing in Maestro?
→ Make sure you connected it via VirtualHere GUI first
→ Check devices with: lsusb (in terminal)

VirtualHere shows no devices?
→ Verify your VirtualHere server is online and on the same network
→ Check VirtualHere GUI is running (icon in system tray)

For more help, see TROUBLESHOOTING.txt in the installer package.

========================================
README

chown ubuntu:ubuntu /home/ubuntu/Desktop/README.txt
EOF
        else
            # RDP access mode
            multipass exec "$VM_NAME" -- bash <<'EOF'
cat > /home/ubuntu/Desktop/README.txt << 'README'
========================================
Droidnet Maestro Control Center
========================================

Welcome! This Ubuntu desktop environment provides access to:
- VirtualHere USB device sharing (GUI Client)
- Pololu Maestro Control Center

REMOTE ACCESS
-------------
You are using RDP Client access:
  - Server: [VM-IP]:3389
  - Username: ubuntu
  - Password: maestro

To get VM IP: Open terminal and run: hostname -I

QUICK START
-----------

1. CONNECT USB DEVICES
   - Double-click "VirtualHere USB Client" icon (or it starts automatically)
   - Right-click on devices in the VirtualHere window to connect/disconnect
   - VirtualHere will auto-discover servers on your network

2. LAUNCH MAESTRO
   - Double-click "Maestro Control Center" icon
   - Your USB device should appear in the device list

TROUBLESHOOTING
---------------

Device not showing in Maestro?
→ Make sure you connected it via VirtualHere GUI first
→ Check devices with: lsusb (in terminal)

VirtualHere shows no devices?
→ Verify your VirtualHere server is online and on the same network
→ Check VirtualHere GUI is running (icon in system tray)

For more help, see TROUBLESHOOTING.txt in the installer package.

========================================
README

chown ubuntu:ubuntu /home/ubuntu/Desktop/README.txt
EOF
        fi
    else
        # CLI mode README
        if [[ "$DESKTOP_ACCESS_MODE" == "novnc" ]]; then
            # NoVNC access mode
            multipass exec "$VM_NAME" -- bash <<'EOF'
cat > /home/ubuntu/Desktop/README.txt << 'README'
========================================
Droidnet Maestro Control Center
========================================

Welcome! This Ubuntu desktop environment provides access to:
- VirtualHere USB device sharing (CLI Daemon)
- Pololu Maestro Control Center

REMOTE ACCESS
-------------
You are using Web Browser (NoVNC) access:
  - URL: http://[VM-IP]:6080/vnc.html
  - Password: maestro

To get VM IP: Open terminal and run: hostname -I

QUICK START
-----------

1. CONNECT USB DEVICES
   - Double-click "VirtualHere Control" icon
   - View the LIST output to see available servers and devices
   - Type: USE,<server.device> (e.g., USE,myserver.114)
   - Use the device addresses shown in the LIST output
   - Press Enter

2. LAUNCH MAESTRO
   - Double-click "Maestro Control Center" icon
   - Your USB device should appear in the device list

TROUBLESHOOTING
---------------

Device not showing in Maestro?
→ Make sure you connected it via VirtualHere Control first
→ Check devices with: lsusb (in terminal)

VirtualHere shows no devices?
→ Verify your VirtualHere server is online and on the same network
→ Check service: sudo systemctl status vhclient
→ Run LIST command to see discovered servers

Need to disconnect a device?
→ VirtualHere Control: STOP USING,<server.device>
→ Use device address from LIST output

TERMINAL COMMANDS
-----------------
Check USB devices: lsusb
List VirtualHere devices: /usr/sbin/vhclientarm64 -t LIST
Connect device: /usr/sbin/vhclientarm64 -t "USE,<server.device>"
Disconnect device: /usr/sbin/vhclientarm64 -t "STOP USING,<server.device>"

Note: Run LIST first to see available servers and device addresses

For more help, see TROUBLESHOOTING.txt in the installer package.

========================================
README

chown ubuntu:ubuntu /home/ubuntu/Desktop/README.txt
EOF
        else
            # RDP access mode
            multipass exec "$VM_NAME" -- bash <<'EOF'
cat > /home/ubuntu/Desktop/README.txt << 'README'
========================================
Droidnet Maestro Control Center
========================================

Welcome! This Ubuntu desktop environment provides access to:
- VirtualHere USB device sharing (CLI Daemon)
- Pololu Maestro Control Center

REMOTE ACCESS
-------------
You are using RDP Client access:
  - Server: [VM-IP]:3389
  - Username: ubuntu
  - Password: maestro

To get VM IP: Open terminal and run: hostname -I

QUICK START
-----------

1. CONNECT USB DEVICES
   - Double-click "VirtualHere Control" icon
   - View the LIST output to see available servers and devices
   - Type: USE,<server.device> (e.g., USE,myserver.114)
   - Use the device addresses shown in the LIST output
   - Press Enter

2. LAUNCH MAESTRO
   - Double-click "Maestro Control Center" icon
   - Your USB device should appear in the device list

TROUBLESHOOTING
---------------

Device not showing in Maestro?
→ Make sure you connected it via VirtualHere Control first
→ Check devices with: lsusb (in terminal)

VirtualHere shows no devices?
→ Verify your VirtualHere server is online and on the same network
→ Check service: sudo systemctl status vhclient
→ Run LIST command to see discovered servers

Need to disconnect a device?
→ VirtualHere Control: STOP USING,<server.device>
→ Use device address from LIST output

TERMINAL COMMANDS
-----------------
Check USB devices: lsusb
List VirtualHere devices: /usr/sbin/vhclientarm64 -t LIST
Connect device: /usr/sbin/vhclientarm64 -t "USE,<server.device>"
Disconnect device: /usr/sbin/vhclientarm64 -t "STOP USING,<server.device>"

Note: Run LIST first to see available servers and device addresses

For more help, see TROUBLESHOOTING.txt in the installer package.

========================================
README

chown ubuntu:ubuntu /home/ubuntu/Desktop/README.txt
EOF
        fi
    fi

    if [[ $? -ne 0 ]]; then
        print_warning "Failed to create desktop README"
    else
        print_success "Desktop README created"
    fi
}

trust_desktop_files() {
    print_step "Configuring desktop file permissions..."

    # Mark desktop files as trusted (XFCE specific)
    multipass exec "$VM_NAME" -- bash <<'EOF'
# Set permissions
chmod 755 /home/ubuntu/Desktop/*.desktop 2>/dev/null || true

# For XFCE, we need to mark them as trusted
mkdir -p /home/ubuntu/.config/xfce4
cat > /home/ubuntu/.config/xfce4/helpers.rc << 'HELPERS'
# XFCE Helpers
TerminalEmulator=xfce4-terminal
HELPERS

chown -R ubuntu:ubuntu /home/ubuntu/.config
EOF

    print_success "Desktop files configured"
}

# Main execution
create_desktop_directory
create_virtualhere_shortcut
create_maestro_shortcut
create_desktop_readme
trust_desktop_files

print_success "Desktop shortcuts and documentation created"
