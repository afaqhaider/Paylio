# Implementation Plan: Home Dashboard & Budgeting System

This plan outlines the steps to add a new "Home" overview page and a "Budgets" management system to Paylio.

## Proposed Changes

### [Database & Models]
#### [NEW] [budget_model.dart](file:///C:/Develop/Paylio/App%20Code/paylio/lib/Features/Budgets/budget_model.dart)
- Define `BudgetModel`: `id`, `category`, `amountLimit`, `period` (Monthly/Weekly).

#### [database_helper.dart](file:///C:/Develop/Paylio/App%20Code/paylio/lib/Core/database_helper.dart)
- Add `budgets` table to `_createDB`.
- Add CRUD methods for budgets.
- Add `getTotalBalance()` helper.
- Add `getCategorySpending(String category, DateTime start, DateTime end)` helper.

---

### [Features: Dashboard]
#### [NEW] [dashboard_screen.dart](file:///C:/Develop/Paylio/App%20Code/paylio/lib/Features/Dashboard/dashboard_screen.dart)
- **Top Card**: Total Balance across all accounts.
- **In/Out Summary**: Monthly Income vs Expenses.
- **Recent Activity**: Last 3-5 transactions.
- **Quick Actions**: Buttons for Add Expense/Income.

---

### [Features: Budgets]
#### [NEW] [budgets_screen.dart](file:///C:/Develop/Paylio/App%20Code/paylio/lib/Features/Budgets/budgets_screen.dart)
- List of active budgets.
- **Progress Bars**: Visual indicator of spent vs. remaining.
- Color coding (Green/Yellow/Red).

#### [NEW] [add_budget_screen.dart](file:///C:/Develop/Paylio/App%20Code/paylio/lib/Features/Budgets/add_budget_screen.dart)
- Form to create/edit budgets (Category, Amount, Period).

---

### [Navigation]
#### [Home_Screen.dart](file:///C:/Develop/Paylio/App%20Code/paylio/lib/Features/Dashboard/Home_Screen.dart)
- Update Bottom Navigation to include:
    1. Home (Dashboard)
    2. Transactions
    3. Budgets
    4. Accounts
    5. Stats/Settings (optional)

## Verification Plan
### Manual Verification
1. **Dashboard**: Verify "Total Balance" matches the sum of accounts.
2. **Dashboard**: Verify "Recent Activity" updates immediately after adding a transaction.
3. **Budgets**: Create a budget for "Food" and add a "Food" transaction; verify the progress bar updates.
4. **Navigation**: Ensure all 5 tabs work correctly.
