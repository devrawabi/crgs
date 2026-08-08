import { useCallback, useEffect, useMemo, useState } from 'react'
import { Download, FileText } from 'lucide-react'
import * as XLSX from 'xlsx'
import { Card } from '../ui/Card'
import { Table } from '../ui/Table'
import { formatCurrency } from '../../context/AppContext'
import {
  TASK_TYPE_LABELS,
  CUSTOMER_TARGET_LABELS,
  PRODUCT_TARGET_LABELS,
} from '../../data/mockData'
import { fetchOrders, fetchAllOrders, type DbOrder } from '../../api/orders'
import { fetchTasks, type DbTask } from '../../api/tasks'
import { fetchVisits, type DbVisit } from '../../api/visits'
import {
  fetchProductReviews,
  type DbProductReview,
} from '../../api/productReviews'
import {
  fetchSalesTargets,
  fetchProductTargets,
  fetchCustomerTargets,
  type DbSalesTarget,
  type DbProductTarget,
  type DbCustomerTarget,
} from '../../api/targets'
import {
  normalizeRouteNo,
  parseRouteColumn,
  type DbLoginUser,
} from '../../api/users'
import { downloadExecutiveDetailPdf } from '../../utils/downloadExecutiveDetailPdf'
import { InlineLoading } from '../ui/LoadingState'

type DetailSection = 'orders' | 'visits' | 'tasks' | 'targets' | 'reviews'

const DETAIL_PAGE_SIZE = 100

interface ExecutiveDetailReportProps {
  executives: DbLoginUser[]
  routeNameByNo: Map<string, string>
  loadingUsers: boolean
}

