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
  fetchSalesTargets,
  fetchCustomerTargets,
  type DbSalesTarget,
  type DbCustomerTarget,
} from '../api/targets'
import {
  fetchAllUsers,
  isRouteNoSelected,
  normalizeRouteNo,
  parseRouteColumn,
  type DbLoginUser,
} from '../api/users'
import { fetchRoutes, type DbRoute } from '../api/routes'
import {
  fetchCustomerStatsBatch,
  type CustomerRouteStats,
} from '../api/customers'
import { InlineLoading } from '../components/ui/LoadingState'

type ReportTab = 'executive' | 'executive_detail' | 'route'
type ReportScope = 'all' | 'route'

const REPORT_TARGET_PAGE = 200

const reportTabs: { id: ReportTab; label: string }[] = [
  { id: 'executive', label: 'Executive Performance' },
  { id: 'executive_detail', label: 'Executive Detail' },
  { id: 'route', label: 'Route Performance' },
]

function targetCoversRoute(targetRouteNo: string, routeNo: string) {
  const nos = parseRouteColumn(targetRouteNo)
  if (nos.length === 0) return true
  return isRouteNoSelected(nos, routeNo)
}

export function ReportsPage() {
  const [tab, setTab] = useState<ReportTab>('executive')
  const [reportScope, setReportScope] = useState<ReportScope>('all')
  const [selectedRouteNo, setSelectedRouteNo] = useState('')
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

  const routeOptions = useMemo(
    () =>
      assignedRouteNos.map((no) => ({
        value: no,
        label: routeNameByNo.get(no) ?? no,
      })),
    [assignedRouteNos, routeNameByNo]
  )

  useEffect(() => {
    if (reportScope !== 'route') return
    if (!selectedRouteNo && assignedRouteNos.length > 0) {
      setSelectedRouteNo(assignedRouteNos[0])
    }
  }, [reportScope, selectedRouteNo, assignedRouteNos])

  const activeRouteNo =
    reportScope === 'route' ? normalizeRouteNo(selectedRouteNo) : ''

  const loadReports = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const usersRes = await fetchAllUsers({ activeOnly: true })
      setDbExecutives(usersRes.users)

      const assignedNos = Array.from(
        new Set(usersRes.users.flatMap((u) => parseRouteColumn(u.route)))
      ).sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))

      const [routesRes, salesRes, customerRes] = await Promise.all([
        assignedNos.length > 0
          ? fetchRoutes({ routeNos: assignedNos, limit: 500, offset: 0 })
          : Promise.resolve({ routes: [] as DbRoute[] }),
        fetchSalesTargets({ period: 'monthly', limit: REPORT_TARGET_PAGE, offset: 0 }),
        fetchCustomerTargets({ limit: REPORT_TARGET_PAGE, offset: 0 }),
      ])

      setDbRoutes(routesRes.routes)
      setSalesTargets(salesRes.targets)
      setCustomerTargets(customerRes.targets)
      setLoading(false)

      if (assignedNos.length === 0) {
        setRouteStats({})
        return
      }

      setStatsLoading(true)
      try {
        const batch = await fetchCustomerStatsBatch(assignedNos)
        const next: Record<string, CustomerRouteStats> = {}
        for (const row of batch.routes) {
          next[normalizeRouteNo(row.route) || row.route] = row.stats
        }
        for (const routeNo of assignedNos) {
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

  const filteredSalesTargets = useMemo(() => {
    if (!activeRouteNo) return salesTargets
    return salesTargets.filter((t) => targetCoversRoute(t.routeNo, activeRouteNo))
  }, [salesTargets, activeRouteNo])

  const filteredCustomerTargets = useMemo(() => {
    if (!activeRouteNo) return customerTargets
    return customerTargets.filter((t) =>
      targetCoversRoute(t.routeNo, activeRouteNo)
    )
  }, [customerTargets, activeRouteNo])

  const filteredExecutives = useMemo(() => {
    if (!activeRouteNo) return dbExecutives
    return dbExecutives.filter((exec) =>
      isRouteNoSelected(parseRouteColumn(exec.route), activeRouteNo)
    )
  }, [dbExecutives, activeRouteNo])

  const execReport = useMemo(() => {
    return filteredExecutives.map((exec) => {
      const code = exec.employeecode.trim().toUpperCase()
      const routes = parseRouteColumn(exec.route).filter(
        (routeNo) => !activeRouteNo || routeNo === activeRouteNo
      )
      const monthly = filteredSalesTargets.filter(
        (t) => t.employeeCode.trim().toUpperCase() === code
      )
      const recovered = filteredCustomerTargets.find(
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
      const target = monthly.reduce((s, t) => s + t.targetAmount, 0)
      const achieved = monthly.reduce((s, t) => s + t.achievedAmount, 0)
      return {
        name: exec.username,
        routes: routes.length,
        customers,
        missing,
        target,
        achieved,
        progress: formatPercent(achieved, target),
        recoveryRate: recovered
          ? formatPercent(recovered.achievedCount ?? 0, recovered.targetCount)
          : 0,
      }
    })
  }, [
    filteredExecutives,
    filteredSalesTargets,
    filteredCustomerTargets,
    routeStats,
    activeRouteNo,
  ])

  const routeReport = useMemo(() => {
    const nos = activeRouteNo ? [activeRouteNo] : assignedRouteNos
    return nos.map((routeNo) => {
      const stats = routeStats[routeNo] ?? { all: 0, missing: 0, outstanding: 0 }
      const executive = executiveByRoute.get(routeNo)
      const routeSales = salesTargets.filter((t) =>
        targetCoversRoute(t.routeNo, routeNo)
      )
      const target = routeSales.reduce((s, t) => s + t.targetAmount, 0)
      const achieved = routeSales.reduce((s, t) => s + t.achievedAmount, 0)
      return {
        code: routeNo,
        name: routeNameByNo.get(routeNo) ?? routeNo,
        executive: executive?.username ?? 'Unassigned',
        total: stats.all,
        missing: stats.missing,
        outstandingCount: stats.outstanding,
        target,
        achieved,
        progress: formatPercent(achieved, target),
      }
    })
  }, [
    activeRouteNo,
    assignedRouteNos,
    routeStats,
    executiveByRoute,
    routeNameByNo,
    salesTargets,
  ])

  const allSummary = useMemo(() => {
    const customers = routeReport.reduce((s, r) => s + r.total, 0)
    const missing = routeReport.reduce((s, r) => s + r.missing, 0)
    const outstanding = routeReport.reduce((s, r) => s + r.outstandingCount, 0)
    const target = routeReport.reduce((s, r) => s + r.target, 0)
    const achieved = routeReport.reduce((s, r) => s + r.achieved, 0)
    return {
      routes: routeReport.length,
      customers,
      missing,
      outstanding,
      target,
      achieved,
      progress: formatPercent(achieved, target),
    }
  }, [routeReport])

  const scopeLabel =
    reportScope === 'all'
      ? 'All routes'
      : (routeNameByNo.get(activeRouteNo) ?? activeRouteNo) || 'Select route'

  return (
    <div className="flex-1 overflow-auto min-h-0">
      <PageHeader
        title="Dashboard & Reports"
        description="Live performance analytics from CRGS sales, product, customer, and route data"
      />

      {error && <p className="mb-4 text-sm text-red-600">{error}</p>}

      <div className="flex flex-wrap items-center gap-3 mb-4">
        <div className="flex gap-1 bg-gray-100 p-1 rounded-lg">
          <button
            type="button"
            onClick={() => setReportScope('all')}
            className={`px-3 py-2 rounded-md text-xs sm:text-sm font-medium transition-colors ${
              reportScope === 'all'
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            All Routes
          </button>
          <button
            type="button"
            onClick={() => setReportScope('route')}
            className={`px-3 py-2 rounded-md text-xs sm:text-sm font-medium transition-colors ${
              reportScope === 'route'
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            Route-wise
          </button>
        </div>

        {reportScope === 'route' && (
          <select
            value={selectedRouteNo}
            onChange={(e) => setSelectedRouteNo(e.target.value)}
            className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-slate-800 outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-100 min-w-[220px]"
          >
            {routeOptions.length === 0 && (
              <option value="">No assigned routes</option>
            )}
            {routeOptions.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label} ({opt.value})
              </option>
            ))}
          </select>
        )}

        <span className="text-xs text-gray-500 ml-auto">
          Showing: <span className="font-semibold text-slate-700">{scopeLabel}</span>
        </span>
      </div>

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

      {loading && <InlineLoading label="Loading report data..." />}
      {!loading && statsLoading && (
        <InlineLoading label="Loading live customer stats by route..." />
      )}

      {(tab === 'executive' || tab === 'route') && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
          <SummaryTile
            label={reportScope === 'all' ? 'Routes' : 'Route'}
            value={
              reportScope === 'all'
                ? String(allSummary.routes)
                : scopeLabel
            }
          />
          <SummaryTile label="Customers" value={String(allSummary.customers)} />
          <SummaryTile
            label="Sales Progress"
            value={`${allSummary.progress}%`}
            hint={`${formatCurrency(allSummary.achieved)} / ${formatCurrency(allSummary.target)}`}
          />
          <SummaryTile
            label="Missing"
            value={String(allSummary.missing)}
            hint={`${allSummary.outstanding} outstanding`}
            danger
          />
        </div>
      )}

      {tab === 'executive' && (
        <>
          <Card
            title={
              reportScope === 'all'
                ? 'Executive Performance Summary — All Routes'
                : `Executive Performance — ${scopeLabel}`
            }
            className="mb-6"
          >
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
                { key: 'progress', label: 'Progress' },
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
                  <td className="px-4 py-3 font-semibold tabular-nums">
                    {row.progress}%
                  </td>
                  <td className="px-4 py-3">{row.recoveryRate}%</td>
                </tr>
              ))}
            </Table>
            {!loading && execReport.length === 0 && (
              <p className="mt-4 text-sm text-gray-500">
                {reportScope === 'route'
                  ? 'No executives assigned to this route.'
                  : 'No executive data available.'}
              </p>
            )}
          </Card>
        </>
      )}

      {tab === 'executive_detail' && (
        <ExecutiveDetailReport
          executives={filteredExecutives}
          routeNameByNo={routeNameByNo}
          loadingUsers={loading}
        />
      )}

      {tab === 'route' && (
        <Card
          title={
            reportScope === 'all'
              ? 'Route Performance — All Routes'
              : `Route Performance — ${scopeLabel}`
          }
          subtitle={
            reportScope === 'all'
              ? `${routeReport.length} assigned routes · live customer & sales stats`
              : 'Live customer & sales stats for selected route'
          }
        >
          <Table
            columns={[
              { key: 'route', label: 'Route' },
              { key: 'executive', label: 'Executive' },
              { key: 'total', label: 'Total Customers' },
              { key: 'missing', label: 'Missing' },
              { key: 'outstanding', label: 'Outstanding' },
              { key: 'target', label: 'Sales Target' },
              { key: 'achieved', label: 'Achieved' },
              { key: 'progress', label: 'Progress' },
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
                <td className="px-4 py-3">{formatCurrency(row.target)}</td>
                <td className="px-4 py-3">{formatCurrency(row.achieved)}</td>
                <td className="px-4 py-3 font-semibold tabular-nums">
                  {row.progress}%
                </td>
              </tr>
            ))}
          </Table>
          {!loading && routeReport.length === 0 && (
            <p className="mt-4 text-sm text-gray-500">
              {reportScope === 'route'
                ? 'Select a route to view performance.'
                : 'No routes assigned to active executives.'}
            </p>
          )}
        </Card>
      )}
    </div>
  )
}

function SummaryTile({
  label,
  value,
  hint,
  danger,
}: {
  label: string
  value: string
  hint?: string
  danger?: boolean
}) {
  return (
    <div className="rounded-xl border border-gray-200 bg-white px-4 py-3 shadow-sm">
      <p className="text-[11px] font-semibold uppercase tracking-wide text-gray-400">
        {label}
      </p>
      <p
        className={`mt-1 text-lg font-bold truncate ${
          danger ? 'text-red-600' : 'text-slate-800'
        }`}
      >
        {value}
      </p>
      {hint && <p className="mt-0.5 text-[11px] text-gray-400 truncate">{hint}</p>}
    </div>
  )
}
