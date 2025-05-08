# Build stage
FROM debian:bookworm-slim as builder

ENV DEBIAN_FRONTEND=noninteractive
ARG FS_TOKEN
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
        iproute2 \
        nano \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Create VGTPBX directory structure first
RUN mkdir -p \
    /etc/vgtpbx/freeswitch \
    /etc/vgtpbx/media/fs/recordings \
    /etc/vgtpbx/media/fs/storage \
    /etc/vgtpbx/media/fs/voicemail/default \
    /etc/vgtpbx/media/fs/sounds/music/default \
    /etc/vgtpbx/media/fs/sounds/en \
    /var/log/freeswitch \
    /var/lib/freeswitch/db

# Copy templates before FreeSWITCH installation
COPY ./templates /templates

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
        freeswitch-mod-sofia-dbg \
        freeswitch-mod-event-socket \
        freeswitch-lang-en \
        freeswitch-mod-loopback \
        freeswitch-mod-dptools \
        freeswitch-mod-dialplan-xml \
        freeswitch-mod-conference \
        freeswitch-mod-callcenter \
        freeswitch-mod-xml-cdr \
        freeswitch-mod-curl \
        freeswitch-mod-enum \
        freeswitch-mod-xml-curl \
        freeswitch-mod-db \
        freeswitch-mod-httapi \
        freeswitch-mod-hash \
        freeswitch-mod-voicemail \
        freeswitch-meta-codecs \
        freeswitch-mod-directory \
        freeswitch-music-default \
        freeswitch-mod-local-stream \
        freeswitch-mod-tone-stream \
        freeswitch-meta-mod-say \
        freeswitch-mod-sndfile \
        freeswitch-mod-native-file \ 
        freeswitch-mod-say-en \ 
        freeswitch-mod-spandsp \  
        freeswitch-mod-opus \ 
        freeswitch-mod-shout \ 
        freeswitch-sounds-en-us-callie \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Get mod_bcg729.so
RUN wget -O /usr/lib/freeswitch/mod/mod_bcg729.so \
    https://github.com/vogatpbx/vgtpbx-install/raw/main/modules/mod_bcg729.so

# Create VGTPBX directory structure and set up symlinks
RUN cp -r /etc/freeswitch/* /etc/vgtpbx/freeswitch/ \
    && rm -rf /etc/freeswitch \
    && ln -s /etc/vgtpbx/freeswitch /etc/freeswitch \
    && cd /etc/vgtpbx/freeswitch \
    && rm -r autoload_configs \
    && rm -r dialplan \
    && rm -r chatplan \
    && rm -r directory \
    && rm -r sip_profiles \
    && cp -r /templates/conf/* /etc/vgtpbx/freeswitch/ \
    && cp -r /usr/share/freeswitch/sounds/music/* /etc/vgtpbx/media/fs/sounds/music/default/ \
    && cp -r /usr/share/freeswitch/sounds/en/* /etc/vgtpbx/media/fs/sounds/en \
    && rm -rf /usr/share/freeswitch/sounds \
    && ln -s /etc/vgtpbx/media/fs/sounds /usr/share/freeswitch/sounds \
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