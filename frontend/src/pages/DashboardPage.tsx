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
  fetchSalesTargets,
  fetchProductTargets,
  fetchCustomerTargets,
  type DbSalesTarget,
  type DbProductTarget,
  type DbCustomerTarget,
} from '../api/targets'
import {
  fetchUsers,
  parseRouteColumn,
  type DbLoginUser,
} from '../api/users'
import { fetchTasks, type DbTask } from '../api/tasks'
import { STATUS_COLORS, TASK_TYPE_LABELS } from '../data/mockData'

const COLORS = ['#00766e', '#16a34a', '#f59e0b', '#ef4444', '#8b5cf6']

function displayName(username: string) {
  return username.split('.')[0] ?? username
}

function isOverdueTask(task: DbTask) {
  const status = (task.status || '').toLowerCase()
  if (status === 'overdue') return true
  if (status === 'completed' || status === 'done') return false
  if (!task.dueDate) return false
  const due = new Date(task.dueDate.slice(0, 10))
  if (Number.isNaN(due.getTime())) return false
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return due < today
}

export function DashboardPage() {
  const [executives, setExecutives] = useState<DbLoginUser[]>([])
  const [salesTargets, setSalesTargets] = useState<DbSalesTarget[]>([])
  const [productTargets, setProductTargets] = useState<DbProductTarget[]>([])
  const [customerTargets, setCustomerTargets] = useState<DbCustomerTarget[]>([])
  const [tasks, setTasks] = useState<DbTask[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadDashboard = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [usersRes, salesRes, productRes, customerRes, tasksRes] =
        await Promise.all([
          fetchUsers({ activeOnly: true }),
          fetchSalesTargets(),
          fetchProductTargets(),
          fetchCustomerTargets(),
          fetchTasks(),
        ])
      setExecutives(usersRes.users)
      setSalesTargets(salesRes.targets)
      setProductTargets(productRes.targets)
      setCustomerTargets(customerRes.targets)
      setTasks(tasksRes.tasks)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load dashboard')
      setExecutives([])
      setSalesTargets([])
      setProductTargets([])
      setCustomerTargets([])
      setTasks([])
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    loadDashboard()
  }, [loadDashboard])

  const executiveNameByCode = useMemo(() => {
    const map = new Map<string, string>()
    for (const exec of executives) {
      map.set(exec.employeecode.trim().toUpperCase(), exec.username)
    }
    return map
  }, [executives])

  const getExecutiveName = useCallback(
    (employeeCode: string) => {
      const code = employeeCode.trim().toUpperCase()
      return executiveNameByCode.get(code) ?? employeeCode
    },
    [executiveNameByCode]
  )

  const activeRoutes = useMemo(() => {
    const routes = new Set<string>()
    for (const exec of executives) {
      for (const route of parseRouteColumn(exec.route)) {
        routes.add(route)
      }
    }
    return routes.size
  }, [executives])

  const monthlyTargets = useMemo(
    () => salesTargets.filter((t) => t.period === 'monthly'),
    [salesTargets]
  )

  const totalTarget = monthlyTargets.reduce((s, t) => s + t.targetAmount, 0)
  const totalAchieved = monthlyTargets.reduce((s, t) => s + t.achievedAmount, 0)
  const achievementPct = formatPercent(totalAchieved, totalTarget)

  const productTargetTotal = productTargets.reduce((s, t) => s + t.targetValue, 0)
  const productAchievedTotal = productTargets.reduce(
    (s, t) => s + (t.achievedValue ?? 0),
    0
  )
  const productPct = formatPercent(productAchievedTotal, productTargetTotal)

  const customerTargetTotal = customerTargets.reduce((s, t) => s + t.targetCount, 0)
  const customerAchievedTotal = customerTargets.reduce(
    (s, t) => s + (t.achievedCount ?? 0),
    0
  )
  const customerPct = formatPercent(customerAchievedTotal, customerTargetTotal)

  const overdueTasks = tasks.filter(isOverdueTask).length

  const execPerformance = useMemo(() => {
    const byCode = new Map<string, { target: number; achieved: number }>()
    for (const t of monthlyTargets) {
      const code = t.employeeCode.trim().toUpperCase()
      const current = byCode.get(code) ?? { target: 0, achieved: 0 }
      current.target += t.targetAmount
      current.achieved += t.achievedAmount
      byCode.set(code, current)
    }

    return executives.map((exec) => {
      const code = exec.employeecode.trim().toUpperCase()
      const totals = byCode.get(code)
      return {
        name: displayName(exec.username),
        target: totals?.target ?? 0,
        achieved: totals?.achieved ?? 0,
      }
    })
  }, [executives, monthlyTargets])

  const routePerformance = useMemo(() => {
    const byRoute = new Map<string, { target: number; achieved: number }>()
    for (const t of monthlyTargets) {
      const routes = parseRouteColumn(t.routeNo)
      const routeKeys = routes.length > 0 ? routes : [t.routeNo || 'Unassigned']
      for (const route of routeKeys) {
        const key = route || 'Unassigned'
        const current = byRoute.get(key) ?? { target: 0, achieved: 0 }
        current.target += t.targetAmount
        current.achieved += t.achievedAmount
        byRoute.set(key, current)
      }
    }
    return Array.from(byRoute.entries())
      .map(([name, values]) => ({
        name,
        target: values.target,
        achieved: values.achieved,
      }))
      .sort((a, b) => a.name.localeCompare(b.name))
  }, [monthlyTargets])

  const taskBreakdown = useMemo(
    () =>
      Object.entries(
        tasks.reduce<Record<string, number>>((acc, t) => {
          acc[t.type] = (acc[t.type] ?? 0) + 1
          return acc
        }, {})
      ).map(([type, count]) => ({
        name: TASK_TYPE_LABELS[type]?.split(' ').slice(0, 2).join(' ') ?? type,
        value: count,
      })),
    [tasks]
  )

  const recentTasks = useMemo(
    () =>
      [...tasks]
        .sort((a, b) => (b.dueDate || '').localeCompare(a.dueDate || ''))
        .slice(0, 5),
    [tasks]
  )

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
              value={executives.length}
              icon={<Users size={20} />}
            />
            <StatCard
              label="Assigned Routes"
              value={activeRoutes}
              icon={<MapPin size={20} />}
            />
            <StatCard
              label="Monthly Sales Achievement"
              value={`${achievementPct}%`}
              change={`${formatCurrency(totalAchieved)} of ${formatCurrency(totalTarget)}`}
              positive={achievementPct >= 70}
              icon={<TrendingUp size={20} />}
            />
            <StatCard
              label="Product Target Achievement"
              value={`${productPct}%`}
              change={`${productAchievedTotal} of ${productTargetTotal}`}
              positive={productPct >= 70}
              icon={<Package size={20} />}
            />
            <StatCard
              label="Customer Target Achievement"
              value={`${customerPct}%`}
              change={`${customerAchievedTotal} of ${customerTargetTotal}`}
              positive={customerPct >= 70}
              icon={<UserPlus size={20} />}
            />
            <StatCard
              label="Overdue Tasks"
              value={overdueTasks}
              change={`${tasks.length} total tasks`}
              positive={overdueTasks === 0}
              icon={<ClipboardList size={20} />}
            />
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
            <Card title="Executive Performance" subtitle="Monthly sales target vs achievement">
              <ResponsiveContainer width="100%" height={260}>
                <BarChart data={execPerformance}>
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
                <LineChart data={routePerformance}>
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
                    const statusKey = isOverdueTask(task)
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
                          {getExecutiveName(task.employeeCode)}
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
