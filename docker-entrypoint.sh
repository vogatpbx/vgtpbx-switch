#!/bin/bash
set -e


if [ "$1" = 'freeswitch' ]; then

    if [ ! -f "/etc/vgtpbx/freeswitch/freeswitch.xml" ]; then
        mkdir -p /etc/vgtpbx/freeswitch
        cp -varf /usr/share/freeswitch/conf/vanilla/* /etc/vgtpbx/freeswitch/
    fi

    sed -i 's|<load module="mod_pgsql"/>|<load module="mod_pgsql" priority="10"/>|g' /etc/vgtpbx/freeswitch/autoload_configs/modules.conf.xml

    chown -R vgtpbx:vgtpbx /etc/vgtpbx/freeswitch
    chown -R vgtpbx:vgtpbx /var/{run,lib}/freeswitch
    
    if [ -d /docker-entrypoint.d ]; then
        for f in /docker-entrypoint.d/*.sh; do
            [ -f "$f" ] && . "$f"
        done
    fi
    
    exec gosu vgtpbx /usr/bin/freeswitch -u vgtpbx -g vgtpbx -nonat -c
fi

exec "$@"