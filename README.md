## WSL2-with-systemd

Tested on Ubuntu 20.04 and 20.10

# Download and import image
Download image from https://cloud-images.ubuntu.com/ and import it on wsl

```bash
wsl --import DISTRO TARGETLOCATION ROOTFS
```
# Setup
Login and run the wslsetup script

```bash
wsl -d DISTRO
```
Start the script with sudo
```bash
chmod +x wslsetup.sh
sudo ./wslsetup.sh
```
Reboot wsl and start your distro with your created user
```bash
WSL --shutdown
wsl -d DISTRO
```

# Install desktop environment

## XFCE
```bash
sudo apt update && sudo apt -y upgrade
sudo apt install xfce4 xfce4-terminal xfce4-goodies -y
```
Select Lightdm when asked
### Create startscript
To reduce terminal output use follwing steps

```bash
sudo cat >> /bin/startxfce <<EOF
#!/bin/bash
xfce4-session > /dev/null 2>&1
EOF
sudo chmod +x /bin/startxfce
```
To start xfce after login use
```bash
startxfce
```

## KDE
```bash
sudo apt update && sudo apt -y upgrade
sudo apt install kde-standard -y
```
Select sddm when asked

### Create startscript
To reduce terminal output use follwing steps

```bash
sudo cat >> /bin/startplasma <<EOF
#!/bin/bash
startplasma-x11 > /dev/null 2>&1
EOF
sudo chmod +x /bin/startplasma
```
To start xfce after login use
```bash
startplasma
```

# Custom Kernel

Get a kernel e.g. from the
Official Microsoft Kernel repository
https://github.com/microsoft/WSL2-Linux-Kernel

Modify Microsoft/config-wsl for your needs.

```bash
sudo apt install build-essential flex bison libssl-dev libelf-dev
make -j4 KCONFIG_CONFIG=Microsoft/config-wsl
```
After the build copy the vmlinux to a folder in your windows system

```bash
mkdir <path/to/kernel/dir/>
cp vmlinux <path/to/kernel/dir/>
```

Add it to global wsl conf in C:\User\<USER>\.wslconfig
```
[wsl2]
kernel=<DRIVE:\\path\\to\\kernel\\dir\\vmlinux\\>
```
*Be sure to use "\\\\" in your path.*

Now restart WSL and check the kernel version
```
wsl --shutdown
wsl -d <distribution>
uname -a
```