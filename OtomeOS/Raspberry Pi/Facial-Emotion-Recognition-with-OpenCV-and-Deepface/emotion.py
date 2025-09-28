# emotion.py
import cv2
import time
import numpy as np
from deepface import DeepFace

# ---------------- Config ----------------
# Windowing / decision rules
WINDOW_SEC = 5.0         # length of the decision window in seconds
POS_RATIO = 0.60         # % of (pos+neg) frames that must be positive to gain 1 heart
NEG_RATIO = 0.60         # % of (pos+neg) frames that must be negative to lose 1 heart
MIN_EFFECTIVE_FRAMES = 10  # minimum (pos+neg) frames in window to consider a change

# Hearts display
HEARTS_MIN = 1
HEARTS_MAX = 5
HEARTS_START = 3
HEART_SIZE = 28
HEART_GAP = 10
HEART_ORIGIN = (20, 50)
TEXT_COLOR = (0, 0, 0)

# Emotion sets
POSITIVE = {'happy', 'surprise'}
NEGATIVE = {'angry', 'disgust', 'fear', 'sad'}
NEUTRAL  = {'neutral'}

emotion_labels = ['angry', 'disgust', 'fear', 'happy', 'sad', 'surprise', 'neutral']

# ---------------- Face detect + tracker ----------------
face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')

def create_tracker():
    for ctor in [
        "legacy.TrackerCSRT_create", "TrackerCSRT_create",
        "legacy.TrackerKCF_create",  "TrackerKCF_create"
    ]:
        obj = cv2
        ok = True
        for part in ctor.split("."):
            if not hasattr(obj, part):
                ok = False
                break
            obj = getattr(obj, part)
        if ok:
            return obj()
    return None

def pick_main_face(faces):
    if len(faces) == 0:
        return None
    return max(faces, key=lambda b: b[2] * b[3])  # largest area

