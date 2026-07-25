import { getRouteTargetNames } from '@/lib/routeTarget'

interface RouteTargetCellProps {
  routeName?: string
  routeNames?: string[]
}

export function RouteTargetCell({ routeName, routeNames }: RouteTargetCellProps) {
  const names = getRouteTargetNames(routeNames, routeName)

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

  return (
    <div className="space-y-1 max-w-md">
      <span className="font-medium text-gray-900">{names.length} routes</span>
      <ul className="text-xs text-gray-500 space-y-0.5">
        {names.map((name) => (
          <li key={name} className="truncate" title={name}>
            {name}
          </li>
        ))}
      </ul>
    </div>
  )
}
