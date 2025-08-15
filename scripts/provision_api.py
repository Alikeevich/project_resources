#!/usr/bin/env python3
# ===================================================================
#  ISS AI Hub - Provisioning API (v10 - MAC Address in Scan)
#  - Includes robust Hub ID generation, async WiFi connection, and detailed network scan.
# ===================================================================
import subprocess
import os
import time
import threading
from flask import Flask, request, jsonify
import logging
import re # Импортируем модуль для работы с регулярными выражениями

# --- Базовая настройка ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
app = Flask(__name__)

# --- Константы ---
FLAG_FILE = "/boot/firmware/setup_complete.flag"
HUB_ID_FILE = "/etc/iss_ai_hub/hub_id.txt"
WPA_SUPPLICANT_CONF = "/etc/wpa_supplicant/wpa_supplicant.conf"
HUB_ID = None # Глобальная переменная для кэширования ID

# --- Функция получения/генерации ID (полная версия) ---
# (Остается без изменений, так как она работает отлично)
def get_hub_id():
    global HUB_ID
    if HUB_ID:
        return HUB_ID
    try:
        if not os.path.exists(HUB_ID_FILE):
            logging.info("Hub ID file not found. Generating a new ID.")
            command = "echo \"isshub_raspi_$(cat /sys/class/net/wlan0/address | tr -d ':' | tail -c 8)\""
            result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
            new_id = result.stdout.strip()
            logging.info(f"New Hub ID '{new_id}' generated. Saving to {HUB_ID_FILE}")
            subprocess.run(['sudo', 'mkdir', '-p', os.path.dirname(HUB_ID_FILE)], check=True)
            tmp_id_file = '/tmp/hub_id.tmp'
            with open(tmp_id_file, 'w') as f:
                f.write(new_id)
            subprocess.run(['sudo', 'mv', tmp_id_file, HUB_ID_FILE], check=True)
            subprocess.run(['sudo', 'chmod', '644', HUB_ID_FILE], check=True)
            HUB_ID = new_id
        else:
            logging.info(f"Hub ID file found. Reading from {HUB_ID_FILE}")
            with open(HUB_ID_FILE, 'r') as f:
                HUB_ID = f.read().strip()
    except Exception as e:
        logging.critical(f"FATAL: Could not generate or read Hub ID: {e}")
        return "id_generation_failed"

# --- ОБНОВЛЕННАЯ Функция для сканирования Wi-Fi сетей с MAC-адресами ---
def scan_wifi_networks():
    """Выполняет сканирование и возвращает список объектов, содержащих SSID и MAC."""
    logging.info("Starting detailed WiFi network scan...")
    try:
        # Запускаем сканирование и получаем полный вывод
        command = "sudo iwlist wlan0 scan"
        result = subprocess.run(command, shell=True, capture_output=True, text=True, check=True)
