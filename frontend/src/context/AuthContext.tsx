import {
  createContext,
  useContext,
  useState,
  useCallback,
  useEffect,
  type ReactNode,
} from 'react'
import { fetchCurrentUser, loginUser } from '../api/auth'
import {
  clearAuthStorage,
  getAccessToken,
  onAuthExpired,
  setAccessToken,
} from '../api/client'
import {
  canAccessPortal,
  isCallCenterRole,
  isFullAdminRole,
  isManagerRole,
  normalizeRoleCode,
} from '../lib/roleAccess'

export interface AuthUser {
  employeeCode: string
  name: string
  roleCode: string
  role: string
  isAdmin: boolean
  isManager: boolean
  isCallCenter: boolean
  canAccessPortal: boolean
}

interface AuthContextValue {
  user: AuthUser | null
  isAuthenticated: boolean
  isLoading: boolean
  login: (
    employeeCode: string,
    password: string
  ) => Promise<{ success: boolean; error?: string; roleCode?: string }>
  logout: () => void
}

const STORAGE_KEY = 'crgs-admin-session'

const AuthContext = createContext<AuthContextValue | null>(null)

function mapRole(roleCode: string): string {
  return roleCode || 'user'
}

function toAuthUser(data: {
  employeeCode: string
  username?: string
  name?: string
  roleCode: string | number
  isAdmin?: boolean
  isManager?: boolean
  isCallCenter?: boolean
}): AuthUser {
  const roleCode = normalizeRoleCode(data.roleCode)
  const isAdmin = Boolean(data.isAdmin) || isFullAdminRole(roleCode)
  const isManager = Boolean(data.isManager) || isManagerRole(roleCode)
  const isCallCenter = Boolean(data.isCallCenter) || isCallCenterRole(roleCode)
  return {
    employeeCode: data.employeeCode,
    name: data.username ?? data.name ?? data.employeeCode,
    roleCode,
    role: mapRole(roleCode),
    isAdmin,
    isManager,
    isCallCenter,
    canAccessPortal:
      isAdmin || isManager || isCallCenter || canAccessPortal(roleCode),
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  const logout = useCallback(() => {
    setUser(null)
    clearAuthStorage()
  }, [])

  useEffect(() => {
    let cancelled = false

    async function restoreSession() {
      try {
        const stored =
          sessionStorage.getItem(STORAGE_KEY) || localStorage.getItem(STORAGE_KEY)
        const token = getAccessToken()
        if (!stored || !token) {
          clearAuthStorage()
          return
        }

        const me = await fetchCurrentUser()
        if (cancelled) return

        const authUser = toAuthUser({
          employeeCode: me.employeeCode,
          username: me.username,
          roleCode: me.roleCode,
          isAdmin: me.isAdmin,
          isManager: me.isManager,
          isCallCenter: me.isCallCenter,
        })
        setUser(authUser)
        localStorage.removeItem(STORAGE_KEY)
        sessionStorage.setItem(STORAGE_KEY, JSON.stringify(authUser))
      } catch {
        if (!cancelled) {
          setUser(null)
          clearAuthStorage()
        }
      } finally {
        if (!cancelled) setIsLoading(false)
      }
    }

    void restoreSession()

    const unsubscribe = onAuthExpired(() => {
      setUser(null)
    })

    return () => {
      cancelled = true
      unsubscribe()
    }
  }, [])

  const login = useCallback(async (employeeCode: string, password: string) => {
    try {
      const data = await loginUser({
        employeeCode: employeeCode.trim(),
        password,
      })
      if (!data.token) {
        return { success: false, error: 'Login response missing token' }
      }
      const authUser = toAuthUser({
        employeeCode: data.employeeCode,
        username: data.username,
        roleCode: data.roleCode,
        isAdmin: data.isAdmin,
        isManager: data.isManager,
        isCallCenter: data.isCallCenter,
      })
      setAccessToken(data.token)
      setUser(authUser)
      localStorage.removeItem(STORAGE_KEY)
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify(authUser))
      return { success: true, roleCode: authUser.roleCode }
    } catch (err) {
      const message =
        err instanceof Error ? err.message : 'Invalid employee code or password'
      return { success: false, error: message }
    }
  }, [])

  return (
    <AuthContext.Provider
      value={{ user, isAuthenticated: !!user, isLoading, login, logout }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
