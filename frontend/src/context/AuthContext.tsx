import {
  createContext,
  useContext,
  useState,
  useCallback,
  useEffect,
  type ReactNode,
} from 'react'
import { loginUser } from '../api/auth'

export interface AuthUser {
  employeeCode: string
  name: string
  role: 'admin'
}

interface AuthContextValue {
  user: AuthUser | null
  isAuthenticated: boolean
  isLoading: boolean
  login: (employeeCode: string, password: string) => Promise<{ success: boolean; error?: string }>
  logout: () => void
}

const STORAGE_KEY = 'crgs-admin-session'

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY)
      if (stored) setUser(JSON.parse(stored) as AuthUser)
    } catch {
      localStorage.removeItem(STORAGE_KEY)
    }
    setIsLoading(false)
  }, [])

  const login = useCallback(async (employeeCode: string, password: string) => {
    try {
      const data = await loginUser({
        employeeCode: employeeCode.trim(),
        password,
      })
      const authUser: AuthUser = {
        employeeCode: data.employeeCode,
        name: data.username,
        role: 'admin',
      }
      setUser(authUser)
      localStorage.setItem(STORAGE_KEY, JSON.stringify(authUser))
      return { success: true }
    } catch (err) {
      const message =
        err instanceof Error ? err.message : 'Invalid employee code or password'
      return { success: false, error: message }
    }
  }, [])

  const logout = useCallback(() => {
    setUser(null)
    localStorage.removeItem(STORAGE_KEY)
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
