import { apiGet } from './client'

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
  items: DbProductReview[]
}

export interface FetchProductReviewsParams {
  search?: string
  employeeCode?: string
  route?: string
}

export function fetchProductReviews(params?: FetchProductReviewsParams) {
  return apiGet<ProductReviewsResponse>('/api/product-reviews', {
    search: params?.search || undefined,
    employeeCode: params?.employeeCode || undefined,
    route: params?.route || undefined,
  })
}
