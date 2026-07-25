import { type ReactNode } from 'react'

interface PageHeaderProps {
  title: string
  description?: string
  action?: ReactNode
}

export function PageHeader({ title, description, action }: PageHeaderProps) {
  return (
    <div className={`shrink-0 ${description ? 'mb-6' : 'mb-4'}`}>
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
        <h1 className="text-xl font-semibold text-gray-900 tracking-tight">{title}</h1>
        {action}
      </div>
      {description && <p className="text-sm text-gray-500 mt-1.5">{description}</p>}
    </div>
  )
}

interface FormFieldProps {
  label: string
  children: ReactNode
  required?: boolean
}

export function FormField({ label, children, required }: FormFieldProps) {
  return (
    <div className="space-y-1.5">
      <label className="block text-sm font-medium text-gray-700">
        {label}
        {required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      {children}
    </div>
  )
}

export const inputClass =
  'w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-primary-500'

export const selectClass = inputClass
