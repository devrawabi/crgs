import { useCallback, useMemo, useState } from 'react'
import { InputWithTags, type TagSuggestion } from '@/components/ui/input-with-tags'
import { fetchItems, formatItemLabel } from '@/api/items'

const DROPDOWN_LIMIT = 10

interface ItemMasterSelectProps {
  value: string[]
  onChange: (products: string[]) => void
  disabled?: boolean
  required?: boolean
}

export function ItemMasterSelect({ value, onChange, disabled, required }: ItemMasterSelectProps) {
  const [items, setItems] = useState<Awaited<ReturnType<typeof fetchItems>>['items']>([])
  const [loading, setLoading] = useState(false)

  const loadItems = useCallback(async (query: string) => {
    if (!query.trim()) {
      setItems([])
      return
    }
    setLoading(true)
    try {
      const data = await fetchItems({ search: query, limit: DROPDOWN_LIMIT })
      setItems(data.items)
    } catch {
      setItems([])
    } finally {
      setLoading(false)
    }
  }, [])

  const suggestions = useMemo<TagSuggestion[]>(
    () =>
      items.map((item) => ({
        id: item.itemcode || item.itemname,
        label: formatItemLabel(item),
      })),
    [items]
  )

  return (
    <InputWithTags
      placeholder="Type to search item code or name..."
      tags={value}
      onTagsChange={onChange}
      suggestions={suggestions}
      onSearch={loadItems}
      loading={loading}
      disabled={disabled}
      required={required}
      minSearchLength={1}
      suggestionLimit={DROPDOWN_LIMIT}
      allowFreeText={false}
    />
  )
}
