#!/bin/bash
set -e

SITE_NAME=${1:-home-lab-exit}

echo "🌐 Setting up exit-node: $SITE_NAME"

# Generate deployment
./scripts/deploy-client.sh exit-node "$SITE_NAME"

DEPLOY_DIR="deployments/${SITE_NAME}"

echo ""
echo "🔧 Exit-node specific configuration:"
echo "1. Ensure host has IP forwarding enabled:"
echo "   echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf"
echo "   echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf"
echo "   sysctl -p"
echo ""
echo "2. Configure firewall (UFW example):"
echo "   ufw allow in on tailscale0"
echo "   ufw allow out on tailscale0"
echo ""
echo "3. After deployment, approve exit-node in headscale:"
echo "   docker-compose exec headscale headscale routes list"
echo "   docker-compose exec headscale headscale routes enable <route-id>"