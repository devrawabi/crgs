import { useCallback, useEffect, useMemo, useState } from 'react'
import { Download, Eye, Loader2, Search } from 'lucide-react'
import { Card } from '../ui/Card'
import { Table } from '../ui/Table'
import { Button } from '../ui/Button'
import { Modal } from '../ui/Modal'
import { inputClass } from '../ui/PageHeader'
import {
  fetchProductReviews,
  productReviewImageSrc,
  type DbProductReview,
} from '../../api/productReviews'
import { fetchUsers, type DbLoginUser } from '../../api/users'
import { downloadProductReviewsExcel } from '../../utils/downloadProductReviewsExcel'

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[130px_1fr] gap-3 text-sm">
      <dt className="text-gray-500 font-medium">{label}</dt>
      <dd className="text-gray-900 break-words">{value || '—'}</dd>
    </div>
  )
}

interface ProductReviewsReportProps {
  /** When provided, skip fetching users and use these for name lookup. */
  executives?: DbLoginUser[]
}

export function ProductReviewsReport({ executives }: ProductReviewsReportProps) {
  const [items, setItems] = useState<DbProductReview[]>([])
  const [users, setUsers] = useState<DbLoginUser[]>(executives ?? [])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<DbProductReview | null>(null)

  const loadReviews = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const needsUsers = !executives
      const [reviewsRes, usersRes] = await Promise.all([
        fetchProductReviews(),
        needsUsers
          ? fetchUsers({ activeOnly: false })
          : Promise.resolve({ users: executives }),
      ])
      setItems(reviewsRes.items ?? [])
      setUsers(usersRes.users ?? [])
    } catch (err) {
      setItems([])
      setError(err instanceof Error ? err.message : 'Failed to load product reviews')
    } finally {
      setLoading(false)
    }
  }, [executives])

  useEffect(() => {
    if (executives) setUsers(executives)
  }, [executives])

  useEffect(() => {
    loadReviews()
  }, [loadReviews])

  const nameByCode = useMemo(() => {
    const map = new Map<string, string>()
    for (const u of users) {
      const code = u.employeecode.trim().toUpperCase()
      if (code) map.set(code, u.username.trim())
    }
    return map
  }, [users])

  const employeeName = useCallback(
    (code: string) =>
      nameByCode.get(code.trim().toUpperCase()) || '',
    [nameByCode]
  )

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return items
    return items.filter((item) => {
      const name = employeeName(item.employeeCode)
      return [
        item.employeeCode,
        name,
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
    })
  }, [items, search, employeeName])

  const handleDownloadExcel = () => {
    downloadProductReviewsExcel(
      filtered.map((r) => ({
        ...r,
        employeeName: employeeName(r.employeeCode),
      }))
    )
  }

  return (
    <div className="space-y-6">
      <Card
        title="Product Reviews — All Users"
        subtitle="Detailed product reviews submitted by every sales executive"
      >
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <div className="relative max-w-md flex-1">
            <Search
              size={16}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
            />
            <input
              className={inputClass + ' pl-9'}
              placeholder="Search by employee, customer, product, route..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
          <div className="flex flex-wrap gap-2">
            <Button variant="secondary" onClick={loadReviews} disabled={loading}>
              {loading ? <Loader2 size={16} className="animate-spin" /> : null}
              Refresh
            </Button>
            <Button
              onClick={handleDownloadExcel}
              disabled={loading || filtered.length === 0}
            >
              <Download size={16} />
              Download Excel
            </Button>
          </div>
        </div>
      </Card>

      <Card>
        {error && <p className="mb-4 text-sm text-red-600">{error}</p>}
        <p className="mb-3 text-sm text-gray-500">
          {loading
            ? 'Loading…'
            : `${filtered.length} review${filtered.length === 1 ? '' : 's'}${
                search.trim() ? ' (filtered)' : ''
              }`}
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
            filtered.map((item, index) => {
              const name = employeeName(item.employeeCode)
              return (
                <tr
                  key={`${item.employeeCode}-${item.customerCode}-${item.itemCode}-${index}`}
                  className="hover:bg-gray-50 cursor-pointer"
                  onClick={() => setSelected(item)}
                >
                  <td className="px-4 py-3">
                    <div className="font-medium text-gray-900">
                      {name || item.employeeCode || '—'}
                    </div>
                    {name ? (
                      <div className="text-xs text-gray-500 font-mono">
                        {item.employeeCode}
                      </div>
                    ) : null}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {item.route || '—'}
                  </td>
                  <td className="px-4 py-3">
                    <div className="font-medium text-gray-900">
                      {item.customerName || '—'}
                    </div>
                    <div className="text-xs text-gray-500 font-mono">
                      {item.customerCode || '—'}
                    </div>
                  </td>
                  <td className="px-4 py-3">
                    <div className="text-sm text-gray-900">
                      {item.itemName || '—'}
                    </div>
                    <div className="text-xs text-gray-500 font-mono">
                      {item.itemCode || '—'}
                    </div>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600 max-w-[240px] truncate">
                    {item.reason || '—'}
                  </td>
                  <td
                    className="px-4 py-3 text-right"
                    onClick={(e) => e.stopPropagation()}
                  >
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
              )
            })
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
              <DetailRow
                label="Employee"
                value={
                  employeeName(selected.employeeCode)
                    ? `${employeeName(selected.employeeCode)} (${selected.employeeCode})`
                    : selected.employeeCode
                }
              />
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
                <img
                  src={productReviewImageSrc(selected.imageUrl)!}
                  alt="Product review attachment"
                  className="max-h-72 w-full rounded-lg border border-gray-200 object-contain bg-gray-50"
                />
              </div>
            ) : null}
            <div className="flex justify-end pt-2">
              <Button
                type="button"
                variant="secondary"
                onClick={() => setSelected(null)}
              >
                Close
              </Button>
            </div>
          </div>
        )}
      </Modal>
    </div>
  )
}
