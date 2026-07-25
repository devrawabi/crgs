import { apiPost } from './client'

export interface LoginPayload {
  employeeCode: string
  password: string
}

export interface LoginResponse {
  username: string
  employeeCode: string
  roleCode: number
  flag: string
}

export function loginUser(payload: LoginPayload) {
  return apiPost<LoginResponse>('/api/auth/login', payload)
}
