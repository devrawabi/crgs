import { apiDelete, apiGet, apiPost } from './client'
import { fetchAllPages } from './paginate'
import type { CustomerTargetType, ProductTargetType, TargetPeriod } from '../types'

export interface DbSalesTarget {
  employeeCode: string
  period: TargetPeriod
  targetAmount: number
  achievedAmount: number
  remainingAmount?: number
  routeNo: string
  dueDate: string
}

export interface SalesTargetsResponse {
  count: number
  offset?: number
  limit?: number
  has_more?: boolean
  targets: DbSalesTarget[]
}

export interface CreateSalesTargetPayload {
  employeeCode: string
  routeNo: string
  period: TargetPeriod
  targetAmount: number
  achievedAmount?: number
  dueDate: string
}

export interface CreateSalesTargetResponse {
  employeeCode: string
  routeNo: string
  period: TargetPeriod
  targetAmount: number
  achievedAmount: number
  dueDate: string
}

export interface FetchSalesTargetsParams {
  employeeCode?: string
  period?: TargetPeriod
  limit?: number
  offset?: number
}

export function fetchSalesTargets(params: FetchSalesTargetsParams = {}) {
  return apiGet<SalesTargetsResponse>('/api/targets/sales', {
    employeeCode: params.employeeCode,
    period: params.period,
    limit: params.limit ?? 200,
    offset: params.offset ?? 0,
  })
}

/** Walk pages when a screen still needs the full filtered set. */
export async function fetchAllSalesTargets(
  params: Omit<FetchSalesTargetsParams, 'limit' | 'offset'> = {}
) {
  const targets = await fetchAllPages<DbSalesTarget>({
    pageSize: 200,
    itemsKey: 'targets',
    fetchPage: ({ limit, offset }) =>
      fetchSalesTargets({ ...params, limit, offset }) as Promise<
        Record<string, unknown>
      >,
  })
  return { count: targets.length, targets }
}

export function createSalesTarget(payload: CreateSalesTargetPayload) {
  return apiPost<CreateSalesTargetResponse>('/api/targets/sales', payload)
}

/** Rebuild ACHIEVED from saved order totals. */
export function recalculateSalesTargets(employeeCode?: string) {
  return apiPost<SalesTargetsResponse>('/api/targets/sales/recalculate', {
    ...(employeeCode ? { employeeCode } : {}),
  })
}

export interface DeleteSalesTargetPayload {
  employeeCode: string
  routeNo: string
  period: TargetPeriod
  dueDate: string
}

export function deleteSalesTarget(payload: DeleteSalesTargetPayload) {
  return apiDelete<{ deleted: number }>('/api/targets/sales', payload)
}

export interface DbProductTarget {
  employeeCode: string
  products: string[]
  productNames?: string[]
  baseUoms?: string[]
  retailPrices?: number[]
  type: ProductTargetType
  targetValue: number
  achievedValue: number
  routeNo: string
}

export interface ProductTargetsResponse {
  count: number
  offset?: number
  limit?: number
  has_more?: boolean
  targets: DbProductTarget[]
}

export interface CreateProductTargetPayload {
  employeeCode: string
  routeNo: string
  type: ProductTargetType
  targetValue: number
  achievedValue?: number
  productNames: string[]
}

export interface CreateProductTargetResponse {
  employeeCode: string
  products: string[]
  type: ProductTargetType
  targetValue: number
  achievedValue: number
  routeNo: string
}

export interface FetchProductTargetsParams {
  employeeCode?: string
  limit?: number
  offset?: number
}

export function fetchProductTargets(params: FetchProductTargetsParams = {}) {
  return apiGet<ProductTargetsResponse>('/api/targets/products', {
    employeeCode: params.employeeCode,
    limit: params.limit ?? 200,
    offset: params.offset ?? 0,
  })
}

export async function fetchAllProductTargets(
  params: Omit<FetchProductTargetsParams, 'limit' | 'offset'> = {}
) {
  const targets = await fetchAllPages<DbProductTarget>({
    pageSize: 200,
    itemsKey: 'targets',
    fetchPage: ({ limit, offset }) =>
      fetchProductTargets({ ...params, limit, offset }) as Promise<
        Record<string, unknown>
      >,
  })
  return { count: targets.length, targets }
}

export function createProductTarget(payload: CreateProductTargetPayload) {
  return apiPost<CreateProductTargetResponse>('/api/targets/products', {
    ...payload,
    products: payload.productNames,
  })
}

export interface DeleteProductTargetPayload {
  employeeCode: string
  routeNo: string
  type: ProductTargetType
  products: string[]
}

export function deleteProductTarget(payload: DeleteProductTargetPayload) {
  return apiDelete<{ deleted: number }>('/api/targets/products', payload)
}

export interface DbCustomerTarget {
  employeeCode: string
  type: CustomerTargetType
  targetCount: number
  achievedCount: number
  targetAmount: number
  period: TargetPeriod
  routeNo: string
}

export interface CustomerTargetsResponse {
  count: number
  offset?: number
  limit?: number
  has_more?: boolean
  /** Total CRGS_CONTACTINFO rows with FLAG = N (add customers). */
  newCustomersFlagN?: number
  targets: DbCustomerTarget[]
}

export interface CreateCustomerTargetPayload {
  employeeCode: string
  routeNo: string
  type: CustomerTargetType
  targetCount: number
  achievedCount?: number
  targetAmount: number
  period: TargetPeriod
}

export interface CreateCustomerTargetResponse {
  employeeCode: string
  type: CustomerTargetType
  targetCount: number
  achievedCount: number
  targetAmount: number
  period: TargetPeriod
  routeNo: string
}

export interface FetchCustomerTargetsParams {
  employeeCode?: string
  period?: TargetPeriod
  limit?: number
  offset?: number
  /** Persist FLAG=N count into ACHIEVED for new_acquisition rows. */
  refreshAchieved?: boolean
}

export function fetchCustomerTargets(params: FetchCustomerTargetsParams = {}) {
  return apiGet<CustomerTargetsResponse>('/api/targets/customers', {
    employeeCode: params.employeeCode,
    period: params.period,
    limit: params.limit ?? 200,
    offset: params.offset ?? 0,
    refreshAchieved: params.refreshAchieved ? 'true' : undefined,
  })
}

export async function fetchAllCustomerTargets(
  params: Omit<FetchCustomerTargetsParams, 'limit' | 'offset'> = {}
) {
  let newCustomersFlagN = 0
  const targets = await fetchAllPages<DbCustomerTarget>({
    pageSize: 200,
    itemsKey: 'targets',
    fetchPage: async ({ limit, offset }) => {
      const response = await fetchCustomerTargets({
        ...params,
        // Refresh once on the first page only.
        refreshAchieved: params.refreshAchieved && offset === 0,
        limit,
        offset,
      })
      if (typeof response.newCustomersFlagN === 'number') {
        newCustomersFlagN = response.newCustomersFlagN
      }
      return response as unknown as Record<string, unknown>
    },
  })
  return { count: targets.length, newCustomersFlagN, targets }
}

export function createCustomerTarget(payload: CreateCustomerTargetPayload) {
  return apiPost<CreateCustomerTargetResponse>('/api/targets/customers', payload)
}

export interface DeleteCustomerTargetPayload {
  employeeCode: string
  routeNo: string
  type: CustomerTargetType
  period: TargetPeriod
}

export function deleteCustomerTarget(payload: DeleteCustomerTargetPayload) {
  return apiDelete<{ deleted: number }>('/api/targets/customers', payload)
}
