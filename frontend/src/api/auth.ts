import { apiPost } from './client'

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
  flag: string
  route?: string | null
  onboardFlag?: string | null
}

export function loginUser(payload: LoginPayload) {
  return apiPost<LoginResponse>('/api/auth/login', payload)
}
