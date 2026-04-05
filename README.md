# MyRekod_FinHealth 📊

**Mobile-Based Financial Formalization Tool for Malaysian Micro-SMEs & Hawkers**

Built with **Flutter** (Frontend) + **Firebase** (Backend-as-a-Service) + **Google ML Kit** (On-Device AI)

## 📑 Table of Contents

  * [Project Overview & FYP Scope](https://www.google.com/search?q=%23-project-overview--fyp-scope)
  * [Core Functional Specifications](https://www.google.com/search?q=%23-core-functional-specifications)
  * [Project Structure](https://www.google.com/search?q=%23-project-structure)
  * [Prerequisites](https://www.google.com/search?q=%23-prerequisites)
  * [Getting Started (Local Environment)](https://www.google.com/search?q=%23-getting-started)
  * [Firebase Setup (Backend)](https://www.google.com/search?q=%23-firebase-setup-backend)
  * [State Management & Theming](https://www.google.com/search?q=%23-state-management--theming)
  * [Git Workflow](https://www.google.com/search?q=%23-git-workflow)
  * [Tech Stack](https://www.google.com/search?q=%23-tech-stack)
  * [Common Issues](https://www.google.com/search?q=%23-common-issues)

-----

\<a id="-project-overview--fyp-scope"\>\</a\>

## 🎯 Project Overview & FYP Scope

MyRekod is designed to bridge the digital gap for informal workers (B40 hawkers, night market traders, freelancers) transitioning into Malaysia's formalized tax and e-invoicing economy.

To cater to low-end devices and areas with unstable internet (e.g., night markets), the application operates on a strict **Offline-First Architecture**.

### Key FYP Modules (Use Cases)

| Module | Description | Complexity |
|--------|-------------|------------|
| **UC-01: Onboarding** | Digital identity creation capturing Business Name, TIN, and Entity Type with local offline syntax validation. | Low |
| **UC-03: Expense OCR** | Camera integration utilizing quantized on-device AI to auto-extract Date, Vendor, and Amount from physical receipts with zero latency. | **Hard** |
| **UC-05: Record Sale** | A brutally minimalist 3-field form (Customer, Item, Price) hiding accounting jargon from the user. | Medium |
| **UC-06: LHDN E-Invoice** | Auto-generates the compliant 55-field JSON payload. Simulates API submission to return a mock validation QR Code. Supports deferred offline submission. | **Hard** |
| **UC-07: Dashboard** | Aggregates local data to calculate a gamified "Business Health Score" providing immediate cash-flow visibility. | Medium |

-----

\<a id="-core-functional-specifications"\>\</a\>

## ⚙️ Core Functional Specifications

To effectively manage the realities of Micro-SME operations, this system implements several specialized architectural logic flows:

### 1\. Dual-Status Transaction Tracking

Transactions track two completely independent lifecycles:

  * **Commercial Status (`Paid` / `Pending Payment`):** Tracks physical cash flow (Has the customer handed the hawker the money?).
  * **Compliance Status (`Valid` / `Pending Submission`):** Tracks LHDN API interaction (Has the JSON payload been sent to the government?).
  * *Benefit:* Allows a user to record a `Paid` cash sale offline, while keeping the compliance status `Pending Submission` until WiFi is restored.

### 2\. On-Device OCR Extraction (Privacy First)

Receipt scanning uses **Google ML Kit**. The image processing model is downloaded to the device, meaning financial data is parsed locally. Receipt images are never sent to a third-party server, ensuring compliance with strict data privacy principles and zero-latency performance.

### 3\. Radical Accessibility (HCI)

The UI adheres to the **Luminescent Vault (Accessible Edition)** `design.md` principles. Target touch areas strictly exceed 48x48dp (Fitts's Law), typography is strictly 16sp minimum, and color themes default to high-contrast Dark/Light modes based on system settings to combat screen glare.

-----

\<a id="-project-structure"\>\</a\>

## 📁 Project Structure

```text
myrekod/
├── android/               ← Native Android configuration
├── ios/                   ← Native iOS configuration
├── lib/                   ← Main Flutter codebase
│   ├── core/              ← Global configurations (constants, themes, design.md rules)
│   ├── models/            ← Data objects (User, Transaction, Receipt)
│   ├── providers/         ← State Management (Auth, HealthScore logic)
│   ├── screens/           ← UI Pages (Dashboard, Sales Form, Scanner)
│   ├── services/          ← Business Logic (Firebase APIs, LHDN Payload Builder, OCR)
│   ├── widgets/           ← Reusable UI components (Massive Buttons, Custom Cards)
│   └── main.dart          ← Application entry point
├── assets/                ← Local images, fonts, and localization dictionaries
├── pubspec.yaml           ← Project dependencies (Packages)
└── README.md
```

-----

\<a id="-prerequisites"\>\</a\>

## 🛠️ Prerequisites

Ensure you have the following installed before opening the project:

| Tool | Purpose | Download |
|------|---------|----------|
| **Flutter SDK** (v3.24+) | Core framework | [flutter.dev](https://www.google.com/search?q=https://docs.flutter.dev/get-started/install) |
| **Antigravity / Cursor / VS Code** | AI-assisted IDE | Based on developer preference |
| **Git** | Version Control | [git-scm.com](https://git-scm.com) |
| **Android Studio** | Android Emulator & Build Tools | [developer.android.com](https://www.google.com/search?q=https://developer.android.com/studio) |
| **Xcode** *(Mac Only)* | iOS Simulator & Build Tools | Mac App Store |

-----

\<a id="-getting-started"\>\</a\>

## 🚀 Getting Started (Local Environment)

### 1\. Clone the Repository

Open your IDE's terminal and clone the repository:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/MyRekod-FYP.git
cd MyRekod-FYP
```

### 2\. Install Dependencies

Fetch all required Flutter packages defined in `pubspec.yaml`:

```bash
flutter pub get
```

### 3\. Run the Application

Start the Android/iOS emulator, or connect a physical device via USB/Wi-Fi debugging, then run:

```bash
flutter run
```

*Note: To force the Impeller rendering engine for smooth 60fps performance on budget Android devices, run `flutter run --enable-impeller`.*

-----

\<a id="-firebase-setup-backend"\>\</a\>

## 🔥 Firebase Setup (Backend)

This project does not use a traditional local backend (like Node.js or .NET). It connects directly to Google Cloud Firebase.

**IMPORTANT: Configuration Files**
To connect the app to the database, you must place the secure Firebase configuration files into the project. *These files are `.gitignore`d and must be obtained from the project lead/Firebase Console.*

1.  **Android:** Place `google-services.json` inside the `android/app/` directory.
2.  **iOS:** Place `GoogleService-Info.plist` inside the `ios/Runner/` directory via Xcode.

### Configured Firebase Services

| Service | Purpose |
|---------|---------|
| **Authentication** | Secure Token Storage, user login management. |
| **Firestore** | NoSQL database storing User Profiles, Invoices, and App Settings. Supports Offline Optimistic Concurrency. |
| **Storage** | (Optional Phase 2) Cloud storage for scanned receipt images. |
| **Crashlytics** | (System Admin UC-12) Monitors OCR failures and app crashes remotely. |

-----

\<a id="-state-management--theming"\>\</a\>

## 🎨 State Management & Theming

### State Management (`Provider`)

We use `Provider` to manage application state globally. For example, the `Business Health Score` recalculates dynamically across screens without needing to pass variables manually:

```dart
// Accessing the score globally
final healthScore = Provider.of<FinancialProvider>(context).currentScore;
```

### Theming (`design.md`)

The app utilizes a centralized `ThemeData` class located in `lib/core/theme.dart`.

  * Never hardcode colors like `Colors.purple` inside individual screens.
  * Always use theme extensions: `Theme.of(context).colorScheme.primary` to ensure the Dark/Light mode toggle functions flawlessly across the entire application.

-----

\<a id="-git-workflow"\>\</a\>

## 🌿 Git Workflow

We use a strict feature-branching workflow to protect the `main` codebase.

```bash
# 1. Pull the latest code before starting
git pull origin main

# 2. Create a new branch for your feature
git checkout -b feature/uc05-sales-form

# 3. Add and commit your changes
git add .
git commit -m "feat: complete 3-field sales UI"

# 4. Push your branch to GitHub
git push -u origin feature/uc05-sales-form
```

**Commit Message Format:**

  * `feat:` A new feature or UI screen.
  * `fix:` A bug fix.
  * `refactor:` Code cleanup without changing behavior.
  * `docs:` Updating this README or specifications.

-----

\<a id="-tech-stack"\>\</a\>

## 💻 Tech Stack Summary

| Component | Technology Choice | Justification for Malaysian Context |
|-----------|-------------------|--------------------------------------|
| **Frontend** | Flutter (Dart) | Impeller engine ensures 60fps on budget Androids (B40 demographic). |
| **Database** | Firebase Firestore | Native SDK supports Optimistic Concurrency (Works 100% offline). |
| **Authentication**| Firebase Auth | Offloads identity management to secure Google infra. |
| **AI / OCR** | Google ML Kit | Zero-latency receipt scanning offline; financial data never leaves the device. |
| **State Mgt.** | Provider | Efficient calculation of Business Health Score across all screens. |

-----

\<a id="-common-issues"\>\</a\>

## ⚠️ Common Issues

**`CocoaPods not installed or not in valid state` (Mac Only)**
→ Run `sudo gem install cocoapods` followed by `pod install` inside the `ios` directory.

**Firebase connection error / `No Firebase App '[DEFAULT]' has been created`**
→ Ensure you placed `google-services.json` or `GoogleService-Info.plist` in the correct folders and that `await Firebase.initializeApp()` is called in `main.dart`.

**`A dependency error occurred / Version solving failed`**
→ A package in `pubspec.yaml` is out of date. Run `flutter pub outdated` and `flutter pub upgrade`.

**UI renders perfectly but data isn't saving**
→ Check if your emulator has internet access, OR verify that your Firestore security rules (`allow read, write: if request.auth != null;`) are properly configured.

-----

### 📞 Questions?

For documentation or specification clarifications, refer to the **Investigation Report (Phase 1)** and **Use Case Specifications Document**.
