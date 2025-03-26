# Base image and environment setup
FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive
ARG SIGNALWIRE_TOKEN
ENV SIGNALWIRE_TOKEN=${SIGNALWIRE_TOKEN}

# Create vgtpbx user/group 
RUN groupadd -r vgtpbx && useradd -r -g vgtpbx vgtpbx

# Install essential dependencies first
RUN apt-get update && apt-get install -y \
    gnupg2 \
    wget \
    lsb-release \
    git \
    && rm -rf /var/lib/apt/lists/*

# FreeSWITCH installation from packages
RUN --mount=type=secret,id=signalwire_token \
    export SIGNALWIRE_TOKEN=$(cat /run/secrets/signalwire_token) && \
    wget --http-user=signalwire --http-password="${SIGNALWIRE_TOKEN}" \
    -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
    https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg && \
    echo "machine freeswitch.signalwire.com login signalwire password ${SIGNALWIRE_TOKEN}" > /etc/apt/auth.conf && \
    echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ `lsb_release -sc` main" > /etc/apt/sources.list.d/freeswitch.list && \
    apt-get update && \
    apt-get install -y \
    freeswitch-meta-bare \
    freeswitch-conf-vanilla \
    freeswitch-mod-commands \
    freeswitch-mod-console \
    freeswitch-mod-logfile \
    freeswitch-lang-en \
    freeswitch-mod-say-en \
    freeswitch-sounds-en-us-callie \
    freeswitch-mod-enum \
    freeswitch-mod-cdr-csv \
    freeswitch-mod-event-socket \
    freeswitch-mod-sofia \
    freeswitch-mod-loopback \
    freeswitch-mod-conference \
    freeswitch-mod-db \
    freeswitch-mod-dptools \
    freeswitch-mod-expr \
    freeswitch-mod-fifo \
    freeswitch-mod-httapi \
    freeswitch-mod-hash \
    freeswitch-mod-esl \
    freeswitch-mod-esf \
    freeswitch-mod-fsv \
    freeswitch-mod-valet-parking \
    freeswitch-mod-dialplan-xml \
    freeswitch-mod-sndfile \
    freeswitch-mod-native-file \
    freeswitch-mod-local-stream \
    freeswitch-mod-tone-stream \
    freeswitch-mod-lua \
    freeswitch-mod-python3 \
    freeswitch-mod-xml-cdr \
    freeswitch-mod-verto \
    freeswitch-mod-callcenter \
    freeswitch-mod-rtc \
    freeswitch-mod-png \
    freeswitch-mod-json-cdr \
    freeswitch-mod-shout \
    freeswitch-mod-sms \
    freeswitch-mod-cidlookup \
    freeswitch-mod-memcache \
    freeswitch-mod-imagick \
    freeswitch-mod-tts-commandline \
    freeswitch-mod-directory \
    freeswitch-mod-flite \
    freeswitch-mod-pgsql \
    freeswitch-mod-curl \
    freeswitch-mod-xml-curl \
    freeswitch-mod-voicemail \
    freeswitch-mod-http-cache \
    freeswitch-mod-amqp \
    && rm -rf /var/lib/apt/lists/*

# Get mod_bcg729.so
RUN wget -O /usr/lib/freeswitch/mod/mod_bcg729.so \
    https://github.com/vogatpbx/vgtpbx-install/raw/main/modules/mod_bcg729.so

# Move recordings and voicemail
RUN mkdir -p /etc/vgtpbx/media/fs/recordings && \
    mkdir -p /etc/vgtpbx/media/fs/voicemail/default && \
    rmdir /var/lib/freeswitch/recordings && \
    ln -s /etc/vgtpbx/media/fs/recordings /var/lib/freeswitch/recordings && \
    rm -rf /var/lib/freeswitch/storage/voicemail && \
    ln -s /etc/vgtpbx/media/fs/voicemail /var/lib/freeswitch/storage/voicemail

# Create necessary directories and set permissions
RUN mkdir -p /etc/freeswitch \
    /var/lib/freeswitch \
    /var/lib/freeswitch/storage \
    /var/lib/freeswitch/db \
    /var/lib/freeswitch/vm_db && \
    # Setup FreeSWITCH configuration directory
    mkdir -p /etc/vgtpbx/freeswitch && \
    cp -r /etc/freeswitch/ /etc/vgtpbx/freeswitch/ && \
    mv /etc/freeswitch /etc/freeswitch.orig && \
    ln -s /etc/vgtpbx/freeswitch /etc/freeswitch && \
    # Remove default configs that will be replaced
    rm -r /etc/vgtpbx/freeswitch/autoload_configs && \
    rm -r /etc/vgtpbx/freeswitch/dialplan && \
    rm -r /etc/vgtpbx/freeswitch/chatplan && \
    rm -r /etc/vgtpbx/freeswitch/directory && \
    rm -r /etc/vgtpbx/freeswitch/sip_profiles && \
    # Setup music directory properly in vgtpbx directory
    mkdir -p /etc/vgtpbx/media/fs/music/default && \
    mv /usr/share/freeswitch/sounds/music/*000 /etc/vgtpbx/media/fs/music/default/ && \
    rm -rf /usr/share/freeswitch/sounds/music && \
    ln -s /etc/vgtpbx/media/fs/music /usr/share/freeswitch/sounds/music && \
    # Set permissions
    chown -R vgtpbx:vgtpbx /usr/share/freeswitch/sounds && \
    chown -R vgtpbx:vgtpbx /etc/vgtpbx/freeswitch && \
    chown -R vgtpbx:vgtpbx /etc/vgtpbx/media/fs/music/*

# Port exposure
EXPOSE 5060/udp 5060/tcp    
EXPOSE 5061/tcp             
EXPOSE 5080/udp 5080/tcp    
EXPOSE 5066/tcp            
EXPOSE 7443/tcp             
EXPOSE 8021/tcp             
EXPOSE 16384-32768/udp     

# Entrypoint setup
COPY switch.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/switch.sh
WORKDIR /etc/freeswitch
ENTRYPOINT ["/usr/local/bin/switch.sh"]