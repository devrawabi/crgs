import { useCallback, useEffect, useMemo, useState } from 'react'
import { Eye, Loader2, Search } from 'lucide-react'
import { PageHeader, inputClass } from '../components/ui/PageHeader'
import { Button } from '../components/ui/Button'
import { Badge } from '../components/ui/Badge'
import { Modal } from '../components/ui/Modal'
import { Card } from '../components/ui/Card'
import { Table } from '../components/ui/Table'
import {
  fetchContactInfo,
  type ContactInfoFlag,
  type DbContactInfo,
} from '../api/customers'

type FlagFilter = 'all' | ContactInfoFlag

const FLAG_LABELS: Record<ContactInfoFlag, string> = {
  N: 'New Customer',
  E: 'Edit Customer',
}

const FLAG_COLORS: Record<ContactInfoFlag, string> = {
  N: 'bg-emerald-100 text-emerald-800',
  E: 'bg-amber-100 text-amber-800',
}

const STATUS_BADGE_COLORS: Record<string, string> = {
  Prospect: 'bg-blue-100 text-blue-800',
  'Follow-up': 'bg-yellow-100 text-yellow-800',
  Converted: 'bg-green-100 text-green-800',
}

function normalizeFlag(value: string): ContactInfoFlag | null {
  const flag = (value ?? '').trim().toUpperCase()
  if (flag === 'N' || flag === 'E') return flag
  return null
}

function formatAmount(value: number | null): string {
  if (value == null || Number.isNaN(value)) return '—'
  return value.toLocaleString(undefined, { maximumFractionDigits: 2 })
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[120px_1fr] gap-3 text-sm">
      <dt className="text-gray-500 font-medium">{label}</dt>
      <dd className="text-gray-900 break-words">{value || '—'}</dd>
    </div>
  )
}

