import { useCallback, useEffect, useMemo, useState } from 'react'
import { Plus, Trash2 } from 'lucide-react'
import { PageHeader, FormField, inputClass, selectClass } from '../components/ui/PageHeader'
import { Button } from '../components/ui/Button'
import { Badge } from '../components/ui/Badge'
import { Modal } from '../components/ui/Modal'
import { Card } from '../components/ui/Card'
import { Table } from '../components/ui/Table'
import {
  useApp,
  formatCurrency,
} from '../context/AppContext'
import {
  PRODUCT_TARGET_LABELS,
  CUSTOMER_TARGET_LABELS,
} from '../data/mockData'
import { fetchRoutes, type DbRoute } from '../api/routes'
import {
  fetchUsers,
  formatRouteColumn,
  isRouteNoSelected,
  parseRouteColumn,
  type DbLoginUser,
} from '../api/users'
import {
  createSalesTarget,
  createProductTarget,
  createCustomerTarget,
  deleteSalesTarget,
  deleteProductTarget,
  deleteCustomerTarget,
  fetchSalesTargets,
  fetchProductTargets,
  fetchCustomerTargets,
  recalculateSalesTargets,
  type DbSalesTarget,
  type DbProductTarget,
  type DbCustomerTarget,
} from '../api/targets'
import type { ProductTarget } from '../types'
import { ItemMasterSelect } from '../components/ui/ItemMasterSelect'
import { ProductTargetCell } from '../components/ui/ProductTargetCell'
import { AssignedRoutesMultiSelect } from '../components/ui/AssignedRoutesMultiSelect'
import { RouteTargetCell } from '../components/ui/RouteTargetCell'

type Tab = 'sales' | 'product' | 'customer'

const initialSalesForm = {
  employeeCode: '',
  routeNos: [] as string[],
  period: 'monthly' as const,
  targetAmount: '',
  achievedAmount: '0',
  endDate: '',
}

const initialProductForm = {
  employeeCode: '',
  routeNos: [] as string[],
  productNames: [] as string[],
  type: 'quantity' as const,
  targetValue: '',
  achievedValue: '0',
  period: 'monthly' as const,
}

const initialCustomerForm = {
  employeeCode: '',
  routeNos: [] as string[],
  type: 'new_acquisition' as const,
  targetCount: '',
  targetAmount: '',
  achievedCount: '0',
  period: 'monthly' as const,
}

function salesTargetKey(target: DbSalesTarget) {
  return `${target.employeeCode}-${target.routeNo}-${target.period}-${target.dueDate}`
}

function productTargetKey(target: DbProductTarget) {
  return `${target.employeeCode}-${target.routeNo}-${target.type}-${target.products.join('|')}`
}

function customerTargetKey(target: DbCustomerTarget) {
  return `${target.employeeCode}-${target.routeNo}-${target.type}-${target.period}`
}

function dbProductToDisplay(
  target: DbProductTarget,
  executiveId: string,
  routeNames: string[]
): ProductTarget {
  const routeNos = parseRouteColumn(target.routeNo)
  const productNames =
    target.productNames?.length ? target.productNames : target.products
  return {
    id: productTargetKey(target),
    executiveId,
    routeNo: target.routeNo,
    routeName: routeNames.length === 1 ? routeNames[0] : `${routeNames.length} routes`,
    routeNos,
    routeNames,
    productName:
      productNames.length === 1 ? productNames[0] : `${productNames.length} products`,
    productNames,
    type: target.type,
    targetValue: target.targetValue,
    achievedValue: target.achievedValue ?? 0,
    period: 'monthly',
  }
}

