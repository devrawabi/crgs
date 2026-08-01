import { apiGet } from './client'
import { fetchAllPages } from './paginate'

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
  offset: number
  limit: number
  has_more: boolean
  visits: DbVisit[]
}

export interface FetchVisitsParams {
  employeeCode?: string
  customerCode?: string
  limit?: number
  offset?: number
}

export function fetchVisits(params: FetchVisitsParams = {}) {
  return apiGet<VisitsResponse>('/api/visits', {
    employeeCode: params.employeeCode,
    customerCode: params.customerCode,
    limit: params.limit ?? 50,
    offset: params.offset ?? 0,
  })
}

export async function fetchAllVisits(
  params: Omit<FetchVisitsParams, 'limit' | 'offset'> = {}
) {
  const visits = await fetchAllPages<DbVisit>({
    pageSize: 200,
    itemsKey: 'visits',
    fetchPage: ({ limit, offset }) =>
      fetchVisits({ ...params, limit, offset }) as Promise<Record<string, unknown>>,
  })
  return { count: visits.length, visits }
}
