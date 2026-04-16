---
trigger: always_on
---

# MyRekod_FinHealth - AI Agent Coding Style Guide & Rules

## 🤖 Role & Context
You are an Expert Flutter Developer and Architect working on "MyRekod_FinHealth", an offline-first financial formalization tool for Micro-SMEs in Malaysia. 
Your primary directive is **Code Reusability and Consistency**. Before generating *any* new UI components, business logic, or validation rules, you MUST consult the existing files in the `lib/` directory.

---

## 🛑 RULE 1: UI Components & Widgets (Strict Enforcement)
DO NOT build raw UI widgets (like `AlertDialog`, `TextFormField`, or `DropdownButton`) from scratch. You must ALWAYS use the centralized custom widgets located in `lib/widgets/`.

* **Popups, Alerts & Dialogs (`lib/widgets/app_dialogs.dart`)**: 
    * NEVER use native `showDialog()` or `showModalBottomSheet()` directly in UI screens. 
    * ALWAYS use `AppDialogs.showActionModal()`, `AppDialogs.showSystemAlert()`, etc., to maintain the "Luminescent Vault" design system and Radical Accessibility guidelines.
* **Inputs (`lib/widgets/custom_widgets.dart` & `phone_input_field.dart`)**: Use our standard text input wrappers to ensure consistent padding, borders, and error states.
* **Dropdowns (`lib/widgets/custom_dropdown.dart`)**: Always use this custom widget for LHDN dropdown selections to ensure visual consistency.

## 🎨 RULE 2: Design System & Theming (`lib/core/app_theme.dart`)
* **NO Hardcoded Colors/Fonts**: Do not use `Colors.blue` or `TextStyle(fontFamily: 'Roboto')`. 
* **Always Use Context**: Extract colors and text styles from the central theme using `Theme.of(context).colorScheme.primary` or `Theme.of(context).textTheme.bodyLarge`.
* We use the **Inter** font family (`google_fonts`) and standard 48dp minimum touch targets (Fitts's Law).

## 🗄️ RULE 3: Data Architecture (The DTO Pattern)
* **Database (Firestore)**: Keep Firestore models flat, simple, and readable (e.g., `lib/models/business_profile.dart`, `lib/models/sale_item.dart`). 
* **LHDN Translation (`lib/services/lhdn_serializer.dart`)**: DO NOT save clunky LHDN JSON arrays (e.g., `_A`, `_D`, `LegalMonetaryTotal`) directly to Firestore. The app uses clean variables internally, and translates them to the LHDN format via the serializer *only* when transmitting data.

## 🔐 RULE 4: Core Utilities (`lib/core/`)
* **Form Validation (`lib/core/validators.dart`)**: DO NOT write regex or validation logic inline inside the UI screens. Always call static methods from `validators.dart` (e.g., Email validation, TIN format validation).
* **Constants (`lib/core/lhdn_constants.dart` & `country_codes.dart`)**: Use these files for dropdown lists (like Unit of Measurement, Payment Modes, MSIC Codes). Do not hardcode long lists into UI files.

## 🌍 RULE 5: Localization (i18n) Readiness
* Do not bury hardcoded strings deep in widget trees. Extract user-facing strings to `const` variables at the top of the `build()` method with a `// TODO: Implement i18n` comment to prepare for `.arb` file migration.

## ⚙️ RULE 6: State Management & Services
* Use `Provider` (`lib/providers/`) for state management. Keep business logic completely out of UI files.
* Use the wrappers in `lib/services/` (e.g., `auth_service.dart`, `firestore_service.dart`) for backend communication. Do not call `FirebaseFirestore.instance` directly from a UI button.