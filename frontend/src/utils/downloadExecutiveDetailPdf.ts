import { jsPDF } from 'jspdf'
import autoTable from 'jspdf-autotable'
import type { DbOrder } from '../api/orders'
import type { DbVisit } from '../api/visits'
import type { DbTask } from '../api/tasks'
import type { DbProductReview } from '../api/productReviews'
import type {
  DbSalesTarget,
  DbProductTarget,
  DbCustomerTarget,
} from '../api/targets'

export interface ExecutivePdfPayload {
  execName: string
  code: string
  designation?: string | null
  routeNames: string
  orders: DbOrder[]
  visits: DbVisit[]
  tasks: DbTask[]
  salesTargets: DbSalesTarget[]
  productTargets: DbProductTarget[]
  customerTargets: DbCustomerTarget[]
  reviews: DbProductReview[]
  completedTaskCount: number
  orderLineCount: number
  routeLabel: (route: string | number | null | undefined) => string
  taskLabel: (type: string) => string
  productTargetLabel: (type: string) => string
  customerTargetLabel: (type: string) => string
  isCompletedStatus: (status: string) => boolean
}

type DocWithAutoTable = jsPDF & { lastAutoTable?: { finalY: number } }

function finalY(doc: jsPDF, fallback: number) {
  return (doc as DocWithAutoTable).lastAutoTable?.finalY ?? fallback
}

function addSectionTitle(doc: jsPDF, title: string, y: number) {
  const pageHeight = doc.internal.pageSize.getHeight()
  if (y > pageHeight - 40) {
    doc.addPage()
    y = 16
  }
  doc.setFontSize(12)
  doc.setFont('helvetica', 'bold')
  doc.setTextColor(15, 118, 110)
  doc.text(title, 14, y)
  doc.setTextColor(0, 0, 0)
  return y + 4
}

function tableStartY(doc: jsPDF, preferredY: number) {
  const pageHeight = doc.internal.pageSize.getHeight()
  if (preferredY > pageHeight - 40) {
    doc.addPage()
    return 16
  }
  return preferredY
}

