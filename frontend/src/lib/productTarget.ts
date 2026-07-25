import type { ProductTarget } from '@/types'

export function getProductTargetNames(target: ProductTarget): string[] {
  if (target.productNames?.length) return target.productNames
  if (target.productName) return [target.productName]
  return []
}

export function formatProductTargetSummary(target: ProductTarget): string {
  const names = getProductTargetNames(target)
  if (names.length === 0) return '—'
  if (names.length === 1) return names[0]
  return `${names.length} products`
}
