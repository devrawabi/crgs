import type { ProductTarget } from '@/types'
import { getProductTargetNames } from '@/lib/productTarget'

function chunkProducts(names: string[], size: number): string[][] {
  const rows: string[][] = []
  for (let i = 0; i < names.length; i += size) {
    rows.push(names.slice(i, i + size))
  }
  return rows
}

export function ProductTargetCell({ target }: { target: ProductTarget }) {
  const names = getProductTargetNames(target)

  if (names.length === 0) {
    return <span className="text-gray-400">—</span>
  }

  if (names.length === 1) {
    return (
      <span className="block max-w-md truncate" title={names[0]}>
        {names[0]}
      </span>
    )
  }

  const rows = chunkProducts(names, 2)

  return (
    <div className="flex flex-col gap-0.5 max-w-md text-xs text-gray-600">
      {rows.map((row) => (
        <div
          key={row.join('|')}
          className="flex min-w-0 items-center"
          title={row.join(', ')}
        >
          {row.map((name, index) => (
            <span key={name} className="inline-flex min-w-0 items-center">
              {index > 0 && <span className="shrink-0 text-gray-400">,&nbsp;</span>}
              <span className="truncate">{name}</span>
            </span>
          ))}
        </div>
      ))}
    </div>
  )
}
