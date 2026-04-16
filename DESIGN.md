# Design System Specification: Editorial Finance
*(Hawker-Accessible Edition)*

---

## 1. Overview & Creative North Star

### Creative North Star: **"The Luminescent Vault"**
This design system moves away from the sterile, flat world of traditional fintech. It is built on the philosophy of **The Luminescent Vault**—an experience that feels as secure as a physical treasury but as fluid and light as modern digital ether.

### Radical Accessibility
Crucially, this premium aesthetic is engineered for **"Radical Accessibility."** The target demographic includes Micro-SME hawkers operating in fast-paced, low-connectivity environments. 

> [!IMPORTANT]
> The high-end editorial approach must prioritize maximum legibility, massive interactive targets, and zero cognitive friction.

---

## 2. Colors & Surface Philosophy

### Adaptive Themes (Dark & Light Mode)
The application must support both Dark and Light modes, automatically mirroring the user's **Device System Settings**. 

Both themes must preserve the "Luminescent Vault" aesthetic—premium, translucent, and highly readable.

### Color Palette (Material Design Mapping)
Our signature palette is rooted in deep purples and high-contrast accents, adapted for both environments.

| Role | Token | Dark Hex | Light Hex | Usage |
| :--- | :--- | :--- | :--- | :--- |
| **Primary** | `primary` | `#5A51C4` | `#5A51C4` | Primary actions and brand identity |
| **Secondary** | `secondary` | `#B6A4F3` | `#6E58B1` | Accents (Adjusted for light contrast) |
| **Tertiary** | `tertiary` | `#4E6DB4` | `#4E6DB4` | Supporting elements |
| **Surface** | `surface` | `#131319` | `#FCFBFF` | Main application background |
| **Surface Alt** | `surface_container` | `#1F1F25` | `#F2F1F9` | Card and modal surfaces |
| **Text Primary** | `on_surface` | `#FFFFFF` | `#131319` | Main text color |
| **Text Muted** | `on_surface_variant`| `#C8C4D5` | `#5A5A66` | Secondary / supporting text |

### Surface Hierarchy & Rules
*   **System Following**: The UI must dynamically switch between themes based on `prefers-color-scheme`.
*   **The "No-Line" Rule**: Boundaries must be defined through background color shifts (`surface_container` vs `surface`). Avoid borders where possible.
*   **The Glass Rule**: All floating modals use semi-transparent surface colors (80% opacity) with a **20px backdrop-blur**.
    *   In **Light Mode**, use a subtle white-tinted glass effect.
    *   In **Dark Mode**, use a deep-vault tinted glass effect.
