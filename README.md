# NovaWallet Mobile 🚀

A production-grade, highly resilient fintech mobile application built in Flutter with Clean Architecture, offline-first synchronization, precise integer financial arithmetic, and complete TalkBack/VoiceOver accessibility support.

---

## 🏗️ Architecture Overview

NovaWallet Mobile adheres strictly to **Clean Architecture** principles with clear separation of concerns across layers and features:

```
lib/
├── core/
│   ├── constants/             # Global app, storage, and route constants
│   ├── di/                    # Dependency Injection (GetIt service locator)
│   ├── error/                 # Failure and Result type definitions
│   ├── money/                 # Money value object (integer kobo representation)
│   ├── network/               # Connectivity monitor & network abstraction
│   ├── routing/               # Centralized named route generator
│   ├── storage/               # Secure storage abstraction (flutter_secure_storage)
│   ├── sync/                  # Standalone, feature-agnostic offline sync engine
│   │   ├── data/              # SQLite database helper & queue repository
│   │   └── domain/            # QueuedAction entity & repository interface
│   └── theme/                 # Design tokens, typography, and dark/light themes
│
└── features/
    ├── wallet_home/           # Dashboard: balance, quick actions, lazy transaction feed
    ├── send_money/            # 3-step NIP bank transfer flow with idempotency protection
    └── nova_save/             # Target savings vaults with integer progress calculation
```

### Layer Responsibilities
- **Domain Layer**: Contains pure business rules, entities (`Money`, `QueuedAction`, `SavingsGoal`, `Transaction`), repository interfaces, and UseCases. Zero dependencies on Flutter UI or database frameworks.
- **Data Layer**: Implements repository contracts, handles SQLite persistence (`sqflite`), interacts with remote backend rails, and serializes DTO models.
- **Presentation Layer**: UI widgets, screens, and state notifiers (`ChangeNotifier`). All formatting (`formatToNaira()`) happens strictly in the UI layer.

---

## ⚡ State Management Choice & Rationale

NovaWallet Mobile uses **Provider** with **`ChangeNotifier`** alongside **`GetIt`** for dependency injection.

### Why Provider?
1. **Predictable Unidirectional Data Flow**: State mutations occur solely within provider methods (`SendMoneyProvider`, `WalletHomeProvider`, `NovaSaveProvider`), keeping UI widgets declarative and thin.
2. **Explicit Lifecycle & Scoping**: Eliminates complex reactive stream subscriptions in UI code while maintaining tight control over widget rebuild scopes via `Consumer` and `Selector`.
3. **Seamless Testability**: Providers receive pure UseCases via dependency injection, allowing unit and widget tests to inject mock UseCases without spinning up full service graphs.
4. **Lightweight & Idiomatic**: Recommended by the Flutter team for maintainability and minimal cognitive overhead.

---

## 🔄 Offline & Synchronization Engine

NovaWallet implements a robust, feature-agnostic **Offline Action Queue** in `core/sync`:

```
User Action (Offline)
        │
        ▼
   SyncEngine ───► SQLite Persistent Queue (ActionStatus.pending)
        │
   [App Killed / Restarted] ──► Startup Crash Recovery (converts "sending" -> "pending")
        │
   Network Reconnected
        │
        ▼
   SyncEngine (Replay Loop)
        ├── 1. Mark status "sending" in SQLite
        ├── 2. Execute Feature Handler via Network Rail (with Idempotency-Key)
        └── 3. On Success: Mark "sent" & delete from SQLite Queue
```

### Key Reliability Guarantees:
- **Crash Recovery & Exactly-Once Replay**: If the application terminates while an action is in the `sending` state, `SyncEngine.init()` on startup converts all `sending` entries back to `pending`. Because each user attempt is tagged with a single immutable UUID `idempotencyKey`, the backend rail safely deduplicates replays.
- **Persistent SQLite Storage**: The queue is persisted using `sqflite` (never `SharedPreferences`), ensuring complete durability across app restarts and device reboots.
- **Immediate User Feedback**: When offline, the UI provides instantaneous status badges (`"Pending — will send when back online"`) without displaying network failure popups or spinner hangs.

---

## 💰 Monetary Integrity & Precision

Floating-point representations (`double`, `float`) introduce IEEE-754 rounding drift that is unacceptable in financial software.

- **Integer Kobo Representation**: All amounts throughout domain, data, and sync layers are encapsulated in the `Money` value object storing kobo as an `int` (1 Naira = 100 Kobo).
- **Integer Progress Math**: In Nova Save, goal progress percentages are computed exclusively via pure integer arithmetic:
  $$\text{percentage} = \lfloor \frac{\text{savedKobo} \times 100}{\text{targetKobo}} \rfloor$$
- **Display-Only Formatting**: Naira currency symbols (₦) and 2-decimal formatting are applied exclusively in presentation formatters.

---

## ♿ Accessibility & Responsive Typography

- **TalkBack & VoiceOver Compliance**: All interactive elements, icons, balances, and progress bars are wrapped in `Semantics` widgets with descriptive labels, roles, and values.
- **Dynamic Text Scaling (1.0x, 1.3x, 2.0x)**: Layouts are built with flexible containers (`Wrap`, `Flexible`, `FittedBox`) to eliminate `RenderFlex` pixel overflows at accessibility font scales up to 2.0x.

---

## 🔒 Security & Credential Protection

- **Secure Storage Guarantee**: Sensitive tokens, biometric flags, and authentication credentials are strictly routed through `SecureStorageService` backed by `flutter_secure_storage` (iOS Keychain / Android EncryptedSharedPreferences).
- **Automated Security Guard Tests**: An automated static analysis test (`test/core/storage/secure_storage_audit_test.dart`) audits the entire codebase to fail the build if `SharedPreferences` is ever imported or used for keys/tokens.

---

## 🧪 Testing & Verification

The test suite includes unit tests, widget tests, font scaling sweeps, accessibility tree audits, and top-level integration tests:

### Running Tests
```bash
# Run all automated tests
flutter test

# Run the top-level offline -> restart -> reconnect integration test
flutter test test/integration/app_offline_sync_integration_test.dart

# Run font scaling and TalkBack/VoiceOver semantics sweep
flutter test test/core/accessibility/font_scale_and_semantics_sweep_test.dart

# Run security and secure storage audit test
flutter test test/core/storage/secure_storage_audit_test.dart

# Run static analysis and lint checks
flutter analyze
```

---

## 📱 Environment & Targets

- **Flutter SDK**: `>=3.24.0` / Flutter 3.x
- **Dart SDK**: `^3.12.2`
- **Supported Platforms**: Android (API 21+), iOS (iOS 13.0+)
