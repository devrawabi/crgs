import { Outlet } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'

/** Portal shell for full admins, managers, and call-center roles. */
export function AdminRoute() {
  const { user, isLoading, logout } = useAuth()

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 border-2 border-primary-600 border-t-transparent rounded-full animate-spin" />
          <p className="text-sm text-gray-500">Loading...</p>
        </div>
      </div>
    )
  }

  if (!user?.canAccessPortal) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 p-6">
        <div className="max-w-md text-center space-y-4">
          <h1 className="text-lg font-semibold text-gray-900">Portal access required</h1>
          <p className="text-sm text-gray-600">
            Your account is signed in but is not assigned a portal role. Contact a system
            administrator if you need access to this portal.
          </p>
          <button
            type="button"
            className="text-sm text-primary-700 underline"
            onClick={() => logout()}
          >
            Sign out
          </button>
        </div>
      </div>
    )
  }

  return <Outlet />
}