function formatDate(value: string | null | undefined) {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return value.slice(0, 10)
  return d.toLocaleDateString('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  })
}

function taskLabel(type: string) {
  return TASK_TYPE_LABELS[type] ?? type.replace(/_/g, ' ')
}

function productTargetLabel(type: string) {
  return PRODUCT_TARGET_LABELS[type] ?? type.replace(/_/g, ' ')
}

function customerTargetLabel(type: string) {
  return CUSTOMER_TARGET_LABELS[type] ?? type.replace(/_/g, ' ')
}

function isCompletedStatus(status: string) {
  const value = status.trim().toLowerCase().replace(/\s+/g, '_')
  return value === 'completed' || value === 'complete' || value === 'done'
}

function sheetFromRows(
  rows: Record<string, string | number>[],
  headers: string[]
) {
  if (rows.length === 0) return XLSX.utils.aoa_to_sheet([headers])
  return XLSX.utils.json_to_sheet(rows)
}

function matchEmployeeCode(value: string, employeeCode: string) {
  return value.trim().toUpperCase() === employeeCode.trim().toUpperCase()
}

export function ExecutiveDetailReport({
  executives,
  routeNameByNo,
  loadingUsers,
}: ExecutiveDetailReportProps) {
  const [selectedCode, setSelectedCode] = useState('')
  const [section, setSection] = useState<DetailSection>('orders')
  const [orders, setOrders] = useState<DbOrder[]>([])
  const [visits, setVisits] = useState<DbVisit[]>([])
  const [tasks, setTasks] = useState<DbTask[]>([])
  const [reviews, setReviews] = useState<DbProductReview[]>([])
  const [salesTargets, setSalesTargets] = useState<DbSalesTarget[]>([])
  const [productTargets, setProductTargets] = useState<DbProductTarget[]>([])
  const [customerTargets, setCustomerTargets] = useState<DbCustomerTarget[]>(
    []
  )
  const [detailLoading, setDetailLoading] = useState(false)
  const [detailError, setDetailError] = useState<string | null>(null)
  const [detailTruncated, setDetailTruncated] = useState(false)

  const selectedExecutive = useMemo(
    () =>
      executives.find((e) =>
        matchEmployeeCode(e.employeecode, selectedCode)
      ) ?? null,
    [executives, selectedCode]
  )

  const routeNos = useMemo(
    () => (selectedExecutive ? parseRouteColumn(selectedExecutive.route) : []),
    [selectedExecutive]
  )

  const completedTasks = useMemo(
    () => tasks.filter((t) => isCompletedStatus(t.status)),
    [tasks]
  )

  const orderLineCount = useMemo(
    () =>
      orders.reduce(
        (sum, o) => sum + (o.itemCount ?? o.items?.length ?? 0),
        0
      ),
    [orders]
  )

  const targetCount =
    salesTargets.length + productTargets.length + customerTargets.length

  const clearDetails = useCallback(() => {
    setOrders([])
    setVisits([])
    setTasks([])
    setReviews([])
    setSalesTargets([])
    setProductTargets([])
    setCustomerTargets([])
  }, [])

  const loadDetails = useCallback(
    async (employeeCode: string) => {
      setDetailLoading(true)
      setDetailError(null)
      setDetailTruncated(false)
      try {
        const [
          ordersRes,
          visitsRes,
          tasksRes,
          reviewsRes,
          salesRes,
          productRes,
          customerTargetRes,
        ] = await Promise.all([
          // First page only — full history available via Excel export.
          fetchOrders({
            employeeCode,
            includeDetails: false,
            limit: DETAIL_PAGE_SIZE,
            offset: 0,
          }),
          fetchVisits({ employeeCode, limit: DETAIL_PAGE_SIZE, offset: 0 }),
          fetchTasks({ employeeCode, limit: DETAIL_PAGE_SIZE, offset: 0 }),
          fetchProductReviews({
            employeeCode,
            limit: DETAIL_PAGE_SIZE,
            offset: 0,
          }),
          fetchSalesTargets({
            employeeCode,
            limit: DETAIL_PAGE_SIZE,
            offset: 0,
          }),
          fetchProductTargets({
            employeeCode,
            limit: DETAIL_PAGE_SIZE,
            offset: 0,
          }),
          fetchCustomerTargets({
            employeeCode,
            limit: DETAIL_PAGE_SIZE,
            offset: 0,
          }),
        ])

        setOrders(ordersRes.orders)
        setVisits(visitsRes.visits)
        setTasks(tasksRes.tasks)
        setReviews(reviewsRes.items ?? [])
        setSalesTargets(salesRes.targets ?? [])
        setProductTargets(productRes.targets ?? [])
        setCustomerTargets(customerTargetRes.targets ?? [])
        setDetailTruncated(
          ordersRes.has_more === true ||
            visitsRes.has_more === true ||
            tasksRes.has_more === true ||
            reviewsRes.has_more === true ||
            salesRes.has_more === true ||
            productRes.has_more === true ||
            customerTargetRes.has_more === true
        )
      } catch (err) {
        clearDetails()
        setDetailTruncated(false)
        setDetailError(
          err instanceof Error
            ? err.message
            : 'Failed to load executive details'
        )
      } finally {
        setDetailLoading(false)
      }
    },
    [clearDetails]
  )

  useEffect(() => {
    if (!selectedCode) {
      clearDetails()
      setDetailError(null)
      return
    }
    void loadDetails(selectedCode)
  }, [selectedCode, loadDetails, clearDetails])

  const routeLabel = useCallback(
    (route: string | number | null | undefined) => {
      const no = normalizeRouteNo(route)
      return routeNameByNo.get(no) || String(route ?? '').trim() || ''
    },
    [routeNameByNo]
  )

  const downloadExcel = async () => {
    if (!selectedExecutive) return

    const workbook = XLSX.utils.book_new()
    const execName = selectedExecutive.username
    const code = selectedExecutive.employeecode
    const routeNames = routeNos.map((no) => routeLabel(no) || no).join(', ')

    // Line-item sheet needs details; fetch only when exporting (not on page load).
    let exportOrders = orders
    const needsDetails = orders.some((o) => !(o.items && o.items.length > 0))
    if (needsDetails && code) {
      try {
        const detailed = await fetchAllOrders({
          employeeCode: code,
          includeDetails: true,
        })
        exportOrders = detailed.orders
      } catch {
        exportOrders = orders
      }
    }

    const exportLineCount = exportOrders.reduce(
      (sum, o) => sum + (o.items?.length ?? o.itemCount ?? 0),
      0
    )

    const summarySheet = XLSX.utils.aoa_to_sheet([
      ['Executive Performance Detail — Full Export'],
      ['Executive', execName],
      ['Employee Code', code],
      ['Designation', selectedExecutive.designation || ''],
      ['Routes', routeNames || routeNos.join(', ') || '—'],
      ['Orders', exportOrders.length],
      ['Order Line Items', exportLineCount],
      ['Visits', visits.length],
      ['Tasks (All)', tasks.length],
      ['Tasks (Completed)', completedTasks.length],
      ['Sales Targets', salesTargets.length],
      ['Product Targets', productTargets.length],
      ['Customer Targets', customerTargets.length],
      ['Product Reviews', reviews.length],
      ['Generated At', new Date().toLocaleString()],
    ])
    XLSX.utils.book_append_sheet(workbook, summarySheet, 'Summary')

    const ordersSheet = sheetFromRows(
      exportOrders.map((o) => ({
        'Order No': o.orderNo || '',
        'Order Date': o.orderDate || '',
        'Employee Code': o.employeeCode || code,
        'Employee Name': execName,
        'Customer Code': o.customerCode || '',
        'Customer Name': o.customerName || '',
        'Route No': o.route || '',
        'Route Name': routeLabel(o.route),
        'Item Count': o.itemCount ?? o.items?.length ?? 0,
        'Total Amount': o.totalAmount ?? 0,
        'Expected Date': o.expectedDate || '',
      })),
      [
        'Order No',
        'Order Date',
        'Employee Code',
        'Employee Name',
        'Customer Code',
        'Customer Name',
        'Route No',
        'Route Name',
        'Item Count',
        'Total Amount',
        'Expected Date',
      ]
    )
    XLSX.utils.book_append_sheet(workbook, ordersSheet, 'Orders')

    const orderItemsSheet = sheetFromRows(
      exportOrders.flatMap((o) =>
        (o.items ?? []).map((item) => ({
          'Order No': o.orderNo || '',
          'Order Date': o.orderDate || '',
          'Employee Code': o.employeeCode || code,
          'Employee Name': execName,
          'Customer Code': o.customerCode || '',
          'Customer Name': o.customerName || '',
          'Order Route': o.route || '',
          'Item Code': item.itemCode || '',
          'Item Name': item.itemName || '',
          Qty: item.qty ?? 0,
          UOM: item.uom || '',
          Price: item.price ?? 0,
          Amount: item.amount ?? 0,
          'Expected Date': o.expectedDate || '',
          'Order Total': o.totalAmount ?? 0,
        }))
      ),
      [
        'Order No',
        'Order Date',
        'Employee Code',
        'Employee Name',
        'Customer Code',
        'Customer Name',
        'Order Route',
        'Item Code',
        'Item Name',
        'Qty',
        'UOM',
        'Price',
        'Amount',
        'Expected Date',
        'Order Total',
      ]
    )
    XLSX.utils.book_append_sheet(workbook, orderItemsSheet, 'Order Line Items')

    const visitsSheet = sheetFromRows(
      visits.map((v) => ({
        'Employee Code': v.employeeCode || code,
        'Employee Name': execName,
        'Visit Date': v.visitDate || '',
        'Visit Start': v.visitStart || '',
        'Visit End': v.visitEnd || '',
        Duration: v.totalDuration || '',
        'Customer Code': v.customerCode || '',
        'Customer Name': v.customerName || '',
        'Route No': v.route || '',
        'Route Name': routeLabel(v.route),
        Location: v.location || '',
        Reason: v.reason || '',
        Remarks: v.remarks || '',
        'Follow Up': v.followUp || '',
      })),
      [
        'Employee Code',
        'Employee Name',
        'Visit Date',
        'Visit Start',
        'Visit End',
        'Duration',
        'Customer Code',
        'Customer Name',
        'Route No',
        'Route Name',
        'Location',
        'Reason',
        'Remarks',
        'Follow Up',
      ]
    )
    XLSX.utils.book_append_sheet(workbook, visitsSheet, 'Visits')

    const tasksSheet = sheetFromRows(
      tasks.map((t) => ({
        'Employee Code': t.employeeCode || code,
        'Employee Name': execName,
        'Task Type': taskLabel(t.type),
        'Task Type Code': t.type || '',
        'Route No': t.routeNo || '',
        'Route Name': routeLabel(t.routeNo),
        Status: t.status || '',
        'Due Date': t.dueDate || '',
        Completed: isCompletedStatus(t.status) ? 'Yes' : 'No',
      })),
      [
        'Employee Code',
        'Employee Name',
        'Task Type',
        'Task Type Code',
        'Route No',
        'Route Name',
        'Status',
        'Due Date',
        'Completed',
      ]
    )
    XLSX.utils.book_append_sheet(workbook, tasksSheet, 'Tasks')

    const salesTargetsSheet = sheetFromRows(
      salesTargets.map((t) => {
        const achievement =
          t.targetAmount > 0
            ? Math.round((t.achievedAmount / t.targetAmount) * 10000) / 100
            : 0
        return {
          'Employee Code': t.employeeCode || code,
          'Employee Name': execName,
          Period: t.period || '',
          'Route No': t.routeNo || '',
          'Route Name': routeLabel(t.routeNo),
          'Target Amount': t.targetAmount ?? 0,
          'Achieved Amount': t.achievedAmount ?? 0,
          'Achievement %': achievement,
          'Due Date': t.dueDate || '',
        }
      }),
      [
        'Employee Code',
        'Employee Name',
        'Period',
        'Route No',
        'Route Name',
        'Target Amount',
        'Achieved Amount',
        'Achievement %',
        'Due Date',
      ]
    )
    XLSX.utils.book_append_sheet(workbook, salesTargetsSheet, 'Sales Targets')

    const productTargetsSheet = sheetFromRows(
      productTargets.map((t) => {
        const achievement =
          t.targetValue > 0
            ? Math.round((t.achievedValue / t.targetValue) * 10000) / 100
            : 0
        return {
          'Employee Code': t.employeeCode || code,
          'Employee Name': execName,
          'Target Type': productTargetLabel(t.type),
          'Target Type Code': t.type || '',
          'Route No': t.routeNo || '',
          'Route Name': routeLabel(t.routeNo),
          Products: (t.productNames ?? t.products ?? []).join('; '),
          'Product Codes': (t.products ?? []).join('; '),
          'Target Value': t.targetValue ?? 0,
          'Achieved Value': t.achievedValue ?? 0,
          'Achievement %': achievement,
        }
      }),
      [
        'Employee Code',
        'Employee Name',
        'Target Type',
        'Target Type Code',
        'Route No',
        'Route Name',
        'Products',
        'Product Codes',
        'Target Value',
        'Achieved Value',
        'Achievement %',
      ]
    )
    XLSX.utils.book_append_sheet(
      workbook,
      productTargetsSheet,
      'Product Targets'
    )

    const customerTargetsSheet = sheetFromRows(
      customerTargets.map((t) => {
        const countAchievement =
          t.targetCount > 0
            ? Math.round((t.achievedCount / t.targetCount) * 10000) / 100
            : 0
        return {
          'Employee Code': t.employeeCode || code,
          'Employee Name': execName,
          'Target Type': customerTargetLabel(t.type),
          'Target Type Code': t.type || '',
          Period: t.period || '',
          'Route No': t.routeNo || '',
          'Route Name': routeLabel(t.routeNo),
          'Target Count': t.targetCount ?? 0,
          'Achieved Count': t.achievedCount ?? 0,
          'Count Achievement %': countAchievement,
          'Target Amount': t.targetAmount ?? 0,
        }
      }),
      [
        'Employee Code',
        'Employee Name',
        'Target Type',
        'Target Type Code',
        'Period',
        'Route No',
        'Route Name',
        'Target Count',
        'Achieved Count',
        'Count Achievement %',
        'Target Amount',
      ]
    )
    XLSX.utils.book_append_sheet(
      workbook,
      customerTargetsSheet,
      'Customer Targets'
    )

    const reviewsSheet = sheetFromRows(
      reviews.map((r) => ({
        'Employee Code': r.employeeCode || code,
        'Employee Name': execName,
        'Route No': r.route || '',
        'Route Name': routeLabel(r.route),
        'Customer Code': r.customerCode || '',
        'Customer Name': r.customerName || '',
        'Item Code': r.itemCode || '',
        'Item Name': r.itemName || '',
        Reason: r.reason || '',
      })),
      [
        'Employee Code',
        'Employee Name',
        'Route No',
        'Route Name',
        'Customer Code',
        'Customer Name',
        'Item Code',
        'Item Name',
        'Reason',
      ]
    )
    XLSX.utils.book_append_sheet(workbook, reviewsSheet, 'Detailed Reviews')

    const safeName = execName.replace(/[^\w\-]+/g, '_').slice(0, 40)
    XLSX.writeFile(
      workbook,
      `executive_full_${safeName}_${code}_${new Date().toISOString().slice(0, 10)}.xlsx`
    )
  }

  const downloadPdf = () => {
    if (!selectedExecutive) return
    const execName = selectedExecutive.username
    const code = selectedExecutive.employeecode
    const routeNames = routeNos.map((no) => routeLabel(no) || no).join(', ')

    downloadExecutiveDetailPdf({
      execName,
      code,
      designation: selectedExecutive.designation,
      routeNames: routeNames || routeNos.join(', '),
      orders,
      visits,
      tasks,
      salesTargets,
      productTargets,
      customerTargets,
      reviews,
      completedTaskCount: completedTasks.length,
      orderLineCount,
      routeLabel,
      taskLabel,
      productTargetLabel,
      customerTargetLabel,
      isCompletedStatus,
    })
  }

  const sectionTabs: { id: DetailSection; label: string; count: number }[] = [
    { id: 'orders', label: 'Orders', count: orders.length },
    { id: 'visits', label: 'Visits', count: visits.length },
    { id: 'tasks', label: 'Tasks', count: tasks.length },
    { id: 'targets', label: 'Targets', count: targetCount },
    { id: 'reviews', label: 'Reviews', count: reviews.length },
  ]

  return (
    <div className="space-y-6">
      <Card
        title="Executive Performance Detail"
        subtitle="Select an executive to download full orders, visits, tasks, targets, and reviews"
      >
        <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <label className="block min-w-0 flex-1">
            <span className="mb-1.5 block text-sm font-medium text-gray-700">
              Executive
            </span>
            <select
              value={selectedCode}
              onChange={(e) => setSelectedCode(e.target.value)}
              disabled={loadingUsers || executives.length === 0}
              className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 shadow-sm focus:border-teal-700 focus:outline-none focus:ring-2 focus:ring-teal-700/20"
            >
              <option value="">Select executive...</option>
              {executives.map((exec) => (
                <option key={exec.employeecode} value={exec.employeecode}>
                  {exec.username} ({exec.employeecode})
                </option>
              ))}
            </select>
          </label>

          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={downloadExcel}
              disabled={!selectedExecutive || detailLoading}
              className="inline-flex items-center justify-center gap-2 rounded-lg bg-teal-800 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-teal-900 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Download className="h-4 w-4" />
              Download Excel
            </button>
            <button
              type="button"
              onClick={downloadPdf}
              disabled={!selectedExecutive || detailLoading}
              className="inline-flex items-center justify-center gap-2 rounded-lg border border-teal-800 bg-white px-4 py-2 text-sm font-medium text-teal-800 transition-colors hover:bg-teal-50 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <FileText className="h-4 w-4" />
              Download PDF
            </button>
          </div>
        </div>

        {selectedExecutive && (
          <div className="mt-4 grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
            <div className="rounded-lg bg-gray-50 px-3 py-3">
              <div className="text-xs text-gray-500">Orders</div>
              <div className="text-lg font-semibold text-gray-900">
                {orders.length}
              </div>
            </div>
            <div className="rounded-lg bg-gray-50 px-3 py-3">
              <div className="text-xs text-gray-500">Visits</div>
              <div className="text-lg font-semibold text-gray-900">
                {visits.length}
              </div>
            </div>
            <div className="rounded-lg bg-gray-50 px-3 py-3">
              <div className="text-xs text-gray-500">Tasks</div>
              <div className="text-lg font-semibold text-gray-900">
                {tasks.length}
              </div>
            </div>
            <div className="rounded-lg bg-gray-50 px-3 py-3">
              <div className="text-xs text-gray-500">Targets</div>
              <div className="text-lg font-semibold text-gray-900">
                {targetCount}
              </div>
            </div>
            <div className="rounded-lg bg-gray-50 px-3 py-3">
              <div className="text-xs text-gray-500">Reviews</div>
              <div className="text-lg font-semibold text-gray-900">
                {reviews.length}
              </div>
            </div>
          </div>
        )}

        {selectedExecutive && routeNos.length > 0 && (
          <p className="mt-3 text-sm text-gray-500">
            Routes:{' '}
            {routeNos.map((no) => routeLabel(no) || no).join(', ')}
          </p>
        )}
      </Card>

      {!selectedCode && (
        <p className="text-sm text-gray-500">
          Choose an executive above to load full performance details.
        </p>
      )}

      {detailError && <p className="text-sm text-red-600">{detailError}</p>}

      {selectedCode && detailLoading && (
        <InlineLoading label="Loading executive details..." />
      )}

      {selectedCode && !detailLoading && detailTruncated && (
        <p className="mb-4 text-sm text-amber-700 bg-amber-50 border border-amber-200 rounded-lg px-3 py-2">
          Showing the latest {DETAIL_PAGE_SIZE} rows per section. Export Excel for the
          full history.
        </p>
      )}

      {selectedCode && !detailLoading && (
        <>
          <div className="flex flex-wrap gap-1 rounded-lg bg-gray-100 p-1">
            {sectionTabs.map((tab) => (
              <button
                key={tab.id}
                type="button"
                onClick={() => setSection(tab.id)}
                className={`rounded-md px-3 py-2 text-xs font-medium transition-colors sm:text-sm ${
                  section === tab.id
                    ? 'bg-white text-gray-900 shadow-sm'
                    : 'text-gray-600 hover:text-gray-900'
                }`}
              >
                {tab.label} ({tab.count})
              </button>
            ))}
          </div>

          {section === 'orders' && (
            <Card
              title="Orders Taken"
              subtitle={`${orders.length} orders · ${orderLineCount} line items`}
            >
              <Table
                columns={[
                  { key: 'orderNo', label: 'Order No' },
                  { key: 'date', label: 'Date' },
                  { key: 'customer', label: 'Customer' },
                  { key: 'route', label: 'Route' },
                  { key: 'items', label: 'Items' },
                  { key: 'amount', label: 'Amount' },
                ]}
              >
                {orders.map((order) => (
                  <tr key={order.orderNo} className="hover:bg-gray-50">
                    <td className="px-4 py-3 font-medium">{order.orderNo}</td>
                    <td className="px-4 py-3">{formatDate(order.orderDate)}</td>
                    <td className="px-4 py-3">
                      <div className="font-medium">{order.customerName}</div>
                      <div className="text-xs text-gray-400">
                        {order.customerCode}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      {routeLabel(order.route) || order.route || '—'}
                    </td>
                    <td className="px-4 py-3">{order.itemCount}</td>
                    <td className="px-4 py-3">
                      {formatCurrency(order.totalAmount)}
                    </td>
                  </tr>
                ))}
              </Table>
              {orders.length === 0 && (
                <p className="mt-4 text-sm text-gray-500">
                  No orders found for this executive.
                </p>
              )}
            </Card>
          )}

          {section === 'visits' && (
            <Card
              title="Customer Visit Details"
              subtitle={`${visits.length} visits`}
            >
              <Table
                columns={[
                  { key: 'date', label: 'Visit Date' },
                  { key: 'customer', label: 'Customer' },
                  { key: 'time', label: 'Start / End' },
                  { key: 'duration', label: 'Duration' },
                  { key: 'reason', label: 'Reason' },
                  { key: 'remarks', label: 'Remarks' },
                ]}
              >
                {visits.map((visit, index) => (
                  <tr
                    key={`${visit.customerCode}-${visit.visitDate}-${visit.visitStart}-${index}`}
                    className="hover:bg-gray-50"
                  >
                    <td className="px-4 py-3">
                      {formatDate(visit.visitDate)}
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-medium">{visit.customerName}</div>
                      <div className="text-xs text-gray-400">
                        {visit.customerCode}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-600">
                      {visit.visitStart || '—'}
                      {visit.visitEnd ? ` → ${visit.visitEnd}` : ''}
                    </td>
                    <td className="px-4 py-3">
                      {visit.totalDuration || '—'}
                    </td>
                    <td className="px-4 py-3">{visit.reason || '—'}</td>
                    <td className="px-4 py-3 max-w-xs truncate">
                      {visit.remarks || '—'}
                    </td>
                  </tr>
                ))}
              </Table>
              {visits.length === 0 && (
                <p className="mt-4 text-sm text-gray-500">
                  No visits found for this executive.
                </p>
              )}
            </Card>
          )}

          {section === 'tasks' && (
            <Card title="All Tasks" subtitle={`${tasks.length} tasks`}>
              <Table
                columns={[
                  { key: 'type', label: 'Task Type' },
                  { key: 'route', label: 'Route' },
                  { key: 'status', label: 'Status' },
                  { key: 'due', label: 'Due Date' },
                ]}
              >
                {tasks.map((task, index) => (
                  <tr
                    key={`${task.type}-${task.routeNo}-${task.dueDate}-${index}`}
                    className="hover:bg-gray-50"
                  >
                    <td className="px-4 py-3 font-medium">
                      {taskLabel(task.type)}
                    </td>
                    <td className="px-4 py-3">
                      {routeLabel(task.routeNo) || task.routeNo || '—'}
                    </td>
                    <td className="px-4 py-3 capitalize">
                      {task.status.replace(/_/g, ' ')}
                    </td>
                    <td className="px-4 py-3">{formatDate(task.dueDate)}</td>
                  </tr>
                ))}
              </Table>
              {tasks.length === 0 && (
                <p className="mt-4 text-sm text-gray-500">
                  No tasks found for this executive.
                </p>
              )}
            </Card>
          )}

          {section === 'targets' && (
            <div className="space-y-6">
              <Card
                title="Sales Targets"
                subtitle={`${salesTargets.length} sales targets`}
              >
                <Table
                  columns={[
                    { key: 'period', label: 'Period' },
                    { key: 'route', label: 'Route' },
                    { key: 'target', label: 'Target' },
                    { key: 'achieved', label: 'Achieved' },
                    { key: 'due', label: 'Due Date' },
                  ]}
                >
                  {salesTargets.map((t, index) => (
                    <tr
                      key={`${t.routeNo}-${t.period}-${t.dueDate}-${index}`}
                      className="hover:bg-gray-50"
                    >
                      <td className="px-4 py-3 capitalize">{t.period}</td>
                      <td className="px-4 py-3">
                        {routeLabel(t.routeNo) || t.routeNo || '—'}
                      </td>
                      <td className="px-4 py-3">
                        {formatCurrency(t.targetAmount)}
                      </td>
                      <td className="px-4 py-3">
                        {formatCurrency(t.achievedAmount)}
                      </td>
                      <td className="px-4 py-3">{formatDate(t.dueDate)}</td>
                    </tr>
                  ))}
                </Table>
                {salesTargets.length === 0 && (
                  <p className="mt-4 text-sm text-gray-500">
                    No sales targets for this executive.
                  </p>
                )}
              </Card>

              <Card
                title="Product Targets"
                subtitle={`${productTargets.length} product targets`}
              >
                <Table
                  columns={[
                    { key: 'type', label: 'Type' },
                    { key: 'route', label: 'Route' },
                    { key: 'products', label: 'Products' },
                    { key: 'target', label: 'Target' },
                    { key: 'achieved', label: 'Achieved' },
                  ]}
                >
                  {productTargets.map((t, index) => (
                    <tr
                      key={`${t.routeNo}-${t.type}-${index}`}
                      className="hover:bg-gray-50"
                    >
                      <td className="px-4 py-3">
                        {productTargetLabel(t.type)}
                      </td>
                      <td className="px-4 py-3">
                        {routeLabel(t.routeNo) || t.routeNo || '—'}
                      </td>
                      <td className="px-4 py-3 max-w-xs truncate">
                        {(t.productNames ?? t.products ?? []).join(', ') ||
                          '—'}
                      </td>
                      <td className="px-4 py-3">{t.targetValue}</td>
                      <td className="px-4 py-3">{t.achievedValue}</td>
                    </tr>
                  ))}
                </Table>
                {productTargets.length === 0 && (
                  <p className="mt-4 text-sm text-gray-500">
                    No product targets for this executive.
                  </p>
                )}
              </Card>

              <Card
                title="Customer Targets"
                subtitle={`${customerTargets.length} customer targets`}
              >
                <Table
                  columns={[
                    { key: 'type', label: 'Type' },
                    { key: 'period', label: 'Period' },
                    { key: 'route', label: 'Route' },
                    { key: 'count', label: 'Count' },
                    { key: 'amount', label: 'Amount' },
                  ]}
                >
                  {customerTargets.map((t, index) => (
                    <tr
                      key={`${t.routeNo}-${t.type}-${t.period}-${index}`}
                      className="hover:bg-gray-50"
                    >
                      <td className="px-4 py-3">
                        {customerTargetLabel(t.type)}
                      </td>
                      <td className="px-4 py-3 capitalize">{t.period}</td>
                      <td className="px-4 py-3">
                        {routeLabel(t.routeNo) || t.routeNo || '—'}
                      </td>
                      <td className="px-4 py-3">
                        {t.achievedCount}/{t.targetCount}
                      </td>
                      <td className="px-4 py-3">
                        {formatCurrency(t.targetAmount)}
                      </td>
                    </tr>
                  ))}
                </Table>
                {customerTargets.length === 0 && (
                  <p className="mt-4 text-sm text-gray-500">
                    No customer targets for this executive.
                  </p>
                )}
              </Card>
            </div>
          )}

          {section === 'reviews' && (
            <Card
              title="Detailed Product Reviews"
              subtitle={`${reviews.length} product reviews`}
            >
              <Table
                columns={[
                  { key: 'route', label: 'Route' },
                  { key: 'customer', label: 'Customer' },
                  { key: 'product', label: 'Product' },
                  { key: 'reason', label: 'Reason' },
                ]}
              >
                {reviews.map((review, index) => (
                  <tr
                    key={`${review.customerCode}-${review.itemCode}-${index}`}
                    className="hover:bg-gray-50"
                  >
                    <td className="px-4 py-3">
                      {routeLabel(review.route) || review.route || '—'}
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-medium">{review.customerName}</div>
                      <div className="text-xs text-gray-400">
                        {review.customerCode}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <div className="text-sm">{review.itemName}</div>
                      <div className="text-xs text-gray-400 font-mono">
                        {review.itemCode}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-sm text-gray-600 max-w-md">
                      {review.reason || '—'}
                    </td>
                  </tr>
                ))}
              </Table>
              {reviews.length === 0 && (
                <p className="mt-4 text-sm text-gray-500">
                  No product reviews found for this executive.
                </p>
              )}
            </Card>
          )}
        </>
      )}
    </div>
  )
}
