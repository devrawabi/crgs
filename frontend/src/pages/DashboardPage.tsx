import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  Users,
  MapPin,
  Package,
  TrendingUp,
  UserPlus,
  ClipboardList,
} from 'lucide-react'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
} from 'recharts'
import { Card, StatCard } from '../components/ui/Card'
import { Badge } from '../components/ui/Badge'
import { PageHeader } from '../components/ui/PageHeader'
import { Table } from '../components/ui/Table'
import { formatCurrency, formatPercent } from '../context/AppContext'
import {
  fetchDashboardSummary,
  type DashboardSummary,
} from '../api/dashboard'
import { STATUS_COLORS, TASK_TYPE_LABELS } from '../data/mockData'

const COLORS = ['#00766e', '#16a34a', '#f59e0b', '#ef4444', '#8b5cf6']

function isOverdueTaskStatus(status: string, dueDate: string) {
  const normalized = (status || '').toLowerCase()
  if (normalized === 'overdue') return true
  if (normalized === 'completed' || normalized === 'done') return false
  if (!dueDate) return false
  const due = new Date(dueDate.slice(0, 10))
  if (Number.isNaN(due.getTime())) return false
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return due < today
}

export function DashboardPage() {
  const [summary, setSummary] = useState<DashboardSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadDashboard = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const data = await fetchDashboardSummary()
      setSummary(data)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load dashboard')
      setSummary(null)
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadDashboard()
  }, [loadDashboard])

  const achievementPct = formatPercent(
    summary?.sales.achievedTotal ?? 0,
    summary?.sales.targetTotal ?? 0
  )
  const productPct = formatPercent(
    summary?.products.achievedTotal ?? 0,
    summary?.products.targetTotal ?? 0
  )
  const customerPct = formatPercent(
    summary?.customers.achievedTotal ?? 0,
    summary?.customers.targetTotal ?? 0
  )

  const taskBreakdown = useMemo(
    () =>
      (summary?.tasks.breakdown ?? []).map((row) => ({
        name:
          TASK_TYPE_LABELS[row.type]?.split(' ').slice(0, 2).join(' ') ??
          row.type,
        value: row.count,
      })),
    [summary]
  )

  const recentTasks = summary?.tasks.recent ?? []

  return (
    <div className="flex-1 overflow-auto min-h-0">
      <PageHeader
        title="Dashboard"
        description="Overview of sales, product, and customer targets"
      />

      {error && (
        <p className="mb-4 text-sm text-red-600">{error}</p>
      )}

      {loading ? (
        <p className="text-sm text-gray-500">Loading dashboard data...</p>
      ) : (
        <>
          <div className="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4 mb-6">
            <StatCard
              label="Active Executives"
              value={summary?.activeExecutives ?? 0}
              icon={<Users size={20} />}
            />
            <StatCard
              label="Assigned Routes"
              value={summary?.assignedRoutes ?? 0}
              icon={<MapPin size={20} />}
            />
            <StatCard
              label="Monthly Sales Achievement"
              value={`${achievementPct}%`}
              change={`${formatCurrency(summary?.sales.achievedTotal ?? 0)} of ${formatCurrency(summary?.sales.targetTotal ?? 0)}`}
              positive={achievementPct >= 70}
              icon={<TrendingUp size={20} />}
            />
            <StatCard
              label="Product Target Achievement"
              value={`${productPct}%`}
              change={`${summary?.products.achievedTotal ?? 0} of ${summary?.products.targetTotal ?? 0}`}
              positive={productPct >= 70}
              icon={<Package size={20} />}
            />
            <StatCard
              label="Customer Target Achievement"
              value={`${customerPct}%`}
              change={`${summary?.customers.achievedTotal ?? 0} of ${summary?.customers.targetTotal ?? 0}`}
              positive={customerPct >= 70}
              icon={<UserPlus size={20} />}
            />
            <StatCard
              label="Overdue Tasks"
              value={summary?.tasks.overdue ?? 0}
              change={`${summary?.tasks.total ?? 0} total tasks`}
              positive={(summary?.tasks.overdue ?? 0) === 0}
              icon={<ClipboardList size={20} />}
            />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
            <Card title="Executive Performance" subtitle="Monthly sales target vs achievement">
              <ResponsiveContainer width="100%" height={260}>
                <BarChart data={summary?.sales.byExecutive ?? []}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                  <YAxis tick={{ fontSize: 12 }} tickFormatter={(v) => `QAR ${v / 1000}K`} />
                  <Tooltip formatter={(v) => formatCurrency(Number(v))} />
                  <Bar dataKey="target" fill="#a3e1db" name="Target" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="achieved" fill="#00766e" name="Achieved" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </Card>

            <Card title="Route Sales Performance" subtitle="Monthly target vs achievement by route">
              <ResponsiveContainer width="100%" height={260}>
                <LineChart data={summary?.sales.byRoute ?? []}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                  <YAxis tick={{ fontSize: 12 }} tickFormatter={(v) => `QAR ${v / 1000}K`} />
                  <Tooltip formatter={(v) => formatCurrency(Number(v))} />
                  <Line type="monotone" dataKey="target" stroke="#a3e1db" strokeWidth={2} name="Target" />
                  <Line type="monotone" dataKey="achieved" stroke="#00766e" strokeWidth={2} name="Achieved" />
                </LineChart>
              </ResponsiveContainer>
            </Card>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <Card title="Task Distribution" className="lg:col-span-1">
              {taskBreakdown.length === 0 ? (
                <p className="text-sm text-gray-500 py-8 text-center">No tasks found</p>
              ) : (
                <ResponsiveContainer width="100%" height={220}>
                  <PieChart>
                    <Pie
                      data={taskBreakdown}
                      dataKey="value"
                      nameKey="name"
                      cx="50%"
                      cy="50%"
                      outerRadius={80}
                      label={({ name, value }) => `${name}: ${value}`}
                    >
                      {taskBreakdown.map((_, i) => (
                        <Cell key={i} fill={COLORS[i % COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              )}
            </Card>

            <Card title="Recent Tasks" className="lg:col-span-2">
              <Table
                columns={[
                  { key: 'type', label: 'Task' },
                  { key: 'executive', label: 'Executive' },
                  { key: 'route', label: 'Route' },
                  { key: 'status', label: 'Status' },
                  { key: 'due', label: 'Due Date' },
                ]}
              >
                {recentTasks.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-gray-500">
                      No tasks found
                    </td>
                  </tr>
                ) : (
                  recentTasks.map((task, index) => {
                    const statusKey = isOverdueTaskStatus(task.status, task.dueDate)
                      ? 'overdue'
                      : (task.status || 'pending').toLowerCase().replace(/\s+/g, '_')
                    return (
                      <tr
                        key={`${task.employeeCode}-${task.type}-${task.routeNo}-${task.dueDate}-${index}`}
                        className="hover:bg-gray-50"
                      >
                        <td className="px-4 py-3 font-medium text-gray-900">
                          {TASK_TYPE_LABELS[task.type] ?? task.type}
                        </td>
                        <td className="px-4 py-3 text-gray-600">
                          {task.executiveName || task.employeeCode}
                        </td>
                        <td className="px-4 py-3 text-gray-600">{task.routeNo || '—'}</td>
                        <td className="px-4 py-3">
                          <Badge
                            label={statusKey.replace('_', ' ')}
                            className={STATUS_COLORS[statusKey] ?? 'bg-gray-100 text-gray-800'}
                          />
                        </td>
                        <td className="px-4 py-3 text-gray-600">{task.dueDate || '—'}</td>
                      </tr>
                    )
                  })
                )}
              </Table>
            </Card>
          </div>
        </>
      )}
    </div>
  )
}
