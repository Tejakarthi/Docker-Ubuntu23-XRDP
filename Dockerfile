FROM ubuntu:latest

# Expose RDP port
EXPOSE 3389/tcp

# Set build arguments
ARG USER=test
ARG PASS=1234
ARG X11Forwarding=false
ARG DEBIAN_FRONTEND=noninteractive

# Install required packages and clean up
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
        ubuntu-desktop-minimal \
        dbus-x11 \
        xrdp \
        sudo \
        openssl \
        locales \
        curl \
        wget \
        pulseaudio \
        software-properties-common && \
    if [ "$X11Forwarding" = "true" ]; then \
        apt-get install -y openssh-server; \
    fi && \
    # Generate locale
    locale-gen en_US.UTF-8 && \
    # Clean up
    apt-get autoremove --purge -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -f /run/reboot-required*

# Configure user, XRDP, and desktop environment
RUN useradd -s /bin/bash -m $USER -p $(openssl passwd "$PASS") && \
    usermod -aG sudo $USER && \
    adduser xrdp ssl-cert && \
    # Setting the required environment variables
    echo 'LANG=en_US.UTF-8' >> /etc/default/locale && \
    echo 'LANGUAGE=en_US:en' >> /etc/default/locale && \
    echo 'LC_ALL=en_US.UTF-8' >> /etc/default/locale && \
    # Configure user session
    echo 'export GNOME_SHELL_SESSION_MODE=ubuntu' > /home/$USER/.xsessionrc && \
    echo 'export XDG_CURRENT_DESKTOP=ubuntu:GNOME' >> /home/$USER/.xsessionrc && \
    echo 'export XDG_SESSION_TYPE=x11' >> /home/$USER/.xsessionrc && \
    echo 'export LANG=en_US.UTF-8' >> /home/$USER/.xsessionrc && \
    chown $USER:$USER /home/$USER/.xsessionrc && \
    # Enabling log to stdout and configuring XRDP
    sed -i "s/#EnableConsole=false/EnableConsole=true/g" /etc/xrdp/xrdp.ini && \
    # Configure XRDP performance settings
    sed -i 's/max_bpp=32/max_bpp=16/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/xserverbpp=24/xserverbpp=16/g' /etc/xrdp/xrdp.ini && \
    # Add custom port setting
    sed -i 's/port=3389/port=3389/g' /etc/xrdp/xrdp.ini && \
    # Configure Polkit for GNOME
    mkdir -p /etc/polkit-1/localauthority/50-local.d && \
    echo "[Allow Colord all Users]\n\
Identity=unix-user:*\n\
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile\n\
ResultAny=no\n\
ResultInactive=no\n\
ResultActive=yes" > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla && \
    # Configure X11 forwarding if enabled
    if [ "$X11Forwarding" = "true" ]; then \
        sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config; \
    fi

# Start required services using a single CMD with shell form
CMD rm -f /var/run/xrdp/xrdp*.pid && \
    service dbus start && \
    /usr/lib/systemd/systemd-logind & \
    if [ -f /usr/sbin/sshd ]; then \
        /usr/sbin/sshd; \
    fi && \
    xrdp-sesman --config /etc/xrdp/sesman.ini && \
    exec xrdp --nodaemon --config /etc/xrdp/xrdp.ini
