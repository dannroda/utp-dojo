#!/bin/bash
echo "🚀 Deploying to Katana..."

# Deploy the world and migrate systems
sozo migrate

# Register the main action system
sozo register system GameActions

echo "✅ Deployment complete."
