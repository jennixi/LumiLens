#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Pi server (TFT only) with optional emotion.py integration.

- One TFT screen (no OLED)
- Button toggles between:
    Mode A: Text (name + AI dialogue)  -> set via POST /display/text
    Mode B: Progress image (0/25/50/75/100) -> set via POST /display/progress
- /status serves:
    { present, emotion: happy|neutral|upset, emotion_conf, embedding: base64(f32[]), last_seen_ts }

Integration with your existing emotion.py:
- If a module named `emotion` is importable and it provides either:
    1) function: analyze_frame(frame_bgr) -> dict with keys:
       { "present": bool,
         "dominant_emotion": <str from deepface like "happy"/"sad"/"angry"/"surprise"/"fear"/"disgust"/"neutral">,
         "emotion_conf": float,
         "embedding": np.ndarray (float32, L2-normalized, shape ~128-512) }
       (you can add this thin wrapper to your file)
    OR
    2) class: EmotionEngine with .analyze(frame_bgr) returning the same dict
- Otherwise we fallback to internal DeepFace pipeline.

Progress images expected at: /app/images/progress/{0,25,50,75,100}.png
"""

import os
import time
import base64
import signal
import threading
import numpy as np
import cv2
from flask import Flask, request, jsonify
from PIL import Image, ImageDraw, ImageFont

# ----------------- CONFIG -----------------
PORT = 8000
FRAME_W, FRAME_H = 320, 240
ANALYZE_EVERY_N_FRAMES = 3
EMOTION_WINDOW_SEC = 5.0

# TFT (logical) size — adjust to your panel
TFT_W, TFT_H = 240, 240

# Button (BCM numbering). If not wired, code still runs (button disabled).
BUTTON_PIN = 17

# Progress images directory
PROGRESS_DIR = "/app/images/progress"
PROGRESS_FILES = {
    0:   os.path.join(PROGRESS_DIR, "0.png"),
    25:  os.path.join(PROGRESS_DIR, "25.png"),
    50:  os.path.join(PROGRESS_DIR, "50.png"),
    75:  os.path.join(PROGRESS_DIR, "75.png"),
    100: os.path.join(PROGRESS_DIR, "100.png"),
}

# Where to drop a preview JPG if you don’t have a real TFT driver yet
RUNTIME_OUT = "/app/runtime"
os.makedirs(RUNTIME_OUT, exist_ok=True)

# ----------------- TFT BACKEND -----------------
class TFT:
    def __init__(self, w=TFT_W, h=TFT_H):
        self.w, self.h = w, h
        try:
            self.font = ImageFont.truetype(
                "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 18
            )
        except Exception:
            self.font = ImageFont.load_default()
        # If you have a real display (e.g. ST7789), init it here.

    def show_image_file(self, path: str):
        try:
            img = Image.open(path).convert("RGB").resize((self.w, self.h))
            self._blit(img)
        except Exception as e:
            print("[TFT] show_image_file error:", e)

    def show_text(self, text: str):
        img = Image.new("RGB", (self.w, self.h), (0, 0, 0))
        d = ImageDraw.Draw(img)
        # naive word-wrapping
        lines, line = [], ""
        for w in text.split():
            if d.textlength((line + " " + w).strip(), font=self.font) > (self.w - 16):
                if line: lines.append(line)
                line = w
            else:
                line = (line + " " + w).strip()
        if line: lines.append(line)
        y = 8
        for ln in lines[:10]:
            d.text((8, y), ln, font=self.font, fill=(255, 255, 255))
            y += 22
        self._blit(img)

    def _blit(self, img: Image.Image):
        # Replace this with real display driver call if available
        img.save(os.path.join(RUNTIME_OUT, "tft_preview.jpg"), quality=92)

tft = TFT()

# ----------------- MODE TOGGLE (BUTTON) -----------------
MODE_TEXT = "text"
MODE_PROGRESS = "progress"
current_mode = MODE_PROGRESS  # default

try:
    import RPi.GPIO as GPIO
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

    def _button_cb(channel):
        global current_mode
        current_mode = MODE_TEXT if current_mode == MODE_PROGRESS else MODE_PROGRESS
        print("[GPIO] Toggled mode ->", current_mode)

    GPIO.add_event_detect(BUTTON_PIN, GPIO.FALLING, callback=_button_cb, bouncetime=300)
except Exception as e:
    print("[GPIO] Skipping GPIO button (not on Pi or no wiring):", e)

# ----------------- EMOTION ENGINE (emotion.py or fallback) -----------------
_engine = None
_use_external = False

def _try_load_external_engine():
    global _engine, _use_external
    try:
        import emotion  # your file
        # Prefer a class EmotionEngine with .analyze(frame_bgr)
        if hasattr(emotion, "EmotionEngine"):
            _engine = emotion.EmotionEngine()
            _use_external = True
            print("[Engine] Using emotion.EmotionEngine from emotion.py")
            return
        # Or a function analyze_frame(frame_bgr)
        if hasattr(emotion, "analyze_frame") and callable(emotion.analyze_frame):
            class _Wrapper:
                def analyze(self, frame_bgr):
                    return emotion.analyze_frame(frame_bgr)
            _engine = _Wrapper()
            _use_external = True
            print("[Engine] Using emotion.analyze_frame from emotion.py")
            return
        print("[Engine] emotion.py found but no compatible API; using fallback.")
    except Exception as e:
        print("[Engine] No emotion.py or import error; using fallback. Details:", e)

_try_load_external_engine()

# Fallback: DeepFace internal
if not _use_external:
    from deepface import DeepFace
    _facenet_ready = False
    def _ensure_facenet():
        global _facenet_ready
        if not _facenet_ready:
            try:
                DeepFace.build_model(model_name="Facenet")
                _facenet_ready = True
            except Exception as e:
                print("[DeepFace] preload warn:", e)

    def _fallback_analyze(frame_bgr):
        """Return dict like external engine would."""
        out = {
            "present": False,
            "dominant_emotion": "neutral",
            "emotion_conf": 0.0,
            "embedding": None,
        }
        try:
            _ensure_facenet()
            analysis = DeepFace.analyze(
                img_path=frame_bgr, actions=["emotion"], enforce_detection=False
            )
            if isinstance(analysis, list) and analysis:
                analysis = analysis[0]
            if analysis:
                de = analysis.get("dominant_emotion", "neutral")
                emo_map = analysis.get("emotion", {})
                conf = float(emo_map.get(de, 1.0)) if isinstance(emo_map, dict) else 1.0
                out["dominant_emotion"] = de
                out["emotion_conf"] = conf
                out["present"] = True

                # Crop by region if available
                roi = frame_bgr
                if "region" in analysis:
                    r = analysis["region"]
                    x, y, w, h = max(0, r.get("x", 0)), max(0, r.get("y", 0)), r.get("w", 0), r.get("h", 0)
                    if w and h: roi = frame_bgr[y:y+h, x:x+w]

                reps = DeepFace.represent(img_path=roi, model_name="Facenet", enforce_detection=False)
                if isinstance(reps, list) and reps and "embedding" in reps[0]:
                    v = np.array(reps[0]["embedding"], dtype=np.float32)
                    n = np.linalg.norm(v)
                    out["embedding"] = v / n if n > 0 else v
        except Exception as e:
            print("[Fallback] analyze warn:", e)
        return out

# Thin adapter so the rest of the code calls one function
def analyze_frame(frame_bgr):
    if _use_external:
        return _engine.analyze(frame_bgr)
    else:
        return _fallback_analyze(frame_bgr)

# Map DeepFace labels -> {happy, neutral, upset}
def map_to_three(label: str) -> str:
    if not label:
        return "neutral"
    l = label.lower()
    if l in ("happy", "surprise"):
        return "happy"
    if l in ("angry", "disgust", "fear", "sad"):
        return "upset"
    return "neutral"

def b64_from_vec(vec: np.ndarray) -> str:
    if vec is None:
        return ""
    if vec.dtype != np.float32:
        vec = vec.astype(np.float32)
    return base64.b64encode(vec.tobytes()).decode("ascii")

# ----------------- VISION THREAD -----------------
cap = None
stop_flag = False

# shared state
last_present = False
last_emotion_label = "neutral"
last_emotion_conf = 0.0
last_embedding = None
last_seen_ts = 0

# smoothing window
_counts = {"happy": 0, "neutral": 0, "upset": 0}
_window_t0 = time.time()

def vision_loop():
    global cap, stop_flag
    global last_present, last_emotion_label, last_emotion_conf, last_embedding, last_seen_ts
    global _counts, _window_t0

    cap = cv2.VideoCapture(0)
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, FRAME_W)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, FRAME_H)

    if not cap.isOpened():
        print("[Camera] Could not open camera")
        return

    idx = 0
    while not stop_flag:
        ok, frame = cap.read()
        if not ok:
            time.sleep(0.03)
            continue

        idx += 1
        if idx % ANALYZE_EVERY_N_FRAMES != 0:
            time.sleep(0.005)
            continue

        try:
            out = analyze_frame(frame)
            present = bool(out.get("present", False))
            de = str(out.get("dominant_emotion", "neutral"))
            conf = float(out.get("emotion_conf", 0.0))
            emb = out.get("embedding", None)

            # Ternary mapping
            tri = map_to_three(de)

            # Update smoothing window
            now = time.time()
            if now - _window_t0 >= EMOTION_WINDOW_SEC:
                # finalize stabilized label
                last_emotion_label = max(_counts, key=lambda k: _counts[k])
                _counts = {"happy": 0, "neutral": 0, "upset": 0}
                _window_t0 = now
            else:
                if tri in _counts:
                    _counts[tri] += 1

            # shared
            last_present = present
            if present:
                last_seen_ts = int(time.time())
            last_emotion_conf = conf
            if emb is not None:
                last_embedding = emb

        except Exception as e:
            print("[Vision] warn:", e)

        time.sleep(0.005)

    try:
        cap.release()
    except Exception:
        pass

# ----------------- HTTP SERVER -----------------
app = Flask(__name__)

text_buffer = "—"
progress_pct = 0  # 0/25/50/75/100

@app.route("/status", methods=["GET"])
def status():
    return jsonify({
        "present": bool(last_present),
        "emotion": last_emotion_label or "neutral",
        "emotion_conf": float(last_emotion_conf),
        "embedding": b64_from_vec(last_embedding) if last_embedding is not None else "",
        "embedding_hash": "",  # optional: add a short hash if you like
        "last_seen_ts": int(last_seen_ts),
    })

@app.route("/display/text", methods=["POST"])
def set_text():
    global text_buffer
    data = request.get_json(silent=True) or {}
    text_buffer = str(data.get("text", ""))[:200]
    if current_mode == MODE_TEXT:
        tft.show_text(text_buffer)
    return jsonify({"ok": True})

@app.route("/display/progress", methods=["POST"])
def set_progress():
    global progress_pct
    data = request.get_json(silent=True) or {}
    image_id = str(data.get("image_id", "progress_0"))
    try:
        pct = int(image_id.split("_")[-1])
    except Exception:
        pct = 0
    if pct not in (0, 25, 50, 75, 100):
        pct = 0
    progress_pct = pct
    if current_mode == MODE_PROGRESS:
        path = PROGRESS_FILES.get(progress_pct, "")
        if path and os.path.exists(path):
            tft.show_image_file(path)
    return jsonify({"ok": True})

def ui_heartbeat():
    last_mode = None
    last_drawn = None
    while not stop_flag:
        if current_mode != last_mode:
            last_mode = current_mode
            last_drawn = None  # force redraw on mode switch
        # Draw if not already current
        if current_mode == MODE_TEXT and text_buffer != last_drawn:
            tft.show_text(text_buffer)
            last_drawn = text_buffer
        elif current_mode == MODE_PROGRESS and progress_pct != last_drawn:
            path = PROGRESS_FILES.get(progress_pct, "")
            if path and os.path.exists(path):
                tft.show_image_file(path)
                last_drawn = progress_pct
        time.sleep(0.1)

def get_ip():
    try:
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "0.0.0.0"

def main():
    # Boot splash on TFT (since no OLED)
    boot = f"Starting…\nIP: {get_ip()}:{PORT}\nMode: {current_mode.upper()}"
    tft.show_text(boot)

    vt = threading.Thread(target=vision_loop, daemon=True)
    vt.start()

    ut = threading.Thread(target=ui_heartbeat, daemon=True)
    ut.start()

    app.run(host="0.0.0.0", port=PORT, debug=False, threaded=True)

def _shutdown(sig, frame):
    global stop_flag
    stop_flag = True
    os._exit(0)

if __name__ == "__main__":
    signal.signal(signal.SIGINT, _shutdown)
    signal.signal(signal.SIGTERM, _shutdown)
    main()
