#!/bin/bash
set -e  # Exit on error
set -x  # Print commands for debugging

# Wait for PostgreSQL
until PGPASSWORD=$SWITCH_DB_PASSWORD psql -h $POSTGRES_HOST -U $SWITCH_DB_USER -d $SWITCH_DB_NAME -c '\q' 2>/dev/null; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 1
done
echo "PostgreSQL is ready!"

# Debug info
echo "Checking FreeSWITCH installation:"
ls -la /usr/lib/freeswitch/mod/
ls -la /etc/vgtpbx/freeswitch/
id vgtpbx

# FreeSWITCH Startup
echo "Starting FreeSWITCH..."
exec freeswitch -u vgtpbx -g vgtpbx -nonat -nc \
    -conf /etc/vgtpbx/freeswitch \
    -log /var/log/freeswitch \
    -db /var/lib/freeswitch/db \
    -run /var/run/freeswitch 