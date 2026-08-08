/** Walk paginated list endpoints until `has_more` is false. */

export type PaginatedPageMeta = {
  has_more?: boolean
  limit?: number
}

export async function fetchAllPages<TItem>(options: {
  pageSize?: number
  maxPages?: number
  itemsKey: string
  fetchPage: (params: {
    limit: number
    offset: number
  }) => Promise<PaginatedPageMeta>
}): Promise<TItem[]> {
  const pageSize = options.pageSize ?? 200
  // Cap walks so admin mounts cannot fire 100 deep-offset Oracle pages.
  const maxPages = options.maxPages ?? 25
  const all: TItem[] = []
  let offset = 0

  for (let page = 0; page < maxPages; page += 1) {
    const response = await options.fetchPage({ limit: pageSize, offset })
    const raw = (response as Record<string, unknown>)[options.itemsKey]
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
