# Droidnet Maestro Control Center for Mac

A tool to help you run Pololu Maestro Control Center on your Mac by creating an Ubuntu virtual machine with remote USB access to the Droidnet server.

## Important Disclaimer

**This software is provided as-is, without warranty or support.** It is offered to help users get started running Maestro Control Center on macOS, but comes with no guarantees. Use at your own risk.

## What This Does

Maestro Control Center is a Linux-only application for controlling Pololu Maestro servo controllers. This installer automatically sets up:

1. **Ubuntu Virtual Machine** - A complete Linux environment running on your Mac
2. **Web-based Desktop** - Access the Linux desktop from your browser (no VNC client needed)
3. **VirtualHere USB** - Connect to USB devices attached to your VirtualHere server (auto-discovered on network)
4. **Pre-installed Maestro** - Control Center ready to use

## System Requirements

- **macOS**: 11 (Big Sur) or newer
- **RAM**: 8GB minimum (16GB recommended)
- **Disk Space**: 25GB free
- **Network**: Active network connection (Ethernet or Wi-Fi) on the same network as your VirtualHere server
- **Hardware**: Apple Silicon (M1/M2/M3) or Intel Mac

### Network Requirements

**Your Mac must have a network interface that provides:**

1. ✓ Connection to your VirtualHere server (same local network)
2. ✓ Internet access (required during installation to download packages)
3. ✓ Private IP range (192.168.x.x, 10.x.x.x, or 172.16-31.x.x)

**Supported Configurations:**

- ✓ Ethernet or Wi-Fi - both fully supported
- ✓ Single or multiple interfaces - installer will guide you through selection
- ✓ USB/Thunderbolt ethernet adapters - fully supported
- ✓ Mac Mini with built-in Ethernet port - fully supported

**Important Notes:**

- If you have multiple network interfaces, the installer will ask you to select which one connects to your VirtualHere server
- The selected interface **must have both** local network access and internet access during installation
- **Split Network Scenario:** If your VirtualHere server is on a network without internet access, you'll need to temporarily connect that network to the internet during installation, or use a different network that has both

## Installation

### Step 1: Unzip the Package

Double-click `DroidnetMaestro.zip` to extract it.

### Step 2: Run the Installer

1. Open the `DroidnetMaestro` folder
2. **Right-click** `install.sh` and select **Open With > Terminal**
   - Or drag `install.sh` into Terminal and press Enter
3. **Do not run with sudo** - the installer will request permissions when needed

### Step 3: Choose VirtualHere Mode

When prompted, choose how you want to manage USB device connections:

- **GUI Mode** (recommended for most users)
  - Desktop shortcut opens a graphical VirtualHere client
  - Easy point-and-click to connect/disconnect devices
  - Best for visual preference

- **CLI Mode** (for terminal users)
  - Desktop shortcut opens terminal with VirtualHere commands
  - More lightweight (no GUI overhead)
  - Best for advanced users who prefer command-line

### Step 4: Wait for Installation

Installation takes **10-15 minutes** depending on your internet speed. The installer will:

- Install Homebrew (if needed)
- Install Multipass VM manager (if needed)
- Create an Ubuntu VM with bridged networking
- Install desktop environment, VNC, and noVNC
- Install VirtualHere USB client
- Install Maestro Control Center
- Configure all services to auto-start

You'll see progress messages for each step. **Do not close the terminal window.**

### Step 5: Save Your Connection Info

When installation completes, you'll see:

```
✓ Installation complete!

VM IP Address: <VM_IP>
Desktop URL: http://<VM_IP>:6080/vnc.html

A shortcut has been saved to your Desktop.
```

**Important**: The VM IP address may change if your network changes. See "Getting the URL" below if you lose it.

## First-Time Setup

### 1. Access the Linux Desktop

Open your web browser and navigate to the URL shown during installation:

```
http://<VM_IP>:6080/vnc.html
```

Or click the shortcut file saved to your Mac Desktop.

**Alternative**: You can also use an RDP client:
- Server: `<VM_IP>:3389`
- Username: `ubuntu`
- Password: `maestro`

### 2. Connect USB Devices

Once you see the Ubuntu desktop in your browser:

1. **Double-click** the "VirtualHere Control" icon on the desktop
2. **GUI Mode**: A window will open showing available devices - right-click a device and select "Use this device"
3. **CLI Mode**: A terminal will open with instructions - enter commands like `USE,droidnet.114`

