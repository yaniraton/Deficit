amazing—here’s a **ready-to-paste Cursor background task prompt** that tells the agent exactly what to build for the **Apple Watch app** MVP based on your specs. It’s scoped, implementation-oriented, and avoids features you said not to include (no favorites/templates).

---

# Background Task — Build **Deficit** watchOS MVP (rings + quick add)

## Objective

Create a **watchOS companion app** for **Deficit** that:

* Shows today’s **ring(s)** (deficit ring always; **protein ring only if enabled** in iOS settings).
* Has a **+** button (top-right) to open a **Quick Add** flow.
* Supports **system Double Tap** (S9/Ultra 2) to activate the same on-screen buttons (no private APIs).
* Quick Add uses the **Digital Crown** to set **Calories** (step ≈ 5) then **Protein** (step ≈ 1, **only if protein feature is enabled**). “Next →” moves Cal → Protein; “✓” confirms and logs a meal at **time = now** via WatchConnectivity to the iPhone; upon confirmation, the watch updates rings.

No other features (e.g., favorites, templates, photos, complications) for this MVP.

---

## Architecture & Targets

* Share small “ring math” helpers between iOS & watch if convenient, but **do not** import SwiftData on watch; use **WatchConnectivity** to sync summaries and to post quick-add meals.

---

## Data flow & contracts

### Ring rules (same as iOS)

* **Burned = Active + Basal** (from iPhone HealthKit summary).
* **Intake = sum of meals** (from iPhone).
* **Deficit ring**:

  * **Surplus** (not in deficit): red, progress = `burned / intake` (0 if intake=0), clamp 0…1.
  * **Deficit**: green, progress = `(burned - intake) / goal` (0 if goal=0), clamp 0…1.
* **Protein ring** (when enabled in iOS): blue, progress = `proteinConsumed / proteinGoal` (can exceed 1.0 for over-goal visuals, cap the drawing at 1.0 but display 100%+ state in text if presented).

### WatchConnectivity (WCSession)

Implement a minimal JSON message protocol.

* **Phone → Watch** (state push after app launch, foreground, or meal add):

  ```json
  {
    "type": "todaySummary",
    "payload": {
      "dateStart": "ISO8601",   // startOfDay in local tz
      "burnedKcal": 1234.0,
      "intakeKcal": 900.0,
      "netKcal": 334.0,
      "goalKcal": 500.0,
      "proteinEnabled": true,
      "proteinConsumed": 60.0,
      "proteinGoal": 100.0
    }
  }
  ```

* **Watch → Phone** (quick add request):

  ```json
  {
    "type": "quickAddMeal",
    "payload": {
      "name": "Quick Add",
      "kcal": 250.0,
      "protein": 20.0,      // 0 if protein disabled or user skipped
      "date": "ISO8601"     // now() on the watch
    }
  }
  ```

* **Phone → Watch** (ack + refreshed summary):

  ```json
  { "type": "ack", "payload": { "for": "quickAddMeal" } }
  { "type": "todaySummary", ... }   // send right after saving
  ```

On the iPhone side (already exists): handle `quickAddMeal` by calling your Meals pipeline, then push `todaySummary` back.

---

## UI & Interaction (watchOS)

### 1) **MainView** (today)

* **Dual rings** when proteinEnabled = true (deficit outer, protein inner), else single deficit ring.
* Small stats row (optional text labels beneath rings): Burned | Intake | Net (and Protein if enabled).
* **Top-right + button** to open Quick Add.
* **System Double Tap** should activate the **+** button when it’s the focused/primary element.

**Implementation notes**

* Use a clean SwiftUI layout with large tap targets.
* For Double Tap compatibility: ensure actionable controls are **focusable** and expose a **primary action**. System Double Tap will trigger the current focused control’s primary action automatically—no private API. In SwiftUI:

  * Use `Button` for +/Next/✓.
  * Ensure `.accessibilityRespondsToUserInteraction(true)` on the container if needed.
  * Keep one clear primary button on each screen so Double Tap maps naturally.

### 2) **QuickAddFlowView**

A paged flow with two steps:

* **Step 1: Calories**

  * Big number, units “kcal”
  * Digital Crown controls a bound `@State` `calories` value.
  * “Next →” button advances to Protein **only if** proteinEnabled=true; otherwise, the “✓ Add” button is shown directly.
* **Step 2: Protein** (only if proteinEnabled)

  * Big number, units “g”
  * Digital Crown controls a bound `@State` `protein` value.
  * “✓ Add” button confirms.

**Digital Crown behavior**

