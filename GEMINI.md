# M5 Sensor Support

## Issue
Regression in CPU temperature monitoring on M5 chips. Sensors were either missing or only visible as "unknown" SMC keys.

## Root Cause
1. **Strict Platform Filtering**: Version 2.11.67 introduced explicit M5 support but lacked comprehensive sensor mappings. The `SensorsReader` strictly filtered sensors by the detected platform. Since M5 keys were not explicitly mapped to the M5 platform, they were miscategorized as "unknown".
2. **Lifecycle Issues**: Toggling "Show unknown sensors" did not trigger a re-identification of sensors, leaving them stuck in the "unknown" state.

## Discovered M5 SMC Keys
A discovery tool was run on an M5 machine to identify the exact core mappings:
- **Performance Cores**: `Tp00`, `Tp04`, `Tp08`, `Tp0C`, `Tp0G`, `Tp0O`, `Tp0X` (Core 7), `Tp0a` (Core 8).
- **Efficiency Cores**: `Ta00`, `Ta04`, `Ta08`, `Ta0K`.
- **GPU**: `Tg0G`, `Tg0d`, `Tg0j`.

## Fix
1. **Precise M5 Mappings**: Added the discovered SMC keys to `Modules/Sensors/values.swift` specifically for the M5 platform family.
2. **Permissive Identification Fallback**: Disabled strict platform filtering for M5 chips in `Modules/Sensors/readers.swift` as a safety measure to allow matching any Apple Silicon sensor entry.
3. **Dynamic Discovery**: Updated `SensorsReader` to re-run full sensor discovery when settings (like "Unknown Sensors") are changed.
4. **Resilient CPU Averaging**: Updated `Modules/CPU/readers.swift` to include the discovered M5 keys in the `TemperatureReader` list for correct "Average CPU" and "Hottest CPU" calculations.

## Verification Standard
The fix was verified on-machine to show the following sensors with their correct names without requiring "Show unknown sensors":
- `Average CPU`
- `Hottest CPU`
- `CPU performance core 7` (SMC key `Tp0X`)
