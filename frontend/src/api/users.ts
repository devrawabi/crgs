import { apiGet, apiPatch, apiPost } from './client'

export interface DbLoginUser {
  username: string
  employeecode: string
  rolecode: string | number
  flag: string
  route: string | null
  designation?: string | null
}

export function normalizeRouteNo(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return ''
  const text = String(value).trim()
  if (!text) return ''
  const numeric = Number(text)
  if (!Number.isNaN(numeric) && Number.isFinite(numeric) && Number.isInteger(numeric)) {
    return String(numeric)
  }
  return text
}

export function parseRouteColumn(route: string | null | undefined): string[] {
  if (!route?.trim()) return []
  return route.split(',').map((no) => normalizeRouteNo(no)).filter(Boolean)
}

export function formatRouteColumn(routeNos: Array<string | number>): string {
  return routeNos.map((no) => normalizeRouteNo(no)).filter(Boolean).join(',')
}

export function isRouteNoSelected(
  selected: Array<string | number>,
  routeno: string | number
): boolean {
  const target = normalizeRouteNo(routeno)
  return selected.some((no) => normalizeRouteNo(no) === target)
}

export function toggleRouteNo(
  selected: Array<string | number>,
  routeno: string | number
): string[] {
  const target = normalizeRouteNo(routeno)
  if (isRouteNoSelected(selected, target)) {
    return selected
      .map((no) => normalizeRouteNo(no))
      .filter((no) => no !== target)
  }
  return [...selected.map((no) => normalizeRouteNo(no)), target]
}

export interface UsersResponse {
  count: number
  users: DbLoginUser[]
}

export interface CreateUserPayload {
  username: string
  employeeCode: string
  password: string
  roleCode: string
}

export interface CreateUserResponse {
  username: string
  employeeCode: string
  roleCode: string
  designation: string
  flag: string
}

export interface FetchUsersParams {
  activeOnly?: boolean
}

export function fetchUsers(params: FetchUsersParams = {}) {
  return apiGet<UsersResponse>('/api/users', {
    activeOnly: params.activeOnly ? 'true' : undefined,
  })
}

export function createUser(payload: CreateUserPayload) {
  return apiPost<CreateUserResponse>('/api/users', payload)
}

export interface AssignRoutesPayload {
  employeeCode: string
  routeNos: string[]
}

export interface AssignRoutesResponse {
  employeeCode: string
  route: string
  routeNos: string[]
}

export function assignUserRoutes(payload: AssignRoutesPayload) {
  return apiPatch<AssignRoutesResponse>('/api/users/routes', payload)
}

export interface UpdateUserStatusPayload {
  employeeCode: string
  flag: 'A' | 'D'
}

export interface UpdateUserStatusResponse {
  employeeCode: string
  flag: string
}

export function updateUserStatus(payload: UpdateUserStatusPayload) {
  return apiPatch<UpdateUserStatusResponse>('/api/users/status', payload)
}
