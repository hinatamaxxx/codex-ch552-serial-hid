"""Jev chooses a visible Windows button; CH552 performs the click.

This is a small, bounded prototype for ordinary desktop dialogs. UAC uses the
separate keyboard path because UI Automation cannot inspect its secure desktop.
"""

import argparse
import ctypes
import json
import time
from pathlib import Path

import serial
import uiautomation as auto
from dotenv import dotenv_values
from typesafe_sdk import Choice, TypeSafeClient


ROOT = Path(__file__).resolve().parent
CONFIG = Path.home() / ".config" / "jev-browser-use" / "config.json"
CLICK_TYPES = {"ButtonControl", "MenuItemControl", "HyperlinkControl"}
USER32 = ctypes.windll.user32


class Point(ctypes.Structure):
    _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]


def cursor_position():
    point = Point()
    if not USER32.GetCursorPos(ctypes.byref(point)):
        raise RuntimeError("Cannot read cursor position")
    return point.x, point.y


def snapshot():
    window = auto.GetForegroundControl()
    title = window.Name or ""
    controls = []
    queue = [(window, 0)]
    while queue and len(controls) < 40:
        parent, depth = queue.pop(0)
        if depth >= 5:
            continue
        for item in parent.GetChildren():
            try:
                name = (item.Name or "").strip()
                rect = item.BoundingRectangle
                if (item.ControlTypeName in CLICK_TYPES and name and item.IsEnabled and not item.IsOffscreen
                        and rect.right > rect.left and rect.bottom > rect.top):
                    controls.append({"name": name[:120], "role": item.ControlTypeName,
                                     "rect": [rect.left, rect.top, rect.right, rect.bottom]})
                if depth < 4:
                    queue.append((item, depth + 1))
            except Exception:
                continue
            if len(controls) >= 40:
                break
    return title, controls


def jev_client():
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    provider = config.get("provider", "typesafe")
    if provider != "typesafe":
        raise RuntimeError("This prototype supports the configured TypeSafe provider only")
    env_path = Path(config["envFile"]).expanduser()
    key = dotenv_values(env_path).get("TYPESAFE_API_KEY")
    if not key:
        raise RuntimeError("TypeSafe credential is not configured")
    return TypeSafeClient(api_key=key, model=config.get("model") or "jev-latest")


def choose(client, goal, title, controls):
    criteria = {f"c{i}": f"Click {item['role']} named {item['name']}" for i, item in enumerate(controls)}
    criteria["done"] = "The user's requested end state is already visible"
    criteria["blocked"] = "No listed control safely advances the goal"
    state = {"goal": goal, "window": title,
             "visible_controls": [{"id": f"c{i}", "role": item["role"], "name": item["name"]}
                                  for i, item in enumerate(controls)]}
    started = time.perf_counter()
    result = client.system_one(
        state=state,
        questions={"next": Choice(
            instructions="Choose exactly one currently visible control for the user's goal. "
                         "Only choose done when the requested result is already visible; "
                         "choose blocked if the listed controls cannot accomplish it.",
            criteria=criteria,
        )},
    )
    answer = result.choices["next"]
    choice = answer.choice
    if choice not in criteria:
        raise RuntimeError("Jev returned an unknown choice")
    return choice, answer.probabilities[choice], answer.confidence, round((time.perf_counter() - started) * 1000)


class Hid:
    def __init__(self, port):
        self.serial = serial.Serial(port, 9600, timeout=1.5, write_timeout=1.5)
        self.sequence = 0
        time.sleep(0.15)
        self.serial.reset_input_buffer()
        self.send(0)

    def close(self):
        self.serial.close()

    def send(self, command, a=0, b=0, c=0):
        self.sequence = (self.sequence + 1) & 255
        seq = self.sequence
        checksum = seq ^ command ^ a ^ b ^ c
        self.serial.write(bytes((0xA5, seq, command, a, b, c, checksum)))
        response = self.serial.read(4)
        if len(response) != 4 or response[0] != 0x5A or response[1] != seq or response[3] != (response[1] ^ response[2]) or response[2] != 0:
            raise RuntimeError("CH552 did not acknowledge the HID command")

    def click_at(self, x, y):
        for _ in range(24):
            now_x, now_y = cursor_position()
            error_x, error_y = x - now_x, y - now_y
            if abs(error_x) <= 8 and abs(error_y) <= 8:
                break
            dx = max(-80, min(80, round(error_x / 2)))
            dy = max(-80, min(80, round(error_y / 2)))
            self.send(3, dx & 255, dy & 255)
            time.sleep(0.02)
        else:
            raise RuntimeError("Hardware cursor could not reach the selected control")
        self.send(4, 1)
        time.sleep(0.06)
        self.send(5, 1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--goal", required=True)
    parser.add_argument("--port", default="COM5")
    parser.add_argument("--window", help="Expected foreground window title fragment")
    parser.add_argument("--steps", type=int, default=1)
    parser.add_argument("--execute", action="store_true", help="Actually click using CH552")
    args = parser.parse_args()
    if not 1 <= args.steps <= 10:
        parser.error("--steps must be 1..10")
    USER32.SetProcessDPIAware()
    started = time.perf_counter()
    records = []
    hid = None
    first_title = None
    try:
        with jev_client() as client:
            for _ in range(args.steps):
                title, controls = snapshot()
                if first_title is None:
                    first_title = title
                elif title != first_title:
                    records[-1]["stopped"] = "window_changed"
                    break
                if args.window and args.window.casefold() not in title.casefold():
                    raise RuntimeError("Foreground window does not match --window")
                if not controls:
                    raise RuntimeError("No enabled, named controls found")
                choice, probability, confidence, jev_ms = choose(client, args.goal, title, controls)
                record = {"window": title, "choice": choice, "probability": probability,
                          "confidence": confidence, "jev_ms": jev_ms,
                          "control": controls[int(choice[1:])] if choice.startswith("c") else None}
                records.append(record)
                if choice in {"done", "blocked"} or not args.execute:
                    break
                if probability < 0.70 or confidence < 0.55:
                    record["stopped"] = "low_confidence"
                    break
                fresh_title, fresh_controls = snapshot()
                item = record["control"]
                if fresh_title != title or item not in fresh_controls:
                    record["stopped"] = "screen_changed"
                    break
                if hid is None:
                    hid = Hid(args.port)
                left, top, right, bottom = item["rect"]
                hid.click_at((left + right) // 2, (top + bottom) // 2)
                record["executed"] = True
                time.sleep(0.15)
                record["post_window"] = auto.GetForegroundControl().Name or ""
    finally:
        if hid is not None:
            hid.close()
    print(json.dumps({"steps": records, "executed": args.execute,
                      "total_ms": round((time.perf_counter() - started) * 1000)}, ensure_ascii=True))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        raise SystemExit(f"{type(error).__name__}: operation stopped") from None
