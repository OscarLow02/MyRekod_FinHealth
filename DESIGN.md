# Design System Specification: Editorial Finance
*(Hawker-Accessible Edition)*

---

## 1. Overview & Creative North Star

### Creative North Star: **"The Luminescent Vault" & "Luminous Ledger"**
This design system moves away from the sterile, flat world of traditional fintech. It is built on two core philosophies:
* **Luminescent Vault (Dark Mode):** Optimized for low-light environments (night markets) with high-emphasis white text on deep charcoal backgrounds. Feels as secure as a physical treasury but fluid and modern.
* **Luminous Ledger (Light Mode):** Focused on outdoor legibility with off-white surfaces and near-black text for maximum contrast under the sun.

### Radical Accessibility
Crucially, this premium aesthetic is engineered for **"Radical Accessibility."** The target demographic includes Micro-SME hawkers operating in fast-paced, low-connectivity environments. 

> [!IMPORTANT]
> The high-end editorial approach must prioritize maximum legibility, massive interactive targets, and zero cognitive friction. Brand Continuity is anchored by the **Luminous Purple (#5A51C4)** across both themes.

---

## 2. Colors & Surface Philosophy

### Adaptive Themes
The application must support both Dark and Light modes, automatically mirroring the user's **Device System Settings**. 

### Color Palette (Material Design Mapping)
Our signature palette is rooted in deep purples and high-contrast accents.

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
* **The "No-Line" Rule**: Boundaries must be defined through background color shifts (`surface_container` vs `surface`). Avoid borders where possible.
* **The Glass Rule**: All floating modals use semi-transparent surface colors (80% opacity) with a **20px backdrop-blur**.
    * In **Light Mode**, use a subtle white-tinted glass effect.
    * In **Dark Mode**, use a deep-vault tinted glass effect.
* **Neon Status Visibility**: Use distinct, accessible neon-tinted accents for status states:
    * **Neon Green**: Paid / Valid (#00FF85 in Dark, #00B35D in Light)
    * **Amber**: Pending / Warning (#FFB800)

---

## 3. Typography (Radical Accessibility)

Using **Inter** to bridge the gap between technical precision and human clarity. 

| Typeface | Level | Specification | Usage |
| :--- | :--- | :--- | :--- |
| **Inter** | **Display** | -2% letter spacing | Balance totals and key numbers |
| **Inter** | **Headlines** | Bold / Semantic | Clear information architecture |
| **Inter** | **Body** | **Min 16sp** | General readability |
| **Inter** | **Labels** | Med / Semi-Bold | Smallest scale; must remain legible |

---

## 4. Components & Interaction Design

### Buttons (Fitts’s Law)
> [!CAUTION]
> **Strict HCI Rule**: ALL interactive buttons, toggles, and nav items must have a minimum touch target size of **56x56dp** (Upgraded from 48dp for radical accessibility). There are no "small" tap targets.

* **Primary Action**: 
    * Solid fill (`primary`)
    * `ROUND_TWELVE` (0.75rem) corners
    * White text
    * Massive presence; impossible to miss.

### Cards & Lists (Hick’s Law)
* **Brutal Minimalism**: The interface must be stripped of clutter. Bottom navigation is limited to a **maximum of 4** distinct icons.
* **Visual Separation**: Use 16px or 24px of vertical white space to separate list items. **No dividers.**

---

## 5. HCI & Usability Checklist
- [ ] **Adaptive Theme**: Supports both Dark and Light modes.
- [ ] **Radical Accessibility**: Hyper-legible typography (Min 16sp) and high contrast against both Dark (#131319) and Light (#FCFBFF) backgrounds.
- [ ] **Fitts's Law**: Massive, single-tap buttons (Min 56dp). No complex swiping.
- [ ] **Hick’s Law**: Brutal minimalism. Hide complex accounting data.
- [ ] **Recognition Over Recall**: Universal iconography paired with all primary actions.

---

## 6. Premium Interactive Components & Interruption Architecture
* **CustomPremiumDropdown**: Uses `surface_container`. Searchable for lists > 10 items.
* **PhoneInputField**: Integrated flag prefix and searchable bottom sheet.
* **Modal & Sheet Principles**: Use `surface` color with `radiusXLarge` (24px) corners. Non-destructive sheets must be dismissible by tapping the scrim.
* **Decorative Graphics**: Built programmatically using standard Flutter `Icons`, `Containers`, and `BoxShadows` to ensure 60fps rendering without SVG bloat.