import { apiGet, apiPost } from './client'

export interface LoginPayload {
  employeeCode: string
  password: string
}

export interface LoginResponse {
  token: string
  tokenType: string
  expiresInHours: number
  username: string
  employeeCode: string
  roleCode: string | number
  isAdmin?: boolean
  isManager?: boolean
  isCallCenter?: boolean
  flag: string
  route?: string | null
  onboardFlag?: string | null
}

export interface MeResponse {
  employeeCode: string
  username: string
  roleCode: string | number
  isAdmin?: boolean
  isManager?: boolean
  isCallCenter?: boolean
  route?: string | null
}

export function loginUser(payload: LoginPayload) {
  return apiPost<LoginResponse>('/api/auth/login', payload)
}

/** Deep session check — validates the current Bearer token with the backend. */
export function fetchCurrentUser() {
  return apiGet<MeResponse>('/api/auth/me')
}