export function TargetsPage() {
  const { syncExecutivesFromDb, getUserByEmployeeCode } = useApp()
  const [dbExecutives, setDbExecutives] = useState<DbLoginUser[]>([])
  const [dbSalesTargets, setDbSalesTargets] = useState<DbSalesTarget[]>([])
  const [dbProductTargets, setDbProductTargets] = useState<DbProductTarget[]>([])
  const [dbCustomerTargets, setDbCustomerTargets] = useState<DbCustomerTarget[]>([])
  const [executivesLoading, setExecutivesLoading] = useState(true)
  const [salesTargetsLoading, setSalesTargetsLoading] = useState(true)
  const [productTargetsLoading, setProductTargetsLoading] = useState(true)
  const [customerTargetsLoading, setCustomerTargetsLoading] = useState(true)
  const [salesTargetsError, setSalesTargetsError] = useState<string | null>(null)
  const [productTargetsError, setProductTargetsError] = useState<string | null>(null)
  const [customerTargetsError, setCustomerTargetsError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [recalculating, setRecalculating] = useState(false)
  const [deletingKey, setDeletingKey] = useState<string | null>(null)
  const [formError, setFormError] = useState<string | null>(null)
  const [tab, setTab] = useState<Tab>('sales')
  const [modalOpen, setModalOpen] = useState(false)
  const [dbRoutes, setDbRoutes] = useState<DbRoute[]>([])
  const [routesLoading, setRoutesLoading] = useState(true)

  const loadExecutives = useCallback(async () => {
    setExecutivesLoading(true)
    try {
      const data = await fetchUsers({ activeOnly: true })
      setDbExecutives(data.users)
      syncExecutivesFromDb(data.users)
    } catch {
      setDbExecutives([])
    } finally {
      setExecutivesLoading(false)
    }
  }, [syncExecutivesFromDb])

  const loadRoutes = useCallback(async () => {
    setRoutesLoading(true)
    try {
      const data = await fetchRoutes()
      setDbRoutes(data.routes)
    } catch {
      setDbRoutes([])
    } finally {
      setRoutesLoading(false)
    }
  }, [])

  const loadSalesTargets = useCallback(async () => {
    setSalesTargetsLoading(true)
    setSalesTargetsError(null)
    try {
      const data = await fetchSalesTargets()
      setDbSalesTargets(data.targets)
    } catch (err) {
      setDbSalesTargets([])
      setSalesTargetsError(err instanceof Error ? err.message : 'Failed to load sales targets')
    } finally {
      setSalesTargetsLoading(false)
    }
  }, [])

  const handleRecalculateSalesAchieved = useCallback(async () => {
    setRecalculating(true)
    setSalesTargetsError(null)
    try {
      const data = await recalculateSalesTargets()
      setDbSalesTargets(data.targets)
    } catch (err) {
      setSalesTargetsError(
        err instanceof Error ? err.message : 'Failed to sync achieved from orders'
      )
    } finally {
      setRecalculating(false)
    }
  }, [])

  const loadProductTargets = useCallback(async () => {
    setProductTargetsLoading(true)
    setProductTargetsError(null)
    try {
      const data = await fetchProductTargets()
      setDbProductTargets(data.targets)
    } catch (err) {
      setDbProductTargets([])
      setProductTargetsError(err instanceof Error ? err.message : 'Failed to load product targets')
    } finally {
      setProductTargetsLoading(false)
    }
  }, [])

  const loadCustomerTargets = useCallback(async () => {
    setCustomerTargetsLoading(true)
    setCustomerTargetsError(null)
    try {
      const data = await fetchCustomerTargets()
      setDbCustomerTargets(data.targets)
    } catch (err) {
      setDbCustomerTargets([])
      setCustomerTargetsError(err instanceof Error ? err.message : 'Failed to load customer targets')
    } finally {
      setCustomerTargetsLoading(false)
    }
  }, [])

  useEffect(() => {
    loadExecutives()
    loadRoutes()
    loadSalesTargets()
    loadProductTargets()
    loadCustomerTargets()
  }, [loadExecutives, loadRoutes, loadSalesTargets, loadProductTargets, loadCustomerTargets])

  const resolveExecutiveId = useCallback(
    (employeeCode: string) => getUserByEmployeeCode(employeeCode)?.id ?? '',
    [getUserByEmployeeCode]
  )

  const [salesForm, setSalesForm] = useState(initialSalesForm)

  const [productForm, setProductForm] = useState(initialProductForm)

  const [customerForm, setCustomerForm] = useState(initialCustomerForm)

  const resetForms = useCallback(() => {
    setSalesForm(initialSalesForm)
    setProductForm(initialProductForm)
    setCustomerForm(initialCustomerForm)
  }, [])

  const closeModal = useCallback(() => {
    setModalOpen(false)
    setFormError(null)
    resetForms()
  }, [resetForms])

  const getRouteNames = useCallback(
    (routeNo: string) => {
      const routeNos = parseRouteColumn(routeNo)
      if (routeNos.length === 0) return []
      return routeNos.map((no) => {
        const match = dbRoutes.find((r) => isRouteNoSelected([no], r.routeno))
        return match?.routename ?? `Route ${no}`
      })
    },
    [dbRoutes]
  )

  const getExecutiveDisplayName = useCallback(
    (employeeCode: string) => {
      const dbUser = dbExecutives.find((e) => e.employeecode === employeeCode)
      if (dbUser) return dbUser.username
      const user = getUserByEmployeeCode(employeeCode)
      return user?.username ?? employeeCode
    },
    [dbExecutives, getUserByEmployeeCode]
  )

  const handleDeleteSalesTarget = async (target: DbSalesTarget) => {
    const key = salesTargetKey(target)
    if (!window.confirm(`Delete sales target for ${getExecutiveDisplayName(target.employeeCode)}?`)) {
      return
    }
    setDeletingKey(key)
    setSalesTargetsError(null)
    try {
      await deleteSalesTarget({
        employeeCode: target.employeeCode,
        routeNo: target.routeNo,
        period: target.period,
        dueDate: String(target.dueDate).slice(0, 10),
      })
      await loadSalesTargets()
    } catch (err) {
      setSalesTargetsError(err instanceof Error ? err.message : 'Failed to delete sales target')
    } finally {
      setDeletingKey(null)
    }
  }

  const handleDeleteProductTarget = async (target: DbProductTarget) => {
    const key = productTargetKey(target)
    if (!window.confirm(`Delete product target for ${getExecutiveDisplayName(target.employeeCode)}?`)) {
      return
    }
    setDeletingKey(key)
    setProductTargetsError(null)
    try {
      await deleteProductTarget({
        employeeCode: target.employeeCode,
        routeNo: target.routeNo,
        type: target.type,
        products: target.products,
      })
      await loadProductTargets()
    } catch (err) {
      setProductTargetsError(err instanceof Error ? err.message : 'Failed to delete product target')
    } finally {
      setDeletingKey(null)
    }
  }

  const handleDeleteCustomerTarget = async (target: DbCustomerTarget) => {
    const key = customerTargetKey(target)
    if (!window.confirm(`Delete customer target for ${getExecutiveDisplayName(target.employeeCode)}?`)) {
      return
    }
    setDeletingKey(key)
    setCustomerTargetsError(null)
    try {
      await deleteCustomerTarget({
        employeeCode: target.employeeCode,
        routeNo: target.routeNo,
        type: target.type,
        period: target.period,
      })
      await loadCustomerTargets()
    } catch (err) {
      setCustomerTargetsError(err instanceof Error ? err.message : 'Failed to delete customer target')
    } finally {
      setDeletingKey(null)
    }
  }

  const tabs = [
    { id: 'sales' as const, label: 'Sales Targets' },
    { id: 'product' as const, label: 'Product Targets' },
    { id: 'customer' as const, label: 'Customer Targets' },
  ]

  const getAssignedRoutes = useCallback(
    (employeeCode: string): DbRoute[] => {
      if (!employeeCode) return []
      const dbUser = dbExecutives.find((e) => e.employeecode === employeeCode)
      const routeNos = parseRouteColumn(dbUser?.route)
      if (!routeNos.length) return []
      return routeNos.map((no) => {
        const match = dbRoutes.find((r) => isRouteNoSelected([no], r.routeno))
        return match ?? { routeno: no, routename: `Route ${no}` }
      })
    },
    [dbExecutives, dbRoutes]
  )

  const salesAssignedRoutes = useMemo(
    () => getAssignedRoutes(salesForm.employeeCode),
    [getAssignedRoutes, salesForm.employeeCode]
  )
  const productAssignedRoutes = useMemo(
    () => getAssignedRoutes(productForm.employeeCode),
    [getAssignedRoutes, productForm.employeeCode]
  )
  const customerAssignedRoutes = useMemo(
    () => getAssignedRoutes(customerForm.employeeCode),
    [getAssignedRoutes, customerForm.employeeCode]
  )

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormError(null)

    if (tab === 'sales') {
      if (salesAssignedRoutes.length > 0 && salesForm.routeNos.length === 0) {
        setFormError('Select at least one route')
        return
      }
      setSubmitting(true)
      try {
        await createSalesTarget({
          employeeCode: salesForm.employeeCode,
          routeNo: formatRouteColumn(salesForm.routeNos),
          period: salesForm.period,
          targetAmount: Number(salesForm.targetAmount),
          achievedAmount: Number(salesForm.achievedAmount || 0),
          dueDate: salesForm.endDate,
        })
        await loadSalesTargets()
        closeModal()
      } catch (err) {
        setFormError(err instanceof Error ? err.message : 'Failed to add sales target')
      } finally {
        setSubmitting(false)
      }
      return
    }

    if (tab === 'product') {
      if (productAssignedRoutes.length > 0 && productForm.routeNos.length === 0) {
        setFormError('Select at least one route')
        return
      }
      if (productForm.productNames.length === 0) {
        setFormError('Select at least one product')
        return
      }
      setSubmitting(true)
      try {
        await createProductTarget({
          employeeCode: productForm.employeeCode,
          routeNo: formatRouteColumn(productForm.routeNos),
          type: productForm.type,
          targetValue: Number(productForm.targetValue),
          achievedValue: Number(productForm.achievedValue || 0),
          productNames: productForm.productNames,
        })
        await loadProductTargets()
        closeModal()
      } catch (err) {
        setFormError(err instanceof Error ? err.message : 'Failed to add product target')
      } finally {
        setSubmitting(false)
      }
      return
    }

    if (tab === 'customer') {
      if (customerAssignedRoutes.length > 0 && customerForm.routeNos.length === 0) {
        setFormError('Select at least one route')
        return
      }
      setSubmitting(true)
      try {
        await createCustomerTarget({
          employeeCode: customerForm.employeeCode,
          routeNo: formatRouteColumn(customerForm.routeNos),
          type: customerForm.type,
          targetCount: Number(customerForm.targetCount),
          achievedCount: Number(customerForm.achievedCount || 0),
          targetAmount: Number(customerForm.targetAmount || 0),
          period: customerForm.period,
        })
        await loadCustomerTargets()
        closeModal()
      } catch (err) {
        setFormError(err instanceof Error ? err.message : 'Failed to add customer target')
      } finally {
        setSubmitting(false)
      }
    }
  }

  return (
    <div className="flex-1 overflow-auto min-h-0">
      <PageHeader
        title="Target Management"
        action={
          <div className="flex items-center gap-2">
            {tab === 'sales' && (
              <Button
                type="button"
                variant="secondary"
                disabled={recalculating || salesTargetsLoading}
                onClick={handleRecalculateSalesAchieved}
              >
                {recalculating ? 'Updating…' : 'Sync Achieved from Orders'}
              </Button>
            )}
            <Button onClick={() => setModalOpen(true)}>
              <Plus size={16} />
              Add Target
            </Button>
          </div>
        }
      />

      <div className="flex gap-1 mb-6 bg-gray-100 p-1 rounded-lg w-fit">
        {tabs.map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`px-4 py-2 rounded-md text-sm font-medium transition-colors ${
              tab === t.id
                ? 'bg-white text-gray-900 shadow-sm'
                : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'sales' && (
        <Card
          title="Sales Targets"
          subtitle="Achieved updates from order totals when an order is saved"
        >
          {salesTargetsError && (
            <p className="mb-4 text-sm text-red-600">{salesTargetsError}</p>
          )}
          <Table
            columns={[
              { key: 'executive', label: 'Executive' },
              { key: 'period', label: 'Period' },
              { key: 'target', label: 'Target' },
              { key: 'achieved', label: 'Achieved' },
              { key: 'route', label: 'Route' },
              { key: 'dates', label: 'Due Date' },
              { key: 'actions', label: '' },
            ]}
          >
            {salesTargetsLoading ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-gray-500">
                  Loading sales targets...
                </td>
              </tr>
            ) : dbSalesTargets.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-gray-500">
                  No sales targets found
                </td>
              </tr>
            ) : (
              dbSalesTargets.map((t) => {
                const key = salesTargetKey(t)
                return (
                  <tr key={key} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium">
                      {getExecutiveDisplayName(t.employeeCode)}
                    </td>
                    <td className="px-4 py-3">
                      <Badge label={t.period} className="bg-blue-100 text-blue-800 capitalize" />
                    </td>
                    <td className="px-4 py-3">{formatCurrency(t.targetAmount)}</td>
                    <td className="px-4 py-3">{formatCurrency(t.achievedAmount)}</td>
                    <td className="px-4 py-3 text-gray-600 text-sm">
                      <RouteTargetCell routeNames={getRouteNames(t.routeNo)} />
                    </td>
                    <td className="px-4 py-3 text-gray-500 text-xs">{t.dueDate}</td>
                    <td className="px-4 py-3 text-right">
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-red-600 hover:bg-red-50 hover:text-red-700"
                        disabled={deletingKey === key}
                        onClick={() => handleDeleteSalesTarget(t)}
                        aria-label="Delete sales target"
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </td>
                  </tr>
                )
              })
            )}
          </Table>
        </Card>
      )}

      {tab === 'product' && (
        <Card
          title="Product Targets"
          subtitle="Quantity-wise · Volume-wise · New promotion · Product replacement · Own products"
        >
          {productTargetsError && (
            <p className="mb-4 text-sm text-red-600">{productTargetsError}</p>
          )}
          <Table
            columns={[
              { key: 'executive', label: 'Executive' },
              { key: 'product', label: 'Product' },
              { key: 'type', label: 'Type' },
              { key: 'target', label: 'Target' },
              { key: 'achieved', label: 'Achieved' },
              { key: 'route', label: 'Route' },
              { key: 'actions', label: '' },
            ]}
          >
            {productTargetsLoading ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-gray-500">
                  Loading product targets...
                </td>
              </tr>
            ) : dbProductTargets.length === 0 ? (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-gray-500">
                  No product targets found
                </td>
              </tr>
            ) : (
              dbProductTargets.map((t) => {
                const key = productTargetKey(t)
                const display = dbProductToDisplay(
                  t,
                  resolveExecutiveId(t.employeeCode),
                  getRouteNames(t.routeNo)
                )
                return (
                  <tr key={key} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium">
                      {getExecutiveDisplayName(t.employeeCode)}
                    </td>
                    <td className="px-4 py-3">
                      <ProductTargetCell target={display} />
                    </td>
                    <td className="px-4 py-3">
                      <Badge
                        label={PRODUCT_TARGET_LABELS[t.type]}
                        className="bg-purple-100 text-purple-800"
                      />
                    </td>
                    <td className="px-4 py-3">{t.targetValue}</td>
                    <td className="px-4 py-3">{t.achievedValue ?? 0}</td>
                    <td className="px-4 py-3 text-gray-600 text-sm">
                      <RouteTargetCell routeNames={display.routeNames} />
                    </td>
                    <td className="px-4 py-3 text-right">
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-red-600 hover:bg-red-50 hover:text-red-700"
                        disabled={deletingKey === key}
                        onClick={() => handleDeleteProductTarget(t)}
                        aria-label="Delete product target"
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </td>
                  </tr>
                )
              })
            )}
          </Table>
        </Card>
      )}

      {tab === 'customer' && (
        <Card
          title="Customer Targets"
          subtitle="New acquisition · Missing recovery · Outstanding collection · Purchase limit"
        >
          {customerTargetsError && (
            <p className="mb-4 text-sm text-red-600">{customerTargetsError}</p>
          )}
          <Table
            columns={[
              { key: 'executive', label: 'Executive' },
              { key: 'type', label: 'Target Type' },
              { key: 'target', label: 'Target' },
              { key: 'achieved', label: 'Achieved' },
              { key: 'amount', label: 'Amount' },
              { key: 'route', label: 'Route' },
              { key: 'period', label: 'Period' },
              { key: 'actions', label: '' },
            ]}
          >
            {customerTargetsLoading ? (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-gray-500">
                  Loading customer targets...
                </td>
              </tr>
            ) : dbCustomerTargets.length === 0 ? (
              <tr>
                <td colSpan={8} className="px-4 py-8 text-center text-gray-500">
                  No customer targets found
                </td>
              </tr>
            ) : (
              dbCustomerTargets.map((t) => {
                const key = customerTargetKey(t)
                return (
                  <tr key={key} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium">
                      {getExecutiveDisplayName(t.employeeCode)}
                    </td>
                    <td className="px-4 py-3">
                      <Badge
                        label={CUSTOMER_TARGET_LABELS[t.type]}
                        className="bg-teal-100 text-teal-800"
                      />
                    </td>
                    <td className="px-4 py-3">{t.targetCount}</td>
                    <td className="px-4 py-3">{t.achievedCount ?? 0}</td>
                    <td className="px-4 py-3">
                      {formatCurrency(t.targetAmount || 0)}
                    </td>
                    <td className="px-4 py-3 text-gray-600 text-sm">
                      <RouteTargetCell routeNames={getRouteNames(t.routeNo)} />
                    </td>
                    <td className="px-4 py-3 capitalize text-gray-500">{t.period}</td>
                    <td className="px-4 py-3 text-right">
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        className="text-red-600 hover:bg-red-50 hover:text-red-700"
                        disabled={deletingKey === key}
                        onClick={() => handleDeleteCustomerTarget(t)}
                        aria-label="Delete customer target"
                      >
                        <Trash2 className="h-4 w-4" />
                      </Button>
                    </td>
                  </tr>
                )
              })
            )}
          </Table>
        </Card>
      )}

      <Modal
        open={modalOpen}
        onClose={closeModal}
        title={`Add ${tabs.find((t) => t.id === tab)?.label}`}
        xl
      >
        <form onSubmit={handleSubmit} className="space-y-4">
          {tab === 'sales' && (
            <>
              <FormField label="Executive" required>
                <select
                  className={selectClass}
                  value={salesForm.employeeCode}
                  onChange={(e) =>
                    setSalesForm({ ...salesForm, employeeCode: e.target.value, routeNos: [] })
                  }
                  required
                  disabled={executivesLoading}
                >
                  <option value="">
                    {executivesLoading ? 'Loading executives...' : 'Select executive'}
                  </option>
                  {dbExecutives.map((ex) => (
                    <option key={ex.employeecode} value={ex.employeecode}>
                      {ex.username}
                    </option>
                  ))}
                </select>
              </FormField>
              <FormField label="Assigned Routes">
                <AssignedRoutesMultiSelect
                  employeeCode={salesForm.employeeCode}
                  routesLoading={routesLoading}
                  assignedRoutes={salesAssignedRoutes}
                  value={salesForm.routeNos}
                  onChange={(routeNos) => setSalesForm({ ...salesForm, routeNos })}
                />
              </FormField>
              <FormField label="Period" required>
                <select
                  className={selectClass}
                  value={salesForm.period}
                  onChange={(e) =>
                    setSalesForm({ ...salesForm, period: e.target.value as typeof salesForm.period })
                  }
                >
                  <option value="daily">Daily</option>
                  <option value="weekly">Weekly</option>
                  <option value="monthly">Monthly</option>
                </select>
              </FormField>
              <FormField label="Target Amount (QAR)" required>
                <input
                  type="number"
                  className={inputClass}
                  value={salesForm.targetAmount}
                  onChange={(e) => setSalesForm({ ...salesForm, targetAmount: e.target.value })}
                  required
                />
              </FormField>
              <FormField label="Due Date" required>
                <input
                  type="date"
                  className={inputClass}
                  value={salesForm.endDate}
                  onChange={(e) => setSalesForm({ ...salesForm, endDate: e.target.value })}
                  required
                />
              </FormField>
            </>
          )}

          {tab === 'product' && (
            <>
              <FormField label="Executive" required>
                <select
                  className={selectClass}
                  value={productForm.employeeCode}
                  onChange={(e) =>
                    setProductForm({ ...productForm, employeeCode: e.target.value, routeNos: [] })
                  }
                  required
                  disabled={executivesLoading}
                >
                  <option value="">
                    {executivesLoading ? 'Loading executives...' : 'Select executive'}
                  </option>
                  {dbExecutives.map((ex) => (
                    <option key={ex.employeecode} value={ex.employeecode}>
                      {ex.username}
                    </option>
                  ))}
                </select>
              </FormField>
              <FormField label="Assigned Routes">
                <AssignedRoutesMultiSelect
                  employeeCode={productForm.employeeCode}
                  routesLoading={routesLoading}
                  assignedRoutes={productAssignedRoutes}
                  value={productForm.routeNos}
                  onChange={(routeNos) => setProductForm({ ...productForm, routeNos })}
                />
              </FormField>
              <FormField label="Target Type" required>
                <select
                  className={selectClass}
                  value={productForm.type}
                  onChange={(e) =>
                    setProductForm({
                      ...productForm,
                      type: e.target.value as typeof productForm.type,
                    })
                  }
                >
                  <option value="quantity">Quantity-wise</option>
                  <option value="volume">Volume-wise</option>
                  <option value="new_promotion">New Product Promotion</option>
                  <option value="replacement">Product Replacement</option>
                  <option value="own_products">Own Products</option>
                </select>
              </FormField>
              <FormField label="Products" required>
                <ItemMasterSelect
                  value={productForm.productNames}
                  onChange={(productNames) => setProductForm({ ...productForm, productNames })}
                  disabled={submitting}
                  required
                />
              </FormField>
              <FormField label="Target Value" required>
                <input
                  type="number"
                  className={inputClass}
                  value={productForm.targetValue}
                  onChange={(e) => setProductForm({ ...productForm, targetValue: e.target.value })}
                  required
                />
              </FormField>
            </>
          )}

          {tab === 'customer' && (
            <>
              <FormField label="Executive" required>
                <select
                  className={selectClass}
                  value={customerForm.employeeCode}
                  onChange={(e) =>
                    setCustomerForm({
                      ...customerForm,
                      employeeCode: e.target.value,
                      routeNos: [],
                    })
                  }
                  required
                  disabled={executivesLoading}
                >
                  <option value="">
                    {executivesLoading ? 'Loading executives...' : 'Select executive'}
                  </option>
                  {dbExecutives.map((ex) => (
                    <option key={ex.employeecode} value={ex.employeecode}>
                      {ex.username}
                    </option>
                  ))}
                </select>
              </FormField>
              <FormField label="Assigned Routes">
                <AssignedRoutesMultiSelect
                  employeeCode={customerForm.employeeCode}
                  routesLoading={routesLoading}
                  assignedRoutes={customerAssignedRoutes}
                  value={customerForm.routeNos}
                  onChange={(routeNos) => setCustomerForm({ ...customerForm, routeNos })}
                />
              </FormField>
              <FormField label="Target Type" required>
                <select
                  className={selectClass}
                  value={customerForm.type}
                  onChange={(e) =>
                    setCustomerForm({
                      ...customerForm,
                      type: e.target.value as typeof customerForm.type,
                    })
                  }
                >
                  <option value="new_acquisition">New Acquisition</option>
                  <option value="missing_recovery">Missing Customer Recovery</option>
                  <option value="outstanding_collection">Outstanding Collection</option>
                  <option value="purchase_limit">Customer Purchase Limit</option>
                </select>
              </FormField>
              <FormField label="Period" required>
                <select
                  className={selectClass}
                  value={customerForm.period}
                  onChange={(e) =>
                    setCustomerForm({
                      ...customerForm,
                      period: e.target.value as typeof customerForm.period,
                    })
                  }
                >
                  <option value="daily">Daily</option>
                  <option value="weekly">Weekly</option>
                  <option value="monthly">Monthly</option>
                </select>
              </FormField>
              <FormField label="Target Count" required>
                <input
                  type="number"
                  className={inputClass}
                  value={customerForm.targetCount}
                  onChange={(e) =>
                    setCustomerForm({ ...customerForm, targetCount: e.target.value })
                  }
                  required
                />
              </FormField>
              <FormField label="Target Amount (QAR)">
                <input
                  type="number"
                  className={inputClass}
                  value={customerForm.targetAmount}
                  onChange={(e) =>
                    setCustomerForm({ ...customerForm, targetAmount: e.target.value })
                  }
                />
              </FormField>
            </>
          )}

          {formError && <p className="text-sm text-red-600">{formError}</p>}

          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" variant="secondary" onClick={closeModal} disabled={submitting}>
              Cancel
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Saving...' : 'Add Target'}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
