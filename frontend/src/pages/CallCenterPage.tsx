import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type KeyboardEvent,
  type ReactNode,
} from 'react'
import {
  CreditCard,
  Loader2,
  Plus,
  Printer,
  Search,
  Send,
  Settings,
  Sparkles,
  Trash2,
} from 'lucide-react'
import { postAiChat, type AiChatMessage } from '../api/ai'
import { fetchCustomers, type DbCustomer } from '../api/customers'
import { fetchItems, type DbItemMaster } from '../api/items'
import { fetchAllUsers, type DbLoginUser } from '../api/users'
import { CustomerSearchModal } from '../components/call-center/CustomerSearchModal'
import { useAuth } from '../context/AuthContext'
import { cn } from '../lib/utils'

const VAT_RATE = 0.05
const CURRENCY = 'QAR'

type InvoiceType = 'CREDIT' | 'CASH'
type InvoiceStatus = 'DRAFT' | 'HELD' | 'SAVED'

interface LineItem {
  id: string
  itemCode: string
  description: string
  uom: string
  rate: number
  qty: number
  discount: number
}

interface ChatMessage {
  id: string
  role: 'assistant' | 'user'
  text: string
  /** Full prompt sent to the API when different from display text */
  apiText?: string
}

const AI_COPY = {
  welcome:
    'Ask about customers, purchase history, credit risk, discounts, or next steps.',
  statusIdle: 'Order help',
  statusThinking: 'Thinking…',
  placeholder: 'Ask about this order…',
  discount: '5% discount',
  credit: 'Credit risk',
  next: 'Next steps',
  history: 'Purchase history',
  repeat: 'Repeat customers',
  discountAsk: 'Apply 5% bulk discount',
  creditAsk: 'Review credit risk',
  nextAsk: 'Suggest next steps',
  historyAsk: 'Purchase history',
  repeatAsk: 'Repeat customers',
  noReply: 'No reply from AI.',
}

const WELCOME_CHAT: ChatMessage = {
  id: 'welcome',
  role: 'assistant',
  text: AI_COPY.welcome,
}

function formatMoney(value: number) {
  return value.toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
}

function nextInvoiceNo() {
  const now = new Date()
  const y = now.getFullYear()
  const seq = String(now.getTime()).slice(-4)
  return `INV-${y}-${seq}`
}

function newLineId() {
  return `line-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`
}

