import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard,
  Users,
  MapPin,
  Target,
  ClipboardList,
  BarChart3,
  UserPlus,
  PackageSearch,
  Menu,
  X,
  LogOut,
} from 'lucide-react'
import { useState } from 'react'
import logo from '../../assets/crgs-logo.png'
import { useAuth } from '../../context/AuthContext'

const navItems = [
  { to: '/', label: 'Dashboard', icon: LayoutDashboard },
  { to: '/users', label: 'User Management', icon: Users },
  { to: '/routes', label: 'Route Management', icon: MapPin },
  { to: '/targets', label: 'Target Management', icon: Target },
  { to: '/tasks', label: 'Task Management', icon: ClipboardList },
  { to: '/customer-requests', label: 'Customer Request', icon: UserPlus },
  { to: '/product-review-report', label: 'Product Review Report', icon: PackageSearch },
  { to: '/reports', label: 'Reports', icon: BarChart3 },
]

export function Layout() {
  const [sidebarOpen, setSidebarOpen] = useState(false)
  const { user, logout } = useAuth()
  const navigate = useNavigate()

  const handleLogout = () => {
    logout()
    navigate('/login')
  }

  const initials = user?.name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .slice(0, 2)
    .toUpperCase() ?? 'SM'

  return (
    <div className="h-screen overflow-hidden bg-gray-50 flex">
      {sidebarOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 lg:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}

      <aside
        className={`fixed lg:static inset-y-0 left-0 z-50 w-64 h-full bg-sidebar text-white flex flex-col transition-transform lg:translate-x-0 ${
          sidebarOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="shrink-0 flex items-center gap-3 px-6 py-5 border-b border-white/10">
          <img src={logo} alt="CRGS Admin" className="w-10 h-10 rounded-xl object-cover" />
          <div>
            <p className="font-bold text-sm">CRGS Admin</p>
            <p className="text-xs text-gray-400">Sales Manager Portal</p>
          </div>
          <button
            className="ml-auto lg:hidden text-gray-400 hover:text-white"
            onClick={() => setSidebarOpen(false)}
          >
            <X size={20} />
          </button>
        </div>

        <nav className="flex-1 min-h-0 overflow-y-auto px-3 py-4 space-y-1">
          {navItems.map(({ to, label, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              onClick={() => setSidebarOpen(false)}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors ${
                  isActive
                    ? 'bg-primary-600 text-white'
                    : 'text-gray-300 hover:bg-sidebar-hover hover:text-white'
                }`
              }
            >
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
        </nav>

        <div className="shrink-0 px-6 py-4 border-t border-white/10">
          <div className="flex items-center gap-3">
            <div className="w-8 h-8 rounded-full bg-primary-600 flex items-center justify-center text-xs font-bold">
              {initials}
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium truncate">{user?.name ?? 'Sales Manager'}</p>
              <p className="text-xs text-gray-400 truncate">{user?.employeeCode ?? 'ADMIN'}</p>
            </div>
            <button
              onClick={handleLogout}
              className="p-1.5 rounded-lg text-gray-400 hover:text-white hover:bg-sidebar-hover"
              title="Sign out"
            >
              <LogOut size={16} />
            </button>
          </div>
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-w-0 min-h-0 overflow-hidden">
        <header className="shrink-0 bg-white border-b border-gray-200 px-4 lg:px-8 py-4 flex items-center gap-4">
          <button
            className="lg:hidden p-2 rounded-lg hover:bg-gray-100 text-gray-600"
            onClick={() => setSidebarOpen(true)}
          >
            <Menu size={20} />
          </button>
          <div className="flex-1" />
          <span className="text-xs text-gray-500 hidden sm:block">
            Customer Recovery & Growth System
          </span>
        </header>

        <main className="flex-1 flex flex-col min-h-0 overflow-hidden p-4 lg:p-8">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
