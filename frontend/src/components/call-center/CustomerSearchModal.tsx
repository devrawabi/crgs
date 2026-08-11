import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { History, Loader2, Package, Plus, Search } from 'lucide-react'
import {
  fetchCustomerBillHistory,
  fetchCustomerLastOrder,
  type DbBillHeader,
  type DbBillItem,
  type DbCustomer,
} from '../../api/customers'
import { Modal } from '../ui/Modal'
import { cn } from '../../lib/utils'

const CURRENCY = 'QAR'

type CustomersTab = 'purchases' | 'own'

export interface OrderLineDraft {
  itemCode: string
  description: string
  uom: string
  rate: number
  qty: number
}

interface CustomerSearchModalProps {
  open: boolean
  onClose: () => void
  selectedCustomer: DbCustomer | null
  onAddItem: (item: OrderLineDraft) => void
}

function formatMoney(value: number) {
  return value.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
}

function formatBillDate(raw: string | null | undefined) {
  if (!raw) return '—'
  const d = new Date(raw)
  if (Number.isNaN(d.getTime())) return String(raw)
  return d.toLocaleDateString(undefined, {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  })
}

function billAmount(bill: DbBillHeader) {
  const n = Number(bill.netbillamount)
  return Number.isFinite(n) ? n : 0
}

function sameBill(a: DbBillHeader | null, b: DbBillHeader | null) {
  if (!a || !b) return false
  return (
    String(a.billno ?? '') === String(b.billno ?? '') &&
    String(a.locationcode ?? '') === String(b.locationcode ?? '')
  )
}

