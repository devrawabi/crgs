# REX APP — Screen Inventory

**App:** REX APP · **Platform:** Flutter Mobile · **Total screens:** 18

---

## 1. Authentication & Onboarding
- **Login** — Employee ID & password sign-in (`/login`)
- **Onboarding** — 3-slide app intro; shown once after first login (`/onboarding`)

## 2. Main Navigation (Bottom Nav + Sidebar)
- **Dashboard** — Stats, targets, map, weekly chart, quick actions (`/dashboard`)
- **My Routes** — Assigned route cards with customer counts (`/routes`)
- **Route Customers** — Search, filter, customer list for a route (`/routes/:routeId`)
- **Task Management** — Tabs: All, Route, Additional, Follow-ups (`/tasks`)
- **Reports & Analytics** — Sales, visits, charts (`/reports`)
- **Profile** — User info, theme, settings links (`/profile`)

## 3. Customer & Field Operations
- **Customer Detail** — Full customer info & action chips (`/customers/:id`)
- **Visit Tracking** — Timer, location, products, visit form, end visit (`/visit/:customerId`)
- **Recovery Form** — Recovery report for a customer (`/recovery/:customerId`)
- **Product Intro** — Recommended products & expected order (`/products/:customerId`)
- **Follow-up** — Schedule and manage follow-ups (`/follow-up`)
- **Market Research** — Competitor & market data capture (`/market-research`)

## 4. Sales & Collections
- **New Customer / Lead** — Prospect registration form (`/new-customer`)
- **Outstanding Collection** — Pending invoices & collection commitments (`/outstanding`)

## 5. Account Settings
- **Settings** — App preferences (`/settings`)
- **Change Password** — Password update form (`/change-password`)

---

## Overlay Sheets (not full screens)
- Customer Detail Sheet · Product Detail Sheet · Visit Location Picker Sheet

## Navigation Flow
`Login → Onboarding → Routes (default) ↔ Dashboard / Tasks via bottom nav · Sidebar → Profile, Reports, Outstanding, Follow-ups, Settings`
