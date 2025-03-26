# Base image and environment setup
FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive
ARG SIGNALWIRE_TOKEN
ENV SIGNALWIRE_TOKEN=${SIGNALWIRE_TOKEN}
ARG SOFIA_VERSION=1.13.17

# Create vgtpbx user/group 
RUN groupadd -r vgtpbx && useradd -r -g vgtpbx vgtpbx

# Install dependencies (build and runtime)
RUN apt-get update && apt-get install -y \
    gnupg2 \
    wget \
    lsb-release \
    git \
    build-essential \
    cmake \
    libtool \
    pkg-config \
    libssl-dev \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libspandsp-dev \
    libedit-dev \
    libldns-dev \
    libpcre3-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libopus-dev \
    libjpeg-dev \
    autoconf \
    automake \
    uuid-dev \
    # Additional dependencies for FreeSWITCH build
    gdb \
    libncurses5-dev \
    libgdbm-dev \
    libdb-dev \
    gettext \
    equivs \
    mlocate \
    dpkg-dev \
    libpq-dev \
    liblua5.2-dev \
    libtiff5-dev \
    libperl-dev \
    libshout3-dev \
    libmpg123-dev \
    libmp3lame-dev \
    yasm \
    nasm \
    libsndfile1-dev \
    libuv1-dev \
    libvpx-dev \
    libavformat-dev \
    libswscale-dev \
    libvlc-dev \
    python3-distutils \
    flac \
    libvpx7 \
    swig4.0 \
    devscripts \
    && rm -rf /var/lib/apt/lists/*

# Build and install core dependencies in correct order
# libks (SignalWire dependency)
RUN cd /usr/src && \
    git clone https://github.com/signalwire/libks.git libks && \
    cd libks && \
    cmake . && \
    make -j $(nproc) && \
    make install && \
    cd / && \
    rm -rf /usr/src/libks && \
    export C_INCLUDE_PATH=/usr/include/libks

# spandsp (Audio processing)
RUN cd /usr/src && \
    git clone https://github.com/freeswitch/spandsp.git spandsp && \
    cd spandsp && \
    git reset --hard 0d2e6ac65e0e8f53d652665a743015a88bf048d4 && \
    sh autogen.sh && \
    ./configure --enable-debug && \
    make -j $(nproc) && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /usr/src/spandsp

# sofia-sip (SIP stack)
RUN cd /usr/src && \
    wget https://github.com/freeswitch/sofia-sip/archive/refs/tags/v${SOFIA_VERSION}.tar.gz && \
    tar -xvf v${SOFIA_VERSION}.tar.gz && \
    cd sofia-sip-${SOFIA_VERSION} && \
    sh autogen.sh && \
    ./configure && \
    make -j $(nproc) && \
    make install && \
    ldconfig && \
    cd / && \
    rm -rf /usr/src/sofia-sip-${SOFIA_VERSION} && \
    rm /usr/src/v${SOFIA_VERSION}.tar.gz

# FreeSWITCH installation
RUN wget --http-user=signalwire --http-password=${SIGNALWIRE_TOKEN} \
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

# Sound files installation
RUN cd /usr/src && \
    git clone https://github.com/signalwire/freeswitch.git && \
    cd freeswitch && \
    ./bootstrap.sh -j && \
    # Disable problematic modules
    sed -i 's/applications\/mod_signalwire/#applications\/mod_signalwire/g' build/modules.conf.in && \
    sed -i 's/endpoints\/mod_skinny/#endpoints\/mod_skinny/g' build/modules.conf.in && \
    sed -i 's/endpoints\/mod_verto/#endpoints\/mod_verto/g' build/modules.conf.in && \
    # Enable required modules
    sed -i 's/#applications\/mod_callcenter/applications\/mod_callcenter/g' build/modules.conf.in && \
    sed -i 's/#applications\/mod_cidlookup/applications\/mod_cidlookup/g' build/modules.conf.in && \
    sed -i 's/#applications\/mod_memcache/applications\/mod_memcache/g' build/modules.conf.in && \
    sed -i 's/#applications\/mod_curl/applications\/mod_curl/g' build/modules.conf.in && \
    sed -i 's/#applications\/mod_nibblebill/applications\/mod_nibblebill/g' build/modules.conf.in && \
    sed -i 's/#formats\/mod_shout/formats\/mod_shout/g' build/modules.conf.in && \
    sed -i 's/#formats\/mod_pgsql/formats\/mod_pgsql/g' build/modules.conf.in && \
    sed -i 's/#say\/mod_say_es/say\/mod_say_es/g' build/modules.conf.in && \
    sed -i 's/#say\/mod_say_fr/say\/mod_say_fr/g' build/modules.conf.in && \
    # Configure and build
    ./configure -C --enable-portable-binary \
                --disable-dependency-tracking \
                --prefix=/usr \
                --localstatedir=/var \
                --sysconfdir=/etc \
                --with-openssl \
                --enable-core-pgsql-support && \
    # Install
    make -j $(nproc) && \
    make install && \
    # Install sounds
    make sounds-install moh-install && \
    make hd-sounds-install hd-moh-install && \
    make cd-sounds-install cd-moh-install && \
    # Setup music directory properly in vgtpbx directory
    mkdir -p /etc/vgtpbx/media/fs/music/default && \
    mv /usr/share/freeswitch/sounds/music/*000 /etc/vgtpbx/media/fs/music/default/ && \
    rm -rf /usr/share/freeswitch/sounds/music && \
    ln -s /etc/vgtpbx/media/fs/music /usr/share/freeswitch/sounds/music && \
    # Cleanup
    cd / && \
    rm -rf /usr/src/freeswitch

# mod_bcg729 installation
RUN cd /usr/src && \
    git clone https://github.com/xadhoom/mod_bcg729.git && \
    cd mod_bcg729 && \
    make -j $(nproc) && \
    make install && \
    cd / && \
    rm -rf /usr/src/mod_bcg729

# Move recordings and voicemail to vgtpbx directory
RUN mkdir -p /etc/vgtpbx/media/fs/recordings && \
    mkdir -p /etc/vgtpbx/media/fs/voicemail/default && \
    rmdir /var/lib/freeswitch/recordings && \
    ln -s /etc/vgtpbx/media/fs/recordings /var/lib/freeswitch/recordings && \
    rm -rf /var/lib/freeswitch/storage/voicemail && \
    ln -s /etc/vgtpbx/media/fs/voicemail /var/lib/freeswitch/storage/voicemail && \
    chown -R vgtpbx:vgtpbx /etc/vgtpbx/media/fs/voicemail/default && \
    chown -R vgtpbx:vgtpbx /etc/vgtpbx/media/fs/recordings

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