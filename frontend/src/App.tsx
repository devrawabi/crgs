import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import { AppProvider } from './context/AppContext'
import { ProtectedRoute } from './components/auth/ProtectedRoute'
import { Layout } from './components/layout/Layout'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { UsersPage } from './pages/UsersPage'
import { RoutesPage } from './pages/RoutesPage'
import { TargetsPage } from './pages/TargetsPage'
import { TasksPage } from './pages/TasksPage'
import { CustomerRequestsPage } from './pages/CustomerRequestsPage'
import { ProductReviewReportPage } from './pages/ProductReviewReportPage'
import { ReportsPage } from './pages/ReportsPage'

export default function App() {
  return (
    <AuthProvider>
      <AppProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route element={<ProtectedRoute />}>
              <Route element={<Layout />}>
                <Route index element={<DashboardPage />} />
                <Route path="users" element={<UsersPage />} />
                <Route path="routes" element={<RoutesPage />} />
                <Route path="targets" element={<TargetsPage />} />
                <Route path="tasks" element={<TasksPage />} />
                <Route path="customer-requests" element={<CustomerRequestsPage />} />
                <Route path="product-review-report" element={<ProductReviewReportPage />} />
                <Route path="reports" element={<ReportsPage />} />
              </Route>
            </Route>
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </BrowserRouter>
      </AppProvider>
    </AuthProvider>
  )
}