# ---------------- Drawing (hearts) ----------------
def draw_heart(img, center, size, filled=True, on=True):
    x, y = center
    h = size
    w = int(size * 1.1)
    color = (0, 0, 255) if on else (160, 160, 160)  # BGR
    thickness = -1 if filled else 2
    radius = h // 4
    top_offset = h // 4
    c1 = (x - radius, y - top_offset)
    c2 = (x + radius, y - top_offset)
    pts = np.array([
        (x - w // 2, y),
        (x, y + h // 2 + 2),
        (x + w // 2, y)
    ], dtype=np.int32)
    if filled:
        cv2.circle(img, c1, radius, color, -1)
        cv2.circle(img, c2, radius, color, -1)
        cv2.fillPoly(img, [pts], color)
    else:
        cv2.circle(img, c1, radius, color, thickness)
        cv2.circle(img, c2, radius, color, thickness)
        cv2.polylines(img, [pts], isClosed=True, color=color, thickness=thickness)

def draw_hearts_row(img, hearts_on, total=5, size=HEART_SIZE, gap=HEART_GAP, origin=HEART_ORIGIN):
    ox, oy = origin
    for i in range(total):
        cx = ox + i * (size + gap) + size // 2
        cy = oy
        draw_heart(img, (cx, cy), size, filled=True, on=(i < hearts_on))

# ---------------- DeepFace (version-agnostic) ----------------
def get_top_emotion_from_gray_face(img48gray):
    """
    Takes a grayscale face crop (any size; we'll convert to RGB).
    Uses DeepFace.analyze with detector 'skip' and returns the top emotion label and prob.
    """
    if len(img48gray.shape) == 2:
        rgb = cv2.cvtColor(img48gray, cv2.COLOR_GRAY2RGB)
    else:
        rgb = cv2.cvtColor(img48gray, cv2.COLOR_BGR2RGB)

    result = DeepFace.analyze(
        rgb, actions=['emotion'], detector_backend='skip', enforce_detection=False
    )

    if isinstance(result, list):
        result = result[0]

    em = result.get('emotion', {}) or result.get('emotions', {})
    # Ensure we can pick a top label even if keys vary slightly
    # Default all missing to 0
    scores = {k: float(em.get(k, 0.0)) for k in emotion_labels}
    # Normalize if they look like raw scores
    s = sum(scores.values())
    if s > 0:
        for k in scores:
            scores[k] /= s
    # Pick top
    top_label = max(scores.items(), key=lambda kv: kv[1])[0]
    top_prob  = scores[top_label]
    return top_label, float(top_prob)

# ---------------- Main loop ----------------
cap = cv2.VideoCapture(0)
tracker = None
tracking = False
lost_frames = 0
LOST_LIMIT = 20

hearts = HEARTS_START

# Tumbling window state
win_start = time.time()
pos_count = 0
neg_count = 0
neu_count = 0

while True:
    ok_ret, frame = cap.read()
    if not ok_ret:
        break
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

    # --- Track existing lock ---
    if tracking and tracker is not None:
        ok, bbox = tracker.update(frame)
        if ok:
            x, y, w, h = [int(v) for v in bbox]
            lost_frames = 0
        else:
            lost_frames += 1
            if lost_frames >= LOST_LIMIT:
                tracking = False
                tracker = None

    # --- Acquire lock if needed ---
    if not tracking:
        faces = face_cascade.detectMultiScale(
            gray, scaleFactor=1.1, minNeighbors=5, minSize=(60, 60)
        )
        main_face = pick_main_face(faces)
        if main_face is not None:
            x, y, w, h = main_face
            tracker = create_tracker()
            if tracker is not None:
                tracker.init(frame, (x, y, w, h))
                tracking = True
                lost_frames = 0
        else:
            # Show current hearts even if no lock
            draw_hearts_row(frame, hearts, total=HEARTS_MAX)
            cv2.putText(frame, "No face", (HEART_ORIGIN[0], HEART_ORIGIN[1] + HEART_SIZE + 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (60, 60, 60), 2)
            cv2.imshow("Hearts Mood Meter (One Main Face)", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
            continue

    # --- Crop ROI for the locked face ---
    x = max(0, x); y = max(0, y)
    w = max(1, w); h = max(1, h)
    x2 = min(frame.shape[1], x + w)
    y2 = min(frame.shape[0], y + h)
    roi_gray = gray[y:y2, x:x2]

    top_label = None
    if roi_gray.size >= 48 * 48:
        # DeepFace handles various sizes, but standardize for consistency
        resized = cv2.resize(roi_gray, (96, 96), interpolation=cv2.INTER_AREA)
        try:
            top_label, top_prob = get_top_emotion_from_gray_face(resized)
        except Exception:
            top_label, top_prob = 'neutral', 1.0

        # Update window counts based on top label
        if top_label in POSITIVE:
            pos_count += 1
        elif top_label in NEGATIVE:
            neg_count += 1
        else:  # neutral or anything else
            neu_count += 1

        # Draw face box & label
        cv2.rectangle(frame, (x, y), (x + w, y + h), (20, 20, 220), 2)
        cv2.putText(frame, f"{top_label} ({top_prob:.2f})", (x, y - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, TEXT_COLOR, 2)

    # --- Window decision every WINDOW_SEC (tumbling windows) ---
    now = time.time()
    if now - win_start >= WINDOW_SEC:
        effective = pos_count + neg_count  # neutral frames are ignored
        if effective >= MIN_EFFECTIVE_FRAMES:
            pos_ratio = pos_count / effective if effective > 0 else 0.0
            neg_ratio = neg_count / effective if effective > 0 else 0.0

            if pos_ratio >= POS_RATIO and pos_ratio > neg_ratio:
                hearts = min(HEARTS_MAX, hearts + 1)
            elif neg_ratio >= NEG_RATIO and neg_ratio > pos_ratio:
                hearts = max(HEARTS_MIN, hearts - 1)
            # else: no change

        # reset window
        win_start = now
        pos_count = neg_count = neu_count = 0

    # --- Draw hearts + status ---
    draw_hearts_row(frame, hearts, total=HEARTS_MAX)
    cv2.putText(frame, f"Window {int(WINDOW_SEC)}s  pos:{pos_count}  neg:{neg_count}  neu:{neu_count}",
                (HEART_ORIGIN[0], HEART_ORIGIN[1] + HEART_SIZE + 20),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, TEXT_COLOR, 2)
    cv2.putText(frame, "LOCKED: Main Face", (10, frame.shape[0] - 15),
                cv2.FONT_HERSHEY_SIMPLEX, 0.6, (40, 180, 40), 2)

    cv2.imshow("Hearts Mood Meter (One Main Face)", frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
