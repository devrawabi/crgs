import { apiGet } from './client'
import type { TaskType } from '../types'

export interface DashboardSalesBucket {
  name: string
  employeeCode?: string
  target: number
  achieved: number
}

export interface DashboardTaskBreakdown {
  type: string
  count: number
}

export interface DashboardRecentTask {
  type: TaskType | string
  employeeCode: string
  executiveName: string
  routeNo: string
  status: string
  dueDate: string
}

export interface DashboardSummary {
  activeExecutives: number
  assignedRoutes: number
  sales: {
    period: string
    targetTotal: number
    achievedTotal: number
    byExecutive: DashboardSalesBucket[]
    byRoute: DashboardSalesBucket[]
  }
  products: {
    targetTotal: number
    achievedTotal: number
  }
  customers: {
    targetTotal: number
    achievedTotal: number
  }
  tasks: {
    total: number
    overdue: number
    breakdown: DashboardTaskBreakdown[]
    recent: DashboardRecentTask[]
  }
}

export function fetchDashboardSummary() {
  return apiGet<DashboardSummary>('/api/dashboard/summary')
}
