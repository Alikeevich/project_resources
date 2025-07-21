#!/bin/bash
# ===================================================================
#  ISS AI Hub - Network Mode Manager (v3.1 - NetworkManager Final)
# ===================================================================
set -e

FLAG_FILE="/boot/firmware/setup_complete.flag"

# --- РЕЖИM КЛИЕНТА (Обычная работа) ---
if [ -f "$FLAG_FILE" ]; then
    echo "Setup flag found. Ensuring NetworkManager is active."
    # Убеждаемся, что NetworkManager запущен для работы в режиме клиента
    sudo systemctl start NetworkManager
    # Запускаем скрипт финальной конфигурации Z2M, Node-RED и т.д.
    # Он сам себя отключит после первого успешного выполнения.
    /usr/local/bin/finalize_setup.sh
    exit 0
fi

# --- РЕЖИМ ТОЧКИ ДОСТУПА (Первый запуск) ---
echo "No setup flag. Forcing AP provisioning mode..."

# 1. Жестко останавливаем NetworkManager, чтобы он освободил wlan0
echo "  - Stopping NetworkManager service to free wlan0..."
sudo systemctl stop NetworkManager
sleep 1 # Даем системе мгновение, чтобы интерфейс полностью освободился

# 2. Настраиваем статический IP-адрес для нашей Точки Доступа
echo "  - Configuring static IP (192.168.4.1) for wlan0..."
sudo ip addr flush dev wlan0
sudo ip addr add 192.168.4.1/24 dev wlan0

# 3. Перезапускаем сервисы, необходимые для работы AP
echo "  - Starting AP services (dnsmasq, hostapd)..."
sudo systemctl restart dnsmasq
sudo systemctl restart hostapd

# 4. Проверяем, что hostapd (сервис AP) успешно запустился
sleep 2
if ! sudo systemctl is-active --quiet hostapd.service; then
    echo "  - !!! FATAL ERROR: hostapd service failed to start. !!!"
    echo "  - Check logs with: journalctl -u hostapd.service -n 50"
    exit 1
fi
echo "  - AP services started successfully."

# 5. Запускаем наш API на Python, который ждет данные от мобильного приложения
echo "  - Starting Provisioning API..."
python3 /usr/local/bin/provision_api.py

echo "Provisioning API stopped. System should be rebooting now."

