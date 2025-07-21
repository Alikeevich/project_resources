#!/usr/bin/env python3
# ===================================================================
#  ISS AI Hub - Provisioning API (v6 - Final with ID Generation)
# ===================================================================
import subprocess
import os
import time
from flask import Flask, request, jsonify
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
app = Flask(__name__)

# --- Константы ---
FLAG_FILE = "/boot/firmware/setup_complete.flag"
HUB_ID_FILE = "/etc/iss_ai_hub/hub_id.txt"
HUB_ID = None # Переменная для кэширования ID

def get_hub_id():
    """
    Читает HUB_ID из файла. Если файла нет, генерирует новый,
    сохраняет его и возвращает.
    """
    global HUB_ID
    # Если уже читали, просто возвращаем из кэша
    if HUB_ID:
        return HUB_ID

    # Если файла нет - генерируем
    if not os.path.exists(HUB_ID_FILE):
        logging.info("Hub ID file not found. Generating a new ID.")
        try:
            # Формируем команду bash для генерации ID
            command = "echo \"isshub_raspi_$(cat /sys/class/net/wlan0/address | tr -d ':' | tail -c 8)\""
            # Выполняем ее
            result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
            new_id = result.stdout.strip()

            # Сохраняем сгенерированный ID в файл с правами root
            logging.info(f"New Hub ID '{new_id}' generated. Saving to {HUB_ID_FILE}")
            # Создаем директорию, если ее нет
            subprocess.run(['sudo', 'mkdir', '-p', os.path.dirname(HUB_ID_FILE)], check=True)
            # Записываем во временный файл
            tmp_id_file = '/tmp/hub_id.tmp'
            with open(tmp_id_file, 'w') as f:
                f.write(new_id)
            # Перемещаем и устанавливаем права через sudo
            subprocess.run(['sudo', 'mv', tmp_id_file, HUB_ID_FILE], check=True)
            subprocess.run(['sudo', 'chmod', '644', HUB_ID_FILE], check=True)

            HUB_ID = new_id
        except Exception as e:
            logging.critical(f"FATAL: Could not generate or save Hub ID: {e}")
            HUB_ID = "generation_failed"
    else:
        # Если файл есть - просто читаем
        logging.info(f"Hub ID file found. Reading.")
        with open(HUB_ID_FILE, 'r') as f:
            HUB_ID = f.read().strip()

    return HUB_ID

@app.route('/api/v1/status', methods=['GET'])
def get_status():
    """Отдает статус и HUB_ID для привязки в приложении."""
    return jsonify({
        "hubNumber": get_hub_id(),
    })

@app.route('/api/v1/wifi_credentials', methods=['POST'])
def set_wifi_credentials():
    """Принимает Wi-Fi данные, подключается и перезагружает хаб."""
    logging.info("Request received to set WiFi credentials.")
    try:
        data = request.get_json()
        if not data or 'ssid' not in data or 'password' not in data:
            return jsonify({"error": "Missing 'ssid' or 'password' fields."}), 400
    except Exception as e:
        return jsonify({"error": f"Invalid JSON format: {e}"}), 400

    ssid = data['ssid']
    password = data['password']

    logging.info(f"Attempting to connect to SSID: '{ssid}' using nmcli.")
    try:
        # Запускаем NetworkManager ПЕРЕД использованием nmcli
        subprocess.run(['sudo', 'systemctl', 'start', 'NetworkManager'], check=True, timeout=10)
        time.sleep(3) # Даем время на инициализацию

        # Выполняем команду подключения
        command = ['sudo', 'nmcli', 'device', 'wifi', 'connect', ssid, 'password', password]
        result = subprocess.run(command, capture_output=True, text=True, timeout=45)

        if result.returncode == 0:
            logging.info(f"nmcli successfully connected to '{ssid}'.")
            # Создаем флаг-файл
            with open(FLAG_FILE, 'w') as f:
                f.write("Setup completed via NetworkManager.")

            # Запускаем перезагрузку в фоне
            subprocess.Popen('sleep 3 && sudo reboot', shell=True)
            return jsonify({"status": "ok", "message": "Successfully connected. Rebooting hub..."})
        else:
            logging.error(f"nmcli failed. Stderr: {result.stderr.strip()}")
            # Возвращаем NetworkManager в остановленное состояние для стабильности AP
            subprocess.run(['sudo', 'systemctl', 'stop', 'NetworkManager'])
            return jsonify({"error": "Failed to connect to WiFi.", "details": result.stderr.strip()}), 400
    except Exception as e:
        logging.error(f"An unexpected error occurred: {e}")
        subprocess.run(['sudo', 'systemctl', 'stop', 'NetworkManager'])
        return jsonify({"error": "An internal error occurred on the hub.", "details": str(e)}), 500

if __name__ == '__main__':
    # При старте API, сразу же убеждаемся, что ID сгенерирован
    get_hub_id()
    logging.info(f"Provisioning API started. Current HUB_ID is '{HUB_ID}'")
    app.run(host='192.168.4.1', port=80, debug=False)
