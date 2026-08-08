import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { InputWithTags, type TagSuggestion } from '@/components/ui/input-with-tags'
import {
  fetchAllCustomersForRoutes,
  fetchCustomers,
  type DbCustomer,
} from '@/api/customers'

const DROPDOWN_LIMIT = 10
const SEARCH_PAGE_SIZE = 30
/** Max routes queried in parallel during typeahead (avoids UI freeze). */
const MAX_SEARCH_ROUTES = 5
const SELECT_ALL_CAP = 200
/** Require typing before hitting the customers API. */
const MIN_SEARCH_CHARS = 1

interface CustomersMultiSelectProps {
  routeNos: string[]
  value: string[]
  onChange: (customerCodes: string[]) => void
  disabled?: boolean
  required?: boolean
}

function customerLabel(customer: DbCustomer): string {
  const name = String(customer.cust_name ?? '').trim()
  const code = String(customer.cust_code ?? '').trim()
  if (name && code) return `${name} (${code})`
  return name || code || 'Unknown customer'
}

/** Map a tag label back to cust_code even if knownCustomers was cleared. */
function codeFromTagLabel(
  label: string,
  knownCustomers: Map<string, DbCustomer>,
  currentCodes: string[]
): string {
  const trimmed = String(label ?? '').trim()
  if (!trimmed) return ''

  for (const customer of knownCustomers.values()) {
    if (customerLabel(customer) === trimmed) {
      return String(customer.cust_code ?? '').trim()
    }
  }
  if (knownCustomers.has(trimmed)) return trimmed
  if (currentCodes.includes(trimmed)) return trimmed

  // Labels are rendered as "Name (CODE)" — recover CODE if map miss.
  const match = trimmed.match(/\(([^()]+)\)\s*$/)
  if (match) {
    const nested = match[1].trim()
    if (nested) return nested
  }
  return trimmed
}

