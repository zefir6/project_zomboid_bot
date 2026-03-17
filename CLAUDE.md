# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Setup

Install dependencies:
```
pip install discord.py python-dotenv watchgod file_read_backwards docker
```

Copy and populate the environment file:
```
cp .env.sample .env
```

Run the bots:
```
python3 pzbot.py      # Command bot
python3 pzwatcher.py  # Log watcher bot
```

## Architecture

This is a two-process Discord bot for managing a Project Zomboid game server. Both scripts must run on the same machine as the PZ server.

**`pzbot.py`** — The main command bot. Uses `discord.py` with `commands.Cog` to organize commands into three permission tiers:
- `AdminCommands` — server restart, access level changes (requires role in `ADMIN_ROLES`)
- `ModeratorCommands` — bans, kicks, whitelist management, teleport, items (requires role in `MODERATOR_ROLES`)
- `UserCommands` — player stats, death counts, playtime, mod list, whitelist self-service

Server communication uses `SourceRcon` (TCP socket, Valve RCON protocol) to issue commands. Player statistics are computed by walking and parsing `*_user.txt` log files in `LOG_PATH`. A background `status_task` polls the server every 20s and updates the bot's Discord presence with the current player count or "Server offline".

**`pzwatcher.py`** — A separate log-watching process. Uses `watchgod.awatch` to monitor `LOG_PATH` for file changes, then reads the tail of changed `*_user.txt` files with `file_read_backwards` to detect join, disconnect, and death events, posting them to `NOTIFICATION_CHANNEL`.

**`SourceRcon.py`** — Pure Python implementation of the Valve Source RCON protocol (TCP). Handles authentication, multi-packet responses, and reconnection. Imported directly by `pzbot.py`.

## Key Environment Variables

| Variable | Purpose |
|---|---|
| `RCON_PASS` / `RCON_SERVER` / `RCON_PORT` | RCON connection (default port: 27015) |
| `DISCORD_TOKEN` / `DISCORD_GUILD` | Discord bot credentials |
| `ADMIN_ROLES` / `MODERATOR_ROLES` | Comma-separated role names for permission checks |
| `WHITELIST_ROLES` | Roles allowed to self-register via `!pzrequestaccess` |
| `LOG_PATH` | Path to the PZ server `Logs/` directory |
| `NOTIFICATION_CHANNEL` / `INGAME_CHANNEL` | Discord channel IDs |
| `IGNORE_CHANNELS` | Comma-separated channel names where commands are blocked |
| `PZ_CONTAINER_NAME` | Docker container name for the PZ server (default: `projectzomboid`) |
| `SERVER_ADDRESS` | Shown to players after whitelist access is granted |

## Docker Deployment

The bot runs in a Docker container alongside the PZ server container. Both share a Docker network (`zomboid_zomboid`) so the bot can reach RCON at `projectzomboid:27015` without publishing ports.

A `tecnativa/docker-socket-proxy` sidecar limits Docker socket access to container inspection and restarts only.

```bash
# Create the shared network (if the PZ server container doesn't create it)
docker network create zomboid_zomboid

# Build and start
docker compose up -d

# View logs
docker compose logs -f pz-bot
```

The `./server-data` directory must be the same bind-mount used by the PZ server container (maps to `/project-zomboid-config` inside both containers).
