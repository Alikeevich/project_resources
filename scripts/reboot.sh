#!/bin/bash
#
# ISS AI Hub - System Reboot Script
#
set -e

LOG_FILE="/var/log/hub_updates.log"
echo "--- [$(date)] Reboot command received. Rebooting system in 5 seconds... ---" | tee -a $LOG_FILE

sleep 5
/sbin/reboot
