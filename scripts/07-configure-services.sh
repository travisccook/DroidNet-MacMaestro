#!/bin/bash

###############################################################################
# Phase 7: Configure Services
# Sets up systemd service for VirtualHere and supervisor for VNC/noVNC
###############################################################################

create_virtualhere_service() {
    print_step "Creating VirtualHere systemd service..."

    # CRITICAL: Must NOT use -n flag (daemon mode) due to trial edition restrictions
    multipass exec "$VM_NAME" -- sudo bash <<'EOF'
cat > /etc/systemd/system/vhclient.service << 'VHSERVICE'
[Unit]
Description=VirtualHere USB Client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/sbin/vhclientarm64
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
VHSERVICE
EOF

    if [[ $? -ne 0 ]]; then
        print_error "Failed to create VirtualHere service file"
        exit 1
    fi

    print_success "VirtualHere service created"
}

enable_virtualhere_service() {
    print_step "Enabling VirtualHere service..."

    multipass exec "$VM_NAME" -- sudo systemctl daemon-reload
    multipass exec "$VM_NAME" -- sudo systemctl enable vhclient.service

    # Use --no-block to avoid hanging if service takes time to start
    multipass exec "$VM_NAME" -- sudo systemctl start --no-block vhclient.service

    print_success "VirtualHere service enabled and started"
    echo "Note: Service is starting in background. Check status with: multipass exec $VM_NAME -- sudo systemctl status vhclient"
}

create_supervisor_config() {
    print_step "Creating supervisor configuration for desktop services..."

    multipass exec "$VM_NAME" -- sudo bash <<EOF
cat > /etc/supervisor/conf.d/desktop.conf << 'SUPERVISOR'
[program:vncserver]
command=/usr/bin/Xvnc :1 -geometry 1920x1080 -depth 24 -rfbport 5901 -rfbauth /home/ubuntu/.vnc/passwd -alwaysshared -desktop "Droidnet Maestro"
user=ubuntu
environment=HOME="/home/ubuntu",USER="ubuntu",DISPLAY=":1"
autostart=true
autorestart=true
startsecs=5
stdout_logfile=/var/log/supervisor/vncserver.log
stderr_logfile=/var/log/supervisor/vncserver_err.log
priority=10

[program:xfce-session]
command=/bin/bash -c "sleep 3 && /usr/bin/startxfce4"
user=ubuntu
environment=HOME="/home/ubuntu",USER="ubuntu",DISPLAY=":1",XDG_CURRENT_DESKTOP="XFCE",XDG_SESSION_TYPE="x11",DBUS_SESSION_BUS_ADDRESS="autolaunch:"
autostart=true
autorestart=true
startsecs=8
stdout_logfile=/var/log/supervisor/xfce.log
stderr_logfile=/var/log/supervisor/xfce_err.log
priority=20

[program:novnc]
command=$NOVNC_PATH --vnc localhost:5901 --listen 6080
user=ubuntu
environment=HOME="/home/ubuntu",USER="ubuntu"
autostart=true
autorestart=true
startsecs=5
stdout_logfile=/var/log/supervisor/novnc.log
stderr_logfile=/var/log/supervisor/novnc_err.log
priority=30
SUPERVISOR
EOF

    if [[ $? -ne 0 ]]; then
        print_error "Failed to create supervisor configuration"
        exit 1
    fi

    print_success "Supervisor configuration created"
}

stop_existing_services() {
    print_step "Stopping any existing desktop services..."

    # Stop all supervisor services
    multipass exec "$VM_NAME" -- sudo supervisorctl stop all 2>/dev/null || true

    # Kill any existing VNC servers
    multipass exec "$VM_NAME" -- bash <<'EOF'
sudo -u ubuntu vncserver -kill :1 2>/dev/null || true
sudo pkill -9 -u ubuntu Xvnc 2>/dev/null || true
sudo pkill -9 -u ubuntu xfce4-session 2>/dev/null || true
sleep 2
EOF

    print_success "Existing services stopped"
}

verify_novnc_path() {
    print_step "Verifying noVNC installation path..."

    # Check possible noVNC paths
    if multipass exec "$VM_NAME" -- test -f /usr/share/novnc/utils/novnc_proxy; then
        NOVNC_PATH="/usr/share/novnc/utils/novnc_proxy"
        print_success "Found noVNC at: $NOVNC_PATH"
    elif multipass exec "$VM_NAME" -- test -f /usr/share/novnc/utils/launch.sh; then
        NOVNC_PATH="/usr/share/novnc/utils/launch.sh"
        print_success "Found noVNC at: $NOVNC_PATH"
    else
        print_error "Could not find noVNC proxy script"
        echo "Checking installed files..."
        multipass exec "$VM_NAME" -- find /usr/share/novnc -name "*proxy*" -o -name "launch*" 2>/dev/null || true
        exit 1
    fi

    export NOVNC_PATH
}

start_supervisor_services() {
    print_step "Starting desktop services via supervisor..."

    # Reload supervisor configuration
    multipass exec "$VM_NAME" -- sudo supervisorctl reread
    multipass exec "$VM_NAME" -- sudo supervisorctl update

    # Start services
    multipass exec "$VM_NAME" -- sudo supervisorctl start vncserver
    multipass exec "$VM_NAME" -- sudo supervisorctl start novnc

    if [[ $? -ne 0 ]]; then
        print_warning "Some services may not have started correctly"
        echo "Checking status..."
    fi

    # Give services time to start
    sleep 5

    # Check status
    print_step "Checking service status..."
    multipass exec "$VM_NAME" -- sudo supervisorctl status
}

verify_vnc_running() {
    print_step "Verifying VNC server is accessible..."

    # Check if VNC port is listening
    if multipass exec "$VM_NAME" -- sudo netstat -tuln | grep -q ":5901"; then
        print_success "VNC server is listening on port 5901"
    else
        print_warning "VNC server port 5901 may not be accessible"
        echo "This will be tested in the final verification..."
    fi
}

verify_novnc_running() {
    print_step "Verifying noVNC web interface is accessible..."

    # Check if noVNC port is listening
    if multipass exec "$VM_NAME" -- sudo netstat -tuln | grep -q ":6080"; then
        print_success "noVNC is listening on port 6080"
    else
        print_warning "noVNC port 6080 may not be accessible"
        echo "This will be tested in the final verification..."
    fi
}

# Main execution
# Only create VirtualHere systemd service for CLI mode
# GUI mode uses autostart configured in phase 5
if [[ "$VIRTUALHERE_MODE" == "cli" ]]; then
    create_virtualhere_service
    enable_virtualhere_service
else
    print_step "Skipping VirtualHere service creation (GUI mode - uses autostart)"
fi

verify_novnc_path
stop_existing_services
create_supervisor_config
start_supervisor_services
verify_vnc_running
verify_novnc_running

print_success "All services configured and started"
