# thermal-profile-daemon 🌡️💨

> *A temperature-driven fan-profile stepper for Sony VAIO laptops on Linux. One
> Python file, zero dependencies. Companion to `sensors.gorilla` (same repo).*

---

## 🧸 Section A — For the Layman

### The problem it solves

On Sony VAIO laptops, Linux cannot set the fan to an arbitrary speed — the
fan is owned by Sony's embedded controller (a tiny chip with its own firmware).
What Linux *can* do is choose which of three firmware fan behaviors is active:

- **silent** — quiet, lets the machine run warmer
- **balanced** — the default
- **performance** — aggressive cooling

…plus one emergency lever that forces the fan to full blast.

Out of the box, **nothing ever changes this setting**. It boots to `balanced`
and stays there — even if you compile code for six hours at 85°C. GNOME's
power-profile switcher does not touch it; it is a separate, Sony-proprietary
knob that nobody's software knows about.

This daemon watches your CPU temperature and moves that knob for you:

- Getting hot (≥ 80°C)? → switches to **performance** immediately.
- Genuinely alarming (≥ 93°C for 15 s)? → forces the fan to **full blast**
  until things cool off.
- Been cool for a few minutes? → steps back down to **balanced**, and
  eventually to **silent** when the machine is idling.

The step-down waits are deliberate: they stop the fan from yo-yoing every time
a web page spikes the CPU for two seconds.

### How do I get it?

```bash
# 1. download the script, make it executable
chmod +x thermal-profile-daemon

# 2. ask it whether your machine qualifies (changes nothing, installs nothing)
./thermal-profile-daemon check

# 3. if the check is green, install it
./thermal-profile-daemon install
```

The `check` step tells you honestly what it found: whether your laptop has the
Sony control files, whether a temperature sensor is readable, and which
optional tools are missing (with the exact `sudo apt install …` line to fix
each one). The `install` step spells out the three things it is about to do —
copy itself to `/usr/local/bin`, register a background service (systemd), and
start that service now and on every boot — and asks for a y/N before touching
anything. If your machine is not a Sony VAIO, it refuses instead of guessing.

### How do I see what it's doing?

```bash
thermal-profile-daemon status    # one line: temperature, profile, fan, service
thermal-profile-daemon watch     # the same line, live-updating
journalctl -fu thermal-profile-daemon   # its decision log, live
```

Every profile change is logged with the temperature that caused it, so you can
check in the morning what it did overnight.

### How do I get rid of it?

```bash
thermal-profile-daemon uninstall
```

Removes the service and the installed copy. Your machine is back to stock.

---

## 💻 Section B — For the Developer

### Requirements

- A Sony VAIO exposing `/sys/devices/platform/sony-laptop/thermal_control`
  (the `sony-laptop` SNC driver; standard in mainline kernels). Machines
  without it are detected and **refused** — on other laptops look at
  `thermald` or your vendor's platform driver instead.
- Python 3, stdlib only.
- systemd (for the service; `run` works under any init if you supervise it
  yourself).
- Root for the daemon itself: the Sony sysfs knobs are root-writable.

### The control model

```
/sys/devices/platform/sony-laptop/
├── thermal_control    RW   silent | balanced | performance  (EC fan curve)
├── fan_forced         RW   0 | 1  (full blast override)
└── fanspeed           RO   current speed (%) — read-only: the EC owns PWM
```

There is no writable PWM on this hardware. The daemon is therefore a state
machine over the three EC curves plus the force bit, with hysteresis:

| Transition | Trigger | Delay |
|---|---|---|
| any → performance | pkg ≥ 80°C | immediate |
| silent → balanced | pkg ≥ 72°C | immediate |
| fan_forced = 1 | pkg ≥ 93°C | sustained 15 s |
| fan_forced = 0 | pkg < 85°C | immediate |
| performance → balanced | pkg ≤ 70°C | sustained 180 s |
| balanced → silent | pkg ≤ 55°C | sustained 300 s |

Up-transitions are instant (heat is urgent); down-transitions require the
temperature to hold below the threshold for the whole dwell, resetting on any
excursion. Poll interval 5 s. Within a profile, the EC's own curve handles the
smooth speed changes — the daemon only decides *which* curve is active.

### Temperature source

`coretemp`'s `Package id 0` (hottest point of the CPU/GPU die), falling back
to the hottest core, then the hottest ACPI thermal zone. If nothing is
readable it logs a warning and holds the current profile rather than acting
on invented data.

### Configuration

All thresholds are overridable in `/etc/thermal-profile-daemon.conf`
(`KEY=VALUE`, `#` comments). Keys and defaults:

```
POLL_SECONDS=5
UP_PERFORMANCE_C=80
UP_BALANCED_C=72
FORCED_C=93
FORCED_HOLD_S=15
FORCED_CLEAR_C=85
DOWN_BALANCED_C=70
DOWN_BALANCED_S=180
DOWN_SILENT_C=55
DOWN_SILENT_S=300
```

Restart to apply: `sudo systemctl restart thermal-profile-daemon`.

### Service lifecycle

- `install` copies the script to `/usr/local/bin/thermal-profile-daemon`,
  writes `/etc/systemd/system/thermal-profile-daemon.service`, enables and
  starts it, then **verifies the service actually reports `active`** instead
  of trusting exit codes.
- On SIGTERM/SIGINT the daemon restores `balanced` and releases `fan_forced`,
  so stopping the service never strands the machine in an extreme profile.
- `Restart=on-failure`, `Nice=10`. Footprint is one Python process reading a
  handful of sysfs files every 5 s.

### Exit behaviors worth knowing

- Missing `thermal_control` → refuses to run (exit with explanation).
- Firmware missing one of the three profiles → refuses (no improvising a
  partial ladder).
- No temperature reading at runtime → warn + hold, never guess.

---

*Built and live-tested on a Sony VAIO SVE14A3AJ (i7-3632QM, Debian 13) during
an 8-thread WebKit compile that held the package at 80–85°C for hours.*
