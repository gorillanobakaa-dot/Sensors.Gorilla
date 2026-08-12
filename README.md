# sensors.gorilla 🦍

> *A zero-dependency Python 3 terminal dashboard that maps every readable hardware sensor on a Sony VAIO SVE14A3AJ (and any similar Linux machine) into a single, beautiful, colour-coded live readout.*

---

## 🧸 Section A — For the Layman

### What does this do?

Imagine your laptop had a health panel — like a car dashboard — that told you everything happening inside it in real time: how hot the CPU is, how the fan is coping, how healthy the battery still is, how much life your SSD has left, and how long it will last under different usage styles.

That is exactly what `sensors.gorilla` is.

Run one command in the terminal and you get a full-screen dashboard showing:

- 🌡️ **Temperatures** — Every CPU core, the motherboard chipset, the integrated GPU, and the SSD drive
- 💨 **Fan speed** — What percentage the fan is running at right now
- 🔋 **Battery health** — Not just "how charged is it", but *how worn out is the battery itself* compared to when it was brand new (in %). Plus how many times it has been charged (cycle count)
- 💾 **SSD health and lifetime** — How much life the Kingston Enterprise SSD has left, displayed as years-to-go under realistic usage scenarios:
  - *"If you just browse the web and watch YouTube, this drive will last 1,918 years"*
  - *"If you compile Firefox from scratch every single day, it will last 160 years"*
  - *"If you run it at full enterprise blast (1 full overwrite per day as Kingston designed it for), it lasts 5 years"*

Across the top: a **Gorilla Skynet System** banner made of glowing letters in fire colours (cyan → orange → red) rendered entirely in text characters — no images, just Unicode. Below it the data is laid out in **two columns** (temperatures/cooling/power on the left, storage health on the right) so the whole dashboard fits a maximized window with no scrolling. On narrow terminals it automatically falls back to a single stacked column.

**Companion tool:** [`thermal-profile-daemon`](./thermal-profile-daemon.README.md) — a zero-dependency background service that automatically steps the Sony fan profile (silent/balanced/performance) with CPU temperature, since nothing else on Linux ever touches that knob. The dashboard's `[SYSTEM COOLING]` section shows whether it is running.

### How was it built?

All sensor data is read directly from Linux kernel files (`/sys` filesystem) — the same files the `sensors` command reads. The SSD data comes from the industry-standard `smartctl` tool that queries the drive's built-in health counters (called SMART attributes). No internet connection needed. No cloud. No tracking. Everything runs locally.

The SSD lifespan maths uses the drive manufacturer's (Kingston) official rated endurance of **3,504 Terabytes Written** and compares it to how many bytes have actually been written to the drive so far.

---

## 💻 Section B — For the Developer

### Requirements

- Python 3 (stdlib only — `glob`, `os`, `subprocess`, `re`, `time`, `argparse`)
- `smartmontools` (`sudo apt install smartmontools`) — for SMART attribute reads via `sudo smartctl -A /dev/sda`
- Linux kernel with `coretemp`, `acpitz`, `sony-laptop` modules loaded (standard on VAIO SVE14A3AJ)

### Installation

```bash
cp sensors.gorilla ~/.local/bin/sensors.gorilla
chmod +x ~/.local/bin/sensors.gorilla
```

### Usage

```bash
sensors.gorilla          # single snapshot
sensors.gorilla -w       # live watch, 2s refresh
sensors.gorilla -w -n 5  # live watch, custom interval
```

### Sensor Sources (Complete Map)

| Sensor | sysfs / tool path | SMART attr |
|---|---|---|
| CPU Package Peak | `/sys/.../coretemp/temp1_input` | — |
| CPU Core 0–3 | `/sys/.../coretemp/temp2–5_input` | — |
| Motherboard (acpitz) | `/sys/class/hwmon/hwmon1/temp1_input` | — |
| Intel HD 4000 | Shared CPU package die | — |
| AMD Radeon Turks | `/sys/class/hwmon/hwmon*/name` (amdgpu scan) | — |
| SSD Temperature | `smartctl -A /dev/sda` | attr 194 RAW |
| SSD Health | `smartctl -A /dev/sda` | attr 231 VALUE |
| SSD Lifetime Writes | `smartctl -A /dev/sda` | attr 241 RAW × 32 MB |
| SSD Power-On Hours | `smartctl -A /dev/sda` | attr 9 RAW |
| Fan Speed | `/sys/devices/platform/sony-laptop/fanspeed` | — |
| Thermal Profile | `/sys/devices/platform/sony-laptop/thermal_control` | — |
| AC Online | `/sys/class/power_supply/ADP1/online` | — |
| Battery Charge % | `/sys/class/power_supply/BAT0/capacity` | — |
| Battery Status | `/sys/class/power_supply/BAT0/status` | — |
| Battery Voltage | `/sys/class/hwmon/hwmon2/in0_input` ÷ 1000 | — |
| Power Draw | `/sys/class/hwmon/hwmon2/power1_input` ÷ 1,000,000 | — |
| Battery Wear | `BAT0/energy_full` ÷ `BAT0/energy_full_design` | — |
| Cycle Count | `/sys/class/power_supply/BAT0/cycle_count` | — |
| Sony Care Limiter | `/sys/devices/platform/sony-laptop/battery_care_limiter` | — |

### SSD Lifespan Calculation

```python
TBW_TOTAL_GB = 3_504_000.0          # Kingston DC600M 1.92TB rated endurance
written_gb   = attr_241_raw * 32 / 1024
remaining_gb = TBW_TOTAL_GB - written_gb
years        = remaining_gb / gb_per_day / 365.25
```

Rendered across 10 profiles in 3 categories (Normal / Developer Hardcore / Enterprise).

### Logo Architecture

```
get_skynet_logo_lines()
  └── _LOGO_RAW[]           — 3 hand-crafted thin box-drawing strings (one banner row)
  └── _fire_colour(x, w)    — maps column position → (R, G, B) on cyan→orange→red arc
  └── \033[1;38;2;R;G;Bm    — true-colour bold ANSI per character
```

Fixed 80-char banner, centred over the dashboard. No PIL. No pyfiglet. No external dependencies.

### Architecture Overview

```
sensors.gorilla
├── get_file_val()          — safe sysfs file reader with scale + default
├── get_cpu_temps()         — coretemp hwmon scanner
├── get_amd_gpu_temp()      — hwmon name-scan for amdgpu/radeon
├── get_battery_health()    — BAT0 + sony-laptop sysfs
├── get_ssd_metrics()       — smartctl subprocess parser
├── _fire_colour(x, width)  — gradient math
├── get_skynet_logo_lines() — ANSI-painted logo renderer
├── _two_columns()          — ANSI-aware two-column zip (width-adaptive)
└── build_dashboard()       — banner + two-column assembly, stacked fallback
```

### Notes

- AMD Radeon Turks is disabled in BIOS on this machine → cleanly shows `OFF (Disabled in BIOS)`
- Intel HD 4000 temperature = CPU Package Peak (shared die, no separate sensor)
- `BAT0/cycle_count` may return `0` on some VAIO BIOSes (counter not exposed by ACPI)
- SSD lifespan projections do not account for Write Amplification Factor (WAF ≈ 1.5–3×)
- `sudo` is required for `smartctl` — script will show `N/A` if permission denied

---

*Built on a Sony VAIO SVE14A3AJ (Intel i7-3632QM, 16GB RAM, Kingston DC600M 1.92TB Enterprise SSD) running Debian Linux.*