Available devices on Droidnet:
- `droidnet.114` - CP2102N USB to UART Bridge Controller (Maestro device)
- `droidnet.112` - CSR8510 A10 Bluetooth adapter

### 3. Launch Maestro Control Center

Double-click the "Maestro Control Center" icon on the desktop. The application should detect your connected USB device.

## Daily Usage

### Starting the VM

The VM does **not** start automatically. Each time you want to use it:

```bash
multipass start droidnet-maestro
```

Then get the VM's current IP address:

```bash
multipass info droidnet-maestro | grep IPv4
```

The IP shown is where you'll access the desktop: `http://IP:6080/vnc.html`

### Stopping the VM

When you're done:

```bash
multipass stop droidnet-maestro
```

### Getting the URL

If you forget the URL or the IP address changes:

```bash
multipass info droidnet-maestro
```

Look for the IPv4 address on your local network subnet, then access:
```
http://<VM_IP>:6080/vnc.html
```

### Checking VM Status

```bash
multipass list
```

This shows all VMs and their status (Running/Stopped).

## How It Works

```
Your Mac
  └─ Web Browser → http://VM-IP:6080
                      └─ noVNC Web Interface
                          └─ Ubuntu Desktop (XFCE)
                              ├─ VirtualHere USB Client
                              │   └─ Connects to: Your VirtualHere Server (auto-discovered)
                              │       └─ USB Devices (Maestro controllers)
                              └─ Maestro Control Center
```

The VM uses **bridged networking**, meaning it gets its own IP address on your local network (same subnet as your Mac) just like any other device. This is necessary for VirtualHere to work with your VirtualHere server.

## Troubleshooting

### "I lost the desktop URL"

Run this command to get the current IP:
```bash
multipass info droidnet-maestro | grep IPv4
```

Then access: `http://[that-IP]:6080/vnc.html`

### "The VM won't start"

Check VM status:
```bash
multipass list
```

Try restarting Multipass:
```bash
sudo launchctl stop com.canonical.multipassd
sudo launchctl start com.canonical.multipassd
```

Then try starting the VM again.

### "I can't connect to the desktop URL"

1. Verify the VM is running: `multipass list`
2. If stopped, start it: `multipass start droidnet-maestro`
3. Verify the IP address: `multipass info droidnet-maestro | grep IPv4`
4. Make sure you're on the same network as your Mac

### "No active network interfaces found" (during installation)

1. Check System Preferences → Network
2. Ensure at least one interface is connected and has an IP address
3. Run `ifconfig` in Terminal to verify interfaces are up
4. Try connecting to a network and running the installer again

### "Interface does not have internet access" (during installation)

This error means the selected network interface cannot reach the internet, which is required for installation.

**Solutions:**

1. **Connect to internet:** Ensure your network has internet access and try again
2. **Select different interface:** If you have multiple interfaces, the installer will let you choose another one
3. **Temporary solution:** If your VirtualHere server is on an isolated network, temporarily connect that network to the internet during installation

**To verify internet:**

```bash
ping -c 1 8.8.8.8
```

### "USB devices don't appear in VirtualHere"

1. Make sure you're on the same network as your VirtualHere server
2. Verify your VirtualHere server is running and discoverable on the network
3. Run the LIST command to see discovered servers (check desktop shortcuts)
4. Try restarting the VirtualHere service inside the VM:
   ```bash
   multipass exec droidnet-maestro -- sudo systemctl restart vhclient
   ```

### "Maestro doesn't detect the USB device"

1. First, connect the device using VirtualHere Control (see "Connect USB Devices" above)
2. Verify the device is connected in a terminal inside the VM:
   ```bash
   lsusb
   ```
   You should see your device listed
3. Try restarting Maestro Control Center

### "Installation failed during Maestro download"

Maestro installation can fail if Pololu's website is temporarily down. The installer will continue anyway. To install Maestro manually:

1. Access the VM desktop
2. Open Firefox browser inside the VM
3. Download from: https://www.pololu.com/docs/0J40/3.a
4. Follow Pololu's Linux installation instructions

### "The IP address keeps changing"

This is normal with DHCP. Your router assigns IP addresses dynamically. You can:

1. Use `multipass info droidnet-maestro` to always get the current IP
2. Bookmark the URL in your browser and update it when it changes
3. (Advanced) Configure a static IP in your router for the VM's MAC address

### "Multipass asks for permissions"

