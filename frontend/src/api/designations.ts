import { apiGet } from './client'

export interface DbDesignation {
  rolecode: string
  designation: string
}

export interface DesignationsResponse {
  count: number
  designations: DbDesignation[]
}

export function fetchDesignations() {
  return apiGet<DesignationsResponse>('/api/designations')
}
