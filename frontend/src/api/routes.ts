import { apiGet } from './client'

export interface DbRoute {
  routename: string
  routeno: string
}

export interface RoutesResponse {
  count: number
  offset: number
  limit: number
  routes: DbRoute[]
}

export interface FetchRoutesParams {
  search?: string
  limit?: number
  offset?: number
}

export function fetchRoutes(params: FetchRoutesParams = {}) {
  return apiGet<RoutesResponse>('/api/routes', {
    search: params.search,
    limit: params.limit ?? 500,
    offset: params.offset ?? 0,
  })
}
