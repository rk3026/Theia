# JSON Map Loading Architecture and Building Selection

## Overview
- Introduces a concrete JSON loading pipeline to parse building metadata (`Building.json`) and per-building path maps (`BLD_*.json`).
- Adds a `BuildingSelectScreen` and a `StartSelectScreen`, each mirroring the existing destination screen (voice, gestures, visuals) while sourcing their data from the JSON assets.
- Establishes shared state (`MapState`) and caching inside `MapLoaderService` so the UI can react to asynchronous asset loads, persist selections, and resolve routes without blocking the main isolate.

## Runtime Data Lifecycle
1. **Warm-up** – `MapState.initialize()` runs during app boot: it restores the last building/start from `StorageService`, asks `MapLoaderService` for `Building.json`, and preloads the active building’s map into memory.
2. **Building selection** – When `BuildingSelectScreen` confirms a building, `MapState.selectBuilding()` calls `MapLoaderService.loadBuildingMap()`, caches the result, updates listeners, and persists the id.
3. **Start selection** – `StartSelectScreen` reads the freshly cached `MapData.destinations`, lets the user confirm a starting point, and persists the choice for quick re-entry.
4. **Destination selection** – The existing destination screen now binds to `MapState.destinations` so it stays in sync with the selected building.
5. **Route resolution** – `RouteSelectScreen` requests `MapState.resolvePath(fromId, toId)`; the state object delegates to `MapLoaderService.resolvePath()` using the cached `MapData`. The resulting instructions feed navigation guidance and TTS.
6. **Runtime updates** – Any change to building/start/destination notifies listeners (screens, controllers) so they refresh their list views and spoken prompts immediately.

## State Management
- Introduce a `MapState extends ChangeNotifier` that holds:
  - `List<Building> buildingCatalog`
  - `Building? currentBuilding`
  - `Destination? currentStart`
  - `MapData? currentMap`
  - helper getters (`destinations`, `hasSelections`, etc.).
- Expose `Future<void> initialize()`, `Future<void> selectBuilding(String id)`, `void selectStart(String destinationId)`, and `PathInstructions? resolvePath(String fromId, String toId)`.
- Register `MapState` via `ChangeNotifierProvider` in `TheiaApp` so every screen accesses it through the widget tree.
- Guard async calls with loading/error flags (`isBusy`, `lastError`) to drive progress indicators and retry prompts when JSON fails to load.

## Services
- **MapLoaderService**
  - `Future<List<Building>> loadBuildingList()` — reads and parses `assets/maps/Building.json`.
  - `Future<MapData> loadBuildingMap(String buildingId)` — loads `BLD_<ID>.json`, normalises keys, and attaches metadata.
  - `List<Destination> getDestinations(String buildingId)` — derived from cached `MapData`.
  - `PathInstructions? resolvePath(String buildingId, String fromId, String toId)` — fetches the instruction set for unique keys like `"D1 D2"`.
  - `void clearCache()` / `MapData? peekCached(String buildingId)` — support hot reloads, tests, and memory hygiene.
- **StorageService**
  - `saveLastBuilding(String buildingId)` / `String? getLastBuilding()`.
  - `saveLastStart(String buildingId, String destinationId)` / `String? getLastStart(String buildingId)` so returning users land on familiar contexts.
  - Existing preference/favorites APIs remain unchanged.

## Models
- **Building**: `{ buildingId, name, floors: List<int>, destinations: List<Destination> }`
- **Destination**: `{ id, name, floor, type, keywords: List<String> }`
- **MapData**: `{ mapID, destinations: List<Destination>, paths: Map<String, PathInstructions> }`
- **PathInstructions**: `{ pathType, estimatedTimeMin, instructions: List<String> }`

## Screen Responsibilities
- **BuildingSelectScreen**
  - Subscribes to `MapState.buildingCatalog` and loading flags.
  - Initiates `MapState.selectBuilding()` on confirmation (voice or touch) and speaks status updates through `VoiceService`.
  - Shows retry prompts if `MapLoaderService` raises an error (asset missing, parse failure).
- **StartSelectScreen**
  - Mirrors destination UX using `MapState.currentMap.destinations`.
  - Persists the last start via `StorageService.saveLastStart()` and triggers `MapState.selectStart()`.
- **Destination selection / HomeScreen**
  - Continues to display destinations but now uses `MapState.destinations` filtered by `currentStart` if needed.
  - Existing voice flow is unchanged; only the backing list changes.
- **RouteSelectScreen**
  - Requests routes through `MapState.resolvePath()` and handles null paths (e.g., missing combinations) with user-friendly fallbacks.

## Voice Parity
- All three selection screens (building, start, destination) share the same command grammar and TTS prompts:
  - `"next"`, `"previous"`, `"select <item>"`, `"confirm"`, `"cancel"`, and emergency gestures.
  - On async loads, voice prompts announce progress ("Loading building list", "Building selected, fetching starting locations", etc.).
  - State listeners trigger updated prompts automatically whenever a selection changes.

## Error Handling & Resilience
- Missing assets → surface via snackbar/TTS, allow retry; log with `TraceService` when available.
- Corrupt JSON → fallback to a safe message and block confirmation until the user picks a valid option.
- Empty destination list → treat as configuration error; prompt the user and keep them on the current screen.
- Cache invalidation on hot reload / updates: call `MapLoaderService.clearCache()` before reinitializing.

## Dependencies
- Existing dependencies (`flutter`, `provider`, `intl`) remain sufficient.
- Use Flutter `rootBundle` for asset reads; keep the loader in the services layer to simplify testing.
- Ensure `pubspec.yaml` declares every map asset:

```yaml
flutter:
  assets:
    - assets/maps/Building.json
    - assets/maps/BLD_A.json
    # - assets/maps/BLD_B.json
    # - assets/maps/BLD_C.json
```

## Implementation Notes (non-code)
- Register `MapLoaderService` and `MapState` in the provider graph so widgets can watch selections.
- Maintain consistent path keys (e.g., `"D1 D2"` sorted lexically) and validate them during JSON parsing.
- Route selection and navigation re-use the simplified `instructions` already encoded in JSON; navigation only formats them for TTS/haptics.
- Keep all UI visuals intact; limit changes to data access, provider wiring, and voice prompts.
- Document asset conventions (naming, schema versions) inside `Docs/Architecture` to guide future building additions.

## Testing Considerations
- Unit tests for `MapLoaderService` parsing, caching behaviour, and error handling using fixture JSON.
- Widget tests for `MapState` to verify notifier updates when selections change or loads fail.
- UI/automation tests that assert voice command parity across building/start/destination flows.
- Migration tests: when no persisted selections exist, the app must default to `BuildingSelectScreen`; when they do, the state should hydrate without user interaction.
