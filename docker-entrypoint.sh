#!/bin/bash
set -e

if [ "$1" = 'vgtpbx-switch' ]; then
    if [ ! -f "/etc/vgtpbx/freeswitch/freeswitch.xml" ]; then
        mkdir -p /etc/vgtpbx/freeswitch
        cp -varf /usr/share/freeswitch/conf/vanilla/* /etc/vgtpbx/freeswitch/
    fi

    # Ensure PID directory exists and has proper permissions
    mkdir -p /var/run/freeswitch
    chown -R vgtpbx:vgtpbx /var/run/freeswitch
    chmod 755 /var/run/freeswitch

    # Remove stale PID file if it exists
    rm -f /var/run/freeswitch/freeswitch.pid

    # Ensure modules.conf.xml loads mod_pgsql early
    #sed -i 's|<load module="mod_pgsql"/>|<load module="mod_pgsql" priority="10"/>|g' /etc/vgtpbx/freeswitch/autoload_configs/modules.conf.xml

    # Set proper permissions
    chown -R vgtpbx:vgtpbx /etc/vgtpbx/freeswitch
    chown -R vgtpbx:vgtpbx /var/{run,lib}/freeswitch
    
    if [ -d /docker-entrypoint.d ]; then
        for f in /docker-entrypoint.d/*.sh; do
            [ -f "$f" ] && . "$f"
        done
    fi
    
    # Verify module configuration
    log "Verifying module configuration..."
    grep -r "mod_pgsql" /etc/vgtpbx/freeswitch/autoload_configs/
    
    exec gosu vgtpbx /usr/bin/freeswitch -u vgtpbx -g vgtpbx -nonat -c
fi

exec "$@"