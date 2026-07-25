interface BadgeProps {
  label: string
  className?: string
}

export function Badge({ label, className = 'bg-gray-100 text-gray-700' }: BadgeProps) {
  return (
    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${className}`}>
      {label}
    </span>
  )
}
