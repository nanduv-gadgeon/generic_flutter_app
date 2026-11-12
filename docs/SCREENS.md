# Device Monitor – mockup screens v2 – VitaCare (teal, Nunito)

Captured from `device-monitor-mockup-v2.html`, light mode, iPhone 390 × 844 layout, with the real brand fonts.

- **Scale:** images are 2×. Divide pixel measurements by 2 for Flutter logical pixels (780 px wide = 390 logical px).
- **Long screens** are split into phone-height parts named `_p1`, `_p2`, … from top to bottom. Each part overlaps the previous one by 60 logical px. Fixed bars (tab bar, bottom buttons) appear only in the last part.
- **Dialogs and bottom sheets** (screens 08, 33, 37, 39) are shown at normal phone height.

| # | Screen | Files | Full height (logical px) |
|---|---|---|---|
| 01 | App launch | screens/01_splash.png | 844 |
| 02 | Login | screens/02_login.png | 844 |
| 03 | Register | screens/03_register.png | 844 |
| 04 | Forgot password | screens/04_forgot.png | 844 |
| 05 | First login – no devices | screens/05_home_empty.png | 844 |
| 06 | My devices | screens/06_home_p1.png<br>screens/06_home_p2.png<br>screens/06_home_p3.png | 1725 |
| 07 | My devices – swiped to delete | screens/07_home_swipe_p1.png<br>screens/07_home_swipe_p2.png<br>screens/07_home_swipe_p3.png | 1725 |
| 08 | My devices – delete confirmation | screens/08_home_delete.png | 844 |
| 09 | My devices – reorder | screens/09_home_reorder_p1.png<br>screens/09_home_reorder_p2.png | 1325 |
| 10 | Add device – types | screens/10_add_p1.png<br>screens/10_add_p2.png | 1216 |
| 11 | Add device – BLE scan | screens/11_add_scan.png | 844 |
| 12 | Add device – registered | screens/12_add_register.png | 844 |
| 13 | Live – smart band | screens/13_dash_band.png | 1000 |
| 14 | Live – env sensor | screens/14_dash_sensor.png | 1000 |
| 15 | Live – wearable patch | screens/15_dash_patch.png | 850 |
| 16 | Live – health kit | screens/16_dash_kit.png | 850 |
| 17 | Live – therapy device (event log · minimum) | screens/17_dash_therapy.png | 844 |
| 18 | Live – thermometer (spot reading · minimum) | screens/18_dash_thermo.png | 844 |
| 19 | Live – iNOS (PPG + motion) | screens/19_dash_inos_p1.png<br>screens/19_dash_inos_p2.png | 1489 |
| 20 | Live – ECG monitor | screens/20_dash_ecg_p1.png<br>screens/20_dash_ecg_p2.png | 1138 |
| 21 | Live – sensor hub (24 channels) | screens/21_dash_hub_p1.png<br>screens/21_dash_hub_p2.png<br>screens/21_dash_hub_p3.png | 2350 |
| 22 | History – by day | screens/22_history_p1.png<br>screens/22_history_p2.png<br>screens/22_history_p3.png | 1825 |
| 23 | History – day with no data | screens/23_history_missing.png | 844 |
| 24 | History – 7-day summary | screens/24_history_summary.png | 1078 |
| 25 | History – therapy device (events) | screens/25_history_therapy.png | 844 |
| 26 | History – therapy device (7-day summary) | screens/26_history_therapy_summary.png | 1078 |
| 27 | History – thermometer (readings) | screens/27_history_thermo.png | 844 |
| 28 | History – iNOS (by day) | screens/28_history_inos_p1.png<br>screens/28_history_inos_p2.png<br>screens/28_history_inos_p3.png | 1965 |
| 29 | History – iNOS (7-day summary) | screens/29_history_inos_summary.png | 1078 |
| 30 | History – ECG monitor | screens/30_history_ecg_p1.png<br>screens/30_history_ecg_p2.png | 1470 |
| 31 | History – sensor hub (by day) | screens/31_history_hub_p1.png<br>screens/31_history_hub_p2.png<br>screens/31_history_hub_p3.png<br>screens/31_history_hub_p4.png<br>screens/31_history_hub_p5.png<br>screens/31_history_hub_p6.png<br>screens/31_history_hub_p7.png | 5542 |
| 32 | History – sensor hub (7-day summary) | screens/32_history_hub_heat.png | 1078 |
| 33 | History – export | screens/33_export_sheet.png | 844 |
| 34 | Alerts | screens/34_alerts_p1.png<br>screens/34_alerts_p2.png<br>screens/34_alerts_p3.png | 2238 |
| 35 | Profile | screens/35_profile.png | 844 |
| 36 | Edit profile | screens/36_edit_profile.png | 844 |
| 37 | Auto sync options | screens/37_sync_sheet.png | 844 |
| 38 | Device settings | screens/38_settings_p1.png<br>screens/38_settings_p2.png | 1141 |
| 39 | Remove device | screens/39_remove.png | 844 |