export function CustomersMultiSelect({
  routeNos,
  value,
  onChange,
  disabled = false,
  required = false,
}: CustomersMultiSelectProps) {
  const [query, setQuery] = useState('')
  const [suggestions, setSuggestions] = useState<DbCustomer[]>([])
  const [loading, setLoading] = useState(false)
  const [selectAllLoading, setSelectAllLoading] = useState(false)
  const [knownCustomers, setKnownCustomers] = useState<Map<string, DbCustomer>>(
    () => new Map()
  )
  const requestIdRef = useRef(0)

  const cleanedRoutes = useMemo(
    () => [
      ...new Set(routeNos.map((r) => String(r ?? '').trim()).filter(Boolean)),
    ],
    [routeNos]
  )
  const routesSelected = cleanedRoutes.length > 0
  const routeKey = cleanedRoutes.join(',')
  const searchTerm = query.trim()
  const canSearch = routesSelected && searchTerm.length >= MIN_SEARCH_CHARS

  // Reset search when routes change — do not auto-fetch the whole route.
  useEffect(() => {
    setQuery('')
    setSuggestions([])
    setLoading(false)
    requestIdRef.current += 1
  }, [routeKey])

  // Typeahead only: never load customers on empty query / route select alone.
  useEffect(() => {
    if (!canSearch) {
      setSuggestions([])
      setLoading(false)
      return
    }

    const requestId = ++requestIdRef.current
    let cancelled = false
    setLoading(true)

    const timer = window.setTimeout(async () => {
      try {
        const byCode = new Map<string, DbCustomer>()
        const routesToSearch = cleanedRoutes.slice(0, MAX_SEARCH_ROUTES)

        // Sequential (not Promise.all over dozens of routes) to keep UI responsive.
        for (const route of routesToSearch) {
          if (cancelled || requestId !== requestIdRef.current) return
          const res = await fetchCustomers({
            route,
            search: searchTerm,
            limit: SEARCH_PAGE_SIZE,
            offset: 0,
          })
          for (const customer of res.customers ?? []) {
            const code = String(customer.cust_code ?? '').trim()
            if (code) byCode.set(code, customer)
          }
        }

        if (cancelled || requestId !== requestIdRef.current) return

        const list = [...byCode.values()]
        setSuggestions(list)
        setKnownCustomers((prev) => {
          const next = new Map(prev)
          for (const customer of list) {
            const code = String(customer.cust_code ?? '').trim()
            if (code) next.set(code, customer)
          }
          return next
        })
      } catch {
        if (!cancelled && requestId === requestIdRef.current) {
          setSuggestions([])
        }
      } finally {
        if (!cancelled && requestId === requestIdRef.current) {
          setLoading(false)
        }
      }
    }, 280)

    return () => {
      cancelled = true
      window.clearTimeout(timer)
    }
  }, [canSearch, cleanedRoutes, searchTerm])

  const tagLabels = useMemo(
    () =>
      value.map((code) => {
        const customer = knownCustomers.get(code)
        return customer ? customerLabel(customer) : code
      }),
    [value, knownCustomers]
  )

  const dropdownSuggestions = useMemo<TagSuggestion[]>(() => {
    const selected = new Set(value)
    return suggestions
      .filter((c) => {
        const code = String(c.cust_code ?? '').trim()
        return code && !selected.has(code)
      })
      .slice(0, DROPDOWN_LIMIT)
      .map((c) => ({
        id: String(c.cust_code).trim(),
        label: customerLabel(c),
      }))
  }, [suggestions, value])

  const handleTagsChange = useCallback(
    (labels: string[]) => {
      const codes = labels
        .map((label) => codeFromTagLabel(label, knownCustomers, value))
        .filter(Boolean)
      // Never wipe a non-empty selection down to empty from a remap glitch.
      if (codes.length === 0 && value.length > 0 && labels.length > 0) {
        return
      }
      onChange(codes)
    },
    [knownCustomers, onChange, value]
  )

  const selectAllCustomers = useCallback(async () => {
    if (!routesSelected || selectAllLoading) return
    setSelectAllLoading(true)
    try {
      const data = await fetchAllCustomersForRoutes(cleanedRoutes, {
        maxTotal: SELECT_ALL_CAP,
      })
      const capped = data.customers.slice(0, SELECT_ALL_CAP)
      setKnownCustomers((prev) => {
        const next = new Map(prev)
        for (const customer of capped) {
          const code = String(customer.cust_code ?? '').trim()
          if (code) next.set(code, customer)
        }
        return next
      })
      onChange(
        capped.map((c) => String(c.cust_code ?? '').trim()).filter(Boolean)
      )
    } catch {
      // Keep current selection on failure.
    } finally {
      setSelectAllLoading(false)
    }
  }, [routesSelected, selectAllLoading, cleanedRoutes, onChange])

  const clearAllCustomers = useCallback(() => {
    onChange([])
  }, [onChange])

  const busy = loading || selectAllLoading
  const placeholder = !routesSelected
    ? 'Select a route to view customers'
    : selectAllLoading
      ? 'Loading customers...'
      : loading
        ? 'Searching customers...'
        : 'Type to search customers...'

  return (
    <div className="space-y-2">
      <InputWithTags
        placeholder={placeholder}
        tags={tagLabels}
        onTagsChange={handleTagsChange}
        suggestions={dropdownSuggestions}
        onSearch={setQuery}
        loading={busy}
        disabled={disabled || !routesSelected || selectAllLoading}
        required={required}
        minSearchLength={MIN_SEARCH_CHARS}
        suggestionLimit={DROPDOWN_LIMIT}
        allowFreeText={false}
      />
      {routesSelected && (
        <div className="flex items-center gap-2 flex-wrap">
          <button
            type="button"
            onClick={value.length > 0 ? clearAllCustomers : selectAllCustomers}
            disabled={disabled || selectAllLoading}
            className="inline-flex items-center rounded-md border border-gray-300 bg-white px-2.5 py-1 text-xs font-semibold text-slate-700 hover:bg-gray-50 disabled:opacity-50"
          >
            {value.length > 0 ? 'Clear all customers' : 'Select all customers'}
          </button>
          <span className="text-[11px] text-gray-400">
            {value.length} selected
            {value.length >= SELECT_ALL_CAP ? ` (max ${SELECT_ALL_CAP})` : ''}
            {cleanedRoutes.length > MAX_SEARCH_ROUTES
              ? ` · search uses first ${MAX_SEARCH_ROUTES} routes`
              : ''}
          </span>
        </div>
      )}
    </div>
  )
}
