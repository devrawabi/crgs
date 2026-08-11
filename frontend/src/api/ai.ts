import { apiGet, apiPost } from './client'

export interface AiChatMessage {
  role: 'user' | 'assistant'
  content: string
}

export interface AiOrderContext {
  invoiceNo?: string
  invoiceStatus?: string
  invoiceType?: string
  saleChannel?: string
  priceType?: string
  customer?: {
    code?: string
    name?: string
    route?: string
    mobile?: string
    creditLimit?: number | string | null
    creditAmount?: number | string | null
    lastPurchaseDate?: string | null
    lastPurchaseAmount?: number | string | null
  }
  salesman?: {
    code?: string
    name?: string
  }
  lines?: Array<{
    itemCode: string
    description: string
    uom: string
    qty: number
    rate: number
    discount: number
    amount: number
  }>
  totals?: {
    discount?: number
    netTotal?: number
    vatAmount?: number
    sugarTax?: number
    grandTotal?: number
  }
}

/** Reply language for the Call Center AI (`auto` = detect from message). */
export type AiLanguage = 'auto' | 'en' | 'ar' | 'hi' | 'ml' | 'ur' | 'tl'

export interface AiChatRequest {
  message: string
  messages?: AiChatMessage[]
  context?: AiOrderContext
  language?: AiLanguage | string
}

export interface AiChatResponse {
  reply: string
  model?: string
  language?: string
  languageSelected?: string
}

export function postAiChat(body: AiChatRequest) {
  return apiPost<AiChatResponse>('/api/ai/chat', body)
}

export interface AiStatusResponse {
  status: string
  configured: boolean
  model?: string | null
}

export function fetchAiStatus() {
  return apiGet<AiStatusResponse>('/api/ai/status')
}
