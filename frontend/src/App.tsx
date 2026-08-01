import { Suspense, lazy } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import { AppProvider } from './context/AppContext'
import { ProtectedRoute } from './components/auth/ProtectedRoute'
import { AdminRoute } from './components/auth/AdminRoute'
import { RoleRoute } from './components/auth/RoleRoute'
import { Layout } from './components/layout/Layout'
import { LoginPage } from './pages/LoginPage'

const DashboardPage = lazy(() =>
  import('./pages/DashboardPage').then((m) => ({ default: m.DashboardPage }))
)
const UsersPage = lazy(() =>
  import('./pages/UsersPage').then((m) => ({ default: m.UsersPage }))
)
const RoutesPage = lazy(() =>
  import('./pages/RoutesPage').then((m) => ({ default: m.RoutesPage }))
)
const TargetsPage = lazy(() =>
  import('./pages/TargetsPage').then((m) => ({ default: m.TargetsPage }))
)
const TasksPage = lazy(() =>
  import('./pages/TasksPage').then((m) => ({ default: m.TasksPage }))
)
const CustomerRequestsPage = lazy(() =>
  import('./pages/CustomerRequestsPage').then((m) => ({
    default: m.CustomerRequestsPage,
  }))
)
const ProductReviewReportPage = lazy(() =>
  import('./pages/ProductReviewReportPage').then((m) => ({
    default: m.ProductReviewReportPage,
  }))
)
const CallCenterPage = lazy(() =>
  import('./pages/CallCenterPage').then((m) => ({ default: m.CallCenterPage }))
)
const ReportsPage = lazy(() =>
  import('./pages/ReportsPage').then((m) => ({ default: m.ReportsPage }))
)

function PageFallback() {
  return (
    <div className="flex-1 flex items-center justify-center p-8 text-sm text-gray-500">
      Loading…
    </div>
  )
}

export default function App() {
  return (
    <AuthProvider>
      <AppProvider>
        <BrowserRouter>
          <Suspense fallback={<PageFallback />}>
            <Routes>
              <Route path="/login" element={<LoginPage />} />
              <Route element={<ProtectedRoute />}>
                <Route element={<AdminRoute />}>
                  <Route element={<Layout />}>
                    <Route element={<RoleRoute navKey="dashboard" />}>
                      <Route index element={<DashboardPage />} />
                    </Route>
                    <Route element={<RoleRoute navKey="users" />}>
                      <Route path="users" element={<UsersPage />} />
                    </Route>
                    <Route element={<RoleRoute navKey="routes" />}>
                      <Route path="routes" element={<RoutesPage />} />
                    </Route>
                    <Route element={<RoleRoute navKey="targets" />}>
                      <Route path="targets" element={<TargetsPage />} />
                    </Route>
                    <Route element={<RoleRoute navKey="tasks" />}>
                      <Route path="tasks" element={<TasksPage />} />
                    </Route>
                    <Route element={<RoleRoute navKey="customer-requests" />}>
                      <Route
                        path="customer-requests"
                        element={<CustomerRequestsPage />}
                      />
                    </Route>
                    <Route element={<RoleRoute navKey="product-review-report" />}>
                      <Route
                        path="product-review-report"
                        element={<ProductReviewReportPage />}
                      />
                    </Route>
                    <Route element={<RoleRoute navKey="call-center" />}>
                      <Route path="call-center" element={<CallCenterPage />} />
                    </Route>
                    <Route element={<RoleRoute navKey="reports" />}>
                      <Route path="reports" element={<ReportsPage />} />
                    </Route>
                  </Route>
                </Route>
              </Route>
              <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
          </Suspense>
        </BrowserRouter>
      </AppProvider>
    </AuthProvider>
  )
}
