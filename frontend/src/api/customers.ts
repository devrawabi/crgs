import { apiGet } from './client'

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

/** One grouped Oracle query for many routes (reports dashboard). */
export function fetchCustomerStatsBatch(routes: string[], missingDays?: number) {
  return apiGet<CustomerStatsBatchResponse>('/api/customers/stats', {
    routes: routes.join(','),
    missing_days: missingDays,
  })
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
  items: DbContactInfo[]
}

export interface FetchContactInfoParams {
  status?: string
  search?: string
}

export function fetchContactInfo(params?: FetchContactInfoParams) {
  return apiGet<ContactInfoResponse>('/api/customers/contact-info', {
    status: params?.status || undefined,
    search: params?.search || undefined,
  })
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
