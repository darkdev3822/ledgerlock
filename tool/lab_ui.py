"""Tiny uiautomator driver for the device lab (tool/device_lab.py). Emulators only: every call names its serial."""
import html
import re
import subprocess
import time

import os
ADB = os.path.expanduser('~/Android/Sdk/platform-tools/adb')


class Device:
    def __init__(self, serial):
        if not serial.startswith('emulator-'):
            raise SystemExit(f'refusing {serial}: the device lab only drives emulators')
        self.s = serial

    def adb(self, *args, check=True, text=True):
        r = subprocess.run([ADB, '-s', self.s, *args], capture_output=True, text=text, timeout=120)
        if check and r.returncode != 0:
            raise RuntimeError(f'adb {args}: {r.stderr}')
        return r.stdout

    def nodes(self):
        for _ in range(5):
            self.adb('shell', 'uiautomator', 'dump', '/sdcard/u.xml', check=False)
            x = self.adb('shell', 'cat', '/sdcard/u.xml', check=False)
            if '<hierarchy' in x:
                break
            time.sleep(0.5)
        out = []
        for m in re.finditer(r'<node [^>]*>', x):
            n = m.group(0)
            b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
            label = ' | '.join(
                html.unescape(v) for v in re.findall(r'(?:text|content-desc)="([^"]+)"', n)
            )
            out.append((label, tuple(map(int, b.groups())) if b else None, 'focused="true"' in n))
        return out

    def fields(self):
        """Bounds of text fields, top to bottom (password fields expose no label)."""
        self.nodes()
        x = self.adb('shell', 'cat', '/sdcard/u.xml', check=False)
        out = []
        for m in re.finditer(r'<node [^>]*class="android.widget.EditText"[^>]*>', x):
            b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', m.group(0))
            out.append(tuple(map(int, b.groups())))
        return sorted(out, key=lambda b: b[1])

    def type_into(self, index, text):
        b = self.fields()[index]
        self.tap_xy((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)
        self.type(text)

    def labels(self):
        return [l for l, _, _ in self.nodes() if l]

    def find(self, label, exact=False):
        for l, b, _ in self.nodes():
            parts = [p.strip() for p in re.split(r'\n| \| ', l)]
            if (label in parts) if exact else (l.startswith(label) or label in parts):
                return b
        return None

    def has(self, label):
        return self.find(label) is not None

    def wait(self, label, timeout=30):
        end = time.time() + timeout
        while time.time() < end:
            if self.has(label):
                return True
            time.sleep(1)
        return False

    def tap(self, label, timeout=10, exact=False):
        end = time.time() + timeout
        while True:
            b = self.find(label, exact)
            if b:
                self.adb('shell', 'input', 'tap', str((b[0] + b[2]) // 2), str((b[1] + b[3]) // 2))
                time.sleep(0.8)
                return
            if time.time() > end:
                raise LookupError(f'not on screen: {label!r}; saw {self.labels()[:40]}')
            time.sleep(1)

    def tap_xy(self, x, y):
        self.adb('shell', 'input', 'tap', str(x), str(y))
        time.sleep(0.6)

    def type(self, text):
        self.adb('shell', 'input', 'text', text.replace(' ', '%s'))
        time.sleep(0.5)

    def key(self, code):
        self.adb('shell', 'input', 'keyevent', str(code))
        time.sleep(0.5)

    def swipe_up(self):
        w, h = self.size()
        self.adb('shell', 'input', 'swipe', str(w // 2), str(int(h * 0.75)), str(w // 2), str(int(h * 0.35)), '300')
        time.sleep(0.8)

    def size(self):
        m = re.findall(r'(\d+)x(\d+)', self.adb('shell', 'wm', 'size'))
        return tuple(map(int, m[-1]))

    def shot(self, path):
        data = subprocess.run([ADB, '-s', self.s, 'exec-out', 'screencap', '-p'], capture_output=True, timeout=60).stdout
        open(path, 'wb').write(data)