export function CustomerSearchModal({
  open,
  onClose,
  selectedCustomer,
  onAddItem,
}: CustomerSearchModalProps) {
  const [tab, setTab] = useState<CustomersTab>('purchases')

  const [bills, setBills] = useState<DbBillHeader[]>([])
  const [billsLoading, setBillsLoading] = useState(false)
  const [billsError, setBillsError] = useState<string | null>(null)
  const [selectedBill, setSelectedBill] = useState<DbBillHeader | null>(null)
  const [billItems, setBillItems] = useState<DbBillItem[]>([])
  const [itemsLoading, setItemsLoading] = useState(false)
  const [itemsError, setItemsError] = useState<string | null>(null)

  const [ownItems, setOwnItems] = useState<DbBillItem[]>([])
  const [ownLoading, setOwnLoading] = useState(false)
  const [ownError, setOwnError] = useState<string | null>(null)
  const [ownQuery, setOwnQuery] = useState('')

  const custCode = String(selectedCustomer?.cust_code ?? '').trim()

  useEffect(() => {
    if (!open) return
    setTab('purchases')
    setOwnQuery('')
  }, [open, selectedCustomer])

  const loadBillItems = useCallback(
    async (code: string, bill?: DbBillHeader | null) => {
      setItemsLoading(true)
      setItemsError(null)
      try {
        const res = await fetchCustomerLastOrder(code, {
          itemsLimit: 100,
          billno: bill?.billno != null ? String(bill.billno) : undefined,
          location:
            bill?.locationcode != null ? String(bill.locationcode) : undefined,
          billdate: bill?.billdate ?? undefined,
          netbillamount: bill?.netbillamount ?? undefined,
        })
        const purchase = res.last_purchase
        if (purchase) {
          setSelectedBill((prev) =>
            sameBill(prev, purchase) ? prev : purchase
          )
        }
        setBillItems(res.items ?? [])
        if (!purchase && !bill) {
          setSelectedBill(null)
        }
      } catch {
        setBillItems([])
        setItemsError('Could not load bill items')
      } finally {
        setItemsLoading(false)
      }
    },
    []
  )

  const loadOwnFromBill = useCallback(
    async (code: string, bill?: DbBillHeader | null) => {
      setOwnLoading(true)
      setOwnError(null)
      try {
        const res = await fetchCustomerLastOrder(code, {
          itemsLimit: 100,
          ownOnly: true,
          billno: bill?.billno != null ? String(bill.billno) : undefined,
          location:
            bill?.locationcode != null ? String(bill.locationcode) : undefined,
          billdate: bill?.billdate ?? undefined,
          netbillamount: bill?.netbillamount ?? undefined,
        })
        if (res.last_purchase && !bill) {
          setSelectedBill((prev) => prev ?? res.last_purchase)
        }
        setOwnItems(res.items ?? [])
      } catch {
        setOwnItems([])
        setOwnError('Could not load own products from purchase bill')
      } finally {
        setOwnLoading(false)
      }
    },
    []
  )

  const loadPurchases = useCallback(
    async (code: string) => {
      setBillsLoading(true)
      setBillsError(null)
      setItemsLoading(true)
      setItemsError(null)
      setBillItems([])
      setSelectedBill(null)

      try {
        const lastOrder = await fetchCustomerLastOrder(code, {
          itemsLimit: 100,
        })
        const lastBill = lastOrder.last_purchase
        if (lastBill) {
          setSelectedBill(lastBill)
          setBillItems(lastOrder.items ?? [])
          setBills([lastBill])
        } else {
          setSelectedBill(null)
          setBillItems([])
          setBills([])
        }
        setItemsLoading(false)

        try {
          const history = await fetchCustomerBillHistory(code, 25)
          const list = history.bills ?? []
          if (list.length > 0) {
            setBills(list)
            if (lastBill) {
              const match = list.find((b) => sameBill(b, lastBill))
              setSelectedBill(match ?? lastBill)
            } else {
              setSelectedBill(list[0])
              void loadBillItems(code, list[0])
            }
          }
        } catch {
          // Keep last-order result if history endpoint fails.
        }
      } catch {
        setBills([])
        setSelectedBill(null)
        setBillItems([])
        setBillsError('Could not load last purchase')
        setItemsLoading(false)
      } finally {
        setBillsLoading(false)
      }
    },
    [loadBillItems]
  )

  useEffect(() => {
    if (!open || tab !== 'purchases' || !custCode) {
      if (!custCode) {
        setBills([])
        setSelectedBill(null)
        setBillItems([])
        setOwnItems([])
      }
      return
    }
    void loadPurchases(custCode)
  }, [open, tab, custCode, loadPurchases])

  useEffect(() => {
    if (!open || tab !== 'own' || !custCode) {
      if (!custCode) setOwnItems([])
      return
    }
    void loadOwnFromBill(custCode, selectedBill)
  }, [open, tab, custCode, selectedBill, loadOwnFromBill])

  const filteredOwnItems = useMemo(() => {
    const q = ownQuery.trim().toLowerCase()
    if (!q) return ownItems
    return ownItems.filter((item) => {
      const code = String(item.itemcode || '').toLowerCase()
      const name = String(item.itemname || item.itemdetails || '').toLowerCase()
      return code.includes(q) || name.includes(q)
    })
  }, [ownItems, ownQuery])

  const selectBill = (bill: DbBillHeader) => {
    setSelectedBill(bill)
    if (!custCode) return
    void loadBillItems(custCode, bill)
  }

  const addBillItem = (item: DbBillItem) => {
    const code = String(item.itemcode || '').trim()
    if (!code) return
    const qty = Number(item.quantity)
    onAddItem({
      itemCode: code,
      description: String(item.itemname || item.itemdetails || code).trim(),
      uom: String(item.unitofmeasurement || 'EA').trim(),
      rate: Number(item.rate) || 0,
      qty: Number.isFinite(qty) && qty > 0 ? qty : 1,
    })
  }

  return (
    <Modal
      open={open}
      onClose={onClose}
      title={
        selectedCustomer
          ? `${selectedCustomer.cust_name} · Details`
          : 'Customer details'
      }
      xl
    >
      <div className="space-y-4">
        {selectedCustomer ? (
          <div className="rounded-lg border border-primary-100 bg-primary-50 px-3 py-2.5 text-sm">
            <p className="text-[10px] font-bold uppercase tracking-wide text-primary-600 mb-1">
              Selected customer
            </p>
            <p className="font-semibold text-slate-800">
              {selectedCustomer.cust_name}
              <span className="ml-2 text-xs font-normal text-gray-500">
                {selectedCustomer.cust_code}
              </span>
            </p>
            <div className="mt-1.5 flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-600">
              {selectedCustomer.mobile ? (
                <span>
                  Mobile{' '}
                  <span className="font-medium text-slate-800">
                    {selectedCustomer.mobile}
                  </span>
                </span>
              ) : null}
              {selectedCustomer.routename || selectedCustomer.route != null ? (
                <span>
                  Route{' '}
                  <span className="font-medium text-slate-800">
                    {selectedCustomer.routename ||
                      String(selectedCustomer.route)}
                  </span>
                </span>
              ) : null}
              {selectedCustomer.credit_limit != null ? (
                <span>
                  Credit{' '}
                  <span className="font-medium text-slate-800">
                    {CURRENCY}{' '}
                    {formatMoney(Number(selectedCustomer.credit_limit))}
                  </span>
                </span>
              ) : null}
              {selectedCustomer.credit_amount != null ? (
                <span>
                  Due{' '}
                  <span className="font-medium text-slate-800">
                    {CURRENCY}{' '}
                    {formatMoney(Number(selectedCustomer.credit_amount))}
                  </span>
                </span>
              ) : null}
              {selectedBill ? (
                <span>
                  Last bill{' '}
                  <span className="font-medium text-slate-800">
                    {String(selectedBill.billno ?? '—')}
                    {' · '}
                    {formatBillDate(selectedBill.billdate)}
                    {' · '}
                    {CURRENCY} {formatMoney(billAmount(selectedBill))}
                  </span>
                </span>
              ) : selectedCustomer.last_purchase_date ? (
                <span>
                  Last purchase{' '}
                  <span className="font-medium text-slate-800">
                    {formatBillDate(selectedCustomer.last_purchase_date)}
                    {selectedCustomer.last_purchase_amount != null
                      ? ` · ${CURRENCY} ${formatMoney(Number(selectedCustomer.last_purchase_amount))}`
                      : ''}
                  </span>
                </span>
              ) : null}
            </div>
          </div>
        ) : (
          <EmptyRow label="Select a customer on the order form, then press F2" />
        )}

        <div className="flex gap-1 border-b border-gray-200">
          <TabButton
            active={tab === 'purchases'}
            onClick={() => setTab('purchases')}
            icon={<History size={14} />}
            label="Purchase list"
          />
          <TabButton
            active={tab === 'own'}
            onClick={() => setTab('own')}
            icon={<Package size={14} />}
            label="Own products"
          />
        </div>

        {tab === 'purchases' && (
          <>
            {!custCode ? (
              <EmptyRow label="Select a customer first to view purchase history" />
            ) : (
              <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,280px)_minmax(0,1fr)] gap-4 min-h-[360px]">
                <div className="rounded-lg border border-gray-200 overflow-hidden flex flex-col max-h-[420px]">
                  <div className="px-3 py-2 bg-gray-50 border-b border-gray-200 text-[11px] font-semibold uppercase tracking-wide text-gray-500">
                    Bills
                  </div>
                  <div className="flex-1 overflow-auto">
                    {billsLoading ? (
                      <LoadingRow label="Loading last purchase…" />
                    ) : billsError ? (
                      <EmptyRow label={billsError} />
                    ) : bills.length === 0 ? (
                      <EmptyRow label="No previous purchases found" />
                    ) : (
                      <ul>
                        {bills.map((bill, index) => {
                          const key = `${bill.billno}-${bill.locationcode}-${index}`
                          const active = sameBill(selectedBill, bill)
                          return (
                            <li key={key}>
                              <button
                                type="button"
                                onClick={() => selectBill(bill)}
                                className={cn(
                                  'w-full text-left px-3 py-2.5 border-b border-gray-50 last:border-0 hover:bg-primary-50/60',
                                  active && 'bg-primary-50'
                                )}
                              >
                                <div className="flex justify-between gap-2 text-sm">
                                  <span className="font-medium text-slate-800 truncate">
                                    {index === 0 ? 'Last · ' : ''}
                                    {String(bill.billno ?? '—')}
                                  </span>
                                  <span className="shrink-0 text-xs text-gray-500">
                                    {formatBillDate(bill.billdate)}
                                  </span>
                                </div>
                                <div className="mt-0.5 text-xs text-gray-500">
                                  {CURRENCY} {formatMoney(billAmount(bill))}
                                  {bill.locationcode
                                    ? ` · Loc ${String(bill.locationcode).trim()}`
                                    : ''}
                                </div>
                              </button>
                            </li>
                          )
                        })}
                      </ul>
                    )}
                  </div>
                </div>

                <div className="rounded-lg border border-gray-200 overflow-hidden flex flex-col max-h-[420px]">
                  <div className="px-3 py-2 bg-gray-50 border-b border-gray-200 flex items-center justify-between gap-2">
                    <span className="text-[11px] font-semibold uppercase tracking-wide text-gray-500">
                      {selectedBill
                        ? `Bill ${String(selectedBill.billno)} · ${formatBillDate(selectedBill.billdate)}`
                        : 'Bill items'}
                    </span>
                    {billItems.length > 0 ? (
                      <button
                        type="button"
                        onClick={() => {
                          billItems.forEach(addBillItem)
                        }}
                        className="inline-flex items-center gap-1 rounded-md bg-primary-700 px-2 py-1 text-[11px] font-semibold text-white hover:bg-primary-800"
                      >
                        <Plus size={12} />
                        Add all
                      </button>
                    ) : null}
                  </div>
                  <div className="flex-1 overflow-auto">
                    {itemsLoading || billsLoading ? (
                      <LoadingRow label="Loading bill items…" />
                    ) : itemsError ? (
                      <EmptyRow label={itemsError} />
                    ) : !selectedBill ? (
                      <EmptyRow label="No last purchase bill for this customer" />
                    ) : billItems.length === 0 ? (
                      <EmptyRow label="No items on this bill" />
                    ) : (
                      <table className="w-full text-sm">
                        <thead className="sticky top-0 bg-white text-[11px] uppercase tracking-wide text-gray-500 border-b border-gray-100">
                          <tr>
                            <th className="px-3 py-2 text-left font-semibold">
                              Item
                            </th>
                            <th className="px-3 py-2 text-right font-semibold">
                              Qty
                            </th>
                            <th className="px-3 py-2 text-right font-semibold">
                              Rate
                            </th>
                            <th className="px-3 py-2 text-right font-semibold" />
                          </tr>
                        </thead>
                        <tbody>
                          {billItems.map((item, idx) => {
                            const code = String(item.itemcode || '').trim()
                            const name = String(
                              item.itemname || item.itemdetails || code
                            ).trim()
                            const qty = Number(item.quantity) || 0
                            const rate = Number(item.rate) || 0
                            return (
                              <tr
                                key={`${code}-${idx}`}
                                className="border-t border-gray-50"
                              >
                                <td className="px-3 py-2">
                                  <div className="font-medium text-slate-800">
                                    {name}
                                  </div>
                                  <div className="text-xs text-gray-400">
                                    {code}
                                  </div>
                                </td>
                                <td className="px-3 py-2 text-right text-slate-700">
                                  {qty}
                                </td>
                                <td className="px-3 py-2 text-right text-slate-700">
                                  {formatMoney(rate)}
                                </td>
                                <td className="px-3 py-2 text-right">
                                  <button
                                    type="button"
                                    onClick={() => addBillItem(item)}
                                    className="inline-flex items-center gap-1 rounded-md border border-primary-200 bg-primary-50 px-2 py-1 text-[11px] font-semibold text-primary-800 hover:bg-primary-100"
                                  >
                                    <Plus size={12} />
                                    Add
                                  </button>
                                </td>
                              </tr>
                            )
                          })}
                        </tbody>
                      </table>
                    )}
                  </div>
                </div>
              </div>
            )}
          </>
        )}

        {tab === 'own' && (
          <div className="space-y-3">
            {!custCode ? (
              <EmptyRow label="Select a customer first to view own products from their bill" />
            ) : (
              <>
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className="text-xs text-gray-500">
                    Own products from{' '}
                    {selectedBill
                      ? `bill ${String(selectedBill.billno)} (${formatBillDate(selectedBill.billdate)})`
                      : 'last purchase bill'}
                  </p>
                  {filteredOwnItems.length > 0 ? (
                    <button
                      type="button"
                      onClick={() => filteredOwnItems.forEach(addBillItem)}
                      className="inline-flex items-center gap-1 rounded-md bg-primary-700 px-2 py-1 text-[11px] font-semibold text-white hover:bg-primary-800"
                    >
                      <Plus size={12} />
                      Add all
                    </button>
                  ) : null}
                </div>
                <div className="relative max-w-md">
                  <Search
                    size={15}
                    className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
                  />
                  <input
                    value={ownQuery}
                    onChange={(e) => setOwnQuery(e.target.value)}
                    placeholder="Filter own products on this bill…"
                    className="w-full rounded-lg border border-gray-200 bg-gray-50 pl-9 pr-3 py-2 text-sm outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-100"
                  />
                </div>
                <div className="rounded-lg border border-gray-200 overflow-hidden max-h-[420px] overflow-y-auto">
                  {ownLoading ? (
                    <LoadingRow label="Loading own products from bill…" />
                  ) : ownError ? (
                    <EmptyRow label={ownError} />
                  ) : filteredOwnItems.length === 0 ? (
                    <EmptyRow label="No own products on this purchase bill" />
                  ) : (
                    <table className="w-full text-sm">
                      <thead className="sticky top-0 bg-gray-50 text-[11px] uppercase tracking-wide text-gray-500 border-b border-gray-100">
                        <tr>
                          <th className="px-3 py-2 text-left font-semibold">
                            Product
                          </th>
                          <th className="px-3 py-2 text-right font-semibold">
                            Qty
                          </th>
                          <th className="px-3 py-2 text-right font-semibold">
                            Rate
                          </th>
                          <th className="px-3 py-2 text-right font-semibold" />
                        </tr>
                      </thead>
                      <tbody>
                        {filteredOwnItems.map((item, idx) => {
                          const code = String(item.itemcode || '').trim()
                          const name = String(
                            item.itemname || item.itemdetails || code
                          ).trim()
                          const qty = Number(item.quantity) || 0
                          const rate = Number(item.rate) || 0
                          return (
                            <tr
                              key={`${code}-${idx}`}
                              className="border-t border-gray-50"
                            >
                              <td className="px-3 py-2">
                                <div className="font-medium text-slate-800">
                                  {name}
                                </div>
                                <div className="text-xs text-gray-400">
                                  {code}
                                </div>
                              </td>
                              <td className="px-3 py-2 text-right text-slate-700">
                                {qty}
                              </td>
                              <td className="px-3 py-2 text-right text-slate-700">
                                {CURRENCY} {formatMoney(rate)}
                              </td>
                              <td className="px-3 py-2 text-right">
                                <button
                                  type="button"
                                  onClick={() => addBillItem(item)}
                                  className="inline-flex items-center gap-1 rounded-md border border-primary-200 bg-primary-50 px-2 py-1 text-[11px] font-semibold text-primary-800 hover:bg-primary-100"
                                >
                                  <Plus size={12} />
                                  Add
                                </button>
                              </td>
                            </tr>
                          )
                        })}
                      </tbody>
                    </table>
                  )}
                </div>
              </>
            )}
          </div>
        )}
      </div>
    </Modal>
  )
}

function TabButton({
  active,
  onClick,
  icon,
  label,
}: {
  active: boolean
  onClick: () => void
  icon: ReactNode
  label: string
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors',
        active
          ? 'border-primary-600 text-primary-800'
          : 'border-transparent text-gray-500 hover:text-slate-700'
      )}
    >
      {icon}
      {label}
    </button>
  )
}

function LoadingRow({ label }: { label: string }) {
  return (
    <div className="flex items-center gap-2 px-3 py-8 text-sm text-gray-500 justify-center">
      <Loader2 size={16} className="animate-spin" />
      {label}
    </div>
  )
}

function EmptyRow({ label }: { label: string }) {
  return (
    <div className="px-3 py-8 text-center text-sm text-gray-400">{label}</div>
  )
}
