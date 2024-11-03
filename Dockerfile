# Use the official Ubuntu 22.04 as the base image
FROM ubuntu:latest

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    xrdp \
    xfce4 \
    xfce4-goodies \
    supervisor \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure XRDP to listen on port 3390 instead of the default 3389
RUN adduser xrdp ssl-cert
RUN sed -i 's/3389/3390/g' /etc/xrdp/xrdp.ini
RUN echo "startxfce4" > /etc/skel/.xsession

# Configure Supervisor to manage XRDP services
RUN mkdir -p /var/log/supervisor
RUN echo "[supervisord]" > /etc/supervisor/conf.d/supervisord.conf && \
    echo "nodaemon=true" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "[program:xrdp-sesman]" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "command=/usr/sbin/xrdp-sesman --nodaemon" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stdout_logfile=/var/log/supervisor/xrdp-sesman.log" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stderr_logfile=/var/log/supervisor/xrdp-sesman.err" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "[program:xrdp]" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "command=/usr/sbin/xrdp --nodaemon" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stdout_logfile=/var/log/supervisor/xrdp.log" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stderr_logfile=/var/log/supervisor/xrdp.err" >> /etc/supervisor/conf.d/supervisord.conf

# Set a password for the root user (change 'password' to your desired password)
RUN echo 'root:password' | chpasswd

# Expose the RDP port
EXPOSE 3390

# Start Supervisor, which will manage xrdp and xrdp-sesman
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
