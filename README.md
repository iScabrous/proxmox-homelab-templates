# Proxmox VE & Docker Homelab Stack Templates 🚀

A collection of clean, production-hardened Docker Compose service templates and automation patterns for self-hosted homelabs running on Proxmox VE (LXC or VM).

Designed with security, reproducible configurations, zero open router ports (via Cloudflare Tunnels), and automated offsite backups in mind.

---

## 🏗️ Architecture Overview

```
                                [ Public Internet ]
                                         │
                                (Cloudflare Edge)
                                         │  (Encrypted Tunnel)
                                         ▼
                            ┌────────────────────────┐
                            │ Cloudflare Tunnel /    │
                            │ Reverse Proxy (NPM)    │
                            └───────────┬────────────┘
                                        │
                 ┌──────────────────────┼──────────────────────┐
                 ▼                      ▼                      ▼
      ┌────────────────────┐ ┌────────────────────┐ ┌────────────────────┐
      │  LXC: Productivity │ │  LXC: Sec & Mon    │ │ LXC: Native Core   │
      │  • Paperless-ngx   │ │  • Vaultwarden     │ │  • AdGuard Home    │
      │  • PostgreSQL      │ │  • Uptime Kuma     │ │  • Native Systemd  │
      │  • Redis / Tika    │ │  (Docker Compose)  │ │  • Direct Port 53  │
      └──────────┬─────────┘ └──────────┬─────────┘ └──────────┬─────────┘
                 │                      │                      │
                 └──────────────────────┼──────────────────────┘
                                        │
                                (Nightly Rclone)
                                        ▼
                           ┌────────────────────────┐
                           │ Encrypted Cloud Backup │
                           └────────────────────────┘
```

---

## 📦 Included Services

### 🐳 Docker Compose Stacks (Multi-Container Services)
| Directory | Service Stack | Primary Role | Recommended Base |
| :--- | :--- | :--- | :--- |
| `stacks/vaultwarden/` | Vaultwarden (SQLite) | Password management (Bitwarden-compatible) | Debian / Alpine LXC |
| `stacks/paperless-ngx/` | Paperless-ngx + Tika + Gotenberg | Document management & OCR ingestion | Ubuntu LXC |
| `stacks/uptime-kuma/` | Uptime Kuma | Service uptime & latency monitoring | Debian LXC |

### 🛡️ Native Proxmox LXC Services (Bare-Metal Efficiency)
| Directory | Service Stack | Primary Role | Recommended Base |
| :--- | :--- | :--- | :--- |
| `native-lxc/adguard-home/` | AdGuard Home (Native Binary) | Low-latency DNS sinkhole & ad-blocking | Debian / Alpine LXC |
| `automation/backup/` | Rclone + Bash backup scripts | Encrypted offsite volume & database backups | Host cron / Systemd |

> **Architectural Decision (Docker vs. Native LXC):**
> * Applications with multi-service dependencies, database engines, or complex runtimes (Paperless-ngx, Vaultwarden, Uptime Kuma) run inside **Docker Compose** containers for strict process isolation and reproducible upgrades.
> * Core network infrastructure (AdGuard Home) runs as a **Native Systemd Service** directly inside an unprivileged LXC to eliminate Docker bridge NAT latency, avoid `docker-proxy` overhead, and cleanly bind port 53.

---

## 🔒 Security Principles

1. **Zero Open Ports:** All public ingress routes traverse authenticated Cloudflare Tunnels (`cloudflared`) or internal reverse proxies. Web application ports bind to `127.0.0.1` by default to prevent direct internet or LAN exposure.
2. **Environment Variable Separation & Fail-Closed:** Sensitive credentials, tokens, and domain names reside in `.env` files (never committed to git). Compose templates enforce variable presence to prevent services starting with insecure defaults.
3. **Least Privilege:** Services run as non-root users (`PUID`/`PGID` and `USERMAP_UID`/`USERMAP_GID`) wherever supported by the upstream container image.
4. **Isolated Networks:** Compose stacks reside on distinct Docker bridge networks to prevent unauthorized inter-container communication.

---

## 🔧 Host Setup & Troubleshooting

### AdGuard Home: Port 53 Conflict with `systemd-resolved`
On modern Ubuntu/Debian hosts, `systemd-resolved` binds to `127.0.0.53:53` by default, which blocks AdGuard Home from binding port 53. To resolve this:

1. Edit `/etc/systemd/resolved.conf`:
   ```ini
   [Resolve]
   DNS=1.1.1.1 1.0.0.1
   DNSStubListener=no
   ```
2. Symlink the stub resolver file to static resolv.conf:
   ```bash
   sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
   sudo systemctl restart systemd-resolved
   ```

---

## 🚀 Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/iScabrous/proxmox-homelab-templates.git
cd proxmox-homelab-templates
```

### 2. Choose a Service Stack
Navigate into the respective stack directory, for example Vaultwarden:
```bash
cd stacks/vaultwarden
cp .env.example .env
nano .env
```

### 3. Launch the Stack
```bash
docker compose up -d
```

---

## 📜 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
