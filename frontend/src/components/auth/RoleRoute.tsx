import { Navigate, Outlet } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import {
  canAccessNav,
  defaultPortalPath,
  type PortalNavKey,
} from '../../lib/roleAccess'

/** Restrict a route to roles that may open this nav key. */
export function RoleRoute({ navKey }: { navKey: PortalNavKey }) {
  const { user } = useAuth()
  const roleCode = user?.roleCode

  if (!canAccessNav(roleCode, navKey)) {
    return <Navigate to={defaultPortalPath(roleCode)} replace />
  }

  return <Outlet />
}
