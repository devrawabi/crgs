import { apiGet } from './client'
import { fetchAllPages } from './paginate'

export interface DbCustomer {
  cust_code: string
  cust_name: string
  address?: string | null
  credit_limit?: number | null
  credit_amount?: number | null
  category?: string | null
  categoryname?: string | null
  route?: string | number | null
  routename?: string | null
  type?: string | null
  mobile?: string | null
  customerstatus?: string | null
  last_purchase_date?: string | null
  last_purchase_amount?: number | null
  days_since_purchase?: number | null
  is_missing?: boolean
}

export interface CustomerRouteStats {
  all: number
  missing: number
  outstanding: number
}

export interface CustomerStatsResponse {
  route: string
  missing_days: number
  stats: CustomerRouteStats
}

export interface CustomerStatsBatchResponse {
  missing_days: number
  routes: Array<{ route: string; stats: CustomerRouteStats }>
}

export interface CustomersResponse {
  count: number
  offset: number
  limit: number
  has_more: boolean
  missing_days: number
  customers: DbCustomer[]
}

export interface FetchCustomersParams {
  route: string
  search?: string
  priority?: 'missing' | 'outstanding' | ''
  missingDays?: number
  limit?: number
  offset?: number
}

export function fetchCustomerStats(route: string, missingDays?: number) {
  return apiGet<CustomerStatsResponse>('/api/customers/stats', {
    route,
    missing_days: missingDays,
  })
}

const STATS_ROUTE_CHUNK = 40

/** Grouped Oracle stats; chunks large route lists to keep plans predictable. */
export async function fetchCustomerStatsBatch(
  routes: string[],
  missingDays?: number
) {
  const cleaned = routes.map((r) => r.trim()).filter(Boolean)
  if (cleaned.length === 0) {
    return { missing_days: missingDays ?? 0, routes: [] }
  }

  const merged: CustomerStatsBatchResponse['routes'] = []
  for (let i = 0; i < cleaned.length; i += STATS_ROUTE_CHUNK) {
    const chunk = cleaned.slice(i, i + STATS_ROUTE_CHUNK)
    const batch = await apiGet<CustomerStatsBatchResponse>(
      '/api/customers/stats',
      {
        routes: chunk.join(','),
        missing_days: missingDays,
      }
    )
    merged.push(...(batch.routes ?? []))
  }
  return { routes: merged }
}

export function fetchCustomers(params: FetchCustomersParams) {
  return apiGet<CustomersResponse>('/api/customers', {
    route: params.route,
    search: params.search,
    priority: params.priority || undefined,
    missing_days: params.missingDays,
    limit: params.limit ?? 50,
    offset: params.offset ?? 0,
  })
}

/** Load customers for one or more routes (paginated under the hood). */
export async function fetchAllCustomersForRoutes(
  routeNos: string[],
  options?: { maxTotal?: number; pageSize?: number }
) {
  const cleaned = [
    ...new Set(routeNos.map((r) => String(r).trim()).filter(Boolean)),
  ]
  if (cleaned.length === 0) return { count: 0, customers: [] as DbCustomer[] }

  const maxTotal = options?.maxTotal
  const pageSize = options?.pageSize ?? 200
  const byCode = new Map<string, DbCustomer>()

  for (const route of cleaned) {
    if (maxTotal != null && byCode.size >= maxTotal) break

    const customers = await fetchAllPages<DbCustomer>({
      pageSize,
      maxPages:
        maxTotal != null
          ? Math.max(1, Math.ceil((maxTotal - byCode.size) / pageSize) + 1)
          : 100,
      itemsKey: 'customers',
      fetchPage: ({ limit, offset }) =>
        fetchCustomers({ route, limit, offset }),
    })
    for (const customer of customers) {
      const code = String(customer.cust_code ?? '').trim()
      if (code) byCode.set(code, customer)
      if (maxTotal != null && byCode.size >= maxTotal) break
    }
  }
  return { count: byCode.size, customers: [...byCode.values()] }
}

/** CRGS_CONTACTINFO row — FLAG N = new customer request, FLAG E = edit request */
export type ContactInfoFlag = 'N' | 'E'

export interface DbContactInfo {
  customerCode: string
  customerName: string
  shopName: string
  contactNumber: string
  location: string
  address: string
  businessType: string
  expectedAmount: number | null
  products: string
  remarks: string
  status: string
  flag: string
}

export interface ContactInfoResponse {
  count: number
  offset?: number
  limit?: number
  has_more?: boolean
  items: DbContactInfo[]
}

export interface FetchContactInfoParams {
  status?: string
  search?: string
  limit?: number
  offset?: number
}

export function fetchContactInfo(params?: FetchContactInfoParams) {
  return apiGet<ContactInfoResponse>('/api/customers/contact-info', {
    status: params?.status || undefined,
    search: params?.search || undefined,
    limit: params?.limit ?? 50,
    offset: params?.offset ?? 0,
  })
}

export async function fetchAllContactInfo(
  params: Omit<FetchContactInfoParams, 'limit' | 'offset'> = {}
) {
  const items = await fetchAllPages<DbContactInfo>({
    pageSize: 200,
    itemsKey: 'items',
    fetchPage: ({ limit, offset }) =>
      fetchContactInfo({ ...params, limit, offset }),
  })
  return { count: items.length, items }
}

/** Run async work over items with a fixed concurrency limit. */
export async function mapPool<T, R>(
  items: T[],
  concurrency: number,
  mapper: (item: T, index: number) => Promise<R>
): Promise<R[]> {
  const results: R[] = new Array(items.length)
  let next = 0

  async function worker() {
    while (next < items.length) {
      const index = next++
      results[index] = await mapper(items[index], index)
    }
  }

  const workers = Array.from(
    { length: Math.min(concurrency, Math.max(items.length, 1)) },
    () => worker()
  )
  await Promise.all(workers)
  return results
}
