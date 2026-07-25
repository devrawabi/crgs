import { apiGet } from './client'

export interface DbItemMaster {
  itemcode: string
  itemname: string
  baseuom?: string
  retailprice?: number
}

export interface ItemsResponse {
  count: number
  offset: number
  limit: number
  items: DbItemMaster[]
}

export interface FetchItemsParams {
  search?: string
  limit?: number
  offset?: number
}

export function fetchItems(params: FetchItemsParams = {}) {
  return apiGet<ItemsResponse>('/api/items', {
    search: params.search,
    limit: params.limit ?? 500,
    offset: params.offset ?? 0,
  })
}

export function formatItemLabel(item: DbItemMaster) {
  const code = item.itemcode.trim()
  const name = item.itemname.trim()
  if (code && name) return `${code} — ${name}`
  return name || code
}
