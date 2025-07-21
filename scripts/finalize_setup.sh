#!/bin/bash
# ===================================================================
#  ISS AI Hub - Final Configuration Script (v6.2 - No SUDO Inside)
# ===================================================================
set -e

CONFIG_FILE="/opt/zigbee2mqtt/data/configuration.yaml"
TEMPLATE_FILE="/opt/zigbee2mqtt/data/configuration.template.yaml"
APP_USER="berkut"
HUB_ID_FILE="/etc/iss_ai_hub/hub_id.txt"

# --- Проверка: конфиг уже существует ---
if [ -f "$CONFIG_FILE" ]; then
    echo "System is already finalized. Starting services..."
    systemctl start mosquitto.service nodered.service zigbee2mqtt.service
    exit 0
fi

echo "--- Running Finalize Setup for the First Time ---"

# --- 1. Ожидание интернета ---
echo "Waiting for internet connection..."
while ! ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1; do sleep 3; done
echo "Internet connection is active."

# --- 2. Проверка и чтение HUB ID ---
if [ ! -f "$HUB_ID_FILE" ]; then
    echo "FATAL: HUB ID file not found at $HUB_ID_FILE"
    exit 1
fi

HUB_ID=$(cat "$HUB_ID_FILE")
echo "Finalizing setup for Hub ID: $HUB_ID"

# --- 3. Генерация Zigbee параметров ---
echo "Generating Zigbee network parameters..."
PAN_ID=$(shuf -i 1000-65000 -n 1)
NETWORK_KEY=$(openssl rand -hex 16 | sed 's/\(..\)/0x\1, /g; s/, $//')
EXT_PAN_ID=$(openssl rand -hex 8 | sed 's/\(..\)/0x\1, /g; s/, $//')

# --- 4. Проверка шаблона конфигурации ---
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "FATAL: Template file not found at $TEMPLATE_FILE"
    exit 1
fi

# --- 5. Генерация конфигурационного файла Zigbee2MQTT ---
echo "Creating Zigbee2MQTT configuration..."
TEMP_CONFIG="/tmp/configuration.yaml.tmp"

sed -e "s/__HUB_ID__/$HUB_ID/g" \
    -e "s/__PAN_ID__/$PAN_ID/g" \
    -e "s/__EXT_PAN_ID__/$EXT_PAN_ID/g" \
    -e "s/__NETWORK_KEY__/$NETWORK_KEY/g" \
    "$TEMPLATE_FILE" > "$TEMP_CONFIG"

mv "$TEMP_CONFIG" "$CONFIG_FILE"
chown -R "$APP_USER:$APP_USER" /opt/zigbee2mqtt/data

echo "Zigbee2MQTT configuration created."

# --- 6. Запуск и включение нужных сервисов ---
echo "Starting runtime services..."
systemctl daemon-reexec
systemctl enable --now mosquitto.service
systemctl enable --now nodered.service
systemctl enable --now zigbee2mqtt.service

# --- 7. Отключение менеджера AP-режима ---
echo "Disabling AP provisioning manager..."
systemctl disable network-manager-script.service

echo "--- Finalize Setup Completed Successfully ---"
