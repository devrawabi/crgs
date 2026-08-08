import { useCallback, useEffect, useMemo, useState } from 'react'
import { Eye, Loader2, Search } from 'lucide-react'
import { PageHeader, inputClass } from '../components/ui/PageHeader'
import { Button } from '../components/ui/Button'
import { Modal } from '../components/ui/Modal'
import { Card } from '../components/ui/Card'
import { Table } from '../components/ui/Table'
import { fetchAllWorkReports, type DbWorkReport } from '../api/workReports'

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="grid grid-cols-[140px_1fr] gap-3 text-sm">
      <dt className="text-gray-500 font-medium">{label}</dt>
      <dd className="text-gray-900 break-words whitespace-pre-wrap">{value || '—'}</dd>
    </div>
  )
}

export function WorkReportsPage() {
  const [items, setItems] = useState<DbWorkReport[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<DbWorkReport | null>(null)

  const loadReports = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchAllWorkReports()
      setItems(data.items ?? [])
    } catch (err) {
      setItems([])
      setError(err instanceof Error ? err.message : 'Failed to load work reports')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadReports()
  }, [loadReports])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return items
    return items.filter((item) =>
      [item.employeeCode, item.customerName, item.notes, item.createdAt]
        .join(' ')
        .toLowerCase()
        .includes(q)
    )
  }, [items, search])

  return (
    <div className="flex-1 overflow-auto min-h-0">
      <PageHeader
        title="Additional Work Reports"
        description="Extra work reported by executives outside assigned tasks (not separate tasks)"
        action={
          <Button variant="secondary" onClick={loadReports} disabled={loading}>
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
          placeholder="Search by employee, customer, notes..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      <Card>
        {error && <p className="mb-4 text-sm text-red-600">{error}</p>}
        <p className="mb-3 text-sm text-gray-500">
          {loading
            ? 'Loading…'
            : `${filtered.length} report${filtered.length === 1 ? '' : 's'}`}
        </p>
        <Table
          columns={[
            { key: 'employee', label: 'Employee' },
            { key: 'customer', label: 'Customer' },
            { key: 'notes', label: 'Notes' },
            { key: 'date', label: 'Submitted' },
            { key: 'actions', label: '' },
          ]}
        >
          {loading ? (
            <tr>
              <td colSpan={5} className="px-4 py-10 text-center text-gray-400">
                <span className="inline-flex items-center gap-2">
                  <Loader2 size={16} className="animate-spin" />
                  Loading work reports...
                </span>
              </td>
            </tr>
          ) : filtered.length === 0 ? (
            <tr>
              <td colSpan={5} className="px-4 py-10 text-center text-gray-400">
                No additional work reports yet.
              </td>
            </tr>
          ) : (
            filtered.map((item, index) => (
              <tr key={`${item.employeeCode}-${item.createdAt}-${index}`}>
                <td className="px-4 py-3 text-sm font-medium text-gray-900">
                  {item.employeeCode || '—'}
                </td>
                <td className="px-4 py-3 text-sm text-gray-700">
                  {item.customerName || '—'}
                </td>
                <td className="px-4 py-3 text-sm text-gray-700 max-w-xs truncate">
                  {item.notes || '—'}
                </td>
                <td className="px-4 py-3 text-sm text-gray-700">
                  {item.createdAt || '—'}
                </td>
                <td className="px-4 py-3 text-right">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setSelected(item)}
                  >
                    <Eye size={16} />
                  </Button>
                </td>
              </tr>
            ))
          )}
        </Table>
      </Card>

      <Modal
        open={selected != null}
        onClose={() => setSelected(null)}
        title="Work Report Detail"
      >
        {selected && (
          <dl className="space-y-3">
            <DetailRow label="Employee" value={selected.employeeCode} />
            <DetailRow label="Customer" value={selected.customerName} />
            <DetailRow label="Notes" value={selected.notes} />
            <DetailRow label="Submitted" value={selected.createdAt || ''} />
          </dl>
        )}
      </Modal>
    </div>
  )
}
