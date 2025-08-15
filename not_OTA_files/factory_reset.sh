#!/bin/bash
# ========================================================================
#  ISS AI Hub - Smart Factory Reset Script (v6 - Cloud De-registration)
#  - Notifies cloud server before erasing local data.
#  - Cleans user data but preserves firmware version and core logic.
#  - Re-arms the provisioning system for a new setup.
# ========================================================================
set -e


API_SERVER_URL="https://app.iss-control.kz:443"
HUB_ID_FILE="/etc/iss_ai_hub/hub_id.txt"
# --------------------

echo "--- Starting Smart Factory Reset ---"
echo "This will erase all user data and network settings."

# --- 1. Уведомление облачного сервера об удалении ---
echo "[1/7] Notifying cloud server of deletion..."
if [ -f "$HUB_ID_FILE" ]; then
    HUB_ID=$(cat "$HUB_ID_FILE")
    if [ -n "$HUB_ID" ]; then
        echo "  - Hub ID found: $HUB_ID"
        DELETE_URL="$API_SERVER_URL/api/v1/hub/$HUB_ID/delete-by-user"
        echo "  - Sending DELETE request to: $DELETE_URL"

        # Пытаемся отправить запрос с таймаутом 10 секунд.
        # `|| true` в конце гарантирует, что скрипт не остановится, если curl завершится с ошибкой (например, нет сети).
        curl --silent --show-error -X DELETE --connect-timeout 10 "$DELETE_URL" || true

        echo "  - Server notification sent (or skipped on error). Continuing reset..."
    else
        echo "  - Hub ID file is empty. Skipping notification."
    fi
else
    echo "  - Hub ID file not found. Skipping notification."
fi

# --- 2. Остановка и ОТКЛЮЧЕНИЕ runtime-сервисов ---
echo "[2/7] Stopping and disabling runtime services..."
sudo systemctl stop nodered.service zigbee2mqtt.service || true
sudo systemctl disable nodered.service zigbee2mqtt.service || true
sudo systemctl stop mosquitto.service || true

# --- 3. Очистка сетевых конфигураций ---
echo "[3/7] Purging network configurations..."
sudo rm -f /etc/wpa_supplicant/wpa_supplicant.conf
sudo rm -f /boot/firmware/setup_complete.flag

# --- 4. Очистка УНИКАЛЬНЫХ данных хаба и пользователя ---
echo "[4/7] Purging unique Hub ID and user context..."
sudo rm -f "$HUB_ID_FILE" # Удаляем ID ПОСЛЕ того, как отправили его на сервер
USER_HOME="/home/berkut"
CONTEXT_DIR="$USER_HOME/.node-red/context"
if [ -d "$CONTEXT_DIR" ]; then
    sudo find "$CONTEXT_DIR" -type f -delete
fi

# --- 5. Очистка данных Zigbee2MQTT ---
echo "[5/7] Cleaning Zigbee2MQTT runtime data..."
Z2M_DATA_DIR="/opt/zigbee2mqtt/data"
sudo rm -f "$Z2M_DATA_DIR/configuration.yaml"
sudo rm -f "$Z2M_DATA_DIR/database.db"
sudo rm -f "$Z2M_DATA_DIR/state.json"
sudo rm -f "$Z2M_DATA_DIR/coordinator_backup.json"

# --- 6. "Перевзвод" системы автозапуска в режим AP ---
echo "[6/7] Re-arming AP mode manager for next boot..."
sudo systemctl enable network-manager-script.service

# --- 7. Очистка логов и истории ---
echo "[7/7] Cleaning system logs and command history..."
sudo journalctl --rotate
sudo journalctl --vacuum-time=1s
history -c && history -w
sudo sed -i 's/console=serial0,115200 //' /boot/firmware/cmdline.txt

echo -e "\n--- Smart Factory Reset Complete. ---"
echo "Firmware version has been preserved."
echo "The system will start in AP (Access Point) mode on next boot."
echo "Rebooting now..."
sleep 3
sudo reboot

