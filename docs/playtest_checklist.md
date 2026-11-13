# Playtest Checklist — Lunar Outpost: Mission 01

Run the automated headless verification suite at any time from the project root:

```bash
godot --headless --path . -s res://scripts/test_playtest_checklist.gd
```

Below is the step-by-step checklist for both automated and manual verification across all 5 required scenarios.

---

## 1. Full 10-Day Win (1–3 Stars)
- **Goal:** Survive through the end of Day 10 with `Health >= 50` (1 Star), `Health >= 80` (2 Stars), and `Science >= 30` (3 Stars).
- **Steps to reproduce:**
  1. Start a new mission from the Main Menu (`Play Mission`).
  2. Upgrade the Radiation Shield on Days 1 and 2 (`Shield -> 3`).
  3. Keep Life Support on `Normal` and Greenhouse on `Low`; order a `Food` resupply by Day 6 (`+25 Food` after 3 days).
  4. Request a Space Weather Forecast in the Comms Room on Day 6 (arrives Day 8 to warn of the Day 8/10 storms).
  5. On Day 7 (`Research Window` event), choose `Double experiment` (`3 AP, 25 PU -> +30 Science`) or run `Experiment` three times at the Power Station (`+10 Science` each).
  6. On storm days (Days 4, 8, 10), run to the **Radiation Shelter**, open its dashboard, and click **`START LOCKDOWN NOW`** before the countdown reaches 0.
- **Expected Result:**
  - End screen opens after Day 10 Summary showing `MISSION COMPLETE — YOU SURVIVED 10 DAYS!`, `★ ★ ★ (3 / 3 Stars)`, `Health >= 80`, `Science >= 30`.
  - Over the 10-day run (Start Briefing + 10 Day Summaries + End Screen = 12 fact cards), no OSDR fact card repeats (`17` unique facts in `data/osdr_facts.json`).
- **Status:** **PASS** (Verified by `scripts/test_playtest_checklist.gd`: `Health = 90`, `Science = 30`, `3/3 Stars`, `12` unique OSDR facts with `0` repeats).

---

## 2. Mission Loss & "What Went Wrong" Replay Hints
- **Goal:** Let crew health reach `0` before or on Day 10 and verify the friendly replay screen and plain-language hints.
- **Steps to reproduce:**
  1. Start a new mission, switch Life Support to `Eco` (or let power run out so Life Support is cut), switch Greenhouse to `Off`, and do not shelter during solar storms.
  2. Advance days until Oxygen and Food hit `0` (`-25 Health/day` for 0 Oxygen, `-10 Health/day` for 0 Food) and storm damage reduces Health to `0`.
- **Expected Result:**
  - Game ends immediately when `Health == 0`.
  - End screen displays `MISSION ENDED — TRY AGAIN!`, `0 / 3 Stars`, and a customized **"What went wrong (and tips for next time)"** list explaining which meters hit 0, which forecasts or lockdowns were missed, and when resupplies should be ordered.
- **Status:** **PASS** (Verified by `scripts/test_playtest_checklist.gd`).

---

## 3. Day-5 Worked Example Numeric Test
- **Goal:** Reproduce the exact Day-5 test from `docs/game_mechanics.md`.
- **Steps to reproduce:**
  - Click **`Day-5 Test`** in the top HUD (or run `godot --headless --path . -s res://scripts/test_playtest_checklist.gd`).
  - Starting values (Day 5): `Battery = 50, Oxygen = 70, Food = 30, Water = 26, Shield = 2, Health = 100, AP = 6, LS = Normal, GH = Low` (with `+5` food harvest arriving from Day 3).
  - Actions taken: `repair_pump` (`2 AP, 8 PU`), `forecast` (`1 AP, 4 PU`), `experiment` (`2 AP, 10 PU -> +10 Science`).
- **Expected Result:**
  - Battery after actions: **`28`**
  - End-of-day Battery: **`32`** (`28 + 36 - 6 - 14 - 8 - 4`)
  - End-of-day Oxygen: **`70`** (`70 + 10 - 10`)
  - End-of-day Food: **`27`** (`30 + 5 - 8`)
  - End-of-day Water: **`25`** (`26 - 3 + 2`)
  - End-of-day Health: **`100`**
- **Status:** **PASS** (Verified by `GameState.run_day5_debug_test()`).

---

## 4. Low-Battery Lockdown (`Battery < 4 PU`)
- **Goal:** Verify that triggering shelter lockdown when `Battery < 4 PU` uses the `0.75` low-power damage factor, sets `Battery` to `0`, pauses the Greenhouse that day, and explains it in plain language.
- **Steps to reproduce:**
  1. On a storm day (e.g., Day 4, Severity 1, base damage `10`, `Shield = 1`), spend power so that after Step 1 power resolution `Battery < 4` (for example `Battery = 2`).
  2. When the storm alert starts, open the **Radiation Shelter** and click **`EMERGENCY LOW-POWER LOCKDOWN`**.
- **Expected Result:**
  - `Battery` drops from `2` to `0`.
  - Damage uses `lockdown_low_power_factor = 0.75`: `ceil(10 * (1 - 0.2 * 1) * 0.75) = ceil(6.0) = 6` damage (instead of `4` for full lockdown or `8` with no shelter).
  - Today's Greenhouse harvest is paused (`0` food queued from today).
  - Day Summary explains: *"The battery was too low for a full lockdown, so the shelter only helped a little."*
- **Status:** **PASS** (Verified by `scripts/test_playtest_checklist.gd`).

---

## 5. Mobile Browser / Touch & Accessibility Run
- **Goal:** Verify single-threaded Web export and touch/mouse/keyboard accessibility.
- **Checklist:**
  - [x] **On-screen touch D-pad (bottom-left)** moves the astronaut in all 4 directions (`▲ ▼ ◀ ▶`).
  - [x] **On-screen `Use Room [E]` button (bottom-right)** and direct tap/click on any facility opens its dashboard.
  - [x] **Tap-to-explain `?` buttons** open kid-friendly explanations (max 2 short sentences) for `Solar storm`, `Radiation`, `Shielding`, `Oxygen`, `Battery`, `Greenhouse`, and `Communication delay`.
  - [x] **Non-color status indicators** (`[LOW]` and `[!]`) appear on HUD meter chips when resources drop low, and star ratings show both `★/☆` symbols and numeric text (`3 / 3 Stars`).
  - [x] **Sound Mute toggle** (`Sound: ON` / `Sound: MUTED`) works on both the Main Menu and HUD.
- **Status:** **PASS** (Verified in headless test suite and single-threaded Web export configuration).

