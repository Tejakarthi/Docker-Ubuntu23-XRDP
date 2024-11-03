FROM ubuntu:latest

# Build arguments with more secure defaults
ARG USER=desktop_user
ARG PASS_HASH
ARG X11Forwarding=false
ARG DEBIAN_FRONTEND=noninteractive

# Expose RDP port
EXPOSE 3389/tcp
# Expose health check port
EXPOSE 8080/tcp

# Install required packages and clean up in a single layer
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
        software-properties-common \
        ufw \
        python3-minimal && \
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

# Create a simple health check server
RUN echo '#!/usr/bin/env python3\n\
from http.server import HTTPServer, BaseHTTPRequestHandler\n\
import subprocess\n\
\n\
class HealthHandler(BaseHTTPRequestHandler):\n\
    def do_GET(self):\n\
        if self.path == "/health":\n\
            try:\n\
                subprocess.check_output(["pgrep", "xrdp"])\n\
                self.send_response(200)\n\
                self.send_header("Content-type", "text/plain")\n\
                self.end_headers()\n\
                self.wfile.write(b"OK")\n\
            except subprocess.CalledProcessError:\n\
                self.send_response(503)\n\
                self.send_header("Content-type", "text/plain")\n\
                self.end_headers()\n\
                self.wfile.write(b"XRDP not running")\n\
        else:\n\
            self.send_response(404)\n\
            self.end_headers()\n\
\n\
server = HTTPServer(("", 8080), HealthHandler)\n\
server.serve_forever()' > /usr/local/bin/healthcheck.py && \
    chmod +x /usr/local/bin/healthcheck.py

# Configure user and environment
RUN useradd -s /bin/bash -m $USER && \
    if [ ! -z "$PASS_HASH" ]; then \
        usermod -p "$PASS_HASH" $USER; \
    fi && \
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
    chmod 644 /home/$USER/.xsessionrc

# Configure XRDP with security settings
RUN sed -i "s/#EnableConsole=false/EnableConsole=true/g" /etc/xrdp/xrdp.ini && \
    sed -i 's/max_bpp=32/max_bpp=16/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/xserverbpp=24/xserverbpp=16/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/security_layer=negotiate/security_layer=tls/g' /etc/xrdp/xrdp.ini && \
    sed -i 's/crypt_level=high/crypt_level=fips/g' /etc/xrdp/xrdp.ini && \
    # Configure firewall
    ufw default deny incoming && \
    ufw allow 3389/tcp && \
    ufw allow 8080/tcp && \
    ufw --force enable

# Create Polkit configuration file
RUN echo '[Allow Colord all Users]\n\
Identity=unix-user:*\n\
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile\n\
ResultAny=no\n\
ResultInactive=no\n\
ResultActive=yes' > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla

# X11 forwarding configuration (if enabled)
RUN if [ "$X11Forwarding" = "true" ]; then \
        sed -i 's/#X11UseLocalhost yes/X11UseLocalhost no/g' /etc/ssh/sshd_config && \
        echo "X11Forwarding yes" >> /etc/ssh/sshd_config; \
    fi

# Start required services
CMD rm -f /var/run/xrdp/xrdp*.pid && \
    service dbus start && \
    /usr/lib/systemd/systemd-logind & \
    if [ -f /usr/sbin/sshd ]; then \
        /usr/sbin/sshd; \
    fi && \
    # Start the health check server in the background
    /usr/local/bin/healthcheck.py & \
    xrdp-sesman --config /etc/xrdp/sesman.ini && \
    exec xrdp --nodaemon --config /etc/xrdp/xrdp.ini