/** Download a multi-section PDF on standard A4 portrait (210 × 297 mm). */
export function downloadExecutiveDetailPdf(payload: ExecutivePdfPayload) {
  const {
    execName,
    code,
    designation,
    routeNames,
    orders,
    visits,
    tasks,
    salesTargets,
    productTargets,
    customerTargets,
    reviews,
    completedTaskCount,
    orderLineCount,
    routeLabel,
    taskLabel,
    productTargetLabel,
    customerTargetLabel,
    isCompletedStatus,
  } = payload

  // Standard A4 portrait: 210mm × 297mm
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' })
  const dateStamp = new Date().toISOString().slice(0, 10)
  const generatedAt = new Date().toLocaleString()

  const tableOpts = {
    styles: {
      fontSize: 6.5,
      cellPadding: 1.2,
      overflow: 'linebreak' as const,
    },
    headStyles: {
      fillColor: [15, 118, 110] as [number, number, number],
      fontSize: 7,
    },
    margin: { left: 10, right: 10 },
    tableWidth: 'auto' as const,
  }

  doc.setFontSize(16)
  doc.setFont('helvetica', 'bold')
  doc.text('Executive Performance Detail', 14, 16)

  doc.setFontSize(9)
  doc.setFont('helvetica', 'normal')
  const summaryLines = [
    `Executive: ${execName}`,
    `Employee Code: ${code}`,
    `Designation: ${designation || '—'}`,
    `Routes: ${routeNames || '—'}`,
    `Orders: ${orders.length}  |  Line Items: ${orderLineCount}  |  Visits: ${visits.length}`,
    `Tasks: ${tasks.length} (${completedTaskCount} completed)  |  Targets: ${
      salesTargets.length + productTargets.length + customerTargets.length
    }  |  Reviews: ${reviews.length}`,
    `Page size: A4 (210 × 297 mm)  |  Generated: ${generatedAt}`,
  ]
  let y = 24
  for (const line of summaryLines) {
    const lines = doc.splitTextToSize(line, 182)
    doc.text(lines, 14, y)
    y += lines.length * 4.5
  }

  y = addSectionTitle(doc, 'Orders', y + 4)
  autoTable(doc, {
    startY: tableStartY(doc, y),
    head: [['Order No', 'Date', 'Customer', 'Route', 'Items', 'Amount', 'Expected']],
    body: orders.map((o) => [
      o.orderNo || '',
      o.orderDate || '',
      `${o.customerName || ''} (${o.customerCode || ''})`.trim(),
      routeLabel(o.route) || o.route || '',
      String(o.itemCount ?? o.items?.length ?? 0),
      String(o.totalAmount ?? 0),
      o.expectedDate || '',
    ]),
    ...tableOpts,
  })
  y = finalY(doc, y) + 8

  y = addSectionTitle(doc, 'Order Line Items', y)
  autoTable(doc, {
    startY: tableStartY(doc, y),
    head: [['Order No', 'Date', 'Customer', 'Item', 'Qty', 'UOM', 'Price', 'Amount']],
    body: orders.flatMap((o) =>
      (o.items ?? []).map((item) => [
        o.orderNo || '',
        o.orderDate || '',
        o.customerName || o.customerCode || '',
        item.itemName || item.itemCode || '',
        String(item.qty ?? 0),
        item.uom || '',
        String(item.price ?? 0),
        String(item.amount ?? 0),
      ])
    ),
    ...tableOpts,
  })
  y = finalY(doc, y) + 8

  y = addSectionTitle(doc, 'Visits', y)
  autoTable(doc, {
    startY: tableStartY(doc, y),
    head: [['Date', 'Customer', 'Time', 'Duration', 'Route', 'Reason', 'Remarks']],
    body: visits.map((v) => [
      v.visitDate || '',
      `${v.customerName || ''} (${v.customerCode || ''})`.trim(),
      [v.visitStart, v.visitEnd].filter(Boolean).join(' → ') || '',
      v.totalDuration || '',
      routeLabel(v.route) || v.route || '',
      v.reason || '',
      [v.remarks, v.followUp ? `Follow-up: ${v.followUp}` : '']
        .filter(Boolean)
        .join(' | '),
    ]),
    ...tableOpts,
  })
  y = finalY(doc, y) + 8

  y = addSectionTitle(doc, 'Tasks', y)
  autoTable(doc, {
    startY: tableStartY(doc, y),
    head: [['Type', 'Route', 'Status', 'Due Date', 'Completed']],
    body: tasks.map((t) => [
      taskLabel(t.type),
      routeLabel(t.routeNo) || t.routeNo || '',
      t.status || '',
      t.dueDate || '',
      isCompletedStatus(t.status) ? 'Yes' : 'No',
    ]),
    ...tableOpts,
  })
  y = finalY(doc, y) + 8

  y = addSectionTitle(doc, 'Sales Targets', y)
  autoTable(doc, {
    startY: tableStartY(doc, y),
    head: [['Period', 'Route', 'Target', 'Achieved', 'Achievement %', 'Due Date']],
    body: salesTargets.map((t) => {
      const pct =
        t.targetAmount > 0
          ? Math.round((t.achievedAmount / t.targetAmount) * 10000) / 100
          : 0
      return [
        t.period || '',
        routeLabel(t.routeNo) || t.routeNo || '',
        String(t.targetAmount ?? 0),
        String(t.achievedAmount ?? 0),
        String(pct),
        t.dueDate || '',
      ]
    }),
    ...tableOpts,
  })
  y = finalY(doc, y) + 8

  y = addSectionTitle(doc, 'Product Targets', y)
  autoTable(doc, {
    startY: tableStartY(doc, y),
    head: [['Type', 'Route', 'Products', 'Target', 'Achieved', 'Achievement %']],
    body: productTargets.map((t) => {
      const pct =
        t.targetValue > 0
          ? Math.round((t.achievedValue / t.targetValue) * 10000) / 100
          : 0
      return [
        productTargetLabel(t.type),
        routeLabel(t.routeNo) || t.routeNo || '',
        (t.productNames ?? t.products ?? []).join(', '),
        String(t.targetValue ?? 0),
        String(t.achievedValue ?? 0),
        String(pct),
      ]
    }),
    ...tableOpts,
  })
  y = finalY(doc, y) + 8

  y = addSectionTitle(doc, 'Customer Targets', y)
  autoTable(doc, {
    startY: tableStartY(doc, y),
    head: [
      ['Type', 'Period', 'Route', 'Target Count', 'Achieved', 'Target Amount'],
    ],
    body: customerTargets.map((t) => [
      customerTargetLabel(t.type),
      t.period || '',
      routeLabel(t.routeNo) || t.routeNo || '',
      String(t.targetCount ?? 0),
      String(t.achievedCount ?? 0),
      String(t.targetAmount ?? 0),
    ]),
    ...tableOpts,
  })
  y = finalY(doc, y) + 8

  y = addSectionTitle(doc, 'Detailed Product Reviews', y)
  autoTable(doc, {
    startY: tableStartY(doc, y),
    head: [['Route', 'Customer', 'Product', 'Reason']],
    body: reviews.map((r) => [
      routeLabel(r.route) || r.route || '',
      `${r.customerName || ''} (${r.customerCode || ''})`.trim(),
      `${r.itemName || ''} (${r.itemCode || ''})`.trim(),
      r.reason || '',
    ]),
    ...tableOpts,
  })

  const safeName = execName.replace(/[^\w\-]+/g, '_').slice(0, 40)
  doc.save(`executive_full_${safeName}_${code}_${dateStamp}.pdf`)
}
