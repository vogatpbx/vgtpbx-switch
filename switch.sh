#!/bin/bash

# Directory Management
directories=(
    "/etc/freeswitch"
    "/var/lib/freeswitch"
    "/var/log/freeswitch"
    "/var/run/freeswitch"
    "/var/lib/freeswitch/storage"
    "/var/lib/freeswitch/recordings"
    "/var/lib/freeswitch/storage/voicemail"
    "/var/lib/freeswitch/storage/voicemail/default"
    "/var/lib/freeswitch/db"
    "/var/lib/freeswitch/vm_db"
)

# Create directories and set permissions
for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Creating directory: $dir"
        mkdir -p "$dir"
    fi
    echo "Setting permissions for $dir"
    chown -R vgtpbx:vgtpbx "$dir"
    chmod -R 755 "$dir"
done

# Configuration Management
# Backup original config
if [ ! -d "/etc/freeswitch.orig" ] && [ -d "/etc/freeswitch" ]; then
    echo "Backing up original FreeSWITCH configuration"
    cp -r /etc/freeswitch /etc/freeswitch.orig
fi

# Remove default configs
config_dirs=(
    "autoload_configs"
    "dialplan"
    "chatplan"
    "directory"
    "sip_profiles"
)

for dir in "${config_dirs[@]}"; do
    if [ -d "/etc/freeswitch/$dir" ]; then
        echo "Removing default configuration: $dir"
        rm -rf "/etc/freeswitch/$dir"
    fi
done

# Final Permission Setup
chown -R vgtpbx:vgtpbx /etc/freeswitch
chmod -R 755 /etc/freeswitch

# FreeSWITCH Startup
echo "Starting FreeSWITCH..."
exec freeswitch -u vgtpbx -g vgtpbx -nc -nf \
    -conf /etc/freeswitch \
    -log /var/log/freeswitch \
    -db /var/lib/freeswitch/db \
    -run /var/run/freeswitch 