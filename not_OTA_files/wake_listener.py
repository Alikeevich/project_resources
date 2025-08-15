#!/usr/bin/env python3
import vosk
import json
import os
import subprocess

print("<<<<< V19 (PREFIX-API) >>>>>", flush=True)

WAKE_WORDS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wake_words.json")
try:
    with open(WAKE_WORDS_FILE, 'r', encoding='utf-8') as f:
        WAKE_WORDS = set(json.load(f))
    print(f"Слова для распознавания загружены: {list(WAKE_WORDS)}", flush=True)
except Exception as e:
    print(f"ОШИБКА: Не удалось прочитать {WAKE_WORDS_FILE}. Ошибка: {e}", flush=True)
    WAKE_WORDS = {"компьютер", "станция", "тревога"}

TARGET_RATE = 16000
CHUNK_SIZE = 4096
MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "model")

print("Инициализирую Vosk...", flush=True)
model = vosk.Model(MODEL_PATH)
recognizer = vosk.KaldiRecognizer(model, TARGET_RATE)
recognizer.SetWords(True)
print("Vosk инициализирован.", flush=True)

COMMAND = ['arecord', '-q', '-D', 'default', '-r', str(TARGET_RATE), '-c', '1', '-f', 'S16_LE', '-t', 'raw']
print("Запускаю arecord...", flush=True)
process = subprocess.Popen(COMMAND, stdout=subprocess.PIPE)

print("--- ГОТОВ К РАБОТЕ ---", flush=True)

try:
    while True:
        data = process.stdout.read(CHUNK_SIZE)
        if recognizer.AcceptWaveform(data):
            pass
        else:
            partial_result = json.loads(recognizer.PartialResult())
            partial_text = partial_result.get("partial", "").lower()

            found_word = next((word for word in WAKE_WORDS if word in partial_text), None)

            if found_word:
                # !!! ГЛАВНОЕ ИСПРАВЛЕНИЕ !!!
                # Теперь мы печатаем слово со специальным префиксом.
                print(f"WAKEWORD:{found_word}", flush=True)
                recognizer.Reset()

except (KeyboardInterrupt, BrokenPipeError):
    print("Завершение работы.", flush=True)
finally:
    process.kill()
