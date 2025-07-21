#!/bin/bash
#
# ISS AI Hub - Core OTA Update Script
# Fetches updates from a public GitHub repository.
#
set -e # Exit immediately if a command exits with a non-zero status.

LOG_FILE="/var/log/hub_updates.log"
# Redirect all output to a log file and also to the console (if run manually)
exec &> >(tee -a "${LOG_FILE}")

echo "--- [$(date)] Starting Hub Core Components update ---"

# --- CONFIGURATION ---
# !!! REPLACE WITH YOUR GITHUB RAW URL !!!
BASE_URL="https://raw.githubusercontent.com/Alikeevich/project_resources/main"

# Path to the Node-RED user directory (replace 'admin' if your user is different)
NODERED_USER_DIR="/home/berkut/.node-red"
FLOWS_FILE="${NODERED_USER_DIR}/flows.json"
FLOWS_BACKUP_FILE="${NODERED_USER_DIR}/flows.json.bak"

# --- STEP 1: Safe Node-RED Flows Update ---
echo "Stopping Node-RED to safely update flows..."
sudo systemctl stop nodered.service

echo "Backing up current flows to ${FLOWS_BACKUP_FILE}..."
cp "$FLOWS_FILE" "$FLOWS_BACKUP_FILE"

echo "Downloading latest flows.json from GitHub..."
# The --fail flag will cause curl to exit with an error if the download fails (e.g., 404)
if curl --fail -sL "${BASE_URL}/flows.json" -o "$FLOWS_FILE"; then
    echo "New flows.json downloaded. Validating..."

    # Validate the new flows file by attempting a short run of Node-RED
    node-red --settings ${NODERED_USER_DIR}/settings.js "$FLOWS_FILE" &
    CHECK_PID=$!
    sleep 5 # Give it 5 seconds to start up or crash

    if ps -p $CHECK_PID > /dev/null; then
        # Process is still running, flows are likely valid
        kill $CHECK_PID
        wait $CHECK_PID 2>/dev/null
        echo "SUCCESS: New flows.json appears valid."
        rm "$FLOWS_BACKUP_FILE"
    else
        # Process crashed, flows are invalid
        echo "ERROR: New flows.json is invalid! Restoring from backup."
        mv "$FLOWS_BACKUP_FILE" "$FLOWS_FILE"
        # Exit with an error code to notify the backend
        exit 1
    fi
else
    echo "ERROR: Failed to download new flows.json. Restoring backup."
    mv "$FLOWS_BACKUP_FILE" "$FLOWS_FILE"
    exit 1
fi

# --- STEP 2: Update System Scripts ---
echo "Downloading latest system scripts..."
sudo curl --fail -sL "${BASE_URL}/scripts/provision_api.py" -o "/usr/local/bin/provision_api.py"
sudo curl --fail -sL "${BASE_URL}/scripts/network_manager.sh" -o "/usr/local/bin/network_manager.sh"
sudo curl --fail -sL "${BASE_URL}/scripts/finalize_setup.sh" -o "/usr/local/bin/finalize_setup.sh"
sudo curl --fail -sL "${BASE_URL}/scripts/update_core.sh" -o "/usr/local/bin/update_core.sh" # Self-update!
# Add other scripts here as needed

# --- STEP 3: Update Z2M Template and Version File ---
echo "Downloading templates and version file..."
sudo curl --fail -sL "${BASE_URL}/templates/configuration.template.yaml" -o "/opt/zigbee2mqtt/data/configuration.template.yaml"
sudo curl --fail -sL "${BASE_URL}/version.txt" -o "/etc/iss_ai_hub/version.txt"

# --- STEP 4: Finalize and Restart ---
echo "Setting correct permissions for all scripts..."
sudo chmod +x /usr/local/bin/*.sh /usr/local/bin/*.py

echo "Starting Node-RED service with updated flows..."
sudo systemctl start nodered.service

echo "--- [$(date)] Hub Core Components update finished successfully! ---"
