"""Device lab: runs the same real-app journey on emulators shaped like popular phones, under the settings people
change (text size, display size, dark mode, 3-button navigation, landscape), and reports crashes, Flutter errors
and layout overflows from the debug build's log.

EMULATORS ONLY. It creates and boots its own `lab_*` AVDs, talks to them by serial (emulator-55xx) and refuses
anything else. It never touches a physical phone.

  python3 tool/device_lab.py                 # every profile
  python3 tool/device_lab.py lab_small lab_fold
  KEEP=1 python3 tool/device_lab.py lab_small  # leave the emulator running afterwards

Needs a debug APK: flutter build apk --debug --target-platform android-x64
Results: build/device_lab/<profile>/report.txt + screenshots.
"""
import os
import re
import subprocess
import sys
import time
import traceback

sys.path.insert(0, os.path.dirname(__file__))
from lab_ui import ADB, Device  # noqa: E402

SDK = os.path.expanduser('~/Android/Sdk')
EMU = f'{SDK}/emulator/emulator'
AVDM = f'{SDK}/cmdline-tools/latest/bin/avdmanager'
IMAGE = 'system-images;android-36;google_apis;x86_64'
APK = 'build/app/outputs/flutter-apk/app-debug.apk'
PKG = 'com.darkdev.ledgerlock'
PASSWORD = 'LabTest2026!x'
OUT = 'build/device_lab'

# Popular shapes. Hardware profiles ship with the SDK; the comment says which real phones each one stands in for
# (same logical size class; the emulator can't reproduce Samsung One UI itself).
PROFILES = {
    'lab_small': ('small_phone', 'budget 720p phones: Galaxy A0x/A1x, Moto E/G Play, Redmi A'),
    'lab_medium': ('medium_phone', 'mainstream 6.1-6.5": Galaxy A15/A16/A25/A35, Galaxy S2x, Redmi Note'),
    'lab_pixel9a': ('pixel_9a', 'Pixel 9a / 8a'),
    'lab_big': ('pixel_9_pro_xl', 'big 6.7-6.9": Galaxy S2x Ultra/A5x, Pixel Pro XL, Moto G Power'),
    'lab_fold': ('pixel_9_pro_fold', 'book foldables: Galaxy Z Fold (outer + inner screen), Pixel Fold'),
    'lab_flip': ('6.7in Foldable', 'flip foldables: Galaxy Z Flip, Razr (tall 22:9 inner screen)'),
    'lab_tablet': ('medium_tablet', 'tablets: Galaxy Tab A/S, Pixel Tablet'),
}

# Settings sweeps, applied one at a time over the default state.
VARIANTS = [
    ('default', []),
    ('font130', [['shell', 'settings', 'put', 'system', 'font_scale', '1.3']]),
    ('font200', [['shell', 'settings', 'put', 'system', 'font_scale', '2.0']]),
    ('display_large', ['DENSITY+20%']),
    ('dark', [['shell', 'cmd', 'uimode', 'night', 'yes']]),
    ('threebutton', [['shell', 'cmd', 'overlay', 'enable', 'com.android.internal.systemui.navbar.threebutton']]),
    (
        'landscape',
        [
            ['shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0'],
            ['shell', 'settings', 'put', 'system', 'user_rotation', '1'],
        ],
    ),
]
RESET = [
    ['shell', 'settings', 'put', 'system', 'font_scale', '1.0'],
    ['shell', 'wm', 'density', 'reset'],
    ['shell', 'cmd', 'uimode', 'night', 'no'],
    ['shell', 'cmd', 'overlay', 'disable', 'com.android.internal.systemui.navbar.threebutton'],
    ['shell', 'settings', 'put', 'system', 'user_rotation', '0'],
]
BAD = re.compile(
    r'RenderFlex overflowed|overflowed by|EXCEPTION CAUGHT|FATAL EXCEPTION|ANR in com\.darkdev|'
    r'E/flutter|Unhandled Exception|was used after being disposed|setState\(\) called after dispose'
)


