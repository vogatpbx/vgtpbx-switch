#!/bin/bash

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

# Configure FreeSWITCH for PostgreSQL
log "Configuring FreeSWITCH for PostgreSQL..."

# Debug DNS resolution
log "Testing DNS resolution for PostgreSQL host..."
if ping -c 1 $POSTGRES_HOST >/dev/null 2>&1; then
    log "DNS resolution successful for $POSTGRES_HOST"
    POSTGRES_IP=$(getent hosts $POSTGRES_HOST | awk '{ print $1 }')
    log "PostgreSQL IP address: $POSTGRES_IP"
else
    log "Warning: Cannot resolve $POSTGRES_HOST"
fi

# Update vars.xml with PostgreSQL DSN
sed -i '/<\/include>/i \
<!-- DSN Configuration -->\
<X-PRE-PROCESS cmd="set" data="dsn=pgsql://host='"$POSTGRES_HOST"' dbname='"$SWITCH_DB_NAME"' user='"$SWITCH_DB_USER"' password='"$SWITCH_DB_PASSWORD"'\" />' /etc/vgtpbx/freeswitch/vars.xml

# Update switch.conf.xml - First uncomment the line, then update it
sed -i 's|<!-- *<param name="core-db-dsn" value=".*" */ *> *-->|<param name="core-db-dsn" value="\$\${dsn}"/>|g' /etc/vgtpbx/freeswitch/autoload_configs/switch.conf.xml
sed -i 's|<!-- *<param name="auto-create-schemas" value=".*" */ *> *-->|<param name="auto-create-schemas" value="false"/>|g' /etc/vgtpbx/freeswitch/autoload_configs/switch.conf.xml
sed -i 's|<!-- *<param name="auto-clear-sql" value=".*" */ *> *-->|<param name="auto-clear-sql" value="false"/>|g' /etc/vgtpbx/freeswitch/autoload_configs/switch.conf.xml

# Disable odbc-dsn in config files with proper XML comments
for file in db.conf.xml fifo.conf.xml voicemail.conf.xml; do
    if [ -f "/etc/vgtpbx/freeswitch/autoload_configs/$file" ]; then
        # First, remove any existing comments to avoid doubling
        sed -i 's|<!--.*-->||g' "/etc/vgtpbx/freeswitch/autoload_configs/$file"
        # Then add the proper comment
        sed -i 's|<param name="odbc-dsn" value=".*"/>|<!-- <param name="odbc-dsn" value="${dsn}"/> -->|g' "/etc/vgtpbx/freeswitch/autoload_configs/$file"
    fi
done

# Wait for PostgreSQL
log "Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=1

while [ $attempt -le $max_attempts ]; do
    if PGPASSWORD=$SWITCH_DB_PASSWORD psql -h $POSTGRES_HOST -U $SWITCH_DB_USER -d $SWITCH_DB_NAME -c "SELECT 1;" >/dev/null 2>&1; then
        log "PostgreSQL is ready!"
        break
    else
        log "Attempt $attempt of $max_attempts: PostgreSQL is not ready yet..."
        log "Testing direct connection to PostgreSQL..."
        if netcat -zv $POSTGRES_HOST 5432 2>&1; then
            log "Port 5432 is reachable"
            log "Testing PostgreSQL authentication..."
            PGPASSWORD=$SWITCH_DB_PASSWORD psql -h $POSTGRES_HOST -U $SWITCH_DB_USER -d $SWITCH_DB_NAME -c "SELECT current_database(), current_user;"
        else
            log "Port 5432 is not reachable"
        fi
        if [ $attempt -eq $max_attempts ]; then
            log "Warning: Maximum attempts reached. Continuing anyway..."
            break
        fi
        sleep 2
        attempt=$((attempt + 1))
    fi
done

# Verify PostgreSQL connection and show configuration
log "Verifying PostgreSQL connection and configuration..."
log "Current vars.xml DSN configuration:"
grep "dsn=" /etc/vgtpbx/freeswitch/vars.xml || log "No DSN configuration found in vars.xml"

log "Current switch.conf.xml configuration:"
grep "core-db-dsn" /etc/vgtpbx/freeswitch/autoload_configs/switch.conf.xml || log "No core-db-dsn configuration found in switch.conf.xml"

log "Current db.conf.xml configuration:"
if [ -f "/etc/vgtpbx/freeswitch/autoload_configs/db.conf.xml" ]; then
    grep -A 1 "settings" /etc/vgtpbx/freeswitch/autoload_configs/db.conf.xml || log "No settings section in db.conf.xml"
else
    log "No db.conf.xml found"
fi

log "Current fifo.conf.xml configuration:"
if [ -f "/etc/vgtpbx/freeswitch/autoload_configs/fifo.conf.xml" ]; then
    grep -A 1 "settings" /etc/vgtpbx/freeswitch/autoload_configs/fifo.conf.xml || log "No settings section in fifo.conf.xml"
else
    log "No fifo.conf.xml found"
fi

log "Current voicemail.conf.xml configuration:"
if [ -f "/etc/vgtpbx/freeswitch/autoload_configs/voicemail.conf.xml" ]; then
    grep -A 1 "settings" /etc/vgtpbx/freeswitch/autoload_configs/voicemail.conf.xml || log "No settings section in voicemail.conf.xml"
else
    log "No voicemail.conf.xml found"
fi

if PGPASSWORD=$SWITCH_DB_PASSWORD psql -h $POSTGRES_HOST -U $SWITCH_DB_USER -d $SWITCH_DB_NAME -c "SELECT current_database(), version();" 2>/dev/null; then
    log "PostgreSQL connection verified successfully!"
else
    log "Warning: Could not verify PostgreSQL connection"
fi

# Set proper permissions
chown -R vgtpbx:vgtpbx /etc/vgtpbx/freeswitch/ 