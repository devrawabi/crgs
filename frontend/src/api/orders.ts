import { apiGet } from './client'

export interface DbOrderItem {
  itemCode: string
  itemName: string
  qty: number
  uom: string
  price: number
  amount: number
}

export interface DbOrder {
  orderNo: string
  orderDate: string
  employeeCode: string
  customerCode: string
  customerName: string
  route: string
  totalAmount: number
  itemCount: number
  expectedDate: string
  items: DbOrderItem[]
}

export interface OrdersResponse {
  count: number
  orders: DbOrder[]
}

export function fetchOrders(params?: { employeeCode?: string }) {
  return apiGet<OrdersResponse>('/api/orders', {
    employeeCode: params?.employeeCode,
  })
}
