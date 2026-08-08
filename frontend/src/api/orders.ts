import { apiGet } from './client'
import { fetchAllPages } from './paginate'

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
  offset: number
  limit: number
  has_more: boolean
  orders: DbOrder[]
}

export interface FetchOrdersParams {
  employeeCode?: string
  limit?: number
  offset?: number
  /** When false, skips order-line / ITEMNAME join (lighter list payloads). */
  includeDetails?: boolean
}

export function fetchOrders(params: FetchOrdersParams = {}) {
  return apiGet<OrdersResponse>('/api/orders', {
    employeeCode: params.employeeCode,
    limit: params.limit ?? 50,
    offset: params.offset ?? 0,
    includeDetails:
      params.includeDetails === false
        ? 'false'
        : params.includeDetails === true
          ? 'true'
          : undefined,
  })
}

/** Load every order page (reports / executive detail). */
export async function fetchAllOrders(
  params: Omit<FetchOrdersParams, 'limit' | 'offset'> = {}
) {
  // Default headers-only: skips ORDERDTL + ITEMMASTER join (major live load cut).
  const includeDetails = params.includeDetails === true
  const orders = await fetchAllPages<DbOrder>({
    pageSize: 200,
    maxPages: includeDetails ? 20 : 40,
    itemsKey: 'orders',
    fetchPage: ({ limit, offset }) =>
      fetchOrders({
        ...params,
        includeDetails,
        limit,
        offset,
      }),
  })
  return { count: orders.length, orders }
}
