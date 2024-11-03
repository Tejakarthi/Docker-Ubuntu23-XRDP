# Use the official Ubuntu 22.04 as the base image
FROM ubuntu:latest

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Define arguments for environment variables that will be passed from the .env file
ARG RDP_PORT
ARG RDP_USER
ARG RDP_PASSWORD

# Set environment variables
ENV RDP_PORT=${RDP_PORT}
ENV RDP_USER=${RDP_USER}
ENV RDP_PASSWORD=${RDP_PASSWORD}

# Install required packages
RUN apt-get update && apt-get install -y \
    xrdp \
    xfce4 \
    xfce4-goodies \
    supervisor \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure XRDP to use the specified port and user settings
RUN adduser xrdp ssl-cert
RUN sed -i "s/3389/${RDP_PORT}/g" /etc/xrdp/xrdp.ini
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

# Set a password for the specified user
RUN echo "${RDP_USER}:${RDP_PASSWORD}" | chpasswd

# Expose the specified RDP port
EXPOSE ${RDP_PORT}

# Start Supervisor, which will manage xrdp and xrdp-sesman
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