def run(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def ensure_avd(name, device):
    if name in run([EMU, '-list-avds']).stdout.split():
        return
    r = run([AVDM, 'create', 'avd', '-n', name, '-k', IMAGE, '-d', device], input='no\n')
    if r.returncode != 0:
        raise RuntimeError(r.stderr)
    cfg = os.path.expanduser(f'~/.android/avd/{name}.avd/config.ini')
    s = open(cfg).read()
    s = re.sub(r'disk\.dataPartition\.size=.*', 'disk.dataPartition.size=4G', s)
    s = re.sub(r'hw\.ramSize=.*', 'hw.ramSize=2G', s)
    open(cfg, 'w').write(s)


def boot(name, port):
    log = open(f'{OUT}/{name}/emulator.log', 'w')
    subprocess.Popen(
        [EMU, '-avd', name, '-port', str(port), '-no-window', '-no-audio', '-no-boot-anim', '-no-snapshot',
         '-wipe-data', '-gpu', 'swiftshader_indirect'],
        stdout=log, stderr=log, start_new_session=True,
    )
    d = Device(f'emulator-{port}')
    run([ADB, '-s', d.s, 'wait-for-device'], timeout=300)
    for _ in range(120):
        if d.adb('shell', 'getprop', 'sys.boot_completed', check=False).strip() == '1':
            break
        time.sleep(3)
    d.adb('shell', 'settings', 'put', 'global', 'window_animation_scale', '0', check=False)
    d.adb('shell', 'settings', 'put', 'global', 'transition_animation_scale', '0', check=False)
    d.adb('shell', 'settings', 'put', 'global', 'animator_duration_scale', '0', check=False)
    return d


def launch(d):
    d.adb('shell', 'am', 'force-stop', PKG)
    d.adb('logcat', '-c', check=False)
    d.adb('shell', 'am', 'start', '-n', f'{PKG}/.MainActivity')
    time.sleep(6)


def setup(d):
    d.tap('Get started', timeout=60)
    d.type_into(0, PASSWORD)
    d.type_into(1, PASSWORD)
    d.key(4)
    d.tap('Create encrypted vault')
    d.wait("I've written it down", 60)
    key = [l for l in d.labels() if re.fullmatch(r'([A-Z0-9]{5}\n){5}[A-Z0-9]{5}', l)][0].split('\n')
    d.tap("I've written it down")
    d.type_into(0, f'{key[4]}-{key[5]}')
    d.key(4)
    d.tap('Confirm')
    d.tap('Not now', timeout=20)
    d.tap('Selling products', timeout=20)
    d.tap('Continue')
    d.tap('Look around first', timeout=20)
    d.wait('Home', 20)
    # Screenshots stay blocked (FLAG_SECURE) unless the user allows them; the lab needs them.
    d.tap('Settings')
    for _ in range(8):
        if d.has('Allow screenshots'):
            break
        d.swipe_up()
    d.tap('Allow screenshots')
    d.key(4)


def unlock(d):
    if not d.wait('Unlock', 20):
        return  # already open
    d.type_into(0, PASSWORD)
    d.key(4)
    d.tap('Unlock')
    d.wait('Home', 30)


def keypad(d, digits):
    for ch in digits:
        d.tap(ch, exact=True)


def journey(d, tag, shots):
    """Add an expense and an income with the keypad, then visit every tab, search and settings."""
    steps = []

    def recover():
        # Back out of whatever screen failed, but never past Home (that would close the app).
        for _ in range(4):
            if d.has('Records') and d.has('Taxes'):
                return
            d.key(4)
        if not d.has('Records'):
            launch(d)
            unlock(d)

    def step(name, fn):
        try:
            fn()
            steps.append((name, 'ok'))
        except Exception as e:  # noqa: BLE001
            steps.append((name, f'FAIL {e}'[:400]))
            d.shot(f'{shots}/{tag}-FAIL-{name}.png')
            recover()

    def expense():
        d.tap('Add a record')
        keypad(d, '1250')
        if not d.has('$12.50'):
            raise AssertionError('keypad did not type $12.50')
        d.tap('Supplies', exact=True)
        d.tap('Save expense')
        if not d.wait('Home', 10):
            raise AssertionError('did not return after save')

    def income():
        d.tap('Add a record')
        d.tap('Income', exact=True)
        keypad(d, '45000')
        d.tap('Product sales', exact=True)
        d.tap('Save income')
        if not d.wait('Home', 10):
            raise AssertionError('did not return after save')

    def tabs():
        for t in ['Records', 'Vault', 'Taxes', 'Home']:
            d.tap(t, exact=True)
            time.sleep(1)
            d.shot(f'{shots}/{tag}-{t.lower()}.png')
        if not any(l.startswith('Net profit') for l in d.labels()):
            raise AssertionError('Home has no profit card after adding records')

    def search():
        d.tap('Search')
        d.type('supplies')
        time.sleep(2)
        d.shot(f'{shots}/{tag}-search.png')
        d.key(4)
        d.key(4)

    def settings():
        d.tap('Settings')
        time.sleep(1)
        d.swipe_up()
        d.swipe_up()
        d.shot(f'{shots}/{tag}-settings.png')
        d.key(4)

    for name, fn in [('expense', expense), ('income', income), ('tabs', tabs), ('search', search),
                     ('settings', settings)]:
        step(name, fn)
    return steps


def bad_log(d):
    pid = d.adb('shell', 'pidof', PKG, check=False).strip()
    log = d.adb('logcat', '-d', '-v', 'brief', check=False)
    hits = [l for l in log.splitlines() if BAD.search(l) and (not pid or pid in l or 'ANR' in l or 'FATAL' in l)]
    # Context: the lines after each Flutter error say which widget.
    return hits[:40]


def lab(name, port=5556):
    device, stands_for = PROFILES[name]
    shots = f'{OUT}/{name}'
    os.makedirs(shots, exist_ok=True)
    report = [f'{name} = {device} ({stands_for})']
    ensure_avd(name, device)
    d = boot(name, port)
    try:
        w, h = d.size()
        report.append(f'screen {w}x{h}, density {d.adb("shell", "wm", "density").split()[-1]}')
        d.adb('install', '-r', APK)
        launch(d)
        try:
            setup(d)
            report.append('setup: ok')
        except Exception as e:  # noqa: BLE001
            d.shot(f'{shots}/setup-FAIL.png')
            report.append(f'setup: FAIL {e}'[:600])
            return report
        for vname, cmds in VARIANTS:
            for c in RESET:
                d.adb(*c, check=False)
            for c in cmds:
                if c == 'DENSITY+20%':
                    base = int(re.findall(r'\d+', d.adb('shell', 'wm', 'density'))[0])
                    d.adb('shell', 'wm', 'density', str(int(base * 1.2)))
                else:
                    d.adb(*c, check=False)
            time.sleep(2)
            launch(d)
            unlock(d)
            steps = journey(d, vname, shots)
            bad = bad_log(d)
            ok = all(s == 'ok' for _, s in steps) and not bad
            report.append(f'[{vname}] {"PASS" if ok else "PROBLEMS"}')
            report += [f'    {n}: {s}' for n, s in steps if s != 'ok']
            report += [f'    log: {l[:300]}' for l in bad]
            if bad:
                open(f'{shots}/{vname}-logcat.txt', 'w').write(d.adb('logcat', '-d', check=False))
    except Exception:  # noqa: BLE001
        report.append('LAB ERROR ' + traceback.format_exc()[-800:])
    finally:
        if not os.environ.get('KEEP'):
            d.adb('emu', 'kill', check=False)
            time.sleep(5)
    return report


def main():
    names = sys.argv[1:] or list(PROFILES)
    if not os.path.exists(APK):
        raise SystemExit(f'missing {APK}: flutter build apk --debug --target-platform android-x64')
    os.makedirs(OUT, exist_ok=True)
    all_lines = []
    for n in names:
        lines = lab(n)
        open(f'{OUT}/{n}/report.txt', 'w').write('\n'.join(lines) + '\n')
        print('\n'.join(lines), flush=True)
        all_lines += lines + ['']
    open(f'{OUT}/summary.txt', 'w').write('\n'.join(all_lines))


if __name__ == '__main__':
    main()
