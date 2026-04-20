![marketing_assets_banner](https://github.com/user-attachments/assets/b8b4ae5c-06bb-46a7-8d94-903a04595036)
[![GitHub License](https://img.shields.io/github/license/indifferentbroccoli/windrose-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/windrose-server-docker/blob/main/LICENSE)
[![GitHub Release](https://img.shields.io/github/v/release/indifferentbroccoli/windrose-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/windrose-server-docker/releases)
[![GitHub Repo stars](https://img.shields.io/github/stars/indifferentbroccoli/windrose-server-docker?style=for-the-badge&color=6aa84f)](https://github.com/indifferentbroccoli/windrose-server-docker)
[![Discord](https://img.shields.io/discord/798321161082896395?style=for-the-badge&label=Discord&labelColor=5865F2&color=6aa84f)](https://discord.gg/indifferentbroccoli)
[![Docker Pulls](https://img.shields.io/docker/pulls/indifferentbroccoli/windrose-server-docker?style=for-the-badge&color=6aa84f)](https://hub.docker.com/r/indifferentbroccoli/windrose-server-docker)

Game server hosting · Fast RAM · High-speed internet · Eat lag for breakfast

[Try our Windrose server hosting free for 2 days!](https://indifferentbroccoli.com/windrose-server-hosting)

## Windrose Dedicated Server Docker

A Docker container for running a Windrose dedicated server. The server binary is Windows-only and runs via Wine.

## Server Requirements

| | 2 Players | 4 Players | 10 Players |
|--|-----------|-----------|------------|
| CPU | 2 cores @ 3.2 GHz | 2 cores @ 3.2 GHz | 2 cores @ 3.2 GHz |
| RAM | 8 GB | 12 GB | 16 GB |
| Storage | 35 GB SSD | 35 GB SSD | 35 GB SSD |

## How to use

Copy the `.env.example` file to `.env`, fill in your values, then use either `docker compose` or `docker run`.

### Docker Compose

```yaml
services:
  windrose:
    image: indifferentbroccoli/windrose-server-docker
    restart: unless-stopped
    container_name: windrose
    stop_grace_period: 30s
    env_file:
      - .env
    volumes:
      - ./server-files:/home/steam/server-files
```

```shell
docker compose up -d
```

### Docker Run

```shell
docker run -d \
    --restart unless-stopped \
    --name windrose \
    --stop-timeout 30 \
    --env-file .env \
    -v ./server-files:/home/steam/server-files \
    indifferentbroccoli/windrose-server-docker
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID to run the server process as |
| `PGID` | `1000` | Group ID to run the server process as |
| `UPDATE_ON_START` | `true` | Download and validate server files on every startup. Set to `false` to skip. |
| `USE_DIRECT_CONNECTION` | `false` | Set to `true` to connect to your server via IP and port instead of invite code. |
| `SERVER_PORT` | `7777` | Only applies if `USE_DIRECT_CONNECTION=true`. Port for direct connection. |
| `DIRECT_CONNECTION_PROXY_ADDRESS` | `0.0.0.0` | Only applies if `USE_DIRECT_CONNECTION=true`. Address for the direct connection proxy. |
| `USER_SELECTED_REGION` | `EU` | Region for the connection service. Options: `SEA`, `CIS`, `EU` |
| `INVITE_CODE` | | Invite code players use to connect if `USE_DIRECT_CONNECTION=false` (default). Min 6 characters, `0-9 a-z A-Z`, case sensitive |
| `SERVER_NAME` | | Display name for your server |
| `SERVER_PASSWORD` | | Leave empty for a public server |
| `MAX_PLAYERS` | `10` | Maximum number of simultaneous players |
| `P2P_PROXY_ADDRESS` | `127.0.0.1` | IP address the P2P proxy binds to. Use `127.0.0.1` (default) in Docker — the proxy is an internal socket and does not need to be reachable from outside the container |
| `GENERATE_SETTINGS` | `true` | Set to `false` to skip all config generation and patching. The server will start using whatever is already in `ServerDescription.json` on disk or create a new one. |

## Server Configuration

On first start the server automatically generates two configuration files inside `server-files/`. The container handles this automatically — it starts the server once to generate the files, applies your settings, then starts normally.

### Connecting

Players connect either via invite code (default) or IP address & port. The values for both can be set in your `.env` and are also visible in `server-files/R5/ServerDescription.json`.
Invite codes use the ICE protocol to establish a P2P connection.
Using your server's IP address will establish a direct connection.

> [!IMPORTANT]
> You can use an invite code or a direct connection via IP address, but not both.

#### Invite code

The code is set by `INVITE_CODE` in the `.env` file or `InviteCode` in `ServerDescription.json`. Share it with players who join via **Play → Connect to Server** in-game.

#### IP Address

This is enabled by `USE_DIRECT_CONNECTION=true` in the `.env` file or `UseDirectConnection` in `ServerDescription.json`.

#### LAN connections

If any players are connecting from the same local network, the default `P2P_PROXY_ADDRESS=127.0.0.1` will not work. You must:

1. Set `P2P_PROXY_ADDRESS` to the server machine's LAN IP address (e.g. `192.168.1.100`)
2. Add `network_mode: host` to your `docker-compose.yml` service so the container shares the host's network stack

```yaml
services:
  windrose:
    image: indifferentbroccoli/windrose-server-docker
    restart: unless-stopped
    container_name: windrose
    stop_grace_period: 30s
    network_mode: host
    env_file:
      - .env
    volumes:
      - ./server-files:/home/steam/server-files
```

### ServerDescription.json

Located at `server-files/R5/ServerDescription.json`. This file can only be edited while the server is stopped.

| Field | Description |
|-------|-------------|
| `InviteCode` | Invite code for players to find your server. Min 6 chars, `0-9 a-z A-Z`, case sensitive |
| `UseDirectConnection` | `true` if using direct connection via IP, or `false` (default) if using invite code |
| `DirectConnectionServerPort` | Port when direct connection is enabled. Default is `7777` |
| `DirectConnectionServerAddress` | Technical field — should not be changed |
| `DirectConnectionProxyAddress` | Address for the direct connection proxy. Default is `0.0.0.0` |
| `UserSelectedRegion` | Region for the connection service. Default is `EU`. Options: `SEA`, `CIS`, `EU` |
| `IsPasswordProtected` | `true` or `false` |
| `Password` | Server password |
| `ServerName` | Display name of the server |
| `WorldIslandId` | ID of the world to load — must match the folder name of a `WorldDescription.json` |
| `MaxPlayerCount` | Maximum simultaneous players |
| `P2pProxyAddress` | IP for listening sockets. Use `127.0.0.1` (default) — the proxy is an internal socket |

```json
{
    "Version": 1,
    "ServerDescription_Persistent": {
        "PersistentServerId": "...",
        "InviteCode": "myfriends",
        "IsPasswordProtected": false,
        "Password": "",
        "ServerName": "My Windrose Server",
        "WorldIslandId": "...",
        "MaxPlayerCount": 10,
        "P2pProxyAddress": "127.0.0.1",
        "DirectConnectionProxyAddress": "0.0.0.0",
        "UseDirectConnection": false,
        "DirectConnectionServerPort": 7777,
        "UserSelectedRegion": "EU",
        "DirectConnectionServerAddress": ""
    }
}
```

### WorldDescription.json

Located at `server-files/R5/Saved/SaveProfiles/Default/RocksDB/<version>/Worlds/<world-id>/WorldDescription.json`. One file per world. This file can only be edited while the server is stopped.

| Field | Description |
|-------|-------------|
| `WorldPresetType` | Difficulty preset: `"Easy"`, `"Medium"`, `"Hard"`, or `"Custom"`. If any `WorldSettings` values are present the server forces this to `"Custom"` |
| `WorldName` | Name of the world |
| `WorldSettings` | Custom parameters — leave all sections empty to use a preset |

#### WorldSettings parameters

> Only takes effect when `WorldPresetType` is `"Custom"`. Leave `WorldSettings` empty to use a preset.

**Bool parameters**

| Parameter key | Default | Description |
|---------------|---------|-------------|
| `WDS.Parameter.Coop.SharedQuests` | `true` | When a player completes a co-op quest it auto-completes for all players who have it active |
| `WDS.Parameter.EasyExplore` | `false` | Hides map markers for points of interest, making exploration harder. Called "Immersive Exploration" in-game |

**Float parameters**

| Parameter key | Default | Range | Description |
|---------------|---------|-------|-------------|
| `WDS.Parameter.MobHealthMultiplier` | `1.0` | 0.2 – 5.0 | Enemy health multiplier |
| `WDS.Parameter.MobDamageMultiplier` | `1.0` | 0.2 – 5.0 | Enemy damage multiplier |
| `WDS.Parameter.ShipsHealthMultiplier` | `1.0` | 0.4 – 5.0 | Enemy ship health multiplier |
| `WDS.Parameter.ShipsDamageMultiplier` | `1.0` | 0.2 – 2.5 | Enemy ship damage multiplier |
| `WDS.Parameter.BoardingDifficultyMultiplier` | `1.0` | 0.2 – 5.0 | How many enemy sailors must be defeated to win a boarding action |
| `WDS.Parameter.Coop.StatsCorrectionModifier` | `1.0` | 0.0 – 2.0 | Adjusts enemy health and posture loss based on player count |
| `WDS.Parameter.Coop.ShipStatsCorrectionModifier` | `0.0` | 0.0 – 2.0 | Adjusts enemy ship health based on player count |

**Tag parameters**

| Parameter key | Default | Options | Description |
|---------------|---------|---------|-------------|
| `WDS.Parameter.CombatDifficulty` | `WDS.Parameter.CombatDifficulty.Normal` | `Easy` / `Normal` / `Hard` | Boss encounter difficulty and general enemy aggression |

**Example `WorldDescription.json`:**

```json
{
    "Version": 1,
    "WorldDescription": {
        "IslandId": "...",
        "WorldName": "My World",
        "WorldPresetType": "Custom",
        "WorldSettings": {
            "BoolParameters": {
                "{\"TagName\": \"WDS.Parameter.Coop.SharedQuests\"}": true,
                "{\"TagName\": \"WDS.Parameter.EasyExplore\"}": false
            },
            "FloatParameters": {
                "{\"TagName\": \"WDS.Parameter.MobHealthMultiplier\"}": 1,
                "{\"TagName\": \"WDS.Parameter.MobDamageMultiplier\"}": 1,
                "{\"TagName\": \"WDS.Parameter.ShipsHealthMultiplier\"}": 1,
                "{\"TagName\": \"WDS.Parameter.ShipsDamageMultiplier\"}": 1,
                "{\"TagName\": \"WDS.Parameter.BoardingDifficultyMultiplier\"}": 1,
                "{\"TagName\": \"WDS.Parameter.Coop.StatsCorrectionModifier\"}": 1,
                "{\"TagName\": \"WDS.Parameter.Coop.ShipStatsCorrectionModifier\"}": 0
            },
            "TagParameters": {
                "{\"TagName\": \"WDS.Parameter.CombatDifficulty\"}": {
                    "TagName": "WDS.Parameter.CombatDifficulty.Normal"
                }
            }
        }
    }
}
```

## Volumes

| Path | Description |
|------|-------------|
| `/home/steam/server-files` | Server installation files, world saves, and configuration |

## Proxmox

If you are hosting this server inside a Proxmox VM or LXC container, set the CPU type to **host**.

Proxmox's default CPU types (e.g. `kvm64`) omit instruction sets that Wine and the server binary may depend on. This can cause the server to fail to start, crash at runtime, or fail silently with no useful output.

## About

This is a Dockerized Windrose dedicated server maintained by [indifferent broccoli](https://indifferentbroccoli.com). We offer [managed Windrose server hosting](https://indifferentbroccoli.com/windrose-server-hosting) if you'd rather not self-host.
