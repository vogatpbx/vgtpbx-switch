#!/bin/bash
set -e  # Exit on error
set -x  # Print commands for debugging

# Log function
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting FreeSWITCH container..."

# Configure FreeSWITCH based on FREESWITCH_CORE_IN_POSTGRES
if [ "$FREESWITCH_CORE_IN_POSTGRES" = "yes" ]; then
    log "Updating FreeSWITCH configurations for PostgreSQL..."
    
    # Remove SQLite database files
    log "Removing SQLite database files..."
    dbs="/var/lib/freeswitch/db/core.db /var/lib/freeswitch/db/fifo.db /var/lib/freeswitch/db/call_limit.db /var/lib/freeswitch/db/sofia_reg_*"
    for db in ${dbs}; do
        if [ -f $db ]; then
            log "Deleting $db"
            rm $db
        fi
    done
    
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

    # Update vars.xml for PostgreSQL
    log "Updating vars.xml for PostgreSQL configuration..."
    # First, remove any existing DSN configurations
    sed -i '/<X-PRE-PROCESS cmd="set" data="dsn/d' /etc/vgtpbx/freeswitch/vars.xml
    # Add new DSN configurations before the closing </include>
    sed -i '/<\/include>/i \
    <!-- DSN Configuration -->\
    <X-PRE-PROCESS cmd="set" data="dsn=pgsql://hostaddr='$POSTGRES_HOST' port=5432 dbname='$SWITCH_DB_NAME' user='$SWITCH_DB_USER' password='\''$SWITCH_DB_PASSWORD'\''" />\
    <X-PRE-PROCESS cmd="set" data="dsn_callcenter=pgsql://hostaddr='$POSTGRES_HOST' port=5432 dbname='$SWITCH_DB_NAME' user='$SWITCH_DB_USER' password='\''$SWITCH_DB_PASSWORD'\''" />' /etc/vgtpbx/freeswitch/vars.xml
fi

log "Waiting for PostgreSQL to be ready..."
# Wait for PostgreSQL
until PGPASSWORD=$SWITCH_DB_PASSWORD psql -h $POSTGRES_HOST -U $SWITCH_DB_USER -d $SWITCH_DB_NAME -c '\q' 2>/dev/null; do
    log "PostgreSQL is not ready yet, waiting..."
    sleep 1
done
log "PostgreSQL is ready!"

# Debug info
log "Checking FreeSWITCH installation:"
ls -la /usr/lib/freeswitch/mod/
ls -la /etc/vgtpbx/freeswitch/
id vgtpbx

# FreeSWITCH Startup
log "Starting FreeSWITCH..."
exec freeswitch -u vgtpbx -g vgtpbx -nonat -nc \
    -conf /etc/vgtpbx/freeswitch \
    -log /var/log/freeswitch \
    -db /var/lib/freeswitch/db \
    -run /var/run/freeswitch