# Project Zomboid Discord Bot

Discord bot for managing your PZ server and enabling player interactions.

> **Based on** [rfalias/project_zomboid_bot](https://github.com/rfalias/project_zomboid_bot) — this fork adds Docker support using the [`indifferentbroccoli/projectzomboid-server-docker`](https://github.com/indifferentbroccoli/projectzomboid-server-docker) image, replacing systemd/psutil with Docker SDK-based process management.

---

# Features

#### Bot status displays the server status
Bot updates its status with either the current count of players in-game or "Offline" if the server is down.

Join and leave announcements.

#### Role based commands
Limit administrative server commands to users with specific Discord roles.

Moderators can do everything except elevate users to admin.

#### User Self Service
Players with the correct role can request access to the server whitelist via a command. The bot will DM them with their new password and connection information.

```
!pzrequestaccess someuser
```

#### Player deaths and time on server
Generate a live report of active playtime. Updates live for actively connected users.

```
!pzplaytime
User1 has played for 1d, 7h, 24m, 58s
User2 has played for 1d, 1h, 46m, 15s
Survivor1 has played for 17h, 13m, 40s
```

---

# Architecture

Two processes run inside a single Docker container:

- **`pzbot.py`** — handles all commands, RCON communication, and bot status updates
- **`pzwatcher.py`** — watches log files and reports join/leave/death events to Discord channels

The bot connects to the PZ server via RCON over the shared Docker network (`pz-network`). Server restarts are performed via the Docker SDK (through a restricted socket proxy) rather than systemd or shell commands.

```
Host
├── /var/run/docker.sock
│
└── Docker
    ├── pz-network (external, shared)
    │   ├── projectzomboid   ← PZ server (indifferentbroccoli image)
    │   │   └── RCON :27015 (internal only)
    │   └── pz-bot           ← this bot
    │
    └── proxy-network (internal)
        ├── pz-bot
        └── pz-docker-proxy  ← tecnativa/docker-socket-proxy
            └── CONTAINERS=1, ALLOW_RESTARTS=1 only
```

---

# Requirements and Setup

## Docker (recommended)

**Prerequisites:** Docker + Docker Compose, a running PZ server container on a shared network.

**1. Create the shared Docker network** (skip if it already exists):
```bash
docker network create pz-network
```

**2. Clone and configure:**
```bash
git clone <this repo>
cd project_zomboid_bot
cp .env.sample .env
# edit .env with your values
```

**3. Mount server data:**

The `./server-data` directory must be the same bind-mount used by the PZ server container (it maps to `/project-zomboid-config` in both containers). Either symlink it or adjust the volume path in `docker-compose.yml` to match your setup.

**4. Start:**
```bash
docker compose up -d
docker compose logs -f pz-bot
```

## Manual (without Docker)

Install dependencies:
```bash
pip install discord.py python-dotenv watchgod file_read_backwards docker
```

Copy and populate the environment file:
```bash
cp .env.sample .env
```

Run both bots:
```bash
python3 pzbot.py      # Command bot
python3 pzwatcher.py  # Log watcher bot
```

---

# Configuration

Copy `.env.sample` to `.env` and fill in all values. To get channel IDs, enable Developer Mode in Discord, then right-click a channel and select "Copy ID".

| Variable | Description |
|---|---|
| `RCON_PASS` | RCON password (must match server config) |
| `RCON_SERVER` | RCON hostname — use `projectzomboid` (container name) when running in Docker |
| `RCON_PORT` | RCON port (default: `27015`) |
| `DISCORD_TOKEN` | Discord bot token |
| `DISCORD_GUILD` | Discord server name |
| `ADMIN_ROLES` | Comma-separated role names for admin commands |
| `MODERATOR_ROLES` | Comma-separated role names for moderator commands |
| `WHITELIST_ROLES` | Roles allowed to self-register via `!pzrequestaccess` |
| `LOG_PATH` | Path to PZ server `Logs/` directory — use `/project-zomboid-config/Logs` in Docker |
| `NOTIFICATION_CHANNEL` | Channel ID for join/leave/death notifications |
| `INGAME_CHANNEL` | Channel ID attached to the in-game chat |
| `IGNORE_CHANNELS` | Comma-separated channel names where commands are blocked |
| `SERVER_ADDRESS` | Shown to players after whitelist access is granted |
| `PZ_CONTAINER_NAME` | Docker container name of the PZ server (default: `projectzomboid`) |

---

# Usage

```
AdminCommands:
  pzrestartserver Restart the PZ server
  pzsetaccess     Set the access level of a specific user

ModeratorCommands:
  pzadditem       Adds an item to the specified user's inventory
  pzgetsteamid    Lookup steamid of user
  pzkick          Kick a user
  pzsave          Save the current world
  pzservermsg     Broadcast a server message
  pzsteamban      Steam ban a user
  pzsteamunban    Steam unban a user
  pzteleport      Teleport a user to another user
  pzunwhitelist   Remove a whitelisted user
  pzwhitelist     Whitelist a user
  pzwhitelistall  Whitelist all active users

UserCommands:
  pzdeathcount    Get the total death count of a player
  pzdeaths        Get the total death count of all players
  pzgetoption     Get the value of a server option
  pzlistmods      List currently installed mods
  pzplayers       Show current active players on the server
  pzplaytime      Get the total playtime of all players
  pzrequestaccess Request access to the PZ server (DMs credentials)
  whatareyou      What is the bot
```

---

# Examples

## Ban a user
```
!pzsteamban SteamIDOfUser
```

## Make a user an admin
```
!pzsetaccess SomeUser admin
```

## Get a server option
Fuzzy lookup for a specific server option:
```
!pzgetoption zombie
```
```
Server options:
ZombieUpdateDelta=0.5
ZombieUpdateMaxHighPriority=50
ZombieUpdateRadiusHighPriority=10.0
ZombieUpdateRadiusLowPriority=45.0
```
