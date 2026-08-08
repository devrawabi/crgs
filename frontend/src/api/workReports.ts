import { apiGet } from './client'
import { fetchAllPages } from './paginate'

export interface DbWorkReport {
  employeeCode: string
  customerName: string
  notes: string
  createdAt?: string
}

export interface WorkReportsResponse {
  count: number
  offset?: number
  limit?: number
  has_more?: boolean
  items: DbWorkReport[]
}

export interface FetchWorkReportsParams {
  employeeCode?: string
  limit?: number
  offset?: number
}

export function fetchWorkReports(params: FetchWorkReportsParams = {}) {
  return apiGet<WorkReportsResponse>('/api/work-reports', {
    employeeCode: params.employeeCode || undefined,
    limit: params.limit ?? 50,
    offset: params.offset ?? 0,
  })
}

export async function fetchAllWorkReports(
  params: Omit<FetchWorkReportsParams, 'limit' | 'offset'> = {}
) {
  const items = await fetchAllPages<DbWorkReport>({
    pageSize: 100,
    maxPages: 10,
    itemsKey: 'items',
    fetchPage: ({ limit, offset }) =>
      fetchWorkReports({ ...params, limit, offset }),
  })
  return { count: items.length, items }
}
