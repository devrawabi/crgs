import { Loader2 } from 'lucide-react'
import { Button } from './Button'

interface LoadingBlockProps {
  label?: string
  className?: string
}

/** Centered spinner + label for card/page loading. */
export function LoadingBlock({
  label = 'Loading...',
  className = '',
}: LoadingBlockProps) {
  return (
    <div
      className={`flex items-center justify-center gap-2 px-4 py-8 text-sm text-gray-500 ${className}`}
    >
      <Loader2 className="h-4 w-4 shrink-0 animate-spin text-primary-600" />
      <span>{label}</span>
    </div>
  )
}

interface TableLoadingRowProps {
  colSpan: number
  label?: string
}

/** Single table row used while the first page loads. */
export function TableLoadingRow({
  colSpan,
  label = 'Loading...',
}: TableLoadingRowProps) {
  return (
    <tr>
      <td colSpan={colSpan} className="px-4 py-8 text-center text-gray-400">
        <span className="inline-flex items-center justify-center gap-2">
          <Loader2 className="h-4 w-4 animate-spin text-primary-600" />
          {label}
        </span>
      </td>
    </tr>
  )
}

interface TableEmptyRowProps {
  colSpan: number
  label?: string
}

export function TableEmptyRow({
  colSpan,
  label = 'No results found',
}: TableEmptyRowProps) {
  return (
    <tr>
      <td colSpan={colSpan} className="px-4 py-8 text-center text-gray-400">
        {label}
      </td>
    </tr>
  )
}

interface LoadMoreButtonProps {
  hasMore: boolean
  loading: boolean
  onClick: () => void
  label?: string
  loadingLabel?: string
}

/** Consistent “Load more” control for paginated lists. */
export function LoadMoreButton({
  hasMore,
  loading,
  onClick,
  label = 'Load more',
  loadingLabel = 'Loading…',
}: LoadMoreButtonProps) {
  if (!hasMore) return null
  return (
    <div className="mt-4 flex justify-center">
      <Button
        type="button"
        variant="secondary"
        disabled={loading}
        onClick={onClick}
      >
        {loading ? (
          <>
            <Loader2 className="h-4 w-4 animate-spin" />
            {loadingLabel}
          </>
        ) : (
          label
        )}
      </Button>
    </div>
  )
}

interface InlineLoadingProps {
  label?: string
  className?: string
}

/** Compact spinner for inline/banner loading messages. */
export function InlineLoading({
  label = 'Loading...',
  className = '',
}: InlineLoadingProps) {
  return (
    <p
      className={`mb-4 inline-flex items-center gap-2 text-sm text-gray-500 ${className}`}
    >
      <Loader2 className="h-4 w-4 animate-spin text-primary-600" />
      {label}
    </p>
  )
}
