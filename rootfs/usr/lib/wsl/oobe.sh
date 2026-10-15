#!/usr/bin/env bash
set -euo pipefail

ask_yn() {
    # $1 = prompt, $2 = default answer (y/n)
    local prompt="$1" default_answer="${2:-y}" reply
    if [["default_answer" == "y" ]]; then
        read -rp "$prompt [Y/n]: " reply
        reply="${reply:-y}"
    else
        read -rp "$prompt [y/N]: " reply
        reply="${reply:-n}"
    fi
    [[ "$reply" =~ ^[Yy]$ ]]
}

echo "============================================================="
echo "Welcome to DevArchy - The Arch Linux Development Environment"
echo "============================================================="
echo 
echo "A few questions about how you want to set up your environment:"
echo "These map straigh to /etc/wsl.conf, and can always be manually edited later."
echo "-------------------------------------------------------------"
echo 

# --- Systemd ---
if ask_yn "Enable systemd (required for Docker Engine, most services, and some development tools)?" y; then
    SYSTEMD=true
else 
    SYSTEMD=false
fi

# --- Interop ---
if ask_yn "Enable interop with Windows (allows running Windows executables from Linux)?" y; then
    INTEROP=true
    if ask_yn "Also append Windows PATH to Linux PATH?" y; then
        APPEND_PATH=true
    else
        APPEND_PATH=false
    fi
else 
    INTEROP=false
    APPEND_PATH=false
fi

# --- Drive Mounts ---
if ask_yn "Automount Windows drives (C:, D:, etc.)?" y; then
    AUTOMOUNT=true
    if ask_yn "Also mount drives with metadata (preserves Linux permissions)?" y; then
        METADATA=true
    else
        METADATA=false
    fi

    if ask_yn "Also mount drives with case sensitivity (preserves Linux case sensitivity)?" y; then
        CASE_SENSITIVE=true
    else
        CASE_SENSITIVE=false
    fi

    if ask_yn "Also mount root at / (default is /mnt/c, /mnt/d, etc.)?" y; then
        ROOT_MOUNT=true
    else
        ROOT_MOUNT=false
    fi
else 
    AUTOMOUNT=false
    METADATA=false
    CASE_SENSITIVE=false
    ROOT_MOUNT=false
fi

# --- Network ---
if ask_yn "Manage DNS yourself instead of using Windows resolver?" n; then
    read -rp "Enter DNS server(s) (space-separated): " -a nameservers
    GEN_RESOLV_CONF=false
else 
    GEN_RESOLV_CONF=true
fi

if ask_yn "Change hostname (default is Windows hostname)?" n; then
    read -rp "Enter hostname: " hostname
else 
    hostname=""
fi

echo 
echo "Writing configuration to /etc/wsl.conf..."
{
    echo "[boot]"
    echo "systemd=$SYSTEMD"
    echo "[interop]"
    echo "enabled=$INTEROP"
    echo "appendWindowsPath=$APPEND_PATH"
    echo "[automount]"
    echo "enabled=$AUTOMOUNT"
    echo "options=metadata,case=$CASE_SENSITIVE,root=$ROOT_MOUNT"
} > /etc/wsl.conf

if [[ "$GEN_RESOLV_CONF" == false ]]; then
    : > /etc/resolv.conf
    for ns in "${nameservers[@]}"; do
        echo "nameserver $ns" >> /etc/resolv.conf
    done
fi

echo "NOTE: wsl.conf is only read when the WSL instance is started, so you will need to exit and restart WSL for changes to take effect."
echo "Nothing above is live in this session. Once setup is complete, from PowerShell, run 'wsl --terminate DevArchy' to restart WSL "
echo "and apply changes. Then reopen WSL and and go to down creating the next great project!"

# --- User Setup ---
read -rp "Enter username for new user: " username

useraddd -m -G wheel -s /usr/bin/zsh "$username"
passwd "$username"

echo "ASDF-VM is already installed, would you like to install the any of the following common plugins for $username?"
echo
echo "1) Node.js"
echo "2) Python"
echo "3) Go"
echo "4) Java"
echo "5) Rust"
echo
read -rp "Enter the numbers of the plugins you want to install (space-separated), or press Enter to skip: " -a plugins

declare -A plugin_map=(
    [1]="nodejs"
    [2]="python"
    [3]="golang"
    [4]="java"
    [5]="rust"
)

for p in "${plugins[@]}"; do
    plugin_name="${plugin_map[$p]:-}"
    if [[ -n "$plugin_name" ]]; then
        echo "Installing $plugin_name for $username via asdf..."
        su - "$username" -c "asdf plugin add $plugin_name" || true
        su - "$username" -c "asdf install $plugin_name latest" || true
        su - "$username" -c "asdf set -u $plugin_name latest" || true
    fi
done

echo "Setup complete! You can now log in as $username and start using your DevArchy environment."
exit 0