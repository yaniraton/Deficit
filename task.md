
# Cursor Task: Implement Fitness-style Calendar + Day Detail (Deficit iOS)

## Goal

Add a **Calendar** screen that looks/behaves like the iPhone **Fitness** app’s calendar:

* Month grid with **tiny rings** under each date.
* Shows the **end-of-day snapshot** of the ring for that date (same ring rules we use today).
* Tapping a date opens a **Day Detail** screen:

  * Big ring for that date (same as TopView logic, computed for that day)
  * Below: the **meals list for that date** (same UI/CRUD as MealsListView, but scoped to that day)
  * A small summary row (Burned / Intake / Net / Goal)
* Scope time to **last 12 months** only.
* Use **caching** so the grid scrolls smoothly and we don’t recompute data repeatedly.

## Data Model & Caching

Create a lightweight SwiftData model to cache the daily snapshot (one per day):

```swift
@Model
final class DailySummary {
  @Attribute(.unique) var id: UUID
  var date: Date               // normalized to startOfDay (local TZ)
  var burnedKcal: Double       // active + basal (end-of-day)
  var intakeKcal: Double       // meals total that day
  var goalKcal: Double         // snapshot of the user’s goal *for that day*
  var netKcal: Double          // burned - intake
  var inDeficit: Bool          // net >= 0
  var progress: Double         // snapshot ring progress at EOD (0...1)
  var colorMode: String        // "red" or "green" for quick render
  var createdAt: Date
  var updatedAt: Date
}
```

Notes:

* This is a **snapshot** at end-of-day using the **rules today uses**:

  * Surplus: progress = `burned / intake` (clamped 0…1), color = red
  * Deficit: progress = `(burned - intake) / goal` (clamped 0…1), color = green
* Use device TZ (Asia/Jerusalem) for start/end-of-day. Store `date` normalized to **startOfDay**.
* If data is missing for a day (no Health or no Meals), snapshot uses zeros and `colorMode="gray"` and `progress=0`.

## Health & Meals Range Fetching

Extend **HealthStore** with **range** APIs (uses `HKStatisticsCollectionQuery`) that return per-day totals for a date range for both **active** and **basal** energy. We already read those types today; just add range utilities:

```swift
struct DailyEnergy {
  let date: Date         // startOfDay
  let activeKcal: Double
  let basalKcal: Double
  var burnedKcal: Double { activeKcal + basalKcal }
}

extension HealthStore {
  func dailyEnergy(from start: Date, to end: Date) async throws -> [DailyEnergy]
}
```

Extend **MealsStore** with a day-range intake query:

```swift
extension MealsStore {
  func intake(forDay dayStart: Date, dayEnd: Date) throws -> Double
  func meals(forDay dayStart: Date, dayEnd: Date) throws -> [Meal]
}
```

* Both use local TZ. `dayEnd = startOfDay(next day)`.
* These are pure queries; no UI.

## Calendar ViewModel

Add a new **CalendarViewModel** (ObservableObject, @MainActor) that:

* Maintains the **current month** (shown in UI), and the **last 12 months** range.
* On month change or initial load, **prefetch** summaries for **visible month ±1 month**.
* Fills/updates **DailySummary** cache for each day in range:

  1. Fetch daily Health totals for range (active+basal).
  2. For each day:

     * Compute intake by querying MealsStore for \[dayStart, dayEnd).
     * Goal: snapshot the goal used **on that day** (store `vm.goal` at the time of snapshot creation; if no snapshot exists, use **current goal**).
     * Derive net, inDeficit, progress, colorMode (red/green/gray).
  3. Upsert **DailySummary** rows in SwiftData (idempotent).
* Expose published properties:

  ```swift
  @Published var monthDays: [Date]           // all calendar cells (including leading/trailing blanks)
  @Published var summariesByDay: [Date: DailySummary]
  @Published var isLoading: Bool
  ```
* Provides helpers:

  ```swift
  func monthRange(for date: Date) -> (start: Date, end: Date)
  func prefetchMonthCentered(on monthStart: Date)
  func summary(forDay dayStart: Date) -> DailySummary?
  ```

## Calendar UI (Month Grid)

New screen: **CalendarView**

