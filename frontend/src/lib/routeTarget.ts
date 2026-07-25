export function getRouteTargetNames(routeNames?: string[], routeName?: string): string[] {
  if (routeNames?.length) return routeNames
  if (routeName?.trim()) return [routeName]
  return []
}

export function formatRouteTargetSummary(routeNames?: string[], routeName?: string): string {
  const names = getRouteTargetNames(routeNames, routeName)
  if (names.length === 0) return '—'
  if (names.length === 1) return names[0]
  return `${names.length} routes`
}
