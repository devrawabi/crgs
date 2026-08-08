import { apiGet } from './client'
import { fetchAllPages } from './paginate'

export interface DbRoute {
  routename: string
  routeno: string
}

export interface RoutesResponse {
  count: number
  offset: number
  limit: number
  has_more?: boolean
  routes: DbRoute[]
}

export interface FetchRoutesParams {
  search?: string
  /** Comma-separated ROUTENO filter (assigned routes). */
  routeNos?: string | string[]
  limit?: number
  offset?: number
}

export function fetchRoutes(params: FetchRoutesParams = {}) {
  const routeNos = Array.isArray(params.routeNos)
    ? params.routeNos.filter(Boolean).join(',')
    : params.routeNos
  return apiGet<RoutesResponse>('/api/routes', {
    search: params.search,
    routeNos: routeNos || undefined,
    limit: params.limit ?? 500,
    offset: params.offset ?? 0,
  })
}

export async function fetchAllRoutes(
  params: Omit<FetchRoutesParams, 'limit' | 'offset'> = {}
) {
  const routes = await fetchAllPages<DbRoute>({
    pageSize: 500,
    itemsKey: 'routes',
    fetchPage: ({ limit, offset }) =>
      fetchRoutes({ ...params, limit, offset }),
  })
  return { count: routes.length, offset: 0, limit: routes.length, routes }
}