* Navigation title: “History”
* Month header with chevrons (◀︎ ▶︎) to navigate months (last 12 months only).
* Grid layout: 7 columns, rows enough to cover the month. Week start: **use system default** (simpler).
* Each cell shows:

  * **date number** (1..31) at top
  * **tiny ring** just **below the date number** (like Fitness):

    * red/green/gray based on `colorMode`
    * ring progress is `summary.progress`
  * **empty gray ring** on days without data (future days are dimmed/disabled)
* No special highlight for “today” or selection.
* Tap a past (or today) date to navigate to **DayDetailView**.
* Haptics:

  * Light **tick** on month change (chevrons)
  * Light **tick** on date tap/selection

Behavior:

* Only last **12 months** are navigable (including the current month).
* Future days are dimmed and disabled (show gray empty ring).

## Day Detail UI

New screen: **DayDetailView**

* Inputs: `dayStart: Date`
* ViewModel computes for that day:

  * burned, intake, goal, net, inDeficit, progress (reads from **DailySummary** if present; else compute on the fly, then upsert cache)
  * `mealsForDay`: query MealsStore \[dayStart, dayEnd)
* Layout:

  1. **Big ring** centered (reuse `RingView` with the same colors/progress semantics).
  2. **Summary Row** (like TopView stats):

     * Burned | Intake | Net | Goal
  3. **Meals list** for that day (reuse look of MealsListView):

     * Allow **add/edit/delete meals** for that day (date prefilled to selected date).
     * On changes, update the cache for that day and refresh the UI.
* Haptics:

  * Light **success** on add.
  * **Warning** on delete.

## Ring Semantics (unchanged)

* Surplus (not in deficit): red, `progress = burned / intake` (0 if intake==0).
* Deficit: green, `progress = (burned - intake) / goal` (0 if goal==0).
* Clamp 0…1.
* Snapshot is **end-of-day** value.

## Missing Data Rules

* If **Health** or **Meals** missing:

  * Show **empty gray ring** (progress 0).
  * Day Detail shows zeros and “No data” footnote (optional).
* Future days: dimmed/disabled, empty gray ring.

## Performance

* Use `HKStatisticsCollectionQuery` for range energy (daily).
* Prefetch: **visible month ±1 month**.
* Cache `DailySummary` so we don’t recompute when scrolling months.

## File Plan (high-level)

* `CalendarView.swift` — month header + grid UI, month navigation, haptics on change/tap.
* `CalendarViewModel.swift` — date math, prefetch, cache reconciliation, published summaries.
* `DayDetailView.swift` — big ring + summary + meals for day, CRUD actions.
* `HealthStore+Range.swift` — `dailyEnergy(from:to:)` helper returning `[DailyEnergy]`.
* `DailySummary.swift` — SwiftData model (see above).
* (Existing) `RingView`, `MealsStore` APIs for day querying.

## Acceptance Criteria

* Navigating months (last 12 only) updates grid; tiny rings render fast without hitch.
* Tapping any past or today date opens DayDetailView showing:

  * Big ring with correct progress/color snapshot for that day.
  * Summary row with Burned/Intake/Net/Goal.
  * Meals list for that day; adding/editing/deleting updates the list and the ring **and** the cached DailySummary for that day.
* Empty days display a gray ring (progress 0); future days are dimmed/disabled.
* Haptics trigger as specified.

## Testing Notes

* Unit tests:

  * `CalendarViewModel` date math (month ranges, weekday alignment).
  * Caching: creating/updating `DailySummary` after computing a day.
  * Ring math matches TopView logic per day.
* Integration/UI tests:

  * Month navigation + date tap opens DayDetailView.
  * Adding a meal from DayDetailView updates intake and ring.

## Constraints & Non-goals

* Only last 12 months; no all-time scrolling right now.
* No VoiceOver in this pass.
* No cloud sync yet.

## Implementation Tips

* Normalize all day keys to **startOfDay** for dictionary/cache.
* Keep view bodies simple; extract subviews for calendar cell and month header.
* Use `@Environment(\.calendar)` and locale for weekday symbols; week start uses system default.

---

If you need anything clarified while coding, ask me before making large structural changes. Keep code production-ready and consistent with the current project style (iOS 17+, SwiftUI + SwiftData, Apple-y visuals).
