/** Walk paginated list endpoints until `has_more` is false. */

export async function fetchAllPages<TItem>(options: {
  pageSize?: number
  maxPages?: number
  itemsKey: string
  fetchPage: (params: {
    limit: number
    offset: number
  }) => Promise<Record<string, unknown>>
}): Promise<TItem[]> {
  const pageSize = options.pageSize ?? 200
  const maxPages = options.maxPages ?? 100
  const all: TItem[] = []
  let offset = 0

  for (let page = 0; page < maxPages; page += 1) {
    const response = await options.fetchPage({ limit: pageSize, offset })
    const raw = response[options.itemsKey]
    const batch = Array.isArray(raw) ? (raw as TItem[]) : []
    all.push(...batch)

    if (response.has_more !== true || batch.length === 0) break

    const limitUsed =
      typeof response.limit === 'number' && response.limit > 0
        ? response.limit
        : pageSize
    offset += limitUsed
  }

  return all
}
