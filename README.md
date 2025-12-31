# MEGAcmd Docker with 2FA Support (Multi-Arch)

A Docker container for MEGAcmd (Mega.nz) designed for **ARM64** (Apple Silicon, Raspberry Pi) and **AMD64** (Intel/AMD) devices.

It handles:
* **2FA Authentication**: Persists session via volumes so you only login once.
* **Web UI**: Simple interface for logging in and viewing status.
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
    ports:
      - "8888:8888" # Web UI Port
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

1. Start the container:
   ```bash
   docker compose up -d
   ```

2. Open the Web UI:
   Go to **http://localhost:8888** in your browser.

3. Login:
   Enter your Email, Password, and 2FA Code (if enabled).

4. **Done!**
   The container's "Watchdog" will detect the login and automatically configure your sync folders within 30 seconds.

### 3. Monitoring

You can check the status of your syncs at any time by visiting **http://localhost:8888**.

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
