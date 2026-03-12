# Swift Native Frontend Migration

This branch starts the macOS-native frontend migration while keeping the Python/FastAPI backend contract unchanged.

## Goals

- Replace the Tauri + React frontend with a native Swift frontend.
- Support macOS 11 and newer.
- Keep the existing `/api/*` REST and `/api/ws/alerts` WebSocket contracts unchanged.
- Migrate window behavior into a native `SwiftUI + AppKit` shell.

## Current Scaffold

- `native-ui/Package.swift`: Swift Package entry point for the native app scaffold.
- `native-ui/Sources/ClassFoxNative/Services/BackendAPIClient.swift`: REST client for the existing backend endpoints.
- `native-ui/Sources/ClassFoxNative/Services/AlertWebSocketClient.swift`: WebSocket alert client with reconnect and heartbeat.
- `native-ui/Sources/ClassFoxNative/ViewModels/AppViewModel.swift`: Global app state for monitoring, settings, alerts, and window mode.
- `native-ui/Sources/ClassFoxNative/Windowing/WindowCoordinator.swift`: Floating transparent window configuration and dynamic size changes.
- `native-ui/Sources/ClassFoxNative/Views/*`: Initial native UI for the compact toolbar, alert banner, and settings editor.

## Next Steps

1. Add parity panels for rescue, catch-up, start-monitor flow, and file upload.
2. Replace the temporary inline settings editor with structured forms matching the current React panel.
3. Move release-only backend bootstrapping from Tauri/Rust into the native macOS app launcher.
4. Add an Xcode project or workspace once the Swift package surface stabilizes.
