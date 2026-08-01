import { apiGet } from './client'

export interface DbItemMaster {
  itemcode: string
  itemname: string
  baseuom?: string
  retailprice?: number
  currentstock?: number
  quantitylimit?: number
  last_updated?: string
}

export interface ItemsResponse {
  count: number
  offset: number
  limit: number
  has_more?: boolean
  delta_supported?: boolean
  server_time?: string
  items: DbItemMaster[]
}

export interface FetchItemsParams {
  search?: string
  limit?: number
  offset?: number
  updatedSince?: string
}

export function fetchItems(params: FetchItemsParams = {}) {
  return apiGet<ItemsResponse>('/api/items', {
    search: params.search,
    limit: params.limit ?? 750,
    offset: params.offset ?? 0,
    updated_since: params.updatedSince,
  })
}

export function formatItemLabel(item: DbItemMaster) {
  const code = item.itemcode.trim()
  const name = item.itemname.trim()
  if (code && name) return `${code} — ${name}`
  return name || code
}
