# AdGuard Home (Native Proxmox LXC Deployment) 🛡️

Template and deployment guide for running **AdGuard Home natively** inside an unprivileged Debian or Alpine LXC container on Proxmox VE.

---

## 💡 Why Native LXC instead of Docker?

While applications with complex dependencies (like Paperless-ngx or Vaultwarden) benefit from Docker Compose, network-critical infrastructure like DNS sinkholes are significantly better suited for **native LXC installation**:

1. **Direct Port 53 Binding:** Avoids Docker bridge NAT and `docker-proxy` overhead. Port 53 binds directly to the container's static LAN IP.
2. **Minimal Latency:** Zero containerization network hops; DNS resolution response time is typically `< 1 ms`.
3. **Ultra-Low Memory Footprint:** Consumes `< 40 MB` of RAM, making it suitable for a dedicated, lightweight container.
4. **Native Systemd Integration:** Clean lifecycle management via standard `systemctl` commands and automatic startup on Proxmox boot.

---

## 🚀 Installation Guide (Unprivileged LXC)

### 1. Create the LXC Container
In Proxmox VE, create an unprivileged LXC container:
* **Template:** Debian 12 (Bookworm) or Alpine Linux
* **Cores:** 1
* **Memory:** 512 MB (plenty for high-throughput DNS)
* **Disk:** 4 GB - 8 GB (SSD-backed storage)
* **Network:** Static IP on your management/LAN subnet (e.g., `192.168.188.208/24`), Gateway to your router.

### 2. Disable `systemd-resolved` Port 53 Stub (Debian/Ubuntu)
By default, Debian/Ubuntu systemd-resolved binds port 53 on `127.0.0.53`:
```bash
# In the LXC container:
sudo mkdir -p /etc/systemd/resolved.conf.d/
cat << 'EOF' | sudo tee /etc/systemd/resolved.conf.d/adguard.conf
[Resolve]
DNS=1.1.1.1 1.0.0.1
DNSStubListener=no
EOF

sudo systemctl restart systemd-resolved
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
```

### 3. Install AdGuard Home Standalone Binary
Run the official native installer:
```bash
curl -s -S -L 'https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh' | sh -s -- -v
```
This automatically:
* Installs the binary into `/opt/AdGuardHome`
* Registers and starts the systemd service `/etc/systemd/system/AdGuardHome.service`

### 4. Configuration
1. Open your browser and navigate to `http://<CONTAINER-IP>:3000` to complete the initial setup wizard.
2. Bind the **Admin Web Interface** to port `80` (or `8080`) and **DNS Server** to all interfaces (`0.0.0.0:53`).
3. Set your upstream DNS servers to encrypted providers (DNS-over-HTTPS or DNS-over-TLS), for example:
   * `https://dns.quad9.net/dns-query`
   * `https://cloudflare-dns.com/dns-query`