*   **Neon Status Visibility**: Use distinct, accessible neon-tinted accents for status states:
    *   **Neon Green**: Paid / Valid (#00FF85 in Dark, #00B35D in Light)
    *   **Amber**: Pending / Warning (#FFB800)
*   **Accessibility Exception**: If a "Ghost Border" falls below WCAG AA contrast ratios, increase its opacity to ensure inputs and cards remain visible to users with declining eyesight.

---

## 3. Typography (Radical Accessibility)

Using **Inter** to bridge the gap between technical precision and human clarity. All text must pass strict high-contrast readability tests.

| Typeface | Level | Specification | Usage |
| :--- | :--- | :--- | :--- |
| **Inter** | **Display** | -2% letter spacing | Balance totals and key numbers |
| **Inter** | **Headlines** | Bold / Semantic | Clear information architecture |
| **Inter** | **Body** | **Min 16sp** | General readability; use `on_surface_variant` (#C8C4D5) |
| **Inter** | **Labels** | Med / Semi-Bold | Smallest scale; must remain legible |

---

## 4. Components & Interaction Design

### Buttons (Fitts’s Law)
> [!CAUTION]
> **Strict HCI Rule**: ALL interactive buttons, toggles, and nav items must have a minimum touch target size of **48x48dp**. There are no "small" tap targets.

*   **Primary Action**: 
    *   Gradient fill (`primary` to `primary_container`)
    *   `ROUND_TWELVE` (0.75rem) corners
    *   White or `on_primary` text
    *   Massive presence; impossible to miss.
*   **Secondary/Tertiary**: 
    *   Wide, premium "breathing" feel with large padding.

### Cards & Lists (Hick’s Law)
*   **Brutal Minimalism**: The interface must be stripped of clutter. Bottom navigation is limited to a **maximum of 3 or 4** distinct icons.
*   **Visual Separation**: Use 16px or 24px of vertical white space to separate list items. **No dividers.**
*   **Interactivity**: On tap, list items should transition from `surface` to `surface_container_low`.

### Input Fields (Recognition Over Recall)
*   **Icon Pairing**: Pair all input fields with universal, highly recognizable icons (e.g., a "Scan" icon next to OCR buttons).
*   **Default State**: `surface_container_highest` background, `ROUND_TWELVE` corners.
*   **Active State**: A subtle high-contrast highlight on the bottom edge using the `primary` token.

---

## 5. HCI & Usability Checklist

Every generated screen must adhere to these core principles:

- [ ] **Adaptive Theme**: Supports both Dark and Light modes, following system preference.
- [ ] **Radical Accessibility**: Hyper-legible typography (Min 16sp) and high contrast against both Dark (#131319) and Light (#FCFBFF) backgrounds.
- [ ] **Fitts's Law**: Massive, single-tap buttons (Min 48dp). No complex swiping or tiny dropdowns.
- [ ] **Hick’s Law**: Brutal minimalism. Hide complex accounting data; prioritize 3-field forms for sales.
- [ ] **Recognition Over Recall**: Universal iconography paired with all primary actions.
- [ ] **System Status Visibility**: High-contrast status badges (Pending vs. Paid) must be immediately visible on all transaction cards.

---

## 6. Premium Interactive Components

To maintain the "Luminescent Vault" premium feel while ensuring radical accessibility, we use specialized custom components for core interactions.

### Custom Premium Dropdown (`CustomPremiumDropdown`)
*   **Surface**: Uses `surface_container` with semi-transparent primary border (10% opacity).
*   **Menus**: All dropdown menus must have `AppTheme.radiusLarge` corners and high-elevation shadows (12dp).
*   **Searchability**: For lists exceeding 10 items (e.g., MSIC, State), a search bar must be integrated into the menu.
*   **Interactivity**: Selected items use a subtle 8% `primary` background highlight to guide the eye.

### Phone Input Field (`PhoneInputField`)
*   **Country Selector**: Integrated prefix showing the flag (Emoji) and dial code.
*   **Searchable Picker**: Tapping the country prefix opens a searchable bottom sheet with `radiusXLarge` corners.
*   **Feedback**: Proper focused states using the `primary` token with a 1.5px border.

---

## 7. Interruption Architecture Surfaces

To guarantee users never feel trapped and to retain consistency in popups, we use 4 primary layouts built on top of `AppDialogs`:

### Modal & Sheet Principles
*   **Surface Consistency**: Popups must use the theme's `surface` color with `radiusXLarge` (24px) corners to distinguish themselves from embedded `surface_container` cards.
*   **The "Ease of Exit" Rule**: All non-destructive bottom sheets *must* be dismissible by tapping the outer blurred background (scrim).
    *   *Exception*: Action Modals covering data destruction (e.g. Delete Record) or System Requirements MUST disable background tap dismissal.
*   **Decorative Graphics (Vector-less)**: Complex graphics (glows, auras) must be built programmatically using standard Flutter `Icons`, stacked inside `Containers` with `BoxShadows` to ensure 60fps rendering without external payload bloat like SVGs.
*   **Interaction Decoupling**: All navigation and business logic within Modals must be decoupled from the UI using `VoidCallback` arguments.