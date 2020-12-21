#!/bin/bash
echo "******************************************"
echo "Starting wsl setup"
echo "******************************************"

# create user
echo "Create user"
echo -n "Enter your username: "
read USERNAME
useradd -m -s /bin/bash -G sudo ${USERNAME}
passwd ${USERNAME}

# udpate and install packages
sudo apt update && sudo apt upgrade -y
sudo apt update && sudo apt install -yqq wsl daemonize dbus-user-session fontconfig
sudo apt install --reinstall snapd

# create wsl config
sudo cat >> /etc/wsl.conf <<EOF
[automount]
enabled = true
options = "metadata,uid=1000,gid=1000,umask=22,fmask=11,case=off"
mountFsTab = true
crossDistro = true

[network]
generateHosts = false
generateResolvConf = true

[interop]
enabled = true
appendWindowsPath = true

[user]
default = $USERNAME
EOF

# edit sudo rights
sudo sed -i '/sudo/s/ALL:ALL)/ALL:ALL) NOPASSWD:/g' /etc/sudoers

sudo cat >> /etc/sudoers.d/systemd-namespace <<EOF
Defaults        env_keep += WSLPATH
Defaults        env_keep += WSLENV
Defaults        env_keep += WSL_INTEROP
Defaults        env_keep += WSL_DISTRO_NAME
Defaults        env_keep += PRE_NAMESPACE_PATH
Defaults        env_keep += PRE_NAMESPACE_PWD
%sudo ALL=(ALL) NOPASSWD: /usr/sbin/enter-systemd-namespace
EOF

# solve network policy
sudo cat >> /etc/polkit-1/localauthority/50-local.d/50-allow-network-manager.pkla <<EOF
[Network Manager all Users]
Identity=unix-user:*
Action=org.freedesktop.NetworkManager.settings.modify.system;org.freedesktop.NetworkManager.network-control
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# solve repo refresh policy
sudo cat >> /etc/polkit-1/localauthority/50-local.d/46-allow-update-repo.pkla <<EOF
[Allow Package Management all Users]
Identity=unix-user:*
Action=org.freedesktop.packagekit.system-sources-refresh
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

echo "******************************************"
echo "Setting up systemd"
echo "******************************************"
## create systemd-namespace scripts
# systemd start script
sudo cat >> /usr/sbin/start-systemd-namespace <<EOF
#!/bin/sh

SYSTEMD_EXE="/lib/systemd/systemd --unit=basic.target"
SYSTEMD_PID="\$(ps -eo pid=,args= | awk '\$2" "\$3=="'"\$SYSTEMD_EXE"'" {print \$1}')"
if [ "\$LOGNAME" != "root" ] && ( [ -z "\$SYSTEMD_PID" ] || [ "\$SYSTEMD_PID" != "1" ] ); then
    export | sed -e 's/^declare -x //;/^IFS=".*[^"]\$/{N;s/\n//}' | \
        grep -E -v "^(BASH|BASH_ENV|DIRSTACK|EUID|GROUPS|HOME|HOSTNAME|\
IFS|LANG|LOGNAME|MACHTYPE|MAIL|NAME|OLDPWD|OPTERR|\
OSTYPE|PATH|PIPESTATUS|POSIXLY_CORRECT|PPID|PS1|PS4|\
SHELL|SHELLOPTS|SHLVL|SYSTEMD_PID|UID|USER|_)(=|\\\$)" > "\$HOME/.systemd-env"
    export PRE_NAMESPACE_PATH="\$PATH"
    export PRE_NAMESPACE_PWD="\$(pwd)"
    exec sudo /usr/sbin/enter-systemd-namespace "\$BASH_EXECUTION_STRING"
fi
if [ -n "\$PRE_NAMESPACE_PATH" ]; then
    export PATH="\$PRE_NAMESPACE_PATH"
    unset PRE_NAMESPACE_PATH
fi
if [ -n "\$PRE_NAMESPACE_PWD" ]; then
    cd "\$PRE_NAMESPACE_PWD"
    unset PRE_NAMESPACE_PWD
fi
EOF

# systemd enter script
sudo cat >> /usr/sbin/enter-systemd-namespace <<EOF
#!/bin/bash --norc

if [ "\$LOGNAME" != "root" ]; then
    echo "You need to run \$0 through sudo"
    exit 1
fi

if [ -x /usr/sbin/daemonize ]; then
    DAEMONIZE=/usr/sbin/daemonize
elif [ -x /usr/bin/daemonize ]; then
    DAEMONIZE=/usr/bin/daemonize
else
    echo "Cannot execute daemonize to start systemd."
    exit 1
fi

if ! command -v /lib/systemd/systemd > /dev/null; then
    echo "Cannot execute /lib/systemd/systemd."
    exit 1
fi

if ! command -v /usr/bin/unshare > /dev/null; then
    echo "Cannot execute /usr/bin/unshare."
    exit 1
fi

SYSTEMD_EXE="/lib/systemd/systemd --unit=basic.target"
SYSTEMD_PID="\$(ps -eo pid=,args= | awk '\$2" "\$3=="'"\$SYSTEMD_EXE"'" {print \$1}')"
if [ -z "\$SYSTEMD_PID" ]; then
    "\$DAEMONIZE" /usr/bin/unshare --fork --pid --mount-proc bash -c 'export container=wsl; mount -t binfmt_misc binfmt_misc /proc/sys/fs/binfmt_misc; exec '"\$SYSTEMD_EXE"
    while [ -z "\$SYSTEMD_PID" ]; do
        sleep 1
        SYSTEMD_PID="\$(ps -eo pid=,args= | awk '\$2" "\$3=="'"\$SYSTEMD_EXE"'" {print \$1}')"
    done
fi

USER_HOME="\$(getent passwd | awk -F: '\$1=="'"\$SUDO_USER"'" {print \$6}')"
if [ -n "\$SYSTEMD_PID" ] && [ "\$SYSTEMD_PID" != "1" ]; then
    if [ -n "\$1" ] && [ "\$1" != "bash --login" ] && [ "\$1" != "/bin/bash --login" ]; then
        exec /usr/bin/nsenter -t "\$SYSTEMD_PID" -m -p \
            /usr/bin/sudo -H -u "\$SUDO_USER" \
            /bin/bash -c 'set -a; [ -f "\$HOME/.systemd-env" ] && source "\$HOME/.systemd-env"; set +a; exec bash -c '"\$(printf "%q" "\$@")"
    else
        exec /usr/bin/nsenter -t "\$SYSTEMD_PID" -m -p \
            /bin/login -p -f "\$SUDO_USER" \
            \$([ -f "\$USER_HOME/.systemd-env" ] && /bin/cat "\$USER_HOME/.systemd-env" | xargs printf ' %q')
    fi
    echo "Error: unable to use systemd"
    exit 1
fi
EOF

sudo chmod +x /usr/sbin/enter-systemd-namespace

# edit the bash.bashrc to start with systemd
sudo sed -i '1 a \
# Start or enter a PID namespace in WSL2 \
source /usr/sbin/start-systemd-namespace \
# start all mounts in system (snap related problem) \
for i in \$(ls /etc/systemd/system/*.mount); do sudo systemctl start \$(basename \$i); done' /etc/bash.bashrc

sudo tee -a /etc/bash.bashrc >/dev/null <<EOF
NAMESERVER=$(cat /etc/resolv.conf | grep nameserver | cut -d ' ' -f 2)
export DISPLAY=$NAMESERVER:0
export PULSE_SERVER=tcp:$NAMESERVER
export DONT_PROMPT_WSL_INSTALL=1
EOF

# remove systemd rules
sudo rm -f /etc/systemd/user/sockets.target.wants/dirmngr.socket
sudo rm -f /etc/systemd/user/sockets.target.wants/gpg-agent*.socket
sudo rm -f /etc/systemd/user/sockets.target.wants/multipathd.socket
sudo rm -f /lib/systemd/system/sysinit.target.wants/proc-sys-fs-binfmt_misc.automount
sudo rm -f /lib/systemd/system/sysinit.target.wants/proc-sys-fs-binfmt_misc.mount
sudo rm -f /lib/systemd/system/sysinit.target.wants/systemd-binfmt.service

echo "******************************************"
echo "WSL system setup done"
echo "******************************************"