export function CallCenterPage() {
  const { user } = useAuth()
  const itemSearchRef = useRef<HTMLInputElement>(null)
  const customerSearchRef = useRef<HTMLInputElement>(null)

  const [invoiceNo, setInvoiceNo] = useState(nextInvoiceNo)
  const [invoiceStatus, setInvoiceStatus] = useState<InvoiceStatus>('DRAFT')
  const [invoiceType, setInvoiceType] = useState<InvoiceType>('CREDIT')
  const [saleChannel, setSaleChannel] = useState('Call Center')
  const [priceType, setPriceType] = useState('Retail Price')
  const [discount, setDiscount] = useState(0)
  const [sugarTax, setSugarTax] = useState(0)
  const [createdAt] = useState(() => new Date())

  const [customerQuery, setCustomerQuery] = useState('')
  const [customerResults, setCustomerResults] = useState<DbCustomer[]>([])
  const [customerLoading, setCustomerLoading] = useState(false)
  const [selectedCustomer, setSelectedCustomer] = useState<DbCustomer | null>(null)
  const [showCustomerDropdown, setShowCustomerDropdown] = useState(false)
  const [customerSearchError, setCustomerSearchError] = useState<string | null>(
    null
  )

  const [salesmen, setSalesmen] = useState<DbLoginUser[]>([])
  const [salesmenLoading, setSalesmenLoading] = useState(true)
  const [salesmanCode, setSalesmanCode] = useState('')

  const [itemQuery, setItemQuery] = useState('')
  const [itemResults, setItemResults] = useState<DbItemMaster[]>([])
  const [itemLoading, setItemLoading] = useState(false)
  const [showItemDropdown, setShowItemDropdown] = useState(false)
  const [selectedLineIds, setSelectedLineIds] = useState<Set<string>>(new Set())
  const [lines, setLines] = useState<LineItem[]>([])

  const [aiInput, setAiInput] = useState('')
  const [aiLoading, setAiLoading] = useState(false)
  const [chat, setChat] = useState<ChatMessage[]>([WELCOME_CHAT])
  const chatEndRef = useRef<HTMLDivElement>(null)
  const aiInputRef = useRef<HTMLInputElement>(null)
  const aiCopy = AI_COPY
  const [toast, setToast] = useState<string | null>(null)
  const [customersModalOpen, setCustomersModalOpen] = useState(false)

  const showToast = useCallback((message: string) => {
    setToast(message)
    window.setTimeout(() => setToast(null), 2400)
  }, [])

  const openCustomerDetails = useCallback(() => {
    if (!selectedCustomer) {
      showToast('Select a customer first')
      customerSearchRef.current?.focus()
      return
    }
    setCustomersModalOpen(true)
  }, [selectedCustomer, showToast])

  useEffect(() => {
    let cancelled = false
    setSalesmenLoading(true)
    fetchAllUsers({ activeOnly: true })
      .then((res) => {
        if (cancelled) return
        const list = res.users ?? []
        setSalesmen(list)
        if (list.length > 0) setSalesmanCode(list[0].employeecode)
      })
      .catch(() => {
        if (!cancelled) setSalesmen([])
      })
      .finally(() => {
        if (!cancelled) setSalesmenLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    const onKey = (e: globalThis.KeyboardEvent) => {
      if (e.key === 'F2') {
        e.preventDefault()
        if (customersModalOpen) {
          setCustomersModalOpen(false)
          return
        }
        openCustomerDetails()
        return
      }
      if (e.key === 'F3') {
        e.preventDefault()
        itemSearchRef.current?.focus()
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [customersModalOpen, openCustomerDetails])

  useEffect(() => {
    const queryText = String(customerQuery ?? '')
    if (
      !queryText.trim() ||
      selectedCustomer?.cust_name === queryText
    ) {
      setCustomerResults([])
      setCustomerSearchError(null)
      return
    }
    const t = window.setTimeout(async () => {
      const q = queryText.trim()
      if (q.length < 2) {
        setCustomerResults([])
        setCustomerLoading(false)
        setCustomerSearchError(null)
        return
      }
      setCustomerLoading(true)
      setCustomerSearchError(null)
      try {
        const res = await fetchCustomers({
          route: '',
          search: q,
          limit: 12,
        })
        setCustomerResults(res.customers ?? [])
        setShowCustomerDropdown(true)
      } catch (err) {
        setCustomerResults([])
        setCustomerSearchError(
          err instanceof Error ? err.message : 'Customer search failed'
        )
        setShowCustomerDropdown(true)
      } finally {
        setCustomerLoading(false)
      }
    }, 280)
    return () => window.clearTimeout(t)
  }, [customerQuery, selectedCustomer])

  useEffect(() => {
    if (!itemQuery.trim()) {
      setItemResults([])
      return
    }
    const t = window.setTimeout(async () => {
      const q = itemQuery.trim()
      if (q.length < 2) {
        setItemResults([])
        setItemLoading(false)
        return
      }
      setItemLoading(true)
      try {
        const res = await fetchItems({ search: q, limit: 12 })
        setItemResults(res.items ?? [])
        setShowItemDropdown(true)
      } catch {
        setItemResults([])
      } finally {
        setItemLoading(false)
      }
    }, 280)
    return () => window.clearTimeout(t)
  }, [itemQuery])

  const lineDiscountTotal = useMemo(
    () => lines.reduce((sum, line) => sum + line.discount, 0),
    [lines]
  )
  const subtotal = useMemo(
    () =>
      lines.reduce(
        (sum, line) => sum + Math.max(line.rate * line.qty - line.discount, 0),
        0
      ),
    [lines]
  )
  const totalDiscount = lineDiscountTotal + discount
  const netTotal = Math.max(subtotal - discount, 0)
  const vatAmount = netTotal * VAT_RATE
  const sugarTaxAmount = Math.max(sugarTax, 0)
  const grandTotal = netTotal + vatAmount + sugarTaxAmount

  const selectedSalesman = salesmen.find((s) => s.employeecode === salesmanCode)

  const avgHint = useMemo(() => {
    if (!selectedCustomer || lines.length === 0) {
      return 'Select a customer and add items to get AI insights for this order.'
    }
    const last = selectedCustomer.last_purchase_amount
    if (last != null && last > 0) {
      const pct = Math.round(((netTotal - last) / last) * 100)
      if (pct > 0) {
        return `This order is ${pct}% higher than the last purchase for ${selectedCustomer.cust_name}.`
      }
      if (pct < 0) {
        return `This order is ${Math.abs(pct)}% lower than the last purchase for ${selectedCustomer.cust_name}.`
      }
      return `This order matches the last purchase amount for ${selectedCustomer.cust_name}.`
    }
    return `Building a new order for ${selectedCustomer.cust_name}. Review credit terms before processing.`
  }, [selectedCustomer, lines.length, netTotal])

  const resetInvoice = () => {
    setInvoiceNo(nextInvoiceNo())
    setInvoiceStatus('DRAFT')
    setInvoiceType('CREDIT')
    setSaleChannel('Call Center')
    setPriceType('Retail Price')
    setDiscount(0)
    setSugarTax(0)
    setCustomerQuery('')
    setSelectedCustomer(null)
    setLines([])
    setSelectedLineIds(new Set())
    setItemQuery('')
    setChat([
      {
        id: 'welcome',
        role: 'assistant',
        text: 'New order started. Select a customer, then ask me about credit, discounts, or next steps.',
      },
    ])
    customerSearchRef.current?.focus()
  }

  const pickCustomer = (customer: DbCustomer) => {
    const name = String(customer.cust_name ?? '').trim()
    const code = String(customer.cust_code ?? '').trim()
    setSelectedCustomer({
      ...customer,
      cust_code: code,
      cust_name: name || code,
    })
    setCustomerQuery(name || code)
    setShowCustomerDropdown(false)
    setCustomerResults([])
    setCustomerSearchError(null)
    itemSearchRef.current?.focus()
  }

  const addItem = (item: DbItemMaster) => {
    addOrderLine({
      itemCode: String(item.itemcode ?? '').trim(),
      description: String(item.itemname ?? '').trim(),
      uom: String(item.baseuom || 'EA').trim(),
      rate: Number(item.retailprice ?? 0),
      qty: 1,
    })
    setItemQuery('')
    setItemResults([])
    setShowItemDropdown(false)
    itemSearchRef.current?.focus()
  }

  const addOrderLine = (item: {
    itemCode: string
    description: string
    uom: string
    rate: number
    qty: number
  }) => {
    const code = item.itemCode.trim()
    if (!code) return
    const qty = item.qty > 0 ? item.qty : 1
    const existing = lines.find((l) => l.itemCode === code)
    if (existing) {
      setLines((prev) =>
        prev.map((l) =>
          l.id === existing.id ? { ...l, qty: l.qty + qty } : l
        )
      )
    } else {
      setLines((prev) => [
        ...prev,
        {
          id: newLineId(),
          itemCode: code,
          description: item.description.trim() || code,
          uom: (item.uom || 'EA').trim(),
          rate: item.rate,
          qty,
          discount: 0,
        },
      ])
    }
  }

  const updateLine = (
    id: string,
    patch: Partial<Pick<LineItem, 'qty' | 'rate' | 'discount'>>
  ) => {
    setLines((prev) =>
      prev.map((line) => {
        if (line.id !== id) return line
        const next = { ...line, ...patch }
        if (next.qty < 0) next.qty = 0
        if (next.rate < 0) next.rate = 0
        if (next.discount < 0) next.discount = 0
        const lineGross = next.rate * next.qty
        if (next.discount > lineGross) next.discount = lineGross
        return next
      })
    )
  }

  const deleteSelected = () => {
    if (selectedLineIds.size === 0) {
      showToast('Select one or more lines to delete')
      return
    }
    setLines((prev) => prev.filter((l) => !selectedLineIds.has(l.id)))
    setSelectedLineIds(new Set())
  }

  const toggleLine = (id: string) => {
    setSelectedLineIds((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const applyBulkDiscount = () => {
    const d = Math.round(subtotal * 0.05 * 100) / 100
    setDiscount(d)
    showToast(`Applied 5% bulk discount (${formatMoney(d)})`)
  }

  const buildAiContext = useCallback(() => {
    return {
      invoiceNo,
      invoiceStatus,
      invoiceType,
      saleChannel,
      priceType,
      customer: selectedCustomer
        ? {
            code: String(selectedCustomer.cust_code ?? ''),
            name: String(selectedCustomer.cust_name ?? ''),
            route: String(
              selectedCustomer.routename ?? selectedCustomer.route ?? ''
            ),
            mobile: selectedCustomer.mobile ?? undefined,
            creditLimit: selectedCustomer.credit_limit,
            creditAmount: selectedCustomer.credit_amount,
            lastPurchaseDate: selectedCustomer.last_purchase_date,
            lastPurchaseAmount: selectedCustomer.last_purchase_amount,
          }
        : undefined,
      salesman: selectedSalesman
        ? {
            code: String(selectedSalesman.employeecode ?? ''),
            name: String(selectedSalesman.username ?? ''),
          }
        : undefined,
      lines: lines.map((line) => ({
        itemCode: line.itemCode,
        description: line.description,
        uom: line.uom,
        qty: line.qty,
        rate: line.rate,
        discount: line.discount,
        amount: Math.max(line.rate * line.qty - line.discount, 0),
      })),
      totals: {
        discount,
        netTotal,
        vatAmount,
        sugarTax: sugarTaxAmount,
        grandTotal,
      },
    }
  }, [
    invoiceNo,
    invoiceStatus,
    invoiceType,
    saleChannel,
    priceType,
    selectedCustomer,
    selectedSalesman,
    lines,
    discount,
    netTotal,
    vatAmount,
    sugarTaxAmount,
    grandTotal,
  ])

  const askAi = useCallback(
    async (rawMessage: string, displayText?: string) => {
      const text = rawMessage.trim()
      if (!text || aiLoading) return

      const history: AiChatMessage[] = chat
        .filter((m) => m.id !== 'welcome')
        .slice(-10)
        .map((m) => ({
          role: m.role,
          content: m.apiText ?? m.text,
        }))

      const userMsg: ChatMessage = {
        id: `u-${Date.now()}`,
        role: 'user',
        text: (displayText ?? text).trim(),
        ...(displayText ? { apiText: text } : {}),
      }
      setChat((prev) => [...prev.filter((m) => m.id !== 'welcome'), userMsg])
      setAiInput('')
      setAiLoading(true)

      try {
        const res = await postAiChat({
          message: text,
          messages: history,
          context: buildAiContext(),
          language: 'auto',
        })
        setChat((prev) => [
          ...prev,
          {
            id: `a-${Date.now()}`,
            role: 'assistant',
            text: res.reply?.trim() || aiCopy.noReply,
          },
        ])
      } catch (err) {
        let message =
          err instanceof Error ? err.message : 'AI request failed'
        if (/failed \(404\)/i.test(message) || /not found/i.test(message)) {
          message =
            'AI route not found on the API server. Restart the backend (port 5318) so /api/ai/chat is loaded, then try again.'
        } else if (/not configured|GROQ_API_KEY|503/i.test(message)) {
          message =
            'AI is not configured. Set GROQ_API_KEY in backend/.env and restart the API.'
        }
        setChat((prev) => [
          ...prev,
          {
            id: `a-${Date.now()}`,
            role: 'assistant',
            text: `Sorry — ${message}`,
          },
        ])
      } finally {
        setAiLoading(false)
        requestAnimationFrame(() => aiInputRef.current?.focus())
      }
    },
    [aiCopy.noReply, aiLoading, buildAiContext, chat]
  )

  const sendAi = () => {
    void askAi(aiInput)
  }

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [chat, aiLoading])

  const onItemKeyDown = (e: KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter' && itemResults[0]) {
      e.preventDefault()
      addItem(itemResults[0])
    }
  }

  const processPayment = () => {
    if (!selectedCustomer) {
      showToast('Select a customer first')
      return
    }
    if (lines.length === 0) {
      showToast('Add at least one item')
      return
    }
    setInvoiceStatus('SAVED')
    showToast(`Order ${invoiceNo} ready · ${CURRENCY} ${formatMoney(grandTotal)}`)
  }

  const dateLabel = createdAt.toLocaleDateString(undefined, {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
  })
  const timeLabel = createdAt.toLocaleTimeString(undefined, {
    hour: '2-digit',
    minute: '2-digit',
  })

  return (
    <div className="flex-1 min-h-0 flex flex-col -m-4 lg:-m-8 bg-gray-100 overflow-hidden">
      {/* Top bar */}
      <header className="shrink-0 bg-white border-b border-gray-200 px-4 lg:px-6 py-3 flex flex-wrap items-center gap-3">
        <div className="flex items-center gap-3">
          <h1 className="text-lg font-bold text-slate-800 tracking-tight">Call Center</h1>
          <button
            type="button"
            onClick={resetInvoice}
            className="inline-flex items-center gap-1.5 rounded-md bg-primary-700 px-3 py-1.5 text-xs font-semibold text-white hover:bg-primary-800"
          >
            <Plus size={14} />
            NEW
          </button>
          <button
            type="button"
            onClick={() => customerSearchRef.current?.focus()}
            className="inline-flex items-center gap-1.5 rounded-md border border-gray-300 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-gray-50"
          >
            <Search size={14} />
            SEARCH
          </button>
        </div>

        <nav className="hidden xl:flex items-center gap-5 text-sm text-gray-500">
          <span className="font-semibold text-slate-800 border-b-2 border-slate-800 pb-0.5">
            Order Billing
          </span>
          <button
            type="button"
            onClick={openCustomerDetails}
            className={cn(
              'pb-0.5 hover:text-slate-800 transition-colors',
              customersModalOpen &&
                'font-semibold text-slate-800 border-b-2 border-slate-800'
            )}
            title="Selected customer details (F2)"
          >
            Customers
          </button>
          <span>Sales</span>
        </nav>

        <div className="ml-auto flex items-center gap-3">
          <button type="button" className="p-2 rounded-lg text-gray-400 hover:bg-gray-100">
            <Settings size={18} />
          </button>
          <div className="text-right hidden sm:block">
            <p className="text-sm font-semibold text-slate-800 leading-tight">
              {user?.name ?? 'Agent'}
            </p>
            <p className="text-[10px] uppercase tracking-wide text-gray-400">
              Call Center
            </p>
          </div>
        </div>
      </header>

      {/* Body */}
      <div className="flex-1 min-h-0 flex gap-3 p-3 lg:p-4 overflow-hidden">
        <div className="flex-1 min-w-0 flex flex-col gap-3 min-h-0">
          {/* Customer + invoice meta row */}
          <div className="relative z-40 grid grid-cols-1 xl:grid-cols-[1fr_220px] gap-3 shrink-0">
            <section className="bg-white rounded-xl border border-gray-200 shadow-sm p-4 overflow-visible">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                <Field label="Customer Name">
                  <div className="relative">
                    <input
                      ref={customerSearchRef}
                      value={customerQuery}
                      onChange={(e) => {
                        setCustomerQuery(e.target.value)
                        if (selectedCustomer) setSelectedCustomer(null)
                        setShowCustomerDropdown(true)
                      }}
                      onFocus={() => {
                        if (customerResults.length > 0 || customerLoading) {
                          setShowCustomerDropdown(true)
                        }
                      }}
                      onBlur={() => {
                        window.setTimeout(() => setShowCustomerDropdown(false), 150)
                      }}
                      placeholder="Search customer name or code"
                      className={fieldInput}
                      autoComplete="off"
                    />
                    {showCustomerDropdown &&
                      (customerResults.length > 0 ||
                        customerLoading ||
                        customerSearchError ||
                        String(customerQuery ?? '').trim().length >= 2) && (
                        <div className="absolute left-0 right-0 z-50 mt-1 rounded-lg border border-gray-200 bg-white shadow-lg max-h-56 overflow-auto">
                          {customerLoading && (
                            <div className="flex items-center gap-2 px-3 py-2 text-xs text-gray-500">
                              <Loader2 size={14} className="animate-spin" /> Searching…
                            </div>
                          )}
                          {!customerLoading && customerSearchError && (
                            <div className="px-3 py-2 text-xs text-red-600">
                              {customerSearchError}
                            </div>
                          )}
                          {!customerLoading &&
                            !customerSearchError &&
                            String(customerQuery ?? '').trim().length >= 2 &&
                            customerResults.length === 0 && (
                              <div className="px-3 py-2 text-xs text-gray-400">
                                No customers found
                              </div>
                            )}
                          {customerResults.map((c) => (
                            <button
                              key={String(c.cust_code)}
                              type="button"
                              onMouseDown={(e) => {
                                e.preventDefault()
                                pickCustomer(c)
                              }}
                              className="w-full text-left px-3 py-2 text-sm hover:bg-primary-50 border-b border-gray-50 last:border-0"
                            >
                              <span className="font-medium text-slate-800">
                                {c.cust_name}
                              </span>
                              <span className="ml-2 text-xs text-gray-400">
                                {c.cust_code}
                              </span>
                            </button>
                          ))}
                        </div>
                      )}
                  </div>
                  {selectedCustomer && (
                    <p className="mt-1 text-[11px] text-gray-400">
                      Code {selectedCustomer.cust_code}
                      {selectedCustomer.routename
                        ? ` · ${selectedCustomer.routename}`
                        : ''}
                    </p>
                  )}
                </Field>

                <Field label="Salesman">
                  <select
                    value={salesmanCode}
                    onChange={(e) => setSalesmanCode(e.target.value)}
                    className={fieldInput}
                    disabled={salesmenLoading}
                  >
                    {salesmenLoading && (
                      <option value="">Loading salesmen...</option>
                    )}
                    {!salesmenLoading && salesmen.length === 0 && (
                      <option value="">No salesmen</option>
                    )}
                    {salesmen.map((s) => (
                      <option key={s.employeecode} value={s.employeecode}>
                        {s.username} ({s.employeecode})
                      </option>
                    ))}
                  </select>
                </Field>

                <Field label="Invoice Type & Channel">
                  <div className="flex rounded-lg overflow-hidden border border-gray-200">
                    {(['CREDIT', 'CASH'] as InvoiceType[]).map((type) => (
                      <button
                        key={type}
                        type="button"
                        onClick={() => setInvoiceType(type)}
                        className={cn(
                          'flex-1 py-2 text-xs font-bold tracking-wide transition-colors',
                          invoiceType === type
                            ? 'bg-primary-800 text-white'
                            : 'bg-white text-gray-500 hover:bg-gray-50'
                        )}
                      >
                        {type}
                      </button>
                    ))}
                  </div>
                </Field>

                <Field label="Sale Channel">
                  <select
                    value={saleChannel}
                    onChange={(e) => setSaleChannel(e.target.value)}
                    className={fieldInput}
                  >
                    <option>Call Center</option>
                    <option>B2B - Corporate</option>
                    <option>Walk-in</option>
                    <option>WhatsApp</option>
                  </select>
                </Field>

                <Field label="Price Type">
                  <select
                    value={priceType}
                    onChange={(e) => setPriceType(e.target.value)}
                    className={fieldInput}
                  >
                    <option>Retail Price</option>
                    <option>Wholesale</option>
                    <option>Special</option>
                  </select>
                </Field>
              </div>
            </section>

            <section className="bg-white rounded-xl border border-gray-200 shadow-sm p-4 flex flex-col gap-3">
              <div className="flex flex-wrap gap-1.5">
                <ActionChip
                  onClick={() => {
                    setInvoiceStatus('SAVED')
                    showToast('Invoice saved as draft')
                  }}
                >
                  SAVE
                </ActionChip>
                <ActionChip onClick={() => window.print()}>
                  <Printer size={12} /> PRINT
                </ActionChip>
                <ActionChip
                  onClick={() => {
                    setInvoiceStatus('HELD')
                    showToast('Invoice held')
                  }}
                >
                  HOLD
                </ActionChip>
                <ActionChip
                  danger
                  onClick={() => {
                    resetInvoice()
                    showToast('Invoice reversed')
                  }}
                >
                  REVERSE
                </ActionChip>
              </div>
              <MetaRow label="Invoice No" value={invoiceNo} />
              <MetaRow label="Date & Time" value={`${dateLabel} | ${timeLabel}`} />
              <MetaRow
                label="User"
                value={`${user?.name ?? 'Agent'} (${user?.employeeCode ?? '—'})`}
              />
              <div className="mt-auto">
                <span
                  className={cn(
                    'inline-flex px-2.5 py-1 rounded-full text-[10px] font-bold tracking-wide',
                    invoiceStatus === 'DRAFT' && 'bg-emerald-100 text-emerald-800',
                    invoiceStatus === 'HELD' && 'bg-amber-100 text-amber-800',
                    invoiceStatus === 'SAVED' && 'bg-blue-100 text-blue-800'
                  )}
                >
                  {invoiceStatus}
                </span>
              </div>
            </section>
          </div>

          {/* Items */}
          <section className="flex-1 min-h-0 bg-white rounded-xl border border-gray-200 shadow-sm flex flex-col overflow-hidden">
            <div className="shrink-0 p-3 border-b border-gray-100 space-y-2">
              <div className="flex items-center gap-3">
                <div className="relative flex-1 min-w-0">
                  <Search
                    size={15}
                    className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-gray-400"
                  />
                  <input
                    ref={itemSearchRef}
                    value={itemQuery}
                    onChange={(e) => setItemQuery(e.target.value)}
                    onKeyDown={onItemKeyDown}
                    onFocus={() => itemResults.length > 0 && setShowItemDropdown(true)}
                    placeholder="Search item (F3)"
                    className="h-10 w-full rounded-lg border border-gray-200 bg-gray-50 pl-9 pr-3 text-sm outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-100"
                  />
                  {showItemDropdown && (itemResults.length > 0 || itemLoading) && (
                    <div className="absolute z-30 mt-1 w-full rounded-lg border border-gray-200 bg-white shadow-lg max-h-56 overflow-auto">
                      {itemLoading && (
                        <div className="flex items-center gap-2 px-3 py-2 text-xs text-gray-500">
                          <Loader2 size={14} className="animate-spin" /> Searching…
                        </div>
                      )}
                      {itemResults.map((item) => (
                        <button
                          key={item.itemcode}
                          type="button"
                          onClick={() => addItem(item)}
                          className="w-full text-left px-3 py-2 text-sm hover:bg-primary-50 border-b border-gray-50 last:border-0"
                        >
                          <div className="flex justify-between gap-2">
                            <span className="font-medium text-slate-800 truncate">
                              {item.itemname}
                            </span>
                            <span className="text-xs text-gray-500 shrink-0">
                              {CURRENCY} {formatMoney(Number(item.retailprice ?? 0))}
                            </span>
                          </div>
                          <span className="text-xs text-gray-400">{item.itemcode}</span>
                        </button>
                      ))}
                    </div>
                  )}
                </div>
                <button
                  type="button"
                  onClick={deleteSelected}
                  className="inline-flex h-10 shrink-0 items-center gap-1.5 rounded-lg border border-red-200 bg-red-50 px-3 text-xs font-bold text-red-600 hover:bg-red-100"
                >
                  <Trash2 size={14} />
                  DELETE
                </button>
              </div>
              <p className="text-[10px] text-gray-400 flex flex-wrap gap-x-3 gap-y-0.5">
                <span>
                  <kbd className="font-semibold text-gray-500">F2</kbd> Customer
                </span>
                <span>
                  <kbd className="font-semibold text-gray-500">F3</kbd> Search
                </span>
                <span>
                  <kbd className="font-semibold text-gray-500">Enter</kbd> Add / Next
                </span>
                <span>
                  <kbd className="font-semibold text-gray-500">↑↓</kbd> Navigate
                </span>
              </p>
            </div>

            <div className="flex-1 min-h-0 overflow-auto">
              <table className="w-full text-sm">
                <thead className="sticky top-0 bg-gray-50 text-[11px] uppercase tracking-wide text-gray-500">
                  <tr>
                    <th className="w-10 px-3 py-2.5 text-left font-semibold" />
                    <th className="px-3 py-2.5 text-left font-semibold">Sl.No</th>
                    <th className="px-3 py-2.5 text-left font-semibold">Item Code</th>
                    <th className="px-3 py-2.5 text-left font-semibold">Description</th>
                    <th className="px-3 py-2.5 text-left font-semibold">UOM</th>
                    <th className="px-3 py-2.5 text-right font-semibold">Rate</th>
                    <th className="px-3 py-2.5 text-right font-semibold">Qty</th>
                    <th className="px-3 py-2.5 text-right font-semibold">Discount</th>
                    <th className="px-3 py-2.5 text-right font-semibold">Amount</th>
                  </tr>
                </thead>
                <tbody>
                  {lines.length === 0 ? (
                    <tr>
                      <td
                        colSpan={9}
                        className="px-3 py-16 text-center text-sm text-gray-400"
                      >
                        Press F3 to search and add items to this order
                      </td>
                    </tr>
                  ) : (
                    lines.map((line, index) => (
                      <tr
                        key={line.id}
                        className={cn(
                          'border-t border-gray-100',
                          selectedLineIds.has(line.id) && 'bg-primary-50/50'
                        )}
                      >
                        <td className="px-3 py-2">
                          <input
                            type="checkbox"
                            checked={selectedLineIds.has(line.id)}
                            onChange={() => toggleLine(line.id)}
                            className="rounded border-gray-300"
                          />
                        </td>
                        <td className="px-3 py-2 text-gray-500">{index + 1}</td>
                        <td className="px-3 py-2 font-mono text-xs text-slate-700">
                          {line.itemCode}
                        </td>
                        <td className="px-3 py-2 text-slate-800">{line.description}</td>
                        <td className="px-3 py-2 text-gray-500">{line.uom}</td>
                        <td className="px-3 py-2 text-right">
                          <input
                            type="number"
                            min={0}
                            step={0.01}
                            value={line.rate}
                            onChange={(e) =>
                              updateLine(line.id, { rate: Number(e.target.value) || 0 })
                            }
                            className="w-24 rounded border border-gray-200 px-2 py-1 text-right text-sm outline-none focus:border-primary-500"
                          />
                        </td>
                        <td className="px-3 py-2 text-right">
                          <input
                            type="number"
                            min={0}
                            step={1}
                            value={line.qty}
                            onChange={(e) =>
                              updateLine(line.id, { qty: Number(e.target.value) || 0 })
                            }
                            className="w-16 rounded border border-gray-200 px-2 py-1 text-right text-sm outline-none focus:border-primary-500"
                          />
                        </td>
                        <td className="px-3 py-2 text-right">
                          <input
                            type="number"
                            min={0}
                            step={0.01}
                            value={line.discount}
                            onChange={(e) =>
                              updateLine(line.id, {
                                discount: Number(e.target.value) || 0,
                              })
                            }
                            className="w-20 rounded border border-gray-200 px-2 py-1 text-right text-sm outline-none focus:border-primary-500"
                          />
                        </td>
                        <td className="px-3 py-2 text-right font-medium text-slate-800">
                          {formatMoney(Math.max(line.rate * line.qty - line.discount, 0))}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            <footer className="shrink-0 bg-slate-900 text-white px-3 lg:px-4 py-2.5 flex flex-wrap items-center gap-3 lg:gap-5 border-t border-slate-800">
              <div className="flex flex-wrap gap-4 lg:gap-5 text-sm">
                <div>
                  <p className="text-[10px] uppercase tracking-wider text-slate-400">
                    Total Discount
                  </p>
                  <p className="font-semibold tabular-nums">
                    {formatMoney(totalDiscount)}
                  </p>
                </div>
                <div>
                  <p className="text-[10px] uppercase tracking-wider text-slate-400">
                    Net Total
                  </p>
                  <p className="font-semibold tabular-nums">{formatMoney(netTotal)}</p>
                </div>
                <div>
                  <p className="text-[10px] uppercase tracking-wider text-slate-400">
                    VAT ({Math.round(VAT_RATE * 100)}%)
                  </p>
                  <p className="font-semibold tabular-nums">{formatMoney(vatAmount)}</p>
                </div>
                <div>
                  <p className="text-[10px] uppercase tracking-wider text-slate-400">
                    Sugar Tax
                  </p>
                  <input
                    type="number"
                    min={0}
                    step={0.01}
                    value={sugarTax}
                    onChange={(e) => setSugarTax(Number(e.target.value) || 0)}
                    aria-label="Sugar tax"
                    className="mt-0.5 w-20 rounded-md border border-slate-600 bg-slate-800 px-2 py-1 text-sm font-semibold tabular-nums text-white outline-none focus:border-primary-400"
                  />
                </div>
              </div>

              <div className="flex-1 text-center min-w-[140px]">
                <p className="text-[10px] uppercase tracking-wider text-slate-400">
                  Grand Total (Incl. VAT & Sugar Tax)
                </p>
                <p className="text-xl lg:text-2xl font-bold tracking-tight tabular-nums">
                  {CURRENCY} {formatMoney(grandTotal)}
                </p>
              </div>

              <button
                type="button"
                onClick={processPayment}
                className="ml-auto inline-flex items-center gap-2 rounded-xl bg-primary-500 hover:bg-primary-400 px-4 lg:px-5 py-2.5 text-sm font-bold text-white shadow-lg shadow-primary-900/30"
              >
                <CreditCard size={18} />
                PROCESS PAYMENT
              </button>
            </footer>
          </section>
        </div>

        {/* AI Assistant */}
        <aside
          aria-label="AI assistant"
          className="hidden lg:flex w-72 xl:w-80 shrink-0 flex-col bg-white rounded-xl border border-gray-200 shadow-sm overflow-hidden"
        >
          <div className="px-3.5 py-2.5 border-b border-gray-100 flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-primary-50 text-primary-600">
              <Sparkles size={14} aria-hidden />
            </div>
            <div className="min-w-0 flex-1">
              <h2 className="text-xs font-bold text-slate-800 leading-tight">
                AI Assistant
              </h2>
              <p
                className="text-[10px] text-gray-500 truncate"
                aria-live="polite"
              >
                {aiLoading ? aiCopy.statusThinking : aiCopy.statusIdle}
              </p>
            </div>
          </div>

          <div className="px-3.5 py-2 border-b border-gray-50 bg-gray-50/80">
            <p className="text-[11px] leading-snug text-slate-600 line-clamp-2" dir="auto">
              {avgHint}
            </p>
          </div>

          <div
            className="flex-1 min-h-0 overflow-auto px-3 py-3 space-y-2.5"
            role="log"
            aria-relevant="additions"
            aria-busy={aiLoading}
          >
            {chat.map((msg) => (
              <div
                key={msg.id}
                dir="auto"
                className={cn(
                  'rounded-lg px-3 py-2 text-[12px] leading-relaxed max-w-[92%] whitespace-pre-wrap break-words',
                  msg.role === 'assistant'
                    ? 'bg-slate-50 text-slate-700 border border-slate-100'
                    : 'bg-primary-600 text-white ms-auto'
                )}
              >
                {msg.text}
              </div>
            ))}
            {aiLoading && (
              <div
                className="rounded-lg px-3 py-2 text-[12px] max-w-[92%] bg-slate-50 text-slate-500 border border-slate-100 inline-flex items-center gap-2"
                aria-live="polite"
              >
                <Loader2 size={12} className="animate-spin" aria-hidden />
                {aiCopy.statusThinking}
              </div>
            )}
            <div ref={chatEndRef} />
          </div>

          <div className="px-3 pt-2 pb-1.5 border-t border-gray-100">
            <p className="sr-only">Quick actions</p>
            <div className="flex gap-1.5 overflow-x-auto overscroll-x-contain pb-0.5 [scrollbar-width:thin] [scrollbar-color:rgb(148_163_184)_transparent] [&::-webkit-scrollbar]:h-px [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-slate-400 [&::-webkit-scrollbar-track]:bg-transparent">
              <SuggestBtn
                disabled={aiLoading || lines.length === 0}
                onClick={() => {
                  applyBulkDiscount()
                  void askAi(
                    'I applied a 5% bulk order discount. Briefly confirm the new totals and whether this discount looks reasonable for this customer/order.',
                    aiCopy.discountAsk
                  )
                }}
              >
                {aiCopy.discount}
              </SuggestBtn>
              <SuggestBtn
                disabled={aiLoading}
                onClick={() =>
                  void askAi(
                    'Review credit risk for this customer against the current order totals. Mention due/credit limit from context if available, and recommend whether to proceed, reduce qty, or switch invoice type.',
                    aiCopy.creditAsk
                  )
                }
              >
                {aiCopy.credit}
              </SuggestBtn>
              <SuggestBtn
                disabled={aiLoading}
                onClick={() =>
                  void askAi(
                    'Based on the current draft order, suggest the next practical steps for the call-center agent before processing payment. Be specific to missing fields or empty lines if any.',
                    aiCopy.nextAsk
                  )
                }
              >
                {aiCopy.next}
              </SuggestBtn>
              <SuggestBtn
                disabled={aiLoading || !selectedCustomer}
                onClick={() =>
                  void askAi(
                    'Summarize this customer recent purchase history: recent bill dates and amounts, what they bought on the latest bill, any frequent or own products if visible, and how the current draft order compares. Use only the provided customer and history details. Be specific with bill numbers and QAR amounts.',
                    aiCopy.historyAsk
                  )
                }
              >
                {aiCopy.history}
              </SuggestBtn>
              <SuggestBtn
                disabled={aiLoading}
                onClick={() =>
                  void askAi(
                    'List the top 5 repeat customers. Include customer code, name, route, bill count, and last bill date/amount. No customer needs to be selected on the order first.',
                    aiCopy.repeatAsk
                  )
                }
              >
                {aiCopy.repeat}
              </SuggestBtn>
            </div>
          </div>

          <form
            className="p-3 pt-2 flex gap-2"
            onSubmit={(e) => {
              e.preventDefault()
              sendAi()
            }}
          >
            <label htmlFor="ai-assistant-input" className="sr-only">
              Ask about this order
            </label>
            <input
              id="ai-assistant-input"
              ref={aiInputRef}
              value={aiInput}
              onChange={(e) => setAiInput(e.target.value)}
              disabled={aiLoading}
              placeholder={aiCopy.placeholder}
              autoComplete="off"
              dir="auto"
              className="flex-1 min-w-0 rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-slate-800 outline-none placeholder:text-gray-400 focus:border-primary-500 focus:ring-2 focus:ring-primary-100 disabled:bg-gray-50"
            />
            <button
              type="submit"
              disabled={aiLoading || !aiInput.trim()}
              aria-label="Send message"
              className="shrink-0 rounded-lg bg-primary-600 px-2.5 text-white hover:bg-primary-700 disabled:opacity-40"
            >
              {aiLoading ? (
                <Loader2 size={15} className="animate-spin" aria-hidden />
              ) : (
                <Send size={15} aria-hidden />
              )}
            </button>
          </form>
        </aside>
      </div>

      {toast && (
        <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 rounded-lg bg-slate-800 text-white text-sm px-4 py-2 shadow-xl">
          {toast}
        </div>
      )}

      <CustomerSearchModal
        open={customersModalOpen}
        onClose={() => setCustomersModalOpen(false)}
        selectedCustomer={selectedCustomer}
        onAddItem={(item) => {
          addOrderLine(item)
          showToast(`Added ${item.description || item.itemCode}`)
        }}
      />
    </div>
  )
}

const fieldInput =
  'w-full rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-slate-800 outline-none focus:border-primary-500 focus:ring-2 focus:ring-primary-100'

function Field({
  label,
  children,
}: {
  label: string
  children: ReactNode
}) {
  return (
    <div className="block">
      <span className="block text-[11px] font-semibold uppercase tracking-wide text-gray-500 mb-1">
        {label}
      </span>
      {children}
    </div>
  )
}

function MetaRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-[10px] uppercase tracking-wide text-gray-400">{label}</p>
      <p className="text-sm font-semibold text-slate-800">{value}</p>
    </div>
  )
}

function ActionChip({
  children,
  onClick,
  danger,
}: {
  children: ReactNode
  onClick?: () => void
  danger?: boolean
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        'inline-flex items-center gap-1 rounded-md border px-2 py-1 text-[10px] font-bold tracking-wide',
        danger
          ? 'border-red-200 text-red-600 hover:bg-red-50'
          : 'border-gray-200 text-slate-600 hover:bg-gray-50'
      )}
    >
      {children}
    </button>
  )
}

function SuggestBtn({
  children,
  onClick,
  disabled,
}: {
  children: ReactNode
  onClick?: () => void
  disabled?: boolean
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      className="shrink-0 whitespace-nowrap rounded-md border border-gray-200 bg-white px-2 py-1 text-[11px] font-medium text-slate-600 hover:border-primary-300 hover:bg-primary-50 hover:text-primary-800 transition-colors disabled:opacity-40 disabled:pointer-events-none"
    >
      {children}
    </button>
  )
}
