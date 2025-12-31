# MEGAcmd Docker with 2FA Support (Multi-Arch)

A Docker container for MEGAcmd (Mega.nz) designed for **ARM64** (Apple Silicon, Raspberry Pi) and **AMD64** (Intel/AMD) devices.

It handles:
* **2FA Authentication**: Persists session via volumes so you only login once.
* **Auto-Sync**: Automatically configures sync pairs using environment variables.
* **Auto-Healing**: Checks sync status on container restarts.
* **Monitoring & Alerts**: Logs transactions and sends Gotify alerts on errors.

## Quick Start

### 1. Create docker-compose.yml

```yaml
services:
  mega:
    image: zyetta/mega-sync:latest
    container_name: mega-sync
    restart: unless-stopped
    environment:
      # Pair 1
      - SYNC_LOCAL_1=/data/documents
      - SYNC_REMOTE_1=/CloudDrive/Documents
      # Pair 2
      - SYNC_LOCAL_2=/data/photos
      - SYNC_REMOTE_2=/CloudDrive/Photos
      
      # Monitoring (Optional)
      - GOTIFY_URL=https://gotify.example.com
      - GOTIFY_TOKEN=your_app_token
    volumes:
      # CONFIG: Stores your login session (CRITICAL)
      - ./mega-session:/root/.megaCmd
      # DATA: Your local folders to sync
      - ./my-documents:/data/documents
      - ./my-photos:/data/photos
```

### 2. First Run (Login)

Because MEGA requires 2FA, you cannot login via environment variables. You must do it interactively one time.

Start the container:
```bash
docker compose up -d
```

Enter the container:
```bash
docker exec -it mega-sync bash
```

Login manually:
```bash
mega-login your@email.com "your_password" --auth-code=123456
```

Wait for the login to succeed and fetch your file list.

Exit the container:
```bash
exit
```

### 3. Activate Sync

Now that you are logged in, restart the container. The startup script will detect your session and automatically configure the sync folders defined in your environment variables.

```bash
docker compose restart mega-sync
```

## Configuration

### Environment Variables

You can add as many sync pairs as needed by incrementing the number (up to 10 by default).

| Variable | Description |
| --- | --- |
| SYNC_LOCAL_X | The path inside the container (mapped to your host) |
| SYNC_REMOTE_X | The path on your MEGA Cloud Drive |
| GOTIFY_URL | (Optional) URL of your Gotify server |
| GOTIFY_TOKEN | (Optional) Gotify Application Token |

### Volumes

| Volume | Description |
| --- | --- |
| /root/.megaCmd | Required. Stores session ID and cache. Map this to a host folder to survive restarts. |

## Building Locally

If you want to build this image yourself instead of pulling from Docker Hub:

```bash
docker compose build
```

## Development

### Versioning

The project uses a `VERSION` file to define the Major.Minor version (e.g., `1.0`).
GitHub Actions automatically appends the build number to create the full tag (e.g., `1.0.42`).

To bump the major/minor version, edit the `VERSION` file.

### Safety Hooks

To prevent accidental pushes to the `main` branch, install the git hooks:

```bash
chmod +x scripts/install_hooks.sh
./scripts/install_hooks.sh
```

This installs a `pre-push` hook that blocks direct pushes to `main`. To bypass it (emergency only):

```bash
git push --no-verify
```
