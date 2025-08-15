#!/bin/bash
# ===================================================================
#  ISS AI Hub - Final Configuration Script (v7 - Version Aware)
#  - This script is now designed to run with root privileges.
# ===================================================================
set -e

# --- Проверка: если скрипт запущен не от root, выходим ---
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Aborting." >&2
  exit 1
fi

CONFIG_FILE="/opt/zigbee2mqtt/data/configuration.yaml"
TEMPLATE_FILE="/opt/zigbee2mqtt/data/configuration.template.yaml"
APP_USER="berkut"
HUB_ID_FILE="/etc/iss_ai_hub/hub_id.txt"
VERSION_FILE="/etc/iss_ai_hub/version.txt"

# --- Проверка: если основной конфиг уже существует, ничего не делаем ---
if [ -f "$CONFIG_FILE" ]; then
    echo "System appears to be already finalized. Exiting."
    # Просто убедимся, что сервисы запущены
    systemctl start mosquitto.service nodered.service zigbee2mqtt.service
    exit 0
fi

echo "--- Running Finalize Setup for the First Time (or after reset) ---"

# --- 1. Ожидание интернета ---
echo "Waiting for internet connection..."
while ! ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; do sleep 3; done
echo "Internet connection is active."

# --- 2. Генерация и сохранение УНИКАЛЬНЫХ данных ---
echo "Generating unique Hub ID and Zigbee parameters..."
HUB_ID="isshub_raspi_$(cat /sys/class/net/wlan0/address | tr -d ':' | tail -c 8)"
PAN_ID=$(shuf -i 1000-65000 -n 1)
NETWORK_KEY=$(openssl rand -hex 16 | sed 's/\(..\)/0x\1, /g; s/, $//')
EXT_PAN_ID=$(openssl rand -hex 8 | sed 's/\(..\)/0x\1, /g; s/, $//')

# Создаем директорию, если ее нет
mkdir -p /etc/iss_ai_hub/
# Сохраняем НОВЫЙ Hub ID
echo "$HUB_ID" > "$HUB_ID_FILE"
chmod 644 "$HUB_ID_FILE"
echo "Finalizing setup for Hub ID: $HUB_ID"

# --- 3. Проверка и создание файла ВЕРСИИ ---
# Создаем файл версии, ТОЛЬКО ЕСЛИ ЕГО НЕ СУЩЕСТВУЕТ
if [ ! -f "$VERSION_FILE" ]; then
    echo "Version file not found. Creating with base version."
    BASE_FW_VERSION="1.0.0" # Базовая версия, "зашитая" в этот скрипт
    echo "$BASE_FW_VERSION" > "$VERSION_FILE"
    chmod 644 "$VERSION_FILE"
fi

# --- 4. Генерация конфигурационного файла Zigbee2MQTT ---
echo "Creating Zigbee2MQTT configuration..."
