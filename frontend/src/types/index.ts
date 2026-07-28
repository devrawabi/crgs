export type UserRole = 'admin' | 'sales_executive'
export type UserStatus = 'active' | 'inactive'
export type RiskLevel = 'low' | 'medium' | 'high' | 'critical'
export type TargetPeriod = 'daily' | 'weekly' | 'monthly'
export type ProductTargetType = 'quantity' | 'volume' | 'new_promotion' | 'replacement' | 'own_products'
export type CustomerTargetType =
  | 'new_acquisition'
  | 'missing_recovery'
  | 'outstanding_collection'
  | 'purchase_limit'
export type TaskType =
  | 'missing_customer_followup'
  | 'outstanding_collection_followup'
  | 'new_product_introduction'
  | 'product_replacement_campaign'
  | 'customer_visit_campaign'
  | 'own_products'
  | 'market_research'
  | 'other'
export type TaskStatus = 'pending' | 'in_progress' | 'completed' | 'overdue'

export interface User {
  id: string
  username: string
  employeeCode: string
  password: string
  role: UserRole
  status: UserStatus
  routeIds: string[]
  assignedRouteNos: string[]
  createdAt: string
}

export interface Customer {
  id: string
  name: string
  contact: string
  address: string
  routeId: string
  executiveId: string
  riskLevel: RiskLevel
  isMissing: boolean
  lastOrderDate: string | null
  outstandingAmount: number
  purchaseLimit: number
}

export interface Route {
  id: string
  name: string
  code: string
  area: string
  executiveId: string | null
  customerCount: number
}

export interface SalesTarget {
  id: string
  executiveId: string
  routeNo: string
  routeName: string
  routeNos?: string[]
  routeNames?: string[]
  period: TargetPeriod
  targetAmount: number
  achievedAmount: number
  startDate: string
  endDate: string
}

export interface ProductTarget {
  id: string
  executiveId: string
  routeNo: string
  routeName: string
  routeNos?: string[]
  routeNames?: string[]
  /** Summary label for charts and single-product rows */
  productName: string
  /** All products in this target group (one row in the list) */
  productNames?: string[]
  type: ProductTargetType
  targetValue: number
  achievedValue: number
  period: TargetPeriod
}

export interface CustomerTarget {
  id: string
  executiveId: string
  routeNo: string
  routeName: string
  routeNos?: string[]
  routeNames?: string[]
  type: CustomerTargetType
  targetCount: number
  achievedCount: number
  period: TargetPeriod
}

export interface Product {
  id: string
  name: string
  sku: string
  category: string
}

export interface Task {
  id: string
  title: string
  type: TaskType
  executiveId: string
  routeId: string | null
  routeNos?: string[]
  routeNames?: string[]
  customerIds: string[]
  status: TaskStatus
  dueDate: string
  createdAt: string
  oldProductIds: string[]
  replaceProductIds: string[]
  notes: string
}

export interface MarketIntel {
  id: string
  executiveId: string
  routeId: string
  competitorActivity: string
  demandTrend: string
  pricingInsight: string
  submittedAt: string
}
