import { useCallback, useEffect, useMemo, useState } from 'react'
import { Eye, Loader2, Search } from 'lucide-react'
import { PageHeader, inputClass } from '../components/ui/PageHeader'
import { Button } from '../components/ui/Button'
import { Modal } from '../components/ui/Modal'
import { Card } from '../components/ui/Card'
import { Table } from '../components/ui/Table'
import {
  fetchAllProductReviews,
  productReviewImageSrc,
  type DbProductReview,
} from '../api/productReviews'
import { AuthenticatedImage } from '../components/common/AuthenticatedImage'

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[130px_1fr] gap-3 text-sm">
      <dt className="text-gray-500 font-medium">{label}</dt>
      <dd className="text-gray-900 break-words">{value || '—'}</dd>
    </div>
  )
}

export function ProductReviewReportPage() {
  const [items, setItems] = useState<DbProductReview[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<DbProductReview | null>(null)

  const loadReviews = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchAllProductReviews()
      setItems(data.items ?? [])
    } catch (err) {
      setItems([])
      setError(err instanceof Error ? err.message : 'Failed to load product reviews')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadReviews()
  }, [loadReviews])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return items
    return items.filter((item) =>
      [
        item.employeeCode,
        item.route,
        item.customerCode,
        item.customerName,
        item.itemCode,
        item.itemName,
        item.reason,
      ]
        .join(' ')
        .toLowerCase()
        .includes(q)
    )
  }, [items, search])

  return (
    <div className="flex-1 overflow-auto min-h-0">
      <PageHeader
        title="Product Review Report"
        description="Product reviews and item name issues submitted by sales executives"
        action={
          <Button variant="secondary" onClick={loadReviews} disabled={loading}>
            {loading ? <Loader2 size={16} className="animate-spin" /> : null}
            Refresh
          </Button>
        }
      />

      <div className="relative mb-6 max-w-md">
        <Search
          size={16}
          className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
        />
        <input
          className={inputClass + ' pl-9'}
          placeholder="Search by customer, product, employee, route..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <Card>
        {error && <p className="mb-4 text-sm text-red-600">{error}</p>}
        <p className="mb-3 text-sm text-gray-500">
          {loading ? 'Loading…' : `${filtered.length} review${filtered.length === 1 ? '' : 's'}`}
        </p>
        <Table
          columns={[
            { key: 'employee', label: 'Employee' },
            { key: 'route', label: 'Route' },
            { key: 'customer', label: 'Customer' },
            { key: 'product', label: 'Product' },
            { key: 'reason', label: 'Reason' },
            { key: 'actions', label: '' },
          ]}
        >
          {loading ? (
            <tr>
              <td colSpan={6} className="px-4 py-10 text-center text-gray-400">
                <span className="inline-flex items-center gap-2">
                  <Loader2 size={16} className="animate-spin" />
                  Loading product reviews...
                </span>
              </td>
            </tr>
          ) : filtered.length === 0 ? (
            <tr>
              <td colSpan={6} className="px-4 py-10 text-center text-gray-400">
                No product reviews found
              </td>
            </tr>
          ) : (
            filtered.map((item, index) => (
              <tr
                key={`${item.employeeCode}-${item.customerCode}-${item.itemCode}-${index}`}
                className="hover:bg-gray-50 cursor-pointer"
                onClick={() => setSelected(item)}
              >
                <td className="px-4 py-3 font-mono text-xs text-gray-600">
                  {item.employeeCode || '—'}
                </td>
                <td className="px-4 py-3 text-sm text-gray-600">{item.route || '—'}</td>
                <td className="px-4 py-3">
                  <div className="font-medium text-gray-900">
                    {item.customerName || '—'}
                  </div>
                  <div className="text-xs text-gray-500 font-mono">
                    {item.customerCode || '—'}
                  </div>
                </td>
                <td className="px-4 py-3">
                  <div className="text-sm text-gray-900">{item.itemName || '—'}</div>
                  <div className="text-xs text-gray-500 font-mono">
                    {item.itemCode || '—'}
                  </div>
                </td>
                <td className="px-4 py-3 text-sm text-gray-600 max-w-[240px] truncate">
                  {item.reason || '—'}
                </td>
                <td className="px-4 py-3 text-right" onClick={(e) => e.stopPropagation()}>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    onClick={() => setSelected(item)}
                    aria-label="View review"
                  >
                    <Eye className="h-4 w-4" />
                  </Button>
                </td>
              </tr>
            ))
          )}
        </Table>
      </Card>

      <Modal
        open={!!selected}
        onClose={() => setSelected(null)}
        title="Product Review Details"
        wide
      >
        {selected && (
          <div className="space-y-5">
            <dl className="space-y-3">
              <DetailRow label="Employee Code" value={selected.employeeCode} />
              <DetailRow label="Route" value={selected.route} />
              <DetailRow label="Customer Code" value={selected.customerCode} />
              <DetailRow label="Customer Name" value={selected.customerName} />
              <DetailRow label="Item Code" value={selected.itemCode} />
              <DetailRow label="Item Name" value={selected.itemName} />
              <DetailRow label="Reason" value={selected.reason} />
            </dl>
            {productReviewImageSrc(selected.imageUrl) ? (
              <div className="space-y-2">
                <p className="text-sm font-medium text-gray-500">Photo</p>
                <AuthenticatedImage
                  src={productReviewImageSrc(selected.imageUrl)!}
                  alt="Product review attachment"
                  className="max-h-72 w-full rounded-lg border border-gray-200 object-contain bg-gray-50"
                />
              </div>
            ) : null}
            <div className="flex justify-end pt-2">
              <Button type="button" variant="secondary" onClick={() => setSelected(null)}>
                Close
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  )
}
