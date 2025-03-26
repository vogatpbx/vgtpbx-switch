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
    chown vgtpbx:vgtpbx "$dir"
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