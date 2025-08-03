# Tailscale Clients

Docker-based Tailscale clients for multiple sites with exit-node support.

## Quick Start

1. **Deploy standard client:**
   ```bash
   ./scripts/deploy-client.sh standard home-lab-01
   cd deployments/home-lab-01
   # Edit .env with auth key
   docker-compose up -d
   ```

2. **Deploy exit-node:**
   ```bash
   ./scripts/setup-exit-node.sh home-lab-exit
   cd deployments/home-lab-exit
   # Edit .env with auth key
   docker-compose up -d
   ```

## Client Types

### Standard Client
- Basic VPN connectivity
- DNS resolution through headscale
- Accepts routes from other nodes

### Exit-Node
- Routes internet traffic for other clients
- Requires IP forwarding on host
- Must be approved in headscale admin

## Deployment Profiles

- `standard`: Basic client configuration
- `exit-node`: Internet exit-node setup
- `home-lab`: Custom home lab settings

## Host Requirements

### All Clients
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Reboot or re-login
```

### Exit-Node Additional Setup
```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Configure firewall
sudo ufw allow in on tailscale0
sudo ufw allow out on tailscale0
```

## Getting Auth Keys

1. **Via headscale CLI:**
   ```bash
   docker-compose exec headscale headscale preauthkeys create --user <username> --expiration 1h
   ```

2. **Via Admin UI:**
   - Go to `https://admin.vps.schefenacker.net`
   - Navigate to PreAuth Keys
   - Create new key for user

## Network Architecture

```
Internet
    ↓
[home-lab-exit] ← Exit Node (routes traffic)
    ↓
[headscale] ← Coordination Server
    ↓
[home-lab-01, home-lab-02, remote-site-01] ← Standard Clients
```

## Troubleshooting

- **Connection Issues**: Check auth key validity
- **DNS Problems**: Verify `TS_ACCEPT_DNS=true`
- **Exit-Node**: Ensure routes are approved in headscale
- **Logs**: `docker-compose logs -f tailscale`