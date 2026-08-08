import { apiGet } from './client'
import { fetchAllPages } from './paginate'

export interface DbProductReview {
  employeeCode: string
  route: string
  customerCode: string
  customerName: string
  itemCode: string
  itemName: string
  reason: string
  imagePath?: string | null
  imageUrl?: string | null
}

export function productReviewImageSrc(imageUrl?: string | null): string | null {
  if (!imageUrl) return null
  if (/^https?:\/\//i.test(imageUrl)) return imageUrl
  const apiBase = import.meta.env.VITE_API_URL ?? ''
  return `${apiBase}${imageUrl}`
}

export interface ProductReviewsResponse {
  count: number
  offset?: number
  limit?: number
  has_more?: boolean
  items: DbProductReview[]
}

export interface FetchProductReviewsParams {
  search?: string
  employeeCode?: string
  route?: string
  limit?: number
  offset?: number
}

export function fetchProductReviews(params: FetchProductReviewsParams = {}) {
  return apiGet<ProductReviewsResponse>('/api/product-reviews', {
    search: params.search || undefined,
    employeeCode: params.employeeCode || undefined,
    route: params.route || undefined,
    limit: params.limit ?? 50,
    offset: params.offset ?? 0,
  })
}

export async function fetchAllProductReviews(
  params: Omit<FetchProductReviewsParams, 'limit' | 'offset'> = {}
) {
  const items = await fetchAllPages<DbProductReview>({
    pageSize: 200,
    itemsKey: 'items',
    fetchPage: ({ limit, offset }) =>
      fetchProductReviews({ ...params, limit, offset }),
  })
  return { count: items.length, items }
}
