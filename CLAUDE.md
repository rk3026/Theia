# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Theia is a mobile application designed to help visually impaired users navigate indoors. Built with Flutter, the app supports iOS, Android, macOS, and web platforms.

## Project Documentation

Key project documents are located in the `Docs/` directory:
- `Prelim1_Project-Plan_Rough-Draft.pdf` - Initial project plan
- `Meeting-Notes_Prelim1-Rough-Draft.pdf` - Meeting notes from preliminary planning

## Development Commands

All commands should be run from the `app/` directory.

### Setup
```bash
flutter pub get              # Install dependencies
```

### Running the Application
```bash
flutter run                  # Run on connected device/emulator
flutter run -d <device_id>   # Run on specific device
flutter run -d chrome        # Run in Chrome browser
flutter devices              # List available devices
```

### Testing
```bash
flutter test                 # Run all tests
flutter test test/widget_test.dart  # Run specific test file
```

### Code Quality
```bash
flutter analyze              # Run static analysis (configured via analysis_options.yaml)
flutter format .             # Format all Dart files
flutter format lib/          # Format only lib directory
```

### Building
```bash
flutter build apk            # Build Android APK
flutter build appbundle      # Build Android App Bundle
flutter build ios            # Build iOS app (requires macOS)
flutter build web            # Build web version
flutter build macos          # Build macOS app (requires macOS)
```

### Cleaning
```bash
flutter clean                # Remove build artifacts
flutter pub get              # Reinstall dependencies after clean
```

## Code Architecture

### Project Structure
- `lib/main.dart` - Entry point; contains MyApp (root widget) and MyHomePage (sample stateful widget)
- `test/` - Widget and unit tests
- `pubspec.yaml` - Dependencies and app configuration
- `analysis_options.yaml` - Lint rules using flutter_lints package

### Current State
The app currently contains Flutter's default counter demo template. This will be replaced with Theia's indoor navigation features.

### Flutter Conventions
- State management: Currently using StatefulWidget with setState (may evolve as app grows)
- Material Design is enabled via `uses-material-design: true`
- SDK version: ^3.9.2

## Accessibility Considerations

Given this project's focus on visually impaired users, all UI components should be built with accessibility in mind:
- Ensure all widgets have proper semantic labels
- Test with screen readers (TalkBack on Android, VoiceOver on iOS)
- Maintain high contrast ratios
- Support dynamic text sizing