macOS will ask you to grant permissions for Multipass to create VMs. Click **Allow** in System Preferences > Security & Privacy when prompted.

### "Installation failed at network detection"

Make sure you're connected to WiFi. The installer requires an active WiFi connection on the `en0` interface. Ethernet connections are not currently supported.

## Advanced Usage

### Accessing the VM via SSH

```bash
multipass shell droidnet-maestro
```

This gives you a command-line terminal inside the VM.

### Viewing Service Logs

Inside the VM, check service status:

```bash
multipass exec droidnet-maestro -- sudo supervisorctl status
```

View VNC logs:
```bash
multipass exec droidnet-maestro -- sudo tail -f /var/log/supervisor/vncserver-stdout---supervisor-*.log
```

### Managing VirtualHere Manually (CLI Mode)

If you chose CLI mode, you can control VirtualHere from the command line inside the VM:

List available devices:
```bash
multipass exec droidnet-maestro -- /usr/sbin/vhclientarm64 -t "LIST"
```

Connect a device:
```bash
multipass exec droidnet-maestro -- /usr/sbin/vhclientarm64 -t "USE,droidnet.114"
```

Disconnect a device:
```bash
multipass exec droidnet-maestro -- /usr/sbin/vhclientarm64 -t "STOP USING,droidnet.114"
```

### Changing VM Resources

If you need more CPU, RAM, or disk:

1. Stop and delete the existing VM:
   ```bash
   multipass stop droidnet-maestro
   multipass delete droidnet-maestro
   multipass purge
   ```

2. Edit the VM creation settings in `scripts/03-create-vm.sh`:
   - Change `--cpus 2` to desired CPU count
   - Change `--memory 4G` to desired RAM (e.g., `8G`)
   - Change `--disk 5G` to desired disk (e.g., `10G`)

3. Run the installer again

## Uninstallation

### Remove the VM

```bash
multipass stop droidnet-maestro
multipass delete droidnet-maestro
multipass purge
```

### Remove Multipass (Optional)

If you want to completely remove Multipass:

```bash
brew uninstall multipass
```

### Clean Up Desktop Files

Delete the URL shortcut file from your Mac Desktop (named something like `Droidnet-Maestro-URL.txt`).

## Technical Details

### Components Installed

**On your Mac:**
- Homebrew (package manager)
- Multipass (VM manager)

**Inside the VM:**
- Ubuntu 22.04 LTS
- XFCE desktop environment
- TightVNC server (port 5901)
- noVNC web interface (port 6080)
- xrdp RDP server (port 3389)
- VirtualHere USB client
- Pololu Maestro Control Center (via Mono)

### Networking

- **Type**: Bridged to selected network interface (Ethernet or Wi-Fi)
- **IP Range**: Same subnet as your Mac
- **Required Ports**:
  - 6080 (noVNC web interface)
  - 5901 (VNC server)
  - 3389 (RDP server)
  - 7575 (VirtualHere server on Droidnet)

### VM Specifications

- **CPUs**: 2
- **RAM**: 4GB
- **Disk**: 5GB
- **OS**: Ubuntu 22.04 LTS (ARM64 or AMD64 depending on your Mac)

### VirtualHere Configuration

The VirtualHere client runs in **foreground mode** (not as a background daemon) to comply with the Trial Edition license restrictions on the Droidnet server.

**CLI Mode**: Runs as a systemd service that auto-starts with the VM
**GUI Mode**: Launches manually via desktop shortcut

### Passwords

- **VNC Password**: `maestro`
- **Ubuntu User**: `ubuntu`
- **Ubuntu Password**: `maestro`
- **RDP**: Username `ubuntu`, password `maestro`

## Version Information

- **Target macOS**: 11+ (Big Sur or newer)
- **Ubuntu Version**: 22.04 LTS
- **VirtualHere**: Latest ARM64/AMD64 Linux client from virtualhere.com
- **Maestro**: Latest version from pololu.com (241004 as of last update)

## Support

This tool is provided without official support. For issues:

- **Multipass**: See https://multipass.run/docs
- **VirtualHere**: See https://www.virtualhere.com/home
- **Maestro**: See https://www.pololu.com/docs/0J40

## Credits

**Original Concept and Implementation**: This project was the original brainchild of Jerrod Hofferth. All credit for the idea and initial implementation goes to him.

This installer automates the setup of several open-source and commercial tools to provide a seamless experience for Mac users who need to access Linux-only servo controller software with remote USB devices.
