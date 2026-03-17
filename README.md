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

The bot connects to the PZ server via RCON over the shared Docker network (`zomboid_zomboid`). Server restarts are performed via the Docker SDK (through a restricted socket proxy) rather than systemd or shell commands.

```
Host
├── /var/run/docker.sock
│
└── Docker
    ├── zomboid_zomboid (external, shared)
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

# Discord Bot Setup

Before running the bot you need to create a Discord application and invite it to your server.

**1. Create the application:**
- Go to [discord.com/developers/applications](https://discord.com/developers/applications) and click **New Application**
- Give it a name, then go to the **Bot** tab
- Click **Reset Token** and copy the token — this is your `DISCORD_TOKEN`
- Under **Privileged Gateway Intents**, enable **Server Members Intent** (required for role checks)

**2. Invite the bot to your server:**
- Go to the **OAuth2 → URL Generator** tab
- Under **Scopes**, select `bot`
- Under **Bot Permissions**, select:
  - `Read Messages / View Channels`
  - `Send Messages`
  - `Send Messages in Threads`
  - `Read Message History`
- Copy the generated URL, open it in a browser, and select your Discord server

**3. Get channel IDs:**
- In Discord settings, go to **Advanced** and enable **Developer Mode**
- Right-click any channel and select **Copy Channel ID**

---

# Requirements and Setup

## Docker (recommended)

**Prerequisites:** Docker + Docker Compose, a running PZ server container on a shared network.

**1. Create the shared Docker network** (skip if it already exists):
```bash
docker network create zomboid_zomboid
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

Copy `.env.sample` to `.env` and fill in all values.

## Discord

| Variable | Description |
|---|---|
| `DISCORD_TOKEN` | Bot token from the Discord Developer Portal |
| `DISCORD_GUILD` | Name of your Discord server |

## RCON

| Variable | Description |
|---|---|
| `RCON_PASS` | RCON password — must match `RCON_PASSWORD` set on the PZ server |
| `RCON_SERVER` | RCON hostname — use `projectzomboid` (container name) in Docker, or `127.0.0.1` for manual |
| `RCON_PORT` | RCON port (default: `27015`) |

## Roles

The bot uses your Discord server's **role names** (not IDs) to gate commands. Roles are matched by name, case-sensitively.

| Variable | Who it applies to | What it grants |
|---|---|---|
| `ADMIN_ROLES` | Comma-separated list of role names, e.g. `Admin` or `Admin,ServerOwner` | Full access: server restart, changing player access levels |
| `MODERATOR_ROLES` | Comma-separated list of role names, e.g. `Moderator,Helper` | Moderation commands: bans, kicks, whitelist management, teleport, give items |
| `WHITELIST_ROLES` | Comma-separated list of role names, e.g. `Survivor` | Can run `!pzrequestaccess` to self-register an account on the PZ server |

Users with an `ADMIN_ROLES` role do **not** automatically get moderator commands — add them to both lists if needed:
```
ADMIN_ROLES="Admin"
MODERATOR_ROLES="Admin,Moderator"
```

All other Discord members (no matching role) can only run the read-only `UserCommands` (`!pzplayers`, `!pzplaytime`, etc.).

## Channels

| Variable | Description |
|---|---|
| `NOTIFICATION_CHANNEL` | Channel ID where join, leave, and death events are posted by `pzwatcher.py` |
| `INGAME_CHANNEL` | (Optional) Channel ID attached to in-game chat. Leave unset if using PZ's built-in Discord integration |
| `ALLOWED_CHANNELS` | (Optional) Comma-separated channel **names** where the bot listens for commands. When set, all other channels are ignored. Recommended over `IGNORE_CHANNELS` |
| `IGNORE_CHANNELS` | (Optional) Comma-separated channel **names** to block commands in. Only used when `ALLOWED_CHANNELS` is not set |

## Other

| Variable | Description |
|---|---|
| `LOG_PATH` | Path to the PZ server `Logs/` directory — use `/project-zomboid-config/Logs` in Docker |
| `SERVER_ADDRESS` | Connection address shown to players after `!pzrequestaccess` (e.g. `1.2.3.4:16261`) |
| `PZ_CONTAINER_NAME` | Docker container name of the PZ server (default: `projectzomboid`) |
| `SERVER_NAME` | Server config file name without extension (default: `pzserver`). Used to locate `<SERVER_NAME>.ini` in the `Server/` directory. Set to match your server's `SERVER_NAME` env var (e.g. `pzserver` → `Server/pzserver.ini`) |

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
Fuzzy lookup for a specific server option, or omit the argument to return all options:
```
!pzgetoption zombie
```
```
!pzgetoption
```
```
Server options:
ZombieUpdateDelta=0.5
ZombieUpdateMaxHighPriority=50
ZombieUpdateRadiusHighPriority=10.0
ZombieUpdateRadiusLowPriority=45.0
```
