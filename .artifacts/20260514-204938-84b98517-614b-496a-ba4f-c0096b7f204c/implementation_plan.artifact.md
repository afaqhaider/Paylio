# LedGix Premium Redesign Implementation Plan

This plan outlines the complete UI/UX transformation of the app into "LedGix", a premium fintech financial operating system.

## User Review Required

- **Navigation Change**: Bottom navigation is reduced to 4 items. The "More" tab is removed and replaced by a Drawer.
- **Transaction View**: Individual cards are replaced by date-grouped lists within a single daily card.
- **Onboarding**: A new multi-step setup wizard will be implemented for first-time users.
- **Logo Usage**: `assets/logo/ledgix_logo.png` will be used as the primary branding asset and splash screen.

## Proposed Changes

### Core UI & Theme

#### [theme_data.dart](file:///Users/afaqhaider/Downloads/Develop/LedGix/lib/Core/theme_data.dart)
- Implement new premium dark and light theme palettes.
- Set Manrope/Inter as the primary font family.
- Define consistent button, card, and surface styles.

#### [main.dart](file:///Users/afaqhaider/Downloads/Develop/LedGix/lib/main.dart)
- Apply the new `MaterialApp` theme configuration.
- Update global title and initialization logic.

---

### Navigation & Layout

#### [Home_Screen.dart](file:///Users/afaqhaider/Downloads/Develop/LedGix/lib/Features/Dashboard/Home_Screen.dart)
- Update bottom navigation to: Home, Activity, Budgets, Accounts.
- Implement the Side Drawer with expanded options (Reports, AI Tools, etc.).

---

### Redesigned Features

#### [dashboard_screen.dart](file:///Users/afaqhaider/Downloads/Develop/LedGix/lib/Features/Dashboard/dashboard_screen.dart)
- **Hero Section**: New total balance and monthly summary layout.
- **Middle Section**: Progress indicators for budgets and reminders for EMIs/cheques.
- **Lower Section**: Grouped recent activity and minimal charts.

#### [transactions_screen.dart](file:///Users/afaqhaider/Downloads/Develop/LedGix/lib/Features/Transactions/transactions_screen.dart)
- Implement date-grouped transaction lists.
- Design the "Daily Total" summary row for each group.
- Compact, right-aligned amount layout.

---

### New Onboarding Flow

#### [NEW] [onboarding_wizard.dart](file:///Users/afaqhaider/Downloads/Develop/LedGix/lib/Features/Onboarding/onboarding_wizard.dart)
- Guided multi-step setup:
    1. Welcome & Branding
    2. Currency & Payment Methods
    3. Bank Account & Initial Balances
    4. Income & Savings Goals
    5. Monthly Budget & Notifications

## Verification Plan

### Automated Tests
- `flutter analyze` to ensure no UI breakages.

### Manual Verification
- **Visual Inspection**: Verify the dark fintech aesthetic across all screens.
- **Navigation Flow**: Confirm the Drawer and Bottom Nav work correctly.
- **Onboarding Flow**: Trigger the setup wizard for a new user and verify data persistence.
- **Grouping Logic**: Check if transactions are correctly grouped by date in the Activity screen.
