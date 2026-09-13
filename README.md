# AmneziaWG client for Docker

Run an AmneziaWG peer in a Docker container using the **userspace** `amneziawg-go` implementation. No AmneziaWG or WireGuard kernel module required on the host.

Allows routing of specific Docker networks or the entire `host` network.

### Synology prerequisites

Synology DSM does not load the `tun` kernel module automatically. Without it the container exits with:

```
ERROR: /dev/net/tun does not exist and could not be loaded automatically.
```

Use `docs/synology-compose.yml` as your starting point. It runs with `network_mode: host` (simplest routing — no sysctl tweaks needed) and offers two approaches for the tun module:

**Option A — automatic (recommended):** Add `CAP_SYS_MODULE` and mount `/lib/modules:/lib/modules:ro`. The container loads `tun.ko` itself on every start, so it survives DSM reboots without any manual step. This is the default in `docs/synology-compose.yml`.

**Option B — manual:** Remove `SYS_MODULE` and the `/lib/modules` volume. SSH into the NAS and run:

```bash
sudo insmod /lib/modules/tun.ko   # "File exists" is fine — already loaded
```

Then add a **Scheduled Task → Triggered task → Boot-up** in DSM Control Panel running that line as root so it persists across reboots.

> **Note:** After changing `devices:` or `volumes:` you must **recreate** the container (`docker compose up -d` with `--force-recreate`, or stop → delete → up). A plain restart does not re-evaluate those fields. Synology's Container Manager GUI wizard cannot add device mappings — use a **Project** (compose file) instead.

### Setup

1. Install Docker if you haven't yet:
   ```bash
   curl -sSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```
2. Get an AmneziaWG config

   Generate a `.conf` file and place it in a new directory somewhere on the host.

   If you need multiple interfaces, put multiple config files in that directory. The name of the interface will match the basename of the `.conf` file.

3. Run the container

   To run it on a separate Docker network:

   ```bash
   docker run -d \
    --name=amneziawg-client \
    -v /path/to/dir/with/config:/config \
    --device=/dev/net/tun:/dev/net/tun \
    --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
    --sysctl="net.ipv4.ip_forward=1" \
    --cap-add=NET_ADMIN \
    --restart always \
    ghcr.io/j0rsa/amneziawg-client
   ```

   If you'd like to have access to the VPN network from the host, make it run on the host network:

   ```bash
   docker run -d \
    --name=amneziawg-client \
    -v /path/to/dir/with/config:/config \
    --network=host \
    --device=/dev/net/tun:/dev/net/tun \
    --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
    --cap-add=NET_ADMIN \
    --restart always \
    ghcr.io/j0rsa/amneziawg-client
   ```

   > **Note:** `--cap-add=SYS_MODULE` is not needed. The container runs entirely in userspace via `amneziawg-go` and does not load any kernel modules.

### How it works

The container builds `amneziawg-go` (a userspace AmneziaWG/WireGuard implementation) and `amneziawg-tools` (`awg` / `awg-quick`) from source. At startup, `WG_QUICK_USERSPACE_IMPLEMENTATION=amneziawg-go` is set so that `awg-quick` delegates tunnel creation to the Go userspace binary instead of the kernel module.

### Releases and image tags

| Tag | When produced | Example |
|-----|---------------|---------|
| `latest` | Every semver tag push | `ghcr.io/j0rsa/amneziawg-client:latest` |
| `1.2.3` | Exact version tag | `ghcr.io/j0rsa/amneziawg-client:1.2.3` |
| `1.2` | Minor version alias | `ghcr.io/j0rsa/amneziawg-client:1.2` |
| `1` | Major version alias | `ghcr.io/j0rsa/amneziawg-client:1` |
| `main-<sha>` | Push to `main` (no `latest` bump) | `ghcr.io/j0rsa/amneziawg-client:main-a1b2c3d` |

To publish a new release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

CI will build multi-arch images for `linux/amd64` and `linux/arm64` and push all four tags automatically.

### Supported platforms

The only tested architectures (and the only ones built by CI) are `linux/amd64` and `linux/arm64`. If you require any others, please do not hesitate to open an issue/PR!