* Use `.digitalCrownRotation` with:

  ```swift
  .digitalCrownRotation($value,
                        from: 0, through: maxValue,
                        by: 1,
                        sensitivity: .medium,
                        isContinuous: true,
                        isHapticFeedbackEnabled: true)
  ```
* Implement **speed/acceleration feeling**: bind Crown to a **raw** value and in `onChange` apply stepping rules:

  * Calories: round to nearest **5** for display/storage.
  * Protein: step **1**.
  * Use `WKCrownSequencer` via `WKInterfaceDevice.current().play(.click)` is not needed; the SwiftUI modifier already gives haptics. For extra acceleration, track deltas/time between updates and add small acceleration (optional; keep simple if not needed).

**Haptics**

* Success tick when adding.
* Light tick when moving to next step.

**Buttons**

* **Next →** (only appears on Calories when proteinEnabled).
* **✓ Add**: sends the `quickAddMeal` message, then dismisses on ack.

**Double Tap mapping**

* On Step 1: Double Tap activates **Next →** (when visible) else **✓ Add**.
* On Step 2: Double Tap activates **✓ Add**.
* We don’t implement any private Double Tap API; this works by having the target button be the primary actionable control.

---

## Files to add (Watch Extension)

* `WatchConnectivityManager.swift`

  * `class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate`
  * `@Published var summary: TodaySummary?`
  * `func activate()`; handle incoming `todaySummary` / `ack`
  * `func sendQuickAdd(kcal: Double, protein: Double)`
  * JSON encode/decode helpers (Codable structs).

* `TodaySummary.swift`

  * `struct TodaySummary: Codable` mirroring the JSON payload (burned, intake, net, goal, proteinEnabled, proteinConsumed, proteinGoal).

* `RingMath.swift` (shared or watch-only)

  * Helpers to derive `deficitProgress` and `proteinProgress` from summary.

* `MainView.swift`

  * Shows ring(s) + stats + **+** button.
  * Subscribes to `WatchConnectivityManager.summary`.
  * On appear: `activate()`, and if no summary within \~1–2s, show “Waiting for phone…” placeholder.

* `QuickAddFlowView.swift`

  * `enum Step { case calories, protein }`
  * `@State var step: Step = .calories`
  * `@State var calories: Double = 0`
  * `@State var protein: Double = 0`
  * `.digitalCrownRotation` bound to a temporary raw value with rounding logic (kcal→nearest 5, protein→nearest 1).
  * Buttons: **Next →** or **✓ Add** as described.
  * On Add: `wc.sendQuickAdd(kcal: calories, protein: proteinEnabled ? protein : 0)`

* `RingView.swift` (watch variant)

  * Reuse your iOS ring visuals but scaled for watch.
  * Support single (deficit only) or dual (deficit + protein) display.

---

## Settings dependency

* The watch learns `proteinEnabled` and goals from the phone via `todaySummary`.
* No on-watch settings page for MVP.

---

## Error/empty states

* Before first sync: show “Waiting for phone…” and an empty gray ring.
* If summary has zeros/missing data: show **empty gray ring** (progress=0).
* If WCSession not supported: show a small inline error.

---

## Acceptance Criteria

* App launches to **MainView** and displays:

  * **Deficit ring** and, if enabled, **Protein ring**.
  * A **+** button top-right.
* Tapping **+** OR using **Double Tap** on the + (when it’s the primary control) opens **QuickAddFlowView**.
* **Digital Crown** adjusts values (Calories rounded to 5s, Protein to 1s) with haptic feedback.
* **Next →** moves to Protein step only if proteinEnabled; else skip to Add.
* **✓ Add** sends a `quickAddMeal` to the phone; watch receives **ack** and then an updated **todaySummary** and updates rings.
* System **Double Tap** activates the visible primary button on each step (Next/✓).
* No references to favorites/templates/photos/complications.

---

## Testing notes (dev)

* Add a mock “simulated summary” if WCSession is unavailable in simulator so the UI isn’t empty.
* Unit-test `RingMath` helpers.
* Quick manual test: run iPhone + Watch in sims, simulate a `todaySummary` push from iPhone target after launch.

---

## Implementation reminders

* Keep SwiftUI view bodies lean; extract subviews if needed.
* Use semantic colors and monospaced digits.
* Keep one clear primary button per screen to play nice with system Double Tap.
* Don’t use private APIs for Double Tap; rely on default primary action behavior.

---

**Deliverables:** the new Watch targets compile & run; MainView + QuickAddFlowView implemented; WCSession skeleton working; rings update after Add; no crashes.

---

If you want, I can also produce the **iPhone-side WCSession handler stub** you can drop into your app delegate/manager to receive `quickAddMeal`, persist it, and send `todaySummary` back.
