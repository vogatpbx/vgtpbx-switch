#!/bin/bash
set -e  # Exit on error
set -x  # Print commands for debugging

# Configure FreeSWITCH based on FREESWITCH_CORE_IN_POSTGRES
if [ "$FREESWITCH_CORE_IN_POSTGRES" = "yes" ]; then
    echo "Updating FreeSWITCH configurations for PostgreSQL..."
    # Update switch.conf.xml
    sed -i "s|<!-- <param name=\"core-db-dsn\" value=\"\$\$\{dsn\}\" \/>\s*-->|<param name=\"core-db-dsn\" value=\"pgsql://hostaddr=$POSTGRES_HOST dbname=$SWITCH_DB_NAME user=$SWITCH_DB_USER password='$SWITCH_DB_PASSWORD'\" />|g" /etc/vgtpbx/freeswitch/autoload_configs/switch.conf.xml
    sed -i 's|<!-- <param name="auto-create-schemas" value="false"\/>\s*-->|<param name="auto-create-schemas" value="true"/>|g' /etc/vgtpbx/freeswitch/autoload_configs/switch.conf.xml
    sed -i 's|<!-- <param name="auto-clear-sql" value="false"\/>\s*-->|<param name="auto-clear-sql" value="true"/>|g' /etc/vgtpbx/freeswitch/autoload_configs/switch.conf.xml
    # Update voicemail.conf.xml
    sed -r -i 's/<!--(<param name="odbc-dsn" value="\$\$\{dsn\}"\/>)-->/\1/g' /etc/vgtpbx/freeswitch/autoload_configs/voicemail.conf.xml
    sed -r -i 's/(<param name="dbname" value="\/var\/lib\/freeswitch\/vm_db\/voicemail_default.db"\/>)/<!--\1-->/g' /etc/vgtpbx/freeswitch/autoload_configs/voicemail.conf.xml
    # Update fifo.conf.xml
    sed -r -i 's/<!--(<param name="odbc-dsn" value="\$\$\{dsn\}"\/>)-->/\1/g' /etc/vgtpbx/freeswitch/autoload_configs/fifo.conf.xml
    # Update db.conf.xml
    sed -r -i 's/<!--(<param name="odbc-dsn" value="\$\$\{dsn\}"\/>)-->/\1/g' /etc/vgtpbx/freeswitch/autoload_configs/db.conf.xml
fi

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