import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts'
import { PageHeader } from '../components/ui/PageHeader'
import { Card } from '../components/ui/Card'
import { Table } from '../components/ui/Table'
import { ExecutiveDetailReport } from '../components/reports/ExecutiveDetailReport'
import { formatCurrency, formatPercent } from '../context/AppContext'
import {
  fetchAllSalesTargets,
  fetchAllCustomerTargets,
  type DbSalesTarget,
  type DbCustomerTarget,
} from '../api/targets'
import {
  fetchAllUsers,
  normalizeRouteNo,
  parseRouteColumn,
  type DbLoginUser,
} from '../api/users'
import { fetchAllRoutes, type DbRoute } from '../api/routes'
import {
  fetchCustomerStatsBatch,
  type CustomerRouteStats,
} from '../api/customers'

type ReportTab = 'executive' | 'executive_detail' | 'route'

const reportTabs: { id: ReportTab; label: string }[] = [
  { id: 'executive', label: 'Executive Performance' },
  { id: 'executive_detail', label: 'Executive Detail' },
  { id: 'route', label: 'Route Performance' },
]

export function ReportsPage() {
  const [tab, setTab] = useState<ReportTab>('executive')
  const [dbExecutives, setDbExecutives] = useState<DbLoginUser[]>([])
  const [dbRoutes, setDbRoutes] = useState<DbRoute[]>([])
  const [salesTargets, setSalesTargets] = useState<DbSalesTarget[]>([])
  const [customerTargets, setCustomerTargets] = useState<DbCustomerTarget[]>([])
  const [routeStats, setRouteStats] = useState<
    Record<string, CustomerRouteStats>
  >({})
  const [loading, setLoading] = useState(true)
  const [statsLoading, setStatsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const routeNameByNo = useMemo(() => {
    const map = new Map<string, string>()
    for (const r of dbRoutes) {
      const no = normalizeRouteNo(r.routeno)
      if (no) map.set(no, r.routename?.trim() || no)
    }
    return map
  }, [dbRoutes])

  const executiveByRoute = useMemo(() => {
    const map = new Map<string, DbLoginUser>()
    for (const exec of dbExecutives) {
      for (const routeNo of parseRouteColumn(exec.route)) {
        if (!map.has(routeNo)) map.set(routeNo, exec)
      }
    }
    return map
  }, [dbExecutives])

  const assignedRouteNos = useMemo(() => {
    const set = new Set<string>()
    for (const exec of dbExecutives) {
      for (const routeNo of parseRouteColumn(exec.route)) set.add(routeNo)
    }
    return Array.from(set).sort((a, b) =>
      a.localeCompare(b, undefined, { numeric: true })
    )
  }, [dbExecutives])

  const loadReports = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const [usersRes, routesRes, salesRes, customerRes] = await Promise.all([
        fetchAllUsers({ activeOnly: true }),
        fetchAllRoutes(),
        fetchAllSalesTargets({ period: 'monthly' }),
        fetchAllCustomerTargets(),
      ])

      setDbExecutives(usersRes.users)
      setDbRoutes(routesRes.routes)
      setSalesTargets(salesRes.targets)
      setCustomerTargets(customerRes.targets)
      setLoading(false)

      const routeNos = Array.from(
        new Set(usersRes.users.flatMap((u) => parseRouteColumn(u.route)))
      ).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))

      if (routeNos.length === 0) {
        setRouteStats({})
        return
      }

      setStatsLoading(true)
      try {
        const batch = await fetchCustomerStatsBatch(routeNos)
        const next: Record<string, CustomerRouteStats> = {}
        for (const row of batch.routes) {
          next[normalizeRouteNo(row.route) || row.route] = row.stats
        }
        for (const routeNo of routeNos) {
          if (!next[routeNo]) {
            next[routeNo] = { all: 0, missing: 0, outstanding: 0 }
          }
        }
        setRouteStats(next)
      } catch (statsErr) {
        setRouteStats({})
        setError(
          statsErr instanceof Error
            ? statsErr.message
            : 'Failed to load route customer stats'
        )
      } finally {
        setStatsLoading(false)
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load reports')
      setDbExecutives([])
      setDbRoutes([])
      setSalesTargets([])
      setCustomerTargets([])
      setRouteStats({})
      setLoading(false)
      setStatsLoading(false)
    }
  }, [])

  useEffect(() => {
    loadReports()
  }, [loadReports])

  const execReport = useMemo(() => {
    return dbExecutives.map((exec) => {
      const code = exec.employeecode.trim().toUpperCase()
      const routes = parseRouteColumn(exec.route)
      const monthly = salesTargets.filter(
        (t) => t.employeeCode.trim().toUpperCase() === code
      )
      const recovered = customerTargets.find(
        (t) =>
          t.employeeCode.trim().toUpperCase() === code &&
          t.type === 'missing_recovery'
      )
      const customers = routes.reduce(
        (sum, routeNo) => sum + (routeStats[routeNo]?.all ?? 0),
        0
      )
      const missing = routes.reduce(
        (sum, routeNo) => sum + (routeStats[routeNo]?.missing ?? 0),
        0
      )
      return {
        name: exec.username,
        routes: routes.length,
        customers,
        missing,
        target: monthly.reduce((s, t) => s + t.targetAmount, 0),
        achieved: monthly.reduce((s, t) => s + t.achievedAmount, 0),
        recoveryRate: recovered
          ? formatPercent(recovered.achievedCount ?? 0, recovered.targetCount)
          : 0,
      }
    })
  }, [dbExecutives, salesTargets, customerTargets, routeStats])

  const routeReport = useMemo(() => {
    return assignedRouteNos.map((routeNo) => {
      const stats = routeStats[routeNo] ?? { all: 0, missing: 0, outstanding: 0 }
      const executive = executiveByRoute.get(routeNo)
      return {
        code: routeNo,
        name: routeNameByNo.get(routeNo) ?? routeNo,
        executive: executive?.username ?? 'Unassigned',
        total: stats.all,
        missing: stats.missing,
        outstandingCount: stats.outstanding,
      }
    })
  }, [assignedRouteNos, routeStats, executiveByRoute, routeNameByNo])

  return (
    <div className="flex-1 overflow-auto min-h-0">
      <PageHeader
        title="Dashboard & Reports"
        description="Live performance analytics from CRGS sales, product, customer, and route data"
      />

      {error && <p className="mb-4 text-sm text-red-600">{error}</p>}

      <div className="flex flex-wrap gap-1 mb-6 bg-gray-100 p-1 rounded-lg">
        {reportTabs.map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`px-3 py-2 rounded-md text-xs sm:text-sm font-medium transition-colors ${
              tab === t.id
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {loading && (
        <p className="mb-4 text-sm text-gray-500">Loading report data...</p>
      )}
      {!loading && statsLoading && (
        <p className="mb-4 text-sm text-gray-500">
          Loading live customer stats by route...
        </p>
      )}

      {tab === 'executive' && (
        <>
          <Card title="Executive Performance Summary" className="mb-6">
            <ResponsiveContainer width="100%" height={280}>
              <BarChart data={execReport}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                <XAxis dataKey="name" tick={{ fontSize: 11 }} />
                <YAxis
                  tick={{ fontSize: 11 }}
                  tickFormatter={(v) => `QAR ${v / 1000}K`}
                />
                <Tooltip formatter={(v) => formatCurrency(Number(v))} />
                <Bar
                  dataKey="target"
                  fill="#a3e1db"
                  name="Target"
                  radius={[4, 4, 0, 0]}
                />
                <Bar
                  dataKey="achieved"
                  fill="#00766e"
                  name="Achieved"
                  radius={[4, 4, 0, 0]}
                />
              </BarChart>
            </ResponsiveContainer>
          </Card>
          <Card>
            <Table
              columns={[
                { key: 'name', label: 'Executive' },
                { key: 'routes', label: 'Routes' },
                { key: 'customers', label: 'Customers' },
                { key: 'missing', label: 'Missing' },
                { key: 'target', label: 'Monthly Target' },
                { key: 'achieved', label: 'Achieved' },
                { key: 'recovery', label: 'Recovery Rate' },
              ]}
            >
              {execReport.map((row) => (
                <tr key={row.name} className="hover:bg-gray-50">
                  <td className="px-4 py-3 font-medium">{row.name}</td>
                  <td className="px-4 py-3">{row.routes}</td>
                  <td className="px-4 py-3">{row.customers}</td>
                  <td className="px-4 py-3 text-red-600">{row.missing}</td>
                  <td className="px-4 py-3">{formatCurrency(row.target)}</td>
                  <td className="px-4 py-3">{formatCurrency(row.achieved)}</td>
                  <td className="px-4 py-3">{row.recoveryRate}%</td>
                </tr>
              ))}
            </Table>
          </Card>
        </>
      )}

      {tab === 'executive_detail' && (
        <ExecutiveDetailReport
          executives={dbExecutives}
          routeNameByNo={routeNameByNo}
          loadingUsers={loading}
        />
      )}

      {tab === 'route' && (
        <Card
          title="Route Performance"
          subtitle={`${routeReport.length} assigned routes · live customer stats`}
        >
          <Table
            columns={[
              { key: 'route', label: 'Route' },
              { key: 'executive', label: 'Executive' },
              { key: 'total', label: 'Total Customers' },
              { key: 'missing', label: 'Missing' },
              { key: 'outstanding', label: 'Outstanding' },
            ]}
          >
            {routeReport.map((row) => (
              <tr key={row.code} className="hover:bg-gray-50">
                <td className="px-4 py-3">
                  <div className="font-medium">{row.name}</div>
                  <div className="text-xs text-gray-400">{row.code}</div>
                </td>
                <td className="px-4 py-3">{row.executive}</td>
                <td className="px-4 py-3">{row.total}</td>
                <td className="px-4 py-3 text-red-600">{row.missing}</td>
                <td className="px-4 py-3">{row.outstandingCount}</td>
              </tr>
            ))}
          </Table>
          {!loading && routeReport.length === 0 && (
            <p className="mt-4 text-sm text-gray-500">
              No routes assigned to active executives.
            </p>
          )}
        </Card>
      )}
    </div>
  )
}
