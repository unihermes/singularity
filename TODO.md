# To-do

1. Clean up the repo.
2. Align state and cache paths across QML and helpers, with a migration policy
   for existing settings, notes and chat history.
3. Extract and test pure behavior from large modules one boundary at a time,
   preserving their public APIs and event ordering.
4. Check settings choices, bounds and defaults for consistency before
   considering a shared metadata table for search entries.
5. Add behavioral coverage for queued config writes and AI reset/resume,
   including late process output, before consolidating session state.
