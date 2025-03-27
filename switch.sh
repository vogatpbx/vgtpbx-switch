#!/bin/bash

# Wait for PostgreSQL
until PGPASSWORD=$SWITCH_DB_PASSWORD psql -h $POSTGRES_HOST -U $SWITCH_DB_USER -d $SWITCH_DB_NAME -c '\q' 2>/dev/null; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 1
done
echo "PostgreSQL is ready!"

# Directory Management
directories=(
    "/etc/vgtpbx/freeswitch"
    "/etc/vgtpbx/media/fs/recordings"
    "/etc/vgtpbx/media/fs/storage"
    "/var/log/freeswitch"
    "/var/lib/freeswitch/db"
    "/var/run/freeswitch"
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
chown -R vgtpbx:vgtpbx /etc/vgtpbx/freeswitch
chmod -R 755 /etc/vgtpbx/freeswitch

# FreeSWITCH Startup
echo "Starting FreeSWITCH..."
exec freeswitch -u vgtpbx -g vgtpbx -nc -nf \
    -conf /etc/vgtpbx/freeswitch \
    -log /var/log/freeswitch \
    -db /var/lib/freeswitch/db \
    -run /var/run/freeswitch 