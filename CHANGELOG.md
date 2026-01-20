# Overnight Development Session - 2025-02-14

## New Features Added
1. **RPE Tracking (per set)**
   - Log optional RPE on working sets in the runner.
   - Edit RPE in the set edit sheet and show it in history + shared summaries.
   - Database: uses existing `set_logs.rpe` (no schema change).

2. **Quick Repeat Last Set**
   - One-tap action to duplicate the most recent working set.
   - Keeps rest timer + undo flow consistent.

3. **Live PR Notification (e1RM)**
   - Shows “🔥 NEW PR!” in the save snackbar when you beat your best e1RM.
   - Displays current best e1RM in the runner (when Gym Mode is off).
   - No PR banner on the very first ever set (must beat a prior best).

4. **Theme Mode Support**
   - Light/Dark/System toggle added in Settings.
   - Dark theme added to the app theme.

## Improvements Made
- **Exercise demo (wger) stability**
  - Hardened link-sheet search results to tolerate legacy cache shapes.
  - Search now reliably uses the local index model.
- **History formatting**
  - RPE shown inline with working and warm-up sets.

## Bugs Fixed
- Runtime type mismatch in wger search sheet when cached results were mixed types.

## Database Changes
- None (no new tables/columns or migrations).

## Testing Notes
- Not run in this session: `flutter analyze` / `flutter run`.
- Smoke-tested via hot-reload for the wger link sheet and runner UI.

## Recommendations for Future
- Add optional RPE quick-picks in the number pad.
- Show a “NEW PR” banner when a set beats the previous best e1RM.
- Expand dark theme colors (surface/outline) for stronger contrast.
