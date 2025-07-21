#!/bin/bash
#
# ISS AI Hub - Zigbee2MQTT Updater
#
set -e

LOG_FILE="/var/log/hub_updates.log"
exec &> >(tee -a "${LOG_FILE}")

echo "--- [$(date)] Starting Zigbee2MQTT update ---"

# Stop the service to prevent file conflicts
echo "Stopping Zigbee2MQTT service..."
systemctl stop zigbee2mqtt.service

# Navigate to the Z2M directory
cd /opt/zigbee2mqtt

# Discard any local changes and fetch the latest version
echo "Fetching latest version from GitHub..."
git reset --hard
git pull origin master

# Install/update dependencies using pnpm
echo "Installing dependencies..."
pnpm install --production

# Build the project (if needed, good practice to run it)
echo "Building project..."
pnpm run build

# Start the service again
echo "Starting Zigbee2MQTT service..."
systemctl start zigbee2mqtt.service

echo "--- [$(date)] Zigbee2MQTT update finished successfully! ---"
