import { useCallback, useEffect, useMemo, useState } from 'react'
import { InputWithTags, type TagSuggestion } from '@/components/ui/input-with-tags'
import type { DbRoute } from '@/api/routes'
import { isRouteNoSelected } from '@/api/users'

const DROPDOWN_LIMIT = 10

interface AssignedRoutesMultiSelectProps {
  employeeCode: string
  routesLoading: boolean
  assignedRoutes: DbRoute[]
  value: string[]
  onChange: (routeNos: string[]) => void
  disabled?: boolean
  required?: boolean
}

export function AssignedRoutesMultiSelect({
  employeeCode,
  routesLoading,
  assignedRoutes,
  value,
  onChange,
  disabled = false,
  required = false,
}: AssignedRoutesMultiSelectProps) {
  const [query, setQuery] = useState('')

  useEffect(() => {
    setQuery('')
  }, [employeeCode])

  const tagLabels = useMemo(
    () =>
      value.map((no) => {
        const route = assignedRoutes.find((r) => isRouteNoSelected([no], r.routeno))
        return route?.routename ?? `Route ${no}`
      }),
    [value, assignedRoutes]
  )

  const suggestions = useMemo<TagSuggestion[]>(() => {
    const q = query.trim().toLowerCase()
    return assignedRoutes
      .filter((r) => !isRouteNoSelected(value, r.routeno))
      .filter(
        (r) =>
          !q ||
          r.routename.toLowerCase().includes(q) ||
          r.routeno.toLowerCase().includes(q)
      )
      .slice(0, DROPDOWN_LIMIT)
      .map((r) => ({ id: r.routeno, label: r.routename }))
  }, [assignedRoutes, value, query])

  const handleTagsChange = useCallback(
    (labels: string[]) => {
      const nos = labels
        .map((label) => assignedRoutes.find((r) => r.routename === label)?.routeno ?? '')
        .filter(Boolean)
      onChange(nos)
    },
    [assignedRoutes, onChange]
  )

  const placeholder = !employeeCode
    ? 'Select an executive to view routes'
    : routesLoading
      ? 'Loading routes...'
      : assignedRoutes.length === 0
        ? 'No routes assigned'
        : 'Search or select routes...'

  return (
    <InputWithTags
      placeholder={placeholder}
      tags={tagLabels}
      onTagsChange={handleTagsChange}
      suggestions={suggestions}
      onSearch={setQuery}
      loading={routesLoading}
      disabled={disabled || !employeeCode || routesLoading || assignedRoutes.length === 0}
      required={required && assignedRoutes.length > 0}
      minSearchLength={0}
      suggestionLimit={DROPDOWN_LIMIT}
      allowFreeText={false}
    />
  )
}
