import { useEffect, useMemo, useState, useCallback } from 'react'
import { Loader2, Search } from 'lucide-react'
import { PageHeader, inputClass } from '../components/ui/PageHeader'
import { Badge } from '../components/ui/Badge'
import { Card } from '../components/ui/Card'
import { useApp } from '../context/AppContext'
import { fetchRoutes, type DbRoute } from '../api/routes'
import { assignUserRoutes, fetchUsers, isRouteNoSelected, parseRouteColumn, toggleRouteNo, type DbLoginUser } from '../api/users'

export function RoutesPage() {
  const { assignRoutesByEmployeeCode, syncExecutivesFromDb } = useApp()
  const [executives, setExecutives] = useState<DbLoginUser[]>([])
  const [executivesLoading, setExecutivesLoading] = useState(true)
  const [executivesError, setExecutivesError] = useState<string | null>(null)
  const [dbRoutes, setDbRoutes] = useState<DbRoute[]>([])
  const [routesLoading, setRoutesLoading] = useState(true)
  const [routesError, setRoutesError] = useState<string | null>(null)
  const [selectedEmployeeCode, setSelectedEmployeeCode] = useState<string | null>(null)
  const [routeSearch, setRouteSearch] = useState('')
  const [pendingRouteNos, setPendingRouteNos] = useState<string[]>([])
  const [submitting, setSubmitting] = useState(false)
  const [submitError, setSubmitError] = useState<string | null>(null)

  const selectedExecutive = executives.find(
    (e) => e.employeecode === selectedEmployeeCode
  ) ?? null

  const loadExecutives = useCallback(async () => {
    setExecutivesLoading(true)
    setExecutivesError(null)

    try {
      const data = await fetchUsers({ activeOnly: true })
      setExecutives(data.users)
      syncExecutivesFromDb(data.users)
    } catch (err) {
      setExecutives([])
      setExecutivesError(err instanceof Error ? err.message : 'Failed to load executives')
    } finally {
      setExecutivesLoading(false)
    }
  }, [syncExecutivesFromDb])

  useEffect(() => {
    let cancelled = false

    async function loadRoutes() {
      setRoutesLoading(true)
      setRoutesError(null)

      try {
        const data = await fetchRoutes()
        if (!cancelled) {
          setDbRoutes(data.routes)
        }
      } catch (err) {
        if (!cancelled) {
          setDbRoutes([])
          setRoutesError(err instanceof Error ? err.message : 'Failed to load routes')
        }
      } finally {
        if (!cancelled) {
          setRoutesLoading(false)
        }
      }
    }

    loadExecutives()
    loadRoutes()

    return () => {
      cancelled = true
    }
  }, [loadExecutives])

  useEffect(() => {
    if (!selectedEmployeeCode) {
      setPendingRouteNos([])
      return
    }
    const dbUser = executives.find((e) => e.employeecode === selectedEmployeeCode)
    setPendingRouteNos(parseRouteColumn(dbUser?.route))
  }, [selectedEmployeeCode, executives])

  const filteredRoutes = useMemo(() => {
    const q = routeSearch.trim().toLowerCase()
    if (!q) return dbRoutes
    return dbRoutes.filter(
      (r) =>
        r.routename.toLowerCase().includes(q) ||
        String(r.routeno).toLowerCase().includes(q)
    )
  }, [dbRoutes, routeSearch])

  const toggleRoute = (routeno: string) => {
    setPendingRouteNos((nos) => toggleRouteNo(nos, routeno))
  }

  const handleSubmitRoutes = async () => {
    if (!selectedEmployeeCode) return

    setSubmitting(true)
    setSubmitError(null)

    try {
      await assignUserRoutes({
        employeeCode: selectedEmployeeCode,
        routeNos: pendingRouteNos,
      })
      assignRoutesByEmployeeCode(selectedEmployeeCode, pendingRouteNos)
      setExecutives((prev) =>
        prev.map((exec) =>
          exec.employeecode === selectedEmployeeCode
            ? { ...exec, route: pendingRouteNos.join(',') || null }
            : exec
        )
      )
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : 'Failed to save route assignments')
    } finally {
      setSubmitting(false)
    }
  }

  const getAssignedCount = (employeeCode: string) => {
    const dbUser = executives.find((e) => e.employeecode === employeeCode)
    return parseRouteColumn(dbUser?.route).length
  }

  const initials = (username: string) =>
    username
      .split(/[\s.]+/)
      .map((n) => n[0])
      .join('')
      .slice(0, 2)
      .toUpperCase()

  return (
    <div className="flex-1 flex flex-col min-h-0 overflow-auto lg:overflow-hidden">
      <PageHeader title="Route Management" />

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:flex-1 lg:min-h-0">
        <Card
          title="Sales Executives"
          subtitle={
            executivesLoading
              ? 'Loading executives...'
              : `${executives.length} active executive${executives.length === 1 ? '' : 's'}`
          }
          className="lg:col-span-1 max-h-96 lg:max-h-none"
          scrollable
        >
          {executivesError && (
            <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {executivesError}
            </div>
          )}

          {executivesLoading ? (
            <div className="flex items-center justify-center gap-2 py-12 text-sm text-gray-500">
              <Loader2 size={18} className="animate-spin" />
              Loading executives...
            </div>
          ) : executives.length === 0 ? (
            <p className="text-center text-sm text-gray-400 py-8">No active executives</p>
          ) : (
            <div className="space-y-2 -mx-2">
              {executives.map((executive) => (
                <button
                  key={executive.employeecode}
                  onClick={() => {
                    setSelectedEmployeeCode(executive.employeecode)
                    setRouteSearch('')
                    setSubmitError(null)
                  }}
                  className={`w-full text-left px-4 py-3 rounded-lg transition-colors ${
                    selectedEmployeeCode === executive.employeecode
                      ? 'bg-primary-50 border border-primary-200'
                      : 'hover:bg-gray-50 border border-transparent'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div className="w-9 h-9 rounded-full bg-primary-100 text-primary-700 flex items-center justify-center text-xs font-bold shrink-0">
                      {initials(executive.username)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-medium text-gray-900 truncate">{executive.username}</p>
                      <p className="text-xs text-gray-500 truncate">{executive.employeecode}</p>
                    </div>
                    <Badge
                      label={`${getAssignedCount(executive.employeecode)} routes`}
                      className={
                        getAssignedCount(executive.employeecode) > 0
                          ? 'bg-primary-50 text-primary-700'
                          : 'bg-gray-100 text-gray-500'
                      }
                    />
                  </div>
                </button>
              ))}
            </div>
          )}
        </Card>

        <Card
          title={selectedExecutive ? `Routes — ${selectedExecutive.username}` : 'Assign Routes'}
          subtitle={
            selectedExecutive
              ? `${pendingRouteNos.length} of ${dbRoutes.length} routes assigned`
              : 'Select an executive to assign routes'
          }
          className="lg:col-span-2 max-h-96 lg:max-h-none"
          scrollable
          action={
            selectedExecutive && !routesLoading && dbRoutes.length > 0 ? (
              <button
                type="button"
                onClick={handleSubmitRoutes}
                disabled={submitting}
                className="text-xs font-medium text-primary-600 hover:text-primary-700 whitespace-nowrap disabled:opacity-50"
              >
                {submitting ? 'Saving...' : 'Submit'}
              </button>
            ) : undefined
          }
        >
          {submitError && (
            <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {submitError}
            </div>
          )}

          {routesError && (
            <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {routesError}
            </div>
          )}

          {!selectedExecutive ? (
            <p className="text-gray-500 text-sm text-center py-8">
              Select an executive from the list to assign routes
            </p>
          ) : routesLoading ? (
            <div className="flex items-center justify-center gap-2 py-12 text-sm text-gray-500">
              <Loader2 size={18} className="animate-spin" />
              Loading routes...
            </div>
          ) : (
            <>
              <div className="relative mb-4 -mt-2">
                <Search
                  size={16}
                  className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
                />
                <input
                  className={inputClass + ' pl-9'}
                  placeholder="Search routes by name or code..."
                  value={routeSearch}
                  onChange={(e) => setRouteSearch(e.target.value)}
                />
              </div>

              {filteredRoutes.length === 0 ? (
                <p className="text-center text-sm text-gray-400 py-8">No routes match your search</p>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  {filteredRoutes.map((route) => {
                    const checked = isRouteNoSelected(pendingRouteNos, route.routeno)
                    return (
                      <label
                        key={route.routeno}
                        className={`flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-colors ${
                          checked
                            ? 'border-primary-500 bg-primary-50'
                            : 'border-gray-200 hover:border-gray-300 hover:bg-gray-50'
                        }`}
                      >
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={() => toggleRoute(route.routeno)}
                          className="rounded text-primary-600 shrink-0"
                        />
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-gray-900 truncate">
                            {route.routename}
                          </p>
                          <p className="text-xs text-gray-500">{route.routeno}</p>
                        </div>
                      </label>
                    )
                  })}
                </div>
              )}
            </>
          )}
        </Card>
      </div>
    </div>
  )
}
