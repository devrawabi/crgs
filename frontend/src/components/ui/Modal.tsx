import { type ReactNode } from 'react'
import { X } from 'lucide-react'

interface ModalProps {
  open: boolean
  onClose: () => void
  title: string
  children: ReactNode
  wide?: boolean
  /** Larger modal for forms with wide content (e.g. product pickers) */
  xl?: boolean
}

const modalWidthClass = (wide?: boolean, xl?: boolean) => {
  if (xl) return 'w-full max-w-6xl'
  if (wide) return 'w-full max-w-2xl'
  return 'w-full max-w-lg'
}

export function Modal({ open, onClose, title, children, wide, xl }: ModalProps) {
  if (!open) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/50" onClick={onClose} />
      <div
        className={`relative bg-white rounded-xl shadow-xl max-h-[90vh] overflow-y-auto ${modalWidthClass(wide, xl)}`}
      >
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">{title}</h2>
          <button onClick={onClose} className="p-1 rounded-lg hover:bg-gray-100 text-gray-500">
            <X size={20} />
          </button>
        </div>
        <div className="px-6 py-4">{children}</div>
      </div>
    </div>
  )
}
