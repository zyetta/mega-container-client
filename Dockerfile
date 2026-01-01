FROM ubuntu:24.04

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# Create app directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    ca-certificates \
    uuid-runtime \
    python3 \
    python3-flask \
    gosu \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install MEGAcmd
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        wget -O megacmd.deb https://mega.nz/linux/repo/xUbuntu_24.04/amd64/megacmd-xUbuntu_24.04_amd64.deb; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        wget -O megacmd.deb https://mega.nz/linux/repo/xUbuntu_24.04/arm64/megacmd-xUbuntu_24.04_arm64.deb; \
    else \
        echo "Unsupported architecture: $TARGETARCH" && exit 1; \
    fi \
    && apt-get update \
    && apt-get install -y ./megacmd.deb \
    && rm megacmd.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy scripts
COPY scripts/entrypoint.sh /app/entrypoint.sh
COPY scripts/monitor.sh /app/monitor.sh
COPY scripts/server.py /app/server.py
RUN chmod +x /app/entrypoint.sh /app/monitor.sh

EXPOSE 5000

CMD ["/app/entrypoint.sh"]