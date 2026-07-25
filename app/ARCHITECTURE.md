# Sales Recovery & Route Management System (SRRMS)

Enterprise-grade Flutter mobile application for Sales Executives.

## Architecture Overview

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # MaterialApp + Riverpod root
├── core/
│   ├── constants/            # App constants, API endpoints
│   ├── theme/                # Material 3 light/dark themes
│   ├── network/              # Dio API client, exceptions
│   ├── routes/               # GoRouter configuration
│   ├── providers/            # Core DI providers
│   └── utils/                # Responsive helpers
├── data/
│   ├── models/               # Domain models
│   └── mock/                 # Mock data for UI dev
├── features/                 # Feature-first modules
│   ├── auth/
│   ├── dashboard/
│   ├── customers/
│   ├── visit/
│   ├── recovery/
│   ├── products/
│   ├── follow_up/
│   ├── market_research/
│   ├── new_customer/
│   ├── outstanding/
│   ├── tasks/
│   ├── profile/
│   └── reports/
└── shared/
    ├── providers/            # Theme, connectivity
    └── widgets/              # Reusable design system
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | Flutter Material 3 |
| State | Riverpod |
| Navigation | GoRouter |
| HTTP | Dio |
| Charts | fl_chart |
| Fonts | Google Fonts (Inter) |
| Storage | shared_preferences |
| Offline | connectivity_plus |

## Screens (13)

1. **Login** — Employee auth, remember me
2. **Dashboard** — KPI cards, progress, map, quick actions
3. **Route Customer List** — Priority-sorted customers with filters
4. **Customer Details** — Full profile, charts, action chips
5. **Visit Tracking** — GPS validation, check-in/out timer
6. **Recovery Form** — Missing customer reasons + conditional sections
7. **Product Introduction** — Recommendations + expected orders
8. **Follow-up** — Calendar + timeline views
9. **Market Research** — Trends, notes, photo attachments
10. **New Customer** — Prospect pipeline (Prospect → Follow-up → Converted)
11. **Outstanding Collection** — Invoice tracking + commitments
12. **Task Management** — Start/complete tasks, notes, evidence
13. **Profile** — Performance, settings, logout

## Navigation Flow

```
Login → Dashboard (Bottom Nav Shell)
         ├── Dashboard
         ├── Customers → Customer Detail → Visit / Recovery / Products
         ├── Tasks
         ├── Reports
         └── Profile → Settings / Change Password
```

## Design System

- **Colors**: Blue (#1565C0), Green (#2E7D32), White
- **Priority Badges**: Red (Missing), Orange (Outstanding), Blue (Follow-up), Green (Regular)
- **Components**: StatCard, ProgressCard, PriorityBadge, TimelineItem, RouteMapSummary, SalesBarChart

## Run

```bash
flutter pub get
flutter run
```

**Demo login**: Employee ID `SE-2045`, any password

## API Integration

Replace `MockData` with repository implementations using `ApiClient` and endpoints in `core/constants/app_constants.dart`.
