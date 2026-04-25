# BUILD THE SERVER IMAGE
FROM --platform=linux/amd64 debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    unzip \
    xz-utils \
    procps \
    libicu-dev \
    gettext-base \
    xvfb \
    xauth \
    jq \
    && curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | \
        gpg --dearmor -o /usr/share/keyrings/winehq-archive.key \
    && echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/debian/ bookworm main" \
        > /etc/apt/sources.list.d/winehq.list \
    && apt-get update \
    && apt-get install -y --install-recommends winehq-stable \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install PowerShell 7 (pwsh) — used by WindrosePlus scripts natively on Linux
RUN curl -fsSL https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb \
        -o /tmp/packages-microsoft-prod.deb && \
    dpkg -i /tmp/packages-microsoft-prod.deb && \
    rm /tmp/packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends powershell && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Linux-native repak and retoc (replace WindrosePlus bundled .exe tools)
ARG REPAK_VERSION=v0.2.3
ARG RETOC_VERSION=v0.1.5
RUN set -eux; \
    curl -fsSL "https://github.com/trumank/repak/releases/download/${REPAK_VERSION}/repak_cli-x86_64-unknown-linux-gnu.tar.xz" \
         -o /tmp/repak.tar.xz && \
    tar -xJf /tmp/repak.tar.xz -C /tmp && \
    install -m 0755 "$(find /tmp -maxdepth 3 -type f -name repak | head -1)" /usr/local/bin/repak && \
    rm -rf /tmp/repak.tar.xz /tmp/repak_cli-* ; \
    curl -fsSL "https://github.com/trumank/retoc/releases/download/${RETOC_VERSION}/retoc_cli-x86_64-unknown-linux-gnu.tar.xz" \
         -o /tmp/retoc.tar.xz && \
    tar -xJf /tmp/retoc.tar.xz -C /tmp && \
    install -m 0755 "$(find /tmp -maxdepth 3 -type f -name retoc | head -1)" /usr/local/bin/retoc && \
    rm -rf /tmp/retoc.tar.xz /tmp/retoc_cli-*

# Default Windrose+ version — can be overridden at runtime via WINDROSE_PLUS_VERSION
ARG WINDROSE_PLUS_VERSION_DEFAULT=latest
ENV WINDROSE_PLUS_VERSION_DEFAULT=${WINDROSE_PLUS_VERSION_DEFAULT}

# Install .NET 8 runtime (required for DepotDownloader)
RUN curl -sL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh --channel 8.0 --runtime dotnet --install-dir /usr/share/dotnet && \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet && \
    rm /tmp/dotnet-install.sh

# Download DepotDownloader
ARG DEPOT_DOWNLOADER_VERSION=3.4.0
RUN curl -sL \
    "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DOWNLOADER_VERSION}/DepotDownloader-linux-x64.zip" -o \
    /tmp/dd.zip && \
    mkdir -p /depotdownloader && \
    unzip /tmp/dd.zip -d /depotdownloader && \
    chmod +x /depotdownloader/DepotDownloader && \
    rm /tmp/dd.zip

RUN useradd -m -s /bin/bash steam

# Init Wine prefix
ENV WINEPREFIX=/home/steam/.wine \
    WINEARCH=win64 \
    WINEDLLOVERRIDES="mscoree,mshtml=;dwmapi=n,b" \
    DISPLAY=:0
RUN Xvfb :0 -screen 0 1024x768x16 & \
    sleep 2 && \
    su -l steam -c "WINEPREFIX=/home/steam/.wine WINEARCH=win64 WINEDLLOVERRIDES='mscoree,mshtml=' winecfg -v win10 >/dev/null 2>&1; wineboot --init >/dev/null 2>&1" && \
    kill %1 2>/dev/null; true

ENV HOME=/home/steam \
    UPDATE_ON_START=true

COPY ./scripts /home/steam/server/
COPY branding /branding

RUN mkdir -p /home/steam/server-files && \
    chmod +x /home/steam/server/*.sh

# Persist user data: game files, Windrose+ config, and Lua mods all live under
# this single volume. The installer symlinks the deep UE4SS-mandated Mods path
# to server-files/windrose_plus_mods/ so users only interact with one mount.
VOLUME ["/home/steam/server-files"]

WORKDIR /home/steam/server

HEALTHCHECK --start-period=5m \
            CMD pgrep "wine" > /dev/null || exit 1

ENTRYPOINT ["/home/steam/server/init.sh"]
