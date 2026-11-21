# AeroStem LightShow firmware

Drone light show firmware for the **AeroStem H743 V1 (AeroH7)** flight
controller by [AeroStem Technology](https://aerostemtechnology.com).

AeroStem LightShow is based on ArduCopter 4.6.3 with drone-show support
(show mode, synchronized trajectories and lights, geofence and show
safety checks). This repository holds the AeroStem changes and a
reproducible build. Ready-to-flash firmware is on the
[Releases](../../releases) page.

## What's in it

- AeroStem H743 V1 board support (board ID 7190) with the hardware-tested
  GCC 10 bootloader
- Show lights: WS2812 / NeoPixel LED strip on output **M10**
- RTK GNSS: Bynav M2 and other NovAtel-protocol receivers on the GPS port,
  with a reliability fix (see below)
- AeroStem LightShow branding

## Firmware files

| File | Use |
|---|---|
| `AeroStemH743V1_lightshow_<ver>_with_bl.hex` | First install / recovery: hold BOOT, plug USB, flash with STM32CubeProgrammer |
| `AeroStemH743V1_lightshow_<ver>.apj` | Updates from a ground station (Mission Planner: Load custom firmware) |
| `aerostem-lightshow-<ver>-source.tar.xz` | Complete source code of that release |

## Default setup

| Setting | Default | Notes |
|---|---|---|
| Show LED type | `SHOW_LED0_TYPE 2` (NeoPixel) | WS2812 data line on M10 |
| Show LED output | `SHOW_LED0_CHAN 10` | M7-M10 share one timer, so M7-M9 cannot drive motors |
| LED count | `SHOW_LED0_COUNT 16` | set to the number of LEDs on your strip |
| GNSS type | `GPS1_TYPE 15` (NOVA) | Bynav / NovAtel protocol on the GPS port (UART3) |
| GNSS baud | `SERIAL3_BAUD 115` | must match the receiver's COM port |
| Telemetry | `SERIAL4_PROTOCOL 2` | MAVLink2 on UART4 for the show radio |

For a u-blox GPS instead of the Bynav receiver, set `GPS1_TYPE 1` (auto).

## NovAtel / Bynav GPS fix

Upstream ArduPilot creates the NOVA driver without detecting the receiver
and, after every 4 s without data, re-opens the port at the *next* baud
rate in its list. An RTK receiver that boots slower than the flight
controller, or drops out briefly, was therefore retried at wrong baud
rates and could take tens of seconds to come back, or never came back
("No GPS"). AeroStem LightShow:

1. always opens the port at the configured `SERIALn_BAUD` for `GPS1_TYPE 15`
2. re-sends the receiver configuration every 2 s while no valid position
   data is arriving, so a late-booting or power-cycled receiver is
   configured as soon as it is ready

## Building

```bash
sudo apt install gcc-arm-none-eabi      # Ubuntu 22.04: GCC 10.3
pip3 install "empy==3.3.4" pymavlink future intelhex pexpect
./build.sh                              # output in dist/
```

`upstream.env` pins the exact upstream source; `patches/` holds the AeroStem
changes. GitHub Actions builds every push and publishes a release for every
`v*` tag.

## License

GPL-3.0, like ArduPilot and the show extensions this firmware is built on
(see `LICENSE`). The full source of every released binary is attached to
its release. Copyright notices of the original authors are kept in the
source files.