export function CustomerRequestsPage() {
  const [items, setItems] = useState<DbContactInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [flagFilter, setFlagFilter] = useState<FlagFilter>('all')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<DbContactInfo | null>(null)

  const loadRequests = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchContactInfo()
      setItems(data.items ?? [])
    } catch (err) {
      setItems([])
      setError(err instanceof Error ? err.message : 'Failed to load customer requests')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadRequests()
  }, [loadRequests])

  const newCount = useMemo(
    () => items.filter((item) => normalizeFlag(item.flag) === 'N').length,
    [items]
  )
  const editCount = useMemo(
    () => items.filter((item) => normalizeFlag(item.flag) === 'E').length,
    [items]
  )

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return items.filter((item) => {
      const flag = normalizeFlag(item.flag)
      if (flagFilter !== 'all' && flag !== flagFilter) return false
      if (!q) return true
      return [
        item.customerCode,
        item.customerName,
        item.shopName,
        item.contactNumber,
        item.location,
        item.address,
        item.businessType,
        item.products,
        item.remarks,
        item.status,
      ]
        .join(' ')
        .toLowerCase()
        .includes(q)
    })
  }, [items, flagFilter, search])

  const selectedFlag = selected ? normalizeFlag(selected.flag) : null

  return (
    <div className="flex-1 overflow-auto min-h-0">
      <PageHeader
        title="Customer Request"
        description="Review new customer and edit requests submitted by sales executives"
        action={
          <Button variant="secondary" onClick={loadRequests} disabled={loading}>
            {loading ? <Loader2 size={16} className="animate-spin" /> : null}
            Refresh
          </Button>
        }
      />

      <div className="flex flex-wrap gap-2 mb-4">
        {(
          [
            { key: 'all' as const, label: 'All', count: items.length },
            { key: 'N' as const, label: 'New', count: newCount },
            { key: 'E' as const, label: 'Edit', count: editCount },
          ] as const
        ).map((chip) => (
          <button
            key={chip.key}
            type="button"
            onClick={() => setFlagFilter(chip.key)}
            className={`px-3 py-1.5 rounded-lg text-sm font-medium transition-colors ${
              flagFilter === chip.key
                ? 'bg-primary-600 text-white'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }`}
          >
            {chip.label} ({chip.count})
          </button>
        ))}
      </div>

      <div className="relative mb-6 max-w-md">
        <Search
          size={16}
          className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
        />
        <input
          className={inputClass + ' pl-9'}
          placeholder="Search by name, shop, mobile, location..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <Card>
        {error && <p className="mb-4 text-sm text-red-600">{error}</p>}
        <Table
          columns={[
            { key: 'flag', label: 'Request' },
            { key: 'code', label: 'Code' },
            { key: 'name', label: 'Customer' },
            { key: 'shop', label: 'Shop' },
            { key: 'mobile', label: 'Mobile' },
            { key: 'location', label: 'Location' },
            { key: 'status', label: 'Status' },
            { key: 'actions', label: '' },
          ]}
        >
          {loading ? (
            <tr>
              <td colSpan={8} className="px-4 py-10 text-center text-gray-400">
                <span className="inline-flex items-center gap-2">
                  <Loader2 size={16} className="animate-spin" />
                  Loading customer requests...
                </span>
              </td>
            </tr>
          ) : filtered.length === 0 ? (
            <tr>
              <td colSpan={8} className="px-4 py-10 text-center text-gray-400">
                No customer requests found
              </td>
            </tr>
          ) : (
            filtered.map((item, index) => {
              const flag = normalizeFlag(item.flag)
              return (
                <tr
                  key={`${item.customerCode}-${item.flag}-${index}`}
                  className="hover:bg-gray-50 cursor-pointer"
                  onClick={() => setSelected(item)}
                >
                  <td className="px-4 py-3">
                    {flag ? (
                      <Badge label={FLAG_LABELS[flag]} className={FLAG_COLORS[flag]} />
                    ) : (
                      <Badge label={item.flag || '—'} />
                    )}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs text-gray-600">
                    {item.customerCode || '—'}
                  </td>
                  <td className="px-4 py-3 font-medium text-gray-900">
                    {item.customerName || '—'}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">{item.shopName || '—'}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {item.contactNumber || '—'}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600 max-w-[160px] truncate">
                    {item.location || item.address || '—'}
                  </td>
                  <td className="px-4 py-3">
                    <Badge
                      label={item.status || '—'}
                      className={
                        STATUS_BADGE_COLORS[item.status] ?? 'bg-gray-100 text-gray-700'
                      }
                    />
                  </td>
                  <td className="px-4 py-3 text-right" onClick={(e) => e.stopPropagation()}>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() => setSelected(item)}
                      aria-label="View request"
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
        title={
          selectedFlag
            ? `${FLAG_LABELS[selectedFlag]} Request`
            : 'Customer Request'
        }
        wide
      >
        {selected && (
          <div className="space-y-5">
            <div className="flex flex-wrap items-center gap-2">
              {selectedFlag && (
                <Badge
                  label={FLAG_LABELS[selectedFlag]}
                  className={FLAG_COLORS[selectedFlag]}
                />
              )}
              <Badge
                label={selected.status || '—'}
                className={
                  STATUS_BADGE_COLORS[selected.status] ?? 'bg-gray-100 text-gray-700'
                }
              />
            </div>

            <dl className="space-y-3">
              <DetailRow label="Customer Code" value={selected.customerCode} />
              <DetailRow label="Customer Name" value={selected.customerName} />
              <DetailRow label="Shop Name" value={selected.shopName} />
              <DetailRow label="Mobile" value={selected.contactNumber} />
              <DetailRow label="Location" value={selected.location} />
              <DetailRow label="Address" value={selected.address} />
              <DetailRow label="Business Type" value={selected.businessType} />
              <DetailRow
                label="Expected Amount"
                value={formatAmount(selected.expectedAmount)}
              />
              <DetailRow label="Products" value={selected.products} />
              <DetailRow label="Remarks" value={selected.remarks} />
            </dl>

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
