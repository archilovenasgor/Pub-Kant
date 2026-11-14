#!/bin/bash

set -Eeuo pipefail

# ==========================================
# CONFIGURATION
# ==========================================

PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJD6tElmU5zKJrkh5iAbnvMDON3KLs+aZs9yY25pZHvq u0_a458@localhost"

SSH_DIR="/root/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_DROPIN="/etc/ssh/sshd_config.d/00-ssh-hardening.conf"

echo "======================================"
echo " UNIVERSAL LINUX SERVER SETUP"
echo "======================================"

# ==========================================
# CHECK ROOT
# ==========================================

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] Run this script as root."
    exit 1
fi

# ==========================================
# UPDATE SYSTEM
# ==========================================

echo "[INFO] Detecting package manager..."

if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get upgrade -y
    apt-get install -y curl unzip ca-certificates openssh-server

elif command -v dnf >/dev/null 2>&1; then
    dnf upgrade --refresh -y
    dnf install -y curl unzip ca-certificates openssh-server

elif command -v yum >/dev/null 2>&1; then
    yum update -y
    yum install -y curl unzip ca-certificates openssh-server

elif command -v pacman >/dev/null 2>&1; then
    pacman -Syu --noconfirm
    pacman -S --needed --noconfirm curl unzip ca-certificates openssh

elif command -v zypper >/dev/null 2>&1; then
    zypper refresh
    zypper update -y
    zypper install -y curl unzip ca-certificates openssh

elif command -v apk >/dev/null 2>&1; then
    apk update
    apk upgrade
    apk add curl unzip ca-certificates openssh

else
    echo "[ERROR] Unsupported package manager."
    exit 1
fi

echo "[SUCCESS] System updated."

# ==========================================
# VALIDATE PUBLIC KEY
# ==========================================

echo "[INFO] Validating SSH public key..."

if [[ "$PUBKEY" != ssh-ed25519\ * ]]; then
    echo "[ERROR] Invalid SSH ED25519 public key."
    exit 1
fi

# ==========================================
# SETUP SSH PUBLIC KEY
# ==========================================

echo "[INFO] Configuring SSH public key..."

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

if grep -qxF -- "$PUBKEY" "$AUTH_KEYS"; then
    echo "[INFO] Public key already installed."
else
    echo "$PUBKEY" >> "$AUTH_KEYS"
    echo "[SUCCESS] Public key installed."
fi

# ==========================================
# SSH CONFIGURATION
# ==========================================

echo "[INFO] Configuring SSH security..."

# Backup original configuration
if [[ -f "$SSHD_CONFIG" ]]; then
    cp -a "$SSHD_CONFIG" \
        "${SSHD_CONFIG}.backup.$(date +%Y%m%d-%H%M%S)"
fi

# Create drop-in directory
mkdir -p /etc/ssh/sshd_config.d

# Apply security configuration
cat > "$SSHD_DROPIN" <<'EOF'
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitRootLogin prohibit-password
EOF

# ==========================================
# VALIDATE SSH CONFIGURATION
# ==========================================

echo "[INFO] Validating SSH configuration..."

SSHD_BIN="$(command -v sshd || true)"

if [[ -z "$SSHD_BIN" ]]; then
    echo "[ERROR] sshd binary not found."
    exit 1
fi

if ! "$SSHD_BIN" -t; then
    echo "[ERROR] SSH configuration invalid!"
    rm -f "$SSHD_DROPIN"
    exit 1
fi

echo "[SUCCESS] SSH configuration valid."

# ==========================================
# RESTART SSH
# ==========================================

echo "[INFO] Restarting SSH service..."

if command -v systemctl >/dev/null 2>&1; then
    systemctl enable sshd 2>/dev/null || true
    systemctl enable ssh 2>/dev/null || true

    if systemctl restart sshd 2>/dev/null; then
        echo "[SUCCESS] sshd restarted."
    elif systemctl restart ssh 2>/dev/null; then
        echo "[SUCCESS] ssh restarted."
    else
        echo "[WARNING] Could not restart SSH automatically."
    fi

elif command -v rc-service >/dev/null 2>&1; then
    rc-update add sshd default 2>/dev/null || true
    rc-service sshd restart || true
fi

# ==========================================
# VERIFY SSH SETTINGS
# ==========================================

echo ""
echo "[INFO] Effective SSH security settings:"

"$SSHD_BIN" -T | grep -E \
'^(pubkeyauthentication|passwordauthentication|kbdinteractiveauthentication|permitrootlogin) '

# ==========================================
# INSTALL RCLONE
# ==========================================

echo ""
echo "[INFO] Downloading official Rclone installer..."

curl -fsSL https://rclone.org/install.sh \
    -o /tmp/rclone-install.sh

echo "[INFO] Installing Rclone..."

bash /tmp/rclone-install.sh

rm -f /tmp/rclone-install.sh

echo "[SUCCESS] Rclone installed."

# ==========================================
# FINISH
# ==========================================

echo ""
echo "======================================"
echo " SETUP COMPLETED"
echo "======================================"

echo "[INFO] SSH authorized_keys:"
echo "$AUTH_KEYS"

echo ""
echo "[INFO] SSH authentication:"
echo "Public Key       : ENABLED"
echo "Password Login   : DISABLED"
echo "Keyboard Login   : DISABLED"
echo "Root Password SSH: DISABLED"

echo ""
echo "[INFO] Rclone version:"
rclone version

echo ""
echo "[SUCCESS] All tasks completed!"