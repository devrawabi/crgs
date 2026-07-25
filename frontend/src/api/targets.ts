import { apiDelete, apiGet, apiPost } from './client'
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

export function fetchSalesTargets() {
  return apiGet<SalesTargetsResponse>('/api/targets/sales')
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

export function fetchProductTargets() {
  return apiGet<ProductTargetsResponse>('/api/targets/products')
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

export function fetchCustomerTargets() {
  return apiGet<CustomerTargetsResponse>('/api/targets/customers')
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
