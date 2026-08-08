import { useCallback, useEffect, useMemo, useState } from 'react'
import { InputWithTags, type TagSuggestion } from '@/components/ui/input-with-tags'
import type { DbRoute } from '@/api/routes'
import { isRouteNoSelected, normalizeRouteNo } from '@/api/users'

const DROPDOWN_LIMIT = 10

interface AssignedRoutesMultiSelectProps {
  employeeCode: string
  routesLoading: boolean
  assignedRoutes: DbRoute[]
  value: string[]
  onChange: (routeNos: string[]) => void
  disabled?: boolean
  required?: boolean
  /** When true, routes can be selected without an executive (e.g. Other-route). */
  allowWithoutEmployee?: boolean
  emptyMessage?: string
  placeholderWhenReady?: string
}

function routeLabel(route: DbRoute): string {
  const name = String(route.routename ?? '').trim()
  const no = normalizeRouteNo(route.routeno)
  if (name) return name
  return no ? `Route ${no}` : 'Unknown route'
}

export function AssignedRoutesMultiSelect({
  employeeCode,
  routesLoading,
  assignedRoutes,
  value,
  onChange,
  disabled = false,
  required = false,
  allowWithoutEmployee = false,
  emptyMessage = 'No routes assigned',
  placeholderWhenReady = 'Search or select routes...',
}: AssignedRoutesMultiSelectProps) {
  const [query, setQuery] = useState('')

  useEffect(() => {
    setQuery('')
  }, [employeeCode])

  const readyForRoutes = allowWithoutEmployee || !!employeeCode

  const tagLabels = useMemo(
    () =>
      value.map((no) => {
        const route = assignedRoutes.find((r) =>
          isRouteNoSelected([no], r.routeno)
        )
        return route ? routeLabel(route) : `Route ${no}`
      }),
    [value, assignedRoutes]
  )

  const suggestions = useMemo<TagSuggestion[]>(() => {
    const q = query.trim().toLowerCase()
    return assignedRoutes
      .filter((r) => !isRouteNoSelected(value, r.routeno))
      .filter((r) => {
        if (!q) return true
        const name = String(r.routename ?? '').toLowerCase()
        const no = String(r.routeno ?? '').toLowerCase()
        return name.includes(q) || no.includes(q)
      })
      .slice(0, DROPDOWN_LIMIT)
      .map((r) => ({
        id: normalizeRouteNo(r.routeno) || routeLabel(r),
        label: routeLabel(r),
      }))
  }, [assignedRoutes, value, query])

  const handleTagsChange = useCallback(
    (labels: string[]) => {
      const nos = labels
        .map((label) => {
          const match = assignedRoutes.find((r) => routeLabel(r) === label)
          return match ? normalizeRouteNo(match.routeno) : ''
        })
        .filter(Boolean)
      onChange(nos)
    },
    [assignedRoutes, onChange]
  )

  const allSelected =
    assignedRoutes.length > 0 &&
    assignedRoutes.every((r) => isRouteNoSelected(value, r.routeno))

  const canSelectAll =
    readyForRoutes && !routesLoading && !disabled && assignedRoutes.length > 0

  const selectAllRoutes = useCallback(() => {
    onChange(
      assignedRoutes
        .map((r) => normalizeRouteNo(r.routeno))
        .filter(Boolean)
    )
  }, [assignedRoutes, onChange])

  const clearAllRoutes = useCallback(() => {
    onChange([])
  }, [onChange])

  const placeholder = !readyForRoutes
    ? 'Select an executive to view routes'
    : routesLoading
      ? 'Loading routes...'
      : assignedRoutes.length === 0
        ? emptyMessage
        : placeholderWhenReady

  return (
    <div className="space-y-2">
      <InputWithTags
        placeholder={placeholder}
        tags={tagLabels}
        onTagsChange={handleTagsChange}
        suggestions={suggestions}
        onSearch={setQuery}
        loading={routesLoading}
        disabled={
          disabled || !readyForRoutes || routesLoading || assignedRoutes.length === 0
        }
        required={required && assignedRoutes.length > 0}
        minSearchLength={0}
        suggestionLimit={DROPDOWN_LIMIT}
        allowFreeText={false}
      />
      {canSelectAll && (
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={allSelected ? clearAllRoutes : selectAllRoutes}
            className="inline-flex items-center rounded-md border border-gray-300 bg-white px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-gray-50"
          >
            {allSelected ? 'Clear all routes' : 'Select all routes'}
          </button>
          <span className="text-[11px] text-gray-400">
            {value.length}/{assignedRoutes.length} selected
          </span>
        </div>
      )}
    </div>
  )
}
