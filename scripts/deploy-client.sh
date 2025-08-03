#!/bin/bash
set -e

PROFILE=${1:-standard}
SITE_NAME=${2:-client}

echo "🚀 Deploying Tailscale client: $SITE_NAME (profile: $PROFILE)"

# Validate inputs
if [[ ! -f "profiles/${PROFILE}.env" ]]; then
    echo "❌ Profile 'profiles/${PROFILE}.env' not found!"
    echo "Available profiles:"
    ls profiles/*.env 2>/dev/null | sed 's/profiles\///g' | sed 's/\.env//g'
    exit 1
fi

# Create site-specific directory
DEPLOY_DIR="deployments/${SITE_NAME}"
mkdir -p "$DEPLOY_DIR"

# Copy appropriate docker-compose.yml
if [[ "$PROFILE" == "exit-node" ]]; then
    cp clients/exit-node/docker-compose.yml "$DEPLOY_DIR/"
else
    cp clients/standard/docker-compose.yml "$DEPLOY_DIR/"
fi

# Copy and customize environment
cp "profiles/${PROFILE}.env" "$DEPLOY_DIR/.env"
sed -i "s/CLIENT_NAME=.*/CLIENT_NAME=${SITE_NAME}/" "$DEPLOY_DIR/.env"

echo "✅ Deployment prepared in: $DEPLOY_DIR"
echo ""
echo "📋 Next steps:"
echo "1. Edit $DEPLOY_DIR/.env with your auth key"
echo "2. cd $DEPLOY_DIR && docker-compose up -d"
echo "3. Check status: docker-compose logs -f"