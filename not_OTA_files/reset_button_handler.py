#!/usr/bin/env python3
#
# ISS AI Hub - Hardware Factory Reset Button Handler
#
import RPi.GPIO as GPIO
import time
import subprocess
import logging

# Используем нумерацию BCM (по номеру GPIO), а не по номеру пина на плате
RESET_PIN = 16
HOLD_TIME_SECONDS = 20 # Время удержания для сброса

# Настройка логирования
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s',
                    handlers=[logging.FileHandler("/var/log/reset_button.log"),
                              logging.StreamHandler()])

def setup_gpio():
    """Настраивает пин GPIO."""
    GPIO.setmode(GPIO.BCM)
    # Настраиваем пин на вход.
    # pull_up_down=GPIO.PUD_UP означает что когда кнопка не нажата
    # на пине будет высокий уровень (3.3V) благодаря внутреннему подтягивающему резистору
    # Когда мы нажимаем кнопку (замыкаем на GND), на пине появляется низкий уровень (0V)
    GPIO.setup(RESET_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    logging.info(f"GPIO {RESET_PIN} initialized as input with pull-up resistor.")

def main_loop():
    """Основной цикл, который следит за кнопкой."""
    logging.info("Starting reset button listener...")
    press_start_time = None

    while True:
        # GPIO.input() возвращает 0 (False), если кнопка нажата (пин замкнут на GND),
        # и 1 (True), если отпущена.
        if GPIO.input(RESET_PIN) == GPIO.LOW:
            # Кнопка нажата
            if press_start_time is None:
                # Если мы только что ее нажали, запоминаем время
                press_start_time = time.time()
                logging.info(f"Button pressed. Hold for {HOLD_TIME_SECONDS} seconds to trigger factory reset.")
            else:
                # Если кнопка все еще удерживается, проверяем время
                elapsed_time = time.time() - press_start_time
                if elapsed_time >= HOLD_TIME_SECONDS:
                    logging.warning("Hold time threshold reached! Triggering factory reset...")

                    # Запускаем скрипт сброса.
                    # Используем subprocess.call, чтобы дождаться его завершения (хотя он все равно уйдет в ребут).
                    try:
                        subprocess.call(['sudo', '/usr/local/bin/factory_reset.sh'])
                    except Exception as e:
                        logging.error(f"Failed to execute factory_reset.sh: {e}")

                    # После запуска сброса нет смысла продолжать, выходим
                    break
        else:
            # Кнопка отпущена
            if press_start_time is not None:
                # Если мы ее только что отпустили, сбрасываем таймер
                logging.info("Button released before reset was triggered.")
                press_start_time = None

        # Небольшая задержка, чтобы не загружать процессор на 100%
        time.sleep(0.2)

if __name__ == '__main__':
    try:
        setup_gpio()
        main_loop()
    except Exception as e:
        logging.critical(f"An unexpected error occurred: {e}")
    finally:
        GPIO.cleanup()
        logging.info("GPIO cleanup complete. Script finished.")
