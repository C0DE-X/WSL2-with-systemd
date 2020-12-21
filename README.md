## WSL2-with-systemd

Tested on Ubuntu 20.04 and 20.10

# Download and import image
Download image from https://cloud-images.ubuntu.com/ and import it on wsl

```bash
wsl --import <DISTRO> <TARGETLOCATION> <ROOTFS>
```
- DISTRO: name you want to call your distro
- TARGETLOCATION: path where the vhdx file should be placed
- ROOTFS: full path of the rootfs image you want to import

# Setup
Login and run the wslsetup script

```bash
wsl -d <DISTRO>
```
Start the script with sudo
```bash
chmod +x wslsetup.sh
sudo ./wslsetup.sh
```
Reboot wsl and start your distro. It gets started with the user you created.
```bash
WSL --shutdown
wsl -d <DISTRO>
```
*use -u root* to login as root
# Install desktop environment

Tested desktop environments for ubuntu with X410 as xserver. (https://x410.dev/)
## XFCE
```bash
sudo apt update && sudo apt -y upgrade
sudo apt install xfce4 xfce4-terminal xfce4-goodies -y
```
Select lightdm when asked
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
# Pulseaudio
Under Windows download the pulseaudio zip file. https://www.freedesktop.org/wiki/Software/PulseAudio/Ports/Windows/Support/ and unzip it in the directory you want it to run.

## Changes
In the file etc/pulse/default.pa \
change line 42
```diff
- load-module module-waveout sink_name=output source_name=input
+ load-module module-waveout sink_name=output source_name=input record=0
```
change line 62
```diff
- #load-module module-native-protocol-tcp
+ load-module module-native-protocol-tcp auth-ip-acl=0.0.0.0 auth-anonymous=1
```

in the file etc/pulse/deamon.conf \
change line 39
```diff
- ; exit-idle-time = 20
+ exit-idle-time = -1
```

### Pulseaudio task
Add a task to windows to start pulseaudio server on user login
- Open Windows Task Scheduler and create task
- Name: pulseaudio
- Trigger: on user login
- Action: Start program
- Program: <path\to\pulseaudio\bin\pulseaudio.exe>
    - Arguments: -D

Right click on the task and go to properties.\
Check Invisible and for Windows 10

Run bin\pulseaudio.exe in terminal to access network rules and accept for both privat and public. Close application and log out and in again and check the status of the task. \
Pulseaudio-device should now be available in WSL. The changes to access the pulseaudio-server from wsl are already made in the wslsetup script (*export PULSE_SERVER=tcp:$NAMESERVER* in bash.bashrc). 

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

Add it to global wsl conf in C:\User\\<USER>\\.wslconfig
```
[wsl2]
kernel=<DRIVE:\\path\\to\\kernel\\dir\\vmlinux>
```
*Be sure to use "\\\\" in your path.*

Now restart WSL and check the kernel version
```
wsl --shutdown
wsl -d <DISTRO>
uname -a
```