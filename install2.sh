#!/bin/bash
clear

# ----------------------------
# Cleanup old setup files
# ----------------------------
rm -rf setup.sh /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain /var/lib/ipvps.conf

# ----------------------------
# Color definitions
# ----------------------------
red='\e[1;31m'; green='\e[0;32m'; yell='\e[1;33m'; tyblue='\e[1;36m'
BRed='\e[1;31m'; BGreen='\e[1;32m'; BYellow='\e[1;33m'; BBlue='\e[1;34m'
NC='\e[0m'
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

# ----------------------------
# CDN for remote scripts
# ----------------------------
CDN="https://raw.githubusercontent.com/noelrubio143/vlessws/refs/heads/main/ssh"

# ----------------------------
# Root and virtualization checks
# ----------------------------
if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root"
    exit 1
fi
if [ "$(systemd-detect-virt)" == "openvz" ]; then
    echo "OpenVZ is not supported"
    exit 1
fi

# ----------------------------
# Prepare hostname and hosts
# ----------------------------
localip=$(hostname -I | cut -d' ' -f1)
hst=$(hostname)
dart=$(grep -w "$hst" /etc/hosts | awk '{print $2}')
if [[ "$hst" != "$dart" ]]; then
    echo "$localip $(hostname)" >> /etc/hosts
fi

mkdir -p /etc/xray /etc/v2ray
touch /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain /etc/v2ray/scdomain

# ----------------------------
# Kernel headers check
# ----------------------------
totet=$(uname -r)
REQUIRED_PKG="linux-headers-$totet"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG | grep "install ok installed")
if [ "" = "$PKG_OK" ]; then
    echo "[${BRed}WARNING${NC}] Missing $REQUIRED_PKG. Installing..."
    apt-get update
    apt-get --yes install $REQUIRED_PKG
    echo "[${BBlue}INFO${NC}] After this, run the script again if needed."
    read -p "Press Enter to continue..."
else
    echo "[${BGreen}INFO${NC}] Required headers installed."
fi

# ----------------------------
# System configuration
# ----------------------------
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1

apt install git curl python jq -y >/dev/null 2>&1
mkdir -p /var/lib/
echo "IP=" >> /var/lib/ipvps.conf

# ----------------------------
# Domain setup
# ----------------------------
clear
echo -e "$BBlue    SETUP DOMAIN VPS     $NC"
echo -e "$BYellow-----------------------$NC"
echo -e "$BGreen 2. Your Domain $NC"
echo -e "$BYellow-----------------------$NC"
read -rp " TYPE 2 : " dns

if test $dns -eq 1; then
    wget -q -O /root/cf "${CDN}/cf" >/dev/null 2>&1
    chmod +x /root/cf
    echo "[${BGreen}INFO${NC}] You can inspect /root/cf before execution."
    read -p "Run cf script now? (y/n): " runcf
    if [[ "$runcf" =~ ^[Yy]$ ]]; then
        bash /root/cf | tee /root/install.log
    fi
elif test $dns -eq 2; then
    read -rp "Enter Your Domain : " dom
    echo "$dom" > /root/scdomain
    echo "$dom" > /etc/xray/scdomain
    echo "$dom" > /etc/xray/domain
    echo "$dom" > /etc/v2ray/domain
    echo "$dom" > /root/domain
    echo "IP=$dom" > /var/lib/ipvps.conf
else
    echo "Not Found Argument"
    exit 1
fi

# ----------------------------
# Function to safely download and run scripts
# ----------------------------
safe_run() {
    local url="$1"
    local filename="$2"
    echo "[${BGreen}INFO${NC}] Downloading $filename..."
    curl -sSL -o "/root/$filename" "$url"
    chmod +x "/root/$filename"
    echo "[${BYellow}NOTICE${NC}] You can inspect /root/$filename before running it."
    read -p "Run $filename now? (y/n): " runfile
    if [[ "$runfile" =~ ^[Yy]$ ]]; then
        /root/$filename
    else
        echo "[${BRed}WARNING${NC}] Skipped $filename execution."
    fi
}

# ----------------------------
# Install SSH + WebSocket
# ----------------------------
safe_run "https://raw.githubusercontent.com/noelrubio143/vlessws/refs/heads/main/ssh/ssh-vpn.sh" "ssh-vpn.sh"

# ----------------------------
# Install Xray
# ----------------------------
safe_run "https://raw.githubusercontent.com/noelrubio143/vlessws/refs/heads/main/xray/ins-xray.sh" "ins-xray.sh"

# ----------------------------
# Install SSH WebSocket helper
# ----------------------------
safe_run "https://raw.githubusercontent.com/noelrubio143/vlessws/refs/heads/main/sshws/insshws.sh" "insshws.sh"

# ----------------------------
# Profile setup for menu
# ----------------------------
cat > /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.
if [ "\$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi
mesg n || true
clear
menu
END
chmod 644 /root/.profile

# ----------------------------
# Log files
# ----------------------------
for f in ssh vmess vless trojan shadowsocks; do
    [[ ! -f "/etc/log-create-$f.log" ]] && echo "Log $f Account " > /etc/log-create-$f.log
done

# ----------------------------
# Additional scripts
# ----------------------------
safe_run "https://raw.githubusercontent.com/noelrubio143/v2raysshws/refs/heads/main/dnsdisable.sh" "dnsdisable.sh"
safe_run "https://raw.githubusercontent.com/noelrubio143/v2raysshws/refs/heads/main/dropbearconfig.sh" "dropbearconfig.sh"
safe_run "https://raw.githubusercontent.com/noelrubio143/v2raysshws/refs/heads/main/dropbear.sh" "dropbear.sh"
safe_run "https://raw.githubusercontent.com/noelrubio143/v2raysshws/refs/heads/main/swap.sh" "swap.sh"

sudo systemctl start dropbear
sudo systemctl enable dropbear

# ----------------------------
# Reboot prompt
# ----------------------------
read -p "[ ${yell}WARNING${NC} ] Reboot now? (y/n): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    reboot
else
    echo "Reboot skipped. Setup complete!"
fi
