#!/bin/bash
#
# ISS AI Hub - Operating System Package Updater
#
set -e

LOG_FILE="/var/log/hub_updates.log"
exec &> >(tee -a "${LOG_FILE}")

echo "--- [$(date)] Starting System Package update ---"
export DEBIAN_FRONTEND=noninteractive

echo "Updating package lists..."
apt-get update -qq

echo "Installing available upgrades..."
# The flags -y, -qq, and Dpkg::Options prevent any interactive prompts
apt-get -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" dist-upgrade

echo "Cleaning up downloaded package files..."
apt-get clean

echo "--- [$(date)] System Package update finished! Reboot is recommended. ---"
