# BUILD HELPER TOOLS NATIVELY FOR THE TARGET ARCHITECTURE
FROM --platform=$TARGETPLATFORM rust:bookworm AS rust-tools-builder

ARG REPAK_VERSION=v0.2.3
ARG RETOC_VERSION=v0.1.5

RUN set -eux; \
    git clone --branch "${REPAK_VERSION}" --depth 1 https://github.com/trumank/repak.git /tmp/repak && \
    cargo build --manifest-path /tmp/repak/Cargo.toml --locked --release --bin repak && \
    install -m 0755 /tmp/repak/target/release/repak /usr/local/bin/repak

RUN set -eux; \
    git clone --branch "${RETOC_VERSION}" --depth 1 https://github.com/trumank/retoc.git /tmp/retoc && \
    cargo build --manifest-path /tmp/retoc/Cargo.toml --locked --release --bin retoc && \
    install -m 0755 /tmp/retoc/target/release/retoc /usr/local/bin/retoc

# BUILD THE SERVER IMAGE
FROM --platform=$TARGETPLATFORM debian:bookworm-slim

ARG TARGETARCH
ARG DEPOT_DOWNLOADER_VERSION=3.4.0
ARG HANGOVER_VERSION=hangover-10.18
ARG POWERSHELL_VERSION=7.5.4
ARG WINDROSE_PLUS_VERSION_DEFAULT=latest

ENV DEBIAN_FRONTEND=noninteractive
ENV WINDROSE_PLUS_VERSION_DEFAULT=${WINDROSE_PLUS_VERSION_DEFAULT}

RUN apt-get update && apt-get install -y --no-install-recommends \
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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) \
            dpkg --add-architecture i386; \
            curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | \
                gpg --dearmor -o /usr/share/keyrings/winehq-archive.key; \
            echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/debian/ bookworm main" \
                > /etc/apt/sources.list.d/winehq.list; \
            apt-get update; \
            apt-get install -y --install-recommends winehq-stable; \
            ;; \
        arm64) \
            asset_url="$(curl -fsSL "https://api.github.com/repos/AndreRH/hangover/releases/tags/${HANGOVER_VERSION}" | jq -r '.assets[] | select((.name | test("debian12|bookworm"; "i")) and (.name | test("arm64"; "i")) and (.name | test("\\.(tar|deb)$"; "i"))) | .browser_download_url' | head -n 1)"; \
            if [ -z "${asset_url}" ] || [ "${asset_url}" = "null" ]; then \
                echo "Could not find a Debian 12 / bookworm arm64 Hangover package for ${HANGOVER_VERSION}" >&2; \
                exit 1; \
            fi; \
            mkdir -p /tmp/hangover; \
            if echo "${asset_url}" | grep -qi '\.deb$'; then \
                curl -fsSL "${asset_url}" -o /tmp/hangover/hangover.deb; \
            else \
                curl -fsSL "${asset_url}" -o /tmp/hangover/hangover.tar; \
                tar -xf /tmp/hangover/hangover.tar -C /tmp/hangover; \
            fi; \
            apt-get update; \
            find /tmp/hangover -type f -name '*.deb' -print0 | xargs -0 apt-get install -y --no-install-recommends; \
            ;; \
        *) \
            echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; \
            exit 1; \
            ;; \
    esac; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/hangover

# Install PowerShell 7 (pwsh) used by WindrosePlus scripts natively on Linux.
# Debian arm64 packages are not published in the Microsoft apt repo, so use
# the official release tarball on arm64.
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) \
            curl -fsSL https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb \
                -o /tmp/packages-microsoft-prod.deb; \
            dpkg -i /tmp/packages-microsoft-prod.deb; \
            rm /tmp/packages-microsoft-prod.deb; \
            apt-get update; \
            apt-get install -y --no-install-recommends powershell; \
            apt-get clean; \
            rm -rf /var/lib/apt/lists/*; \
            ;; \
        arm64) \
            mkdir -p /opt/microsoft/powershell/7; \
            curl -fsSL \
                "https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}/powershell-${POWERSHELL_VERSION}-linux-arm64.tar.gz" \
                -o /tmp/powershell.tar.gz; \
            tar -xzf /tmp/powershell.tar.gz -C /opt/microsoft/powershell/7; \
            chmod +x /opt/microsoft/powershell/7/pwsh; \
            ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh; \
            rm /tmp/powershell.tar.gz; \
            ;; \
        *) \
            echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; \
            exit 1; \
            ;; \
    esac

COPY --from=rust-tools-builder /usr/local/bin/repak /usr/local/bin/repak
COPY --from=rust-tools-builder /usr/local/bin/retoc /usr/local/bin/retoc

# Install .NET 8 runtime (required for DepotDownloader)
RUN curl -sL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    chmod +x /tmp/dotnet-install.sh && \
    /tmp/dotnet-install.sh --channel 8.0 --runtime dotnet --install-dir /usr/share/dotnet && \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet && \
    rm /tmp/dotnet-install.sh

# Download DepotDownloader
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) depot_arch="x64" ;; \
        arm64) depot_arch="arm64" ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL \
    "https://github.com/SteamRE/DepotDownloader/releases/download/DepotDownloader_${DEPOT_DOWNLOADER_VERSION}/DepotDownloader-linux-${depot_arch}.zip" -o \
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
    sed -i 's/\r$//' /home/steam/server/*.sh && \
    chmod +x /home/steam/server/*.sh

# Persist user data: game files, Windrose+ config, and Lua mods all live under
# this single volume. The installer symlinks the deep UE4SS-mandated Mods path
# to server-files/windrose_plus_mods/ so users only interact with one mount.
VOLUME ["/home/steam/server-files"]

WORKDIR /home/steam/server

HEALTHCHECK --start-period=5m \
            CMD pgrep "wine" > /dev/null || exit 1

ENTRYPOINT ["/home/steam/server/init.sh"]
