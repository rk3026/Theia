# Theia Phase II Demo Plan (Flutter)

A Flutter-specific rewrite of the React Native plan, aligned to the OneDrive Phase II docs and the current app structure.

## Goals
- Accessibility-first indoor navigation demo; voice/touch parity.
- Sensor-driven safety via accelerometer-based fall detection.
- Offline-only operation; local notifications and storage.
- HIPAA-aware disclosures; consent gating for mic/sensors.
- Traceability references to KAOS/NFR and IDEF0 artifacts in OneDrive.

## Core Scenarios (Presentation)
- **Scenario 1: Classroom Navigation** — Stevie navigates independently from his current location to his next classroom. THEIA asks for current location and destination (voice or touch input), calculates an optimal route, and provides audible step-by-step navigation instructions ("Walk ahead 10 steps, then turn left"). The app continuously guides Stevie with warnings for obstacles and stairs until he safely arrives at his destination. Addresses FR-1, FR-2, FR-3, FR-6, FR-7, FR-9, FR-12.

- **Scenario 2: Caretaker Configuration** — Maria (caretaker) customizes THEIA settings for her son Stevie to support his independence. She accesses caretaker mode and configures app settings based on Stevie's needs: sets audio guidance to step-based instructions, adjusts voice volume, enables route preferences to avoid stairs, sets up emergency contacts (Maria as primary, roommate as secondary), and inputs frequent destinations (classroom buildings, library, dining hall). When Stevie uses THEIA, the app is already customized to work the way he needs it. Addresses FR-8, FR-14.

- **Scenario 3: Emergency Fall Detection and Response** — Stevie falls and his phone flies away. THEIA's fall detection activates using the phone's internal gyroscope. After 10 seconds with no movement, THEIA provides an audio prompt: "Are you okay? Say YES if you need help." Stevie responds "YES". THEIA asks if he can move or needs help locating his phone. Stevie replies "NO", triggering THEIA to automatically call 911 with precise location data ("Engineering Building, Floor 2, near Room 215"), provide Stevie's information and Maria's contact to emergency services, call Maria, and send a text message with his exact location. Emergency responders receive exact location and dispatch directly to the right building and floor, reducing response time to under 5 minutes. Addresses FR-10, FR-11, FR-12.

## Core Features
- Setup & Preferences: consent, voice/haptic toggles; accessibility prefs (Avoid Stairs/Trips).
- Accessible UI: large targets; high contrast; screen-reader semantics; gestures (two-finger double-tap back; three-finger triple-tap emergency).
- Voice Interaction: TTS guidance/confirmations; optional offline STT; fallback text input.
- Touch Fallback: destination input + "Set"; route carousel with accessibility badges.
- Sensor Heuristic: accelerometer sampling; configurable thresholds; inactivity window.
- Alert Workflow: prompt "Are you okay?" → countdown → local notification → audit entry; manual emergency and cancel.
- Routing Stub: present multiple route options honoring preferences; no maps/IPS.
- Non-Accessible Notice: clear message when no accessible route is available.
- Notifications: local-only; actionable return to app.
- Audit Log: append-only events; encrypted at rest; view and clear non-PHI data.
- Traceability Hooks: Docs screen mapping Goal ↔ Requirement ↔ Process ↔ Component, linking to OneDrive files.

## Screens & Flows
- Home: voice activation panel; destination scroller; status panel (sensor state, last event); favorites (optional).
- Route Select: route carousel; accessibility badges; voice shortcut; double-tap select; back via two-finger double-tap.
- Navigation: spoken instruction updates; manual "Read Location"; emergency reminder banner.
- Emergency Alert: 3-second countdown; actions "I'm OK" / "Need Help"; local notification on timeout; audit entries; cancel.
- Settings: consent, voice/haptics, accessibility prefs; favorites; audit log viewer; clear data; HIPAA disclaimer view.
- Docs/Traceability: static screen referencing `OneDrive_2025-11-20` (KAOS/NFR, IDEF0, WRS) with example trace links.

## Acceptance Criteria
- Functional demo runs; fall detection (S1) works end-to-end with notification and logging.
- IDEF0 references present via Docs screen and/or screenshots.
- KAOS/NFR artifacts referenced; trace mapping shown in-app.
- HIPAA consent/disclaimer flow present; mic/sensor access gated.
- Export stubs for WRS/Process Spec with updating log section.

## Flutter Packages
- Sensors: `sensors_plus` — accelerometer stream.
- Voice: `flutter_tts` — TTS; `speech_to_text` — offline STT where supported.
- Notifications: `flutter_local_notifications` — local alerts.
- Permissions: `permission_handler` — runtime prompts.
- Secure Storage: `flutter_secure_storage` — encrypted preferences.
- Audit Log: `sqflite` + `path_provider` — local DB; `uuid` — event IDs.
- State: `provider` (or `riverpod`) — app state.
- Utility: `intl` — timestamps/localization.

Install:
```powershell
cd app
flutter pub add sensors_plus flutter_tts speech_to_text flutter_local_notifications permission_handler flutter_secure_storage sqflite path_provider uuid provider intl
```

## Data & Entities
- SensorEvent(accelX,Y,Z,t), Rule(thresholds), DetectionResult.
- AuditEvent(id, type, ts, details_redacted).
- Preferences(consent, voice/haptics, avoid_stairs/trips).
- Document & DocumentRevision (updating log entries; export stubs).
- TraceLink(type: Goal↔Req, Req↔Process, Process↔Component).

## Privacy & HIPAA
- Mic/sensors off by default; explicit consent required.
- Redact PHI in logs; encrypted at rest; offline-only.
- Clear local data action; disclaimer screen accessible from Settings.

## Integration Plan (into current `lib/main.dart`)
- Services:
  - `voice_service.dart` — TTS/STT with consent checks.
  - `sensor_service.dart` — accelerometer stream + fall heuristic.
  - `notification_service.dart` — local notifications.
  - `storage_service.dart` — secure settings + audit log.
  - `trace_service.dart` — map UI flows to OneDrive artifacts.
- UI:
  - Add `SettingsScreen`, `DocsScreen`, `AuditLogScreen`.
  - Wire navigation from Home; reuse existing `MultiFingerGestureDetector` and screens.
  - Add accessibility semantics labels across widgets.

## Demo Script
1) Home: enable consent; set destination by voice; confirm TTS; check audit entry.
2) Route Select: review accessibility badges; select route; log selection.
3) Navigation: hear guidance; manual readback; emergency banner.
4) Emergency: simulate fall (test toggle or motion); countdown; choose action or let timeout; local notification; audit log.
5) Docs: open traceability screen; show KAOS/NFR/IDEF0 references.
6) Settings: show disclaimer; audit viewer; clear local data.
