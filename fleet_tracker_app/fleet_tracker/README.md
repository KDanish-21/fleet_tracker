# Fleet Tracker — Flutter Mobile App

GPS Fleet Tracking mobile application for Android & iOS.  
Points directly at the existing FastAPI backend at `https://fleet-tracker-5od4.onrender.com/api`.

---

## Folder Structure

```
fleet_tracker/
├── lib/
│   ├── main.dart                          # App entry point
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart         # API URL, route names, storage keys
│   │   ├── theme/
│   │   │   └── app_theme.dart             # Colors, text styles, dark theme
│   │   ├── network/
│   │   │   ├── dio_client.dart            # Dio HTTP instance (Riverpod provider)
│   │   │   ├── auth_interceptor.dart      # JWT Bearer token injection
│   │   │   └── api_failure.dart           # Typed failure classes
│   │   └── utils/
│   │       ├── secure_storage.dart        # flutter_secure_storage wrapper
│   │       ├── date_utils.dart            # Date formatting helpers
│   │       └── app_router.dart            # go_router config + auth guard
│   │
│   ├── data/
│   │   ├── models/
│   │   │   └── models.dart                # UserModel, VehicleModel, PositionModel,
│   │   │                                  # TripRecord, AlarmRecord, FuelRecord
│   │   └── repositories/
│   │       ├── auth_repository.dart       # Login, register, logout, cache
│   │       ├── vehicle_repository.dart    # Vehicles list, live positions
│   │       └── reports_repository.dart    # Trips, alarms, fuel API calls
│   │
│   └── presentation/
│       ├── splash_screen.dart             # Animated logo splash
│       ├── shell_screen.dart              # Bottom nav shell
│       ├── auth/
│       │   ├── login/login_screen.dart    # Email + password login
│       │   └── register/register_screen.dart
│       ├── dashboard/
│       │   └── dashboard_screen.dart      # Live stats + recent activity
│       ├── vehicles/
│       │   └── vehicles_screen.dart       # Searchable vehicle list with filter
│       ├── map/
│       │   └── map_screen.dart            # OpenStreetMap live tracking
│       ├── reports/
│       │   ├── trips/trips_screen.dart    # Trip report with date picker
│       │   ├── alarms/alarms_screen.dart  # Alarm report multi-vehicle
│       │   └── fuel/fuel_screen.dart      # Fuel report + bar chart
│       ├── profile/
│       │   └── profile_screen.dart        # User info + logout
│       └── widgets/
│           └── app_widgets.dart           # StatCard, StatusBadge, ShimmerCard, etc.
│
├── android/
│   └── app/src/main/AndroidManifest.xml  # Internet + location permissions
├── ios/
│   └── Runner/Info.plist                  # Location usage strings
├── pubspec.yaml                           # All dependencies
└── analysis_options.yaml
```

---

## Setup & Run

### 1. Prerequisites
- Flutter SDK ≥ 3.0.0  
  ```bash
  flutter --version
  ```
- Android Studio / Xcode (for emulators)

### 2. Clone & Install
```bash
cd fleet_tracker
flutter pub get
```

### 3. Run
```bash
# Android
flutter run

# iOS (Mac only)
flutter run -d iphone

# Specific device
flutter devices
flutter run -d <device-id>
```

### 4. Build release APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### 5. Build iOS IPA (Mac only)
```bash
flutter build ipa --release
```

---

## Backend API

All calls go to: `https://fleet-tracker-5od4.onrender.com/api`

| Endpoint | Method | Auth |
|---|---|---|
| `/auth/register` | POST | No |
| `/auth/login` | POST | No |
| `/auth/me` | GET | Bearer |
| `/vehicles/` | GET | Bearer |
| `/location/live` | GET | Bearer |
| `/location/live/{id}` | GET | Bearer |
| `/reports/trips` | POST | Bearer |
| `/reports/alarms` | POST | Bearer |
| `/reports/fuel` | POST | Bearer |

---

## Key Libraries

| Library | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `go_router` | Navigation + auth guard |
| `dio` | HTTP client |
| `flutter_secure_storage` | JWT token storage |
| `flutter_map` + `latlong2` | OpenStreetMap live tracking |
| `fl_chart` | Fuel bar chart |
| `shimmer` | Loading skeleton UI |
| `intl` | Date formatting |
| `dartz` | Either type for error handling |

---

## Features

- **Login / Register** — JWT auth stored securely, persists across sessions
- **Dashboard** — Live fleet stats with 10s auto-polling, greeting by time of day
- **Vehicles** — Searchable list with moving/idle/offline filter chips
- **Live Map** — OpenStreetMap with real-time vehicle markers (tap for details)
- **Trip Report** — Per-vehicle, date range, distance + speed stats
- **Alarm Report** — Multi-vehicle, categorized alarm types with color coding
- **Fuel Report** — Multi-vehicle, total usage summary + bar chart
- **Profile** — Account info, app settings, logout with confirmation

---

## Customization

Change the backend URL in `lib/core/constants/app_constants.dart`:
```dart
static const String baseUrl = 'https://fleet-tracker-5od4.onrender.com/api';
```

Change the poll interval (default 10s):
```dart
static const int pollIntervalSeconds = 10;
```
