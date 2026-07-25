import { type ReactNode } from 'react'

interface CardProps {
  title?: string
  subtitle?: string
  action?: ReactNode
  children: ReactNode
  className?: string
  scrollable?: boolean
}

export function Card({
  title,
  subtitle,
  action,
  children,
  className = '',
  scrollable = false,
}: CardProps) {
  return (
    <div
      className={`bg-white rounded-xl border border-gray-200 shadow-sm ${
        scrollable ? 'flex flex-col min-h-0 h-full overflow-hidden' : ''
      } ${className}`}
    >
      {(title || action) && (
        <div className="shrink-0 flex items-center justify-between px-6 py-4 border-b border-gray-100">
          <div>
            {title && <h3 className="text-base font-semibold text-gray-900">{title}</h3>}
            {subtitle && <p className="text-sm text-gray-500 mt-0.5">{subtitle}</p>}
          </div>
          {action}
        </div>
      )}
      <div className={`p-6 ${scrollable ? 'flex-1 min-h-0 overflow-y-auto' : ''}`}>{children}</div>
    </div>
  )
}

interface StatCardProps {
  label: string
  value: string | number
  change?: string
  positive?: boolean
  icon?: ReactNode
}

export function StatCard({ label, value, change, positive, icon }: StatCardProps) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 shadow-sm p-5">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-gray-500">{label}</p>
          <p className="text-2xl font-bold text-gray-900 mt-1">{value}</p>
          {change && (
            <p className={`text-xs mt-1 ${positive ? 'text-green-600' : 'text-red-600'}`}>{change}</p>
          )}
        </div>
        {icon && <div className="p-2.5 rounded-lg bg-primary-50 text-primary-600">{icon}</div>}
      </div>
    </div>
  )
}
