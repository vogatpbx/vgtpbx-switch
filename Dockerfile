# Build stage
FROM debian:bookworm-slim as builder

ENV DEBIAN_FRONTEND=noninteractive
ARG TOKEN
ARG FS_META_PACKAGE=freeswitch-meta-bare

# explicitly set user/group IDs
ARG VGTPBX_UID=499
ARG VGTPBX_GID=499
RUN groupadd -r vgtpbx --gid=${VGTPBX_GID} && useradd -r -g vgtpbx --uid=${VGTPBX_UID} vgtpbx

# make the "en_US.UTF-8" locale and install essential packages
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg2 \
        gosu \
        locales \
        wget \
        postgresql-client \
        libpq-dev \
        netcat-traditional \
        libcap2-bin \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Get FreeSWITCH packages
RUN --mount=type=secret,id=fs_token,target=/run/secrets/fs_token \
    TOKEN=${FS_TOKEN:-$(cat /run/secrets/fs_token 2>/dev/null || echo "")} && \
    wget --no-verbose --http-user=signalwire --http-password=${TOKEN} \
    -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
    https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg \
    && echo "machine freeswitch.signalwire.com login signalwire password ${TOKEN}" > /etc/apt/auth.conf \
    && echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bookworm main" > /etc/apt/sources.list.d/freeswitch.list \
    && apt-get -qq update \
    && apt-get install -y --no-install-recommends \
        ${FS_META_PACKAGE} \
        freeswitch-conf-vanilla \
        freeswitch-mod-pgsql \
        freeswitch-mod-commands \
        freeswitch-mod-console \
        freeswitch-mod-logfile \
        freeswitch-mod-sofia \
        freeswitch-mod-event-socket \
        freeswitch-lang-en \
        freeswitch-mod-dptools \
        freeswitch-mod-dialplan-xml \
        freeswitch-mod-conference \
        freeswitch-mod-callcenter \
        freeswitch-mod-xml-cdr \
        freeswitch-mod-db \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create VGTPBX directory structure and set up symlinks
RUN mkdir -p \
    /etc/vgtpbx/freeswitch \
    /etc/vgtpbx/media/fs/recordings \
    /etc/vgtpbx/media/fs/storage \
    /etc/vgtpbx/media/fs/voicemail/default \
    /var/log/freeswitch \
    /var/lib/freeswitch/db \
    && cp -r /etc/freeswitch/* /etc/vgtpbx/freeswitch/ \
    && rm -rf /etc/freeswitch \
    && ln -s /etc/vgtpbx/freeswitch /etc/freeswitch \
    && cd /etc/vgtpbx/freeswitch \
    && mv directory/default/example.com.xml directory/default/example.com.xml.noload \
    && mv sip_profiles/external-ipv6.xml sip_profiles/external-ipv6.xml.noload \
    && mv sip_profiles/internal-ipv6.xml sip_profiles/internal-ipv6.xml.noload \
    && sed -i 's|<param name="colorize" value="true"/>|<param name="colorize" value="false"/>|g' /etc/vgtpbx/freeswitch/autoload_configs/console.conf.xml \
    && chown -R vgtpbx:vgtpbx \
        /etc/vgtpbx \
        /var/log/freeswitch \
        /var/lib/freeswitch \
    && chmod -R 755 \
        /etc/vgtpbx/freeswitch \
        /etc/vgtpbx/media \
        /var/log/freeswitch \
        /var/lib/freeswitch

# Copy limits configuration
COPY build/freeswitch.limits.conf /etc/security/limits.d/

# Set capabilities for the FreeSWITCH binary
RUN setcap 'cap_net_bind_service,cap_sys_nice,cap_sys_resource,cap_net_raw,cap_net_admin+ep' /usr/bin/freeswitch

# Ports
EXPOSE 8021/tcp
EXPOSE 5060/tcp 5060/udp 5080/tcp 5080/udp
EXPOSE 5061/tcp 5061/udp 5081/tcp 5081/udp
EXPOSE 5066/tcp
EXPOSE 7443/tcp
EXPOSE 64535-65535/udp
EXPOSE 16384-32768/udp


# Healthcheck
HEALTHCHECK --interval=15s --timeout=5s \
    CMD fs_cli -x status | grep -q ^UP || exit 1

COPY docker-entrypoint.sh /
COPY build/config.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.d/config.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["vgtpbx-switch"]