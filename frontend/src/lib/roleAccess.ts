/** Full admin: Dashboard + Users + ops tabs. Call Center nav is only roles 1 & 9. */
export const FULL_ADMIN_ROLE_CODES = new Set(['1', '3', '4', '6', '8'])

/** Manager: all tabs except Dashboard + User Management. */
export const MANAGER_ROLE_CODES = new Set(['2', '5'])

/** Call Center tab only (no other portal tabs). */
export const CALL_CENTER_ROLE_CODES = new Set(['9'])

/** Who may open the Call Center screen (role 9 + role 1). */
export const CALL_CENTER_NAV_ROLE_CODES = new Set(['1', '9'])

/** Only actor role 1 may create users with these designations. */
export const RESTRICTED_CREATE_ROLE_CODES = new Set(['1', '9'])

export type PortalNavKey =
  | 'dashboard'
  | 'users'
  | 'routes'
  | 'targets'
  | 'tasks'
  | 'customer-requests'
  | 'product-review-report'
  | 'work-reports'
  | 'call-center'
  | 'reports'

const FULL_ADMIN_ONLY: ReadonlySet<PortalNavKey> = new Set(['dashboard', 'users'])

export function normalizeRoleCode(value: string | number | undefined | null): string {
  const text = String(value ?? '').trim()
  if (!text) return ''
  const asNum = Number(text)
  if (Number.isFinite(asNum) && Number.isInteger(asNum)) return String(asNum)
  if (
    Number.isFinite(asNum) &&
    Number.isInteger(Math.round(asNum)) &&
    Math.abs(asNum - Math.round(asNum)) < 1e-9
  ) {
    return String(Math.round(asNum))
  }
  return text
}

export function isFullAdminRole(roleCode: string | number | undefined | null): boolean {
  return FULL_ADMIN_ROLE_CODES.has(normalizeRoleCode(roleCode))
}

export function isManagerRole(roleCode: string | number | undefined | null): boolean {
  return MANAGER_ROLE_CODES.has(normalizeRoleCode(roleCode))
}

export function isCallCenterRole(roleCode: string | number | undefined | null): boolean {
  return CALL_CENTER_ROLE_CODES.has(normalizeRoleCode(roleCode))
}

export function canAccessPortal(roleCode: string | number | undefined | null): boolean {
  const code = normalizeRoleCode(roleCode)
  return (
    FULL_ADMIN_ROLE_CODES.has(code) ||
    MANAGER_ROLE_CODES.has(code) ||
    CALL_CENTER_ROLE_CODES.has(code)
  )
}

export function canAccessNav(
  roleCode: string | number | undefined | null,
  key: PortalNavKey
): boolean {
  if (!canAccessPortal(roleCode)) return false
  // Call Center: only role 1 and 9 (hide from managers / other admins).
  if (key === 'call-center') {
    return CALL_CENTER_NAV_ROLE_CODES.has(normalizeRoleCode(roleCode))
  }
  // Role 9: Call Center only (no other tabs).
  if (isCallCenterRole(roleCode)) return false
  if (FULL_ADMIN_ONLY.has(key)) return isFullAdminRole(roleCode)
  return true
}

/** Role-aware landing path after login. */
export function defaultPortalPath(roleCode: string | number | undefined | null): string {
  if (isCallCenterRole(roleCode)) return '/call-center'
  if (isFullAdminRole(roleCode)) return '/'
  return '/routes'
}

/** Whether the actor may assign this designation when creating a user. */
export function canAssignRoleCode(
  actorRoleCode: string | number | undefined | null,
  targetRoleCode: string | number | undefined | null
): boolean {
  const target = normalizeRoleCode(targetRoleCode)
  if (!RESTRICTED_CREATE_ROLE_CODES.has(target)) return true
  return normalizeRoleCode(actorRoleCode) === '1'
}
