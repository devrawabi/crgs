import { apiGet } from './client'

export interface DbVisit {
  employeeCode: string
  customerCode: string
  customerName: string
  route: string
  visitDate: string
  visitStart: string
  visitEnd: string
  totalDuration: string
  location: string
  reason: string
  remarks: string
  followUp: string
}

export interface VisitsResponse {
  count: number
  visits: DbVisit[]
}

export function fetchVisits(params?: {
  employeeCode?: string
  customerCode?: string
}) {
  return apiGet<VisitsResponse>('/api/visits', {
    employeeCode: params?.employeeCode,
    customerCode: params?.customerCode,
  })
}
