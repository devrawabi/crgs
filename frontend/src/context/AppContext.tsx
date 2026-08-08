import {
  createContext,
  useContext,
  useState,
  useCallback,
  useMemo,
  type ReactNode,
} from 'react'
import { parseRouteColumn } from '../api/users'
import type {
  User,
  Route,
  Customer,
  SalesTarget,
  ProductTarget,
  CustomerTarget,
  Product,
  Task,
  MarketIntel,
} from '../types'

interface AppContextValue {
  users: User[]
  routes: Route[]
  customers: Customer[]
  salesTargets: SalesTarget[]
  productTargets: ProductTarget[]
  customerTargets: CustomerTarget[]
  products: Product[]
  tasks: Task[]
  marketIntel: MarketIntel[]
  addUser: (user: Omit<User, 'id' | 'createdAt'>) => void
  updateUser: (id: string, updates: Partial<User>) => void
  toggleUserStatus: (id: string) => void
  addRoute: (route: Omit<Route, 'id' | 'customerCount'>) => void
  updateRoute: (id: string, updates: Partial<Route>) => void
  assignCustomerToRoute: (customerId: string, routeId: string, executiveId: string) => void
  assignCustomersToExecutive: (executiveId: string, customerIds: string[]) => void
  assignRoutesToExecutive: (executiveId: string, routeNos: string[]) => void
  assignRoutesByEmployeeCode: (employeeCode: string, routeNos: string[]) => void
  syncExecutivesFromDb: (
    dbUsers: Array<{ username: string; employeecode: string; flag: string }>
  ) => void
  getUserByEmployeeCode: (employeeCode: string) => User | undefined
  reassignCustomer: (customerId: string, newExecutiveId: string, newRouteId: string) => void
  addSalesTarget: (target: Omit<SalesTarget, 'id'>) => void
  addProductTarget: (target: Omit<ProductTarget, 'id'>) => void
  addCustomerTarget: (target: Omit<CustomerTarget, 'id'>) => void
  addTask: (task: Omit<Task, 'id' | 'createdAt' | 'status'>) => void
  updateTask: (id: string, updates: Partial<Task>) => void
}

const AppContext = createContext<AppContextValue | null>(null)

let idCounter = 0

function generateId(prefix: string) {
  idCounter += 1
  return `${prefix}${Date.now()}_${idCounter}`
}

export function AppProvider({ children }: { children: ReactNode }) {
  // Start empty — pages hydrate from the API. Avoid shipping mock seed data in memory.
  const [users, setUsers] = useState<User[]>([])
  const [routes, setRoutes] = useState<Route[]>([])
  const [customers, setCustomers] = useState<Customer[]>([])
  const [salesTargets, setSalesTargets] = useState<SalesTarget[]>([])
  const [productTargets, setProductTargets] = useState<ProductTarget[]>([])
  const [customerTargets, setCustomerTargets] = useState<CustomerTarget[]>([])
  const [products] = useState<Product[]>([])
  const [tasks, setTasks] = useState<Task[]>([])
  const [marketIntel] = useState<MarketIntel[]>([])

  const addUser = useCallback((user: Omit<User, 'id' | 'createdAt'>) => {
    setUsers((prev) => [
      ...prev,
      { ...user, assignedRouteNos: user.assignedRouteNos ?? [], id: generateId('u'), createdAt: new Date().toISOString().split('T')[0] },
    ])
  }, [])

  const updateUser = useCallback((id: string, updates: Partial<User>) => {
    setUsers((prev) => prev.map((u) => (u.id === id ? { ...u, ...updates } : u)))
  }, [])

  const toggleUserStatus = useCallback((id: string) => {
    setUsers((prev) =>
      prev.map((u) =>
        u.id === id ? { ...u, status: u.status === 'active' ? 'inactive' : 'active' } : u
      )
    )
  }, [])

  const addRoute = useCallback((route: Omit<Route, 'id' | 'customerCount'>) => {
    const newRoute: Route = { ...route, id: generateId('r'), customerCount: 0 }
    setRoutes((prev) => [...prev, newRoute])
    if (route.executiveId) {
      setUsers((prev) =>
        prev.map((u) =>
          u.id === route.executiveId ? { ...u, routeIds: [...u.routeIds, newRoute.id] } : u
        )
      )
    }
  }, [])

  const updateRoute = useCallback((id: string, updates: Partial<Route>) => {
    setRoutes((prev) => prev.map((r) => (r.id === id ? { ...r, ...updates } : r)))
    if (updates.executiveId !== undefined) {
      setUsers((prev) =>
        prev.map((u) => {
          const hadRoute = u.routeIds.includes(id)
          const shouldHave = u.id === updates.executiveId
          if (hadRoute && !shouldHave) {
            return { ...u, routeIds: u.routeIds.filter((rid) => rid !== id) }
          }
          if (!hadRoute && shouldHave) {
            return { ...u, routeIds: [...u.routeIds, id] }
          }
          return u
        })
      )
    }
  }, [])

  const assignCustomerToRoute = useCallback(
    (customerId: string, routeId: string, executiveId: string) => {
      setCustomers((prev) =>
        prev.map((c) => (c.id === customerId ? { ...c, routeId, executiveId } : c))
      )
    },
    []
  )

  const assignCustomersToExecutive = useCallback(
    (executiveId: string, customerIds: string[]) => {
      const executive = users.find((u) => u.id === executiveId)
      const defaultRoute = executive?.routeIds[0]

      setCustomers((prev) =>
        prev.map((c) => {
          const isSelected = customerIds.includes(c.id)
          const wasAssigned = c.executiveId === executiveId

          if (isSelected) {
            const routeId =
              executive?.routeIds.includes(c.routeId) && c.routeId
                ? c.routeId
                : defaultRoute ?? c.routeId
            return { ...c, executiveId, routeId }
          }

          if (wasAssigned) {
            return { ...c, executiveId: '' }
          }

          return c
        })
      )
    },
    [users]
  )

  const assignRoutesByEmployeeCode = useCallback((employeeCode: string, routeNos: string[]) => {
    const code = employeeCode.toUpperCase()
    setUsers((prev) =>
      prev.map((u) =>
        u.employeeCode.toUpperCase() === code ? { ...u, assignedRouteNos: routeNos } : u
      )
    )
  }, [])

  const assignRoutesToExecutive = useCallback((executiveId: string, routeNos: string[]) => {
    setUsers((prev) => {
      const executive = prev.find((u) => u.id === executiveId)
      if (!executive) return prev
      const code = executive.employeeCode.toUpperCase()
      return prev.map((u) =>
        u.employeeCode.toUpperCase() === code ? { ...u, assignedRouteNos: routeNos } : u
      )
    })
  }, [])

  const syncExecutivesFromDb = useCallback(
    (dbUsers: Array<{ username: string; employeecode: string; flag: string; route?: string | null }>) => {
      setUsers((prev) => {
        const next = [...prev]
        for (const db of dbUsers) {
          const code = db.employeecode.toUpperCase()
          const idx = next.findIndex((u) => u.employeeCode.toUpperCase() === code)
          const status = db.flag?.toUpperCase() === 'A' ? 'active' : 'inactive'
          const assignedRouteNos = parseRouteColumn(db.route ?? null)

          if (idx >= 0) {
            next[idx] = {
              ...next[idx],
              username: db.username,
              employeeCode: db.employeecode,
              status,
              role: 'sales_executive',
              assignedRouteNos,
            }
          } else {
            next.push({
              id: generateId('u'),
              username: db.username,
              employeeCode: db.employeecode,
              password: '',
              role: 'sales_executive',
              status,
              routeIds: [],
              assignedRouteNos,
              createdAt: new Date().toISOString().split('T')[0],
            })
          }
        }
        return next
      })
    },
    []
  )

  const getUserByEmployeeCode = useCallback(
    (employeeCode: string) => {
      const code = employeeCode.toUpperCase()
      return users.find((u) => u.employeeCode.toUpperCase() === code)
    },
    [users]
  )

  const reassignCustomer = useCallback(
    (customerId: string, newExecutiveId: string, newRouteId: string) => {
      setCustomers((prev) =>
        prev.map((c) =>
          c.id === customerId
            ? { ...c, executiveId: newExecutiveId, routeId: newRouteId }
            : c
        )
      )
    },
    []
  )

  const addSalesTarget = useCallback((target: Omit<SalesTarget, 'id'>) => {
    setSalesTargets((prev) => [...prev, { ...target, id: generateId('st') }])
  }, [])

  const addProductTarget = useCallback((target: Omit<ProductTarget, 'id'>) => {
    setProductTargets((prev) => [...prev, { ...target, id: generateId('pt') }])
  }, [])

  const addCustomerTarget = useCallback((target: Omit<CustomerTarget, 'id'>) => {
    setCustomerTargets((prev) => [...prev, { ...target, id: generateId('ct') }])
  }, [])

  const addTask = useCallback((task: Omit<Task, 'id' | 'createdAt' | 'status'>) => {
    setTasks((prev) => [
      ...prev,
      {
        ...task,
        id: generateId('t'),
        createdAt: new Date().toISOString().split('T')[0],
        status: 'pending',
      },
    ])
  }, [])

  const updateTask = useCallback((id: string, updates: Partial<Task>) => {
    setTasks((prev) => prev.map((t) => (t.id === id ? { ...t, ...updates } : t)))
  }, [])

  const value = useMemo(
    () => ({
      users,
      routes,
      customers,
      salesTargets,
      productTargets,
      customerTargets,
      products,
      tasks,
      marketIntel,
      addUser,
      updateUser,
      toggleUserStatus,
      addRoute,
      updateRoute,
      assignCustomerToRoute,
      assignCustomersToExecutive,
      assignRoutesToExecutive,
      assignRoutesByEmployeeCode,
      syncExecutivesFromDb,
      getUserByEmployeeCode,
      reassignCustomer,
      addSalesTarget,
      addProductTarget,
      addCustomerTarget,
      addTask,
      updateTask,
    }),
    [
      users,
      routes,
      customers,
      salesTargets,
      productTargets,
      customerTargets,
      products,
      tasks,
      marketIntel,
      addUser,
      updateUser,
      toggleUserStatus,
      addRoute,
      updateRoute,
      assignCustomerToRoute,
      assignCustomersToExecutive,
      assignRoutesToExecutive,
      assignRoutesByEmployeeCode,
      syncExecutivesFromDb,
      getUserByEmployeeCode,
      reassignCustomer,
      addSalesTarget,
      addProductTarget,
      addCustomerTarget,
      addTask,
      updateTask,
    ]
  )

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>
}

export function useApp() {
  const ctx = useContext(AppContext)
  if (!ctx) throw new Error('useApp must be used within AppProvider')
  return ctx
}

export function useExecutives() {
  const { users } = useApp()
  return users.filter((u) => u.role === 'sales_executive')
}

export function getExecutiveName(users: User[], id: string) {
  if (!id) return 'Unassigned'
  return users.find((u) => u.id === id)?.username ?? 'Unassigned'
}

export function getRouteName(routes: Route[], id: string) {
  return routes.find((r) => r.id === id)?.name ?? '—'
}

export function formatCurrency(amount: number) {
  return new Intl.NumberFormat('en-QA', {
    style: 'currency',
    currency: 'QAR',
    maximumFractionDigits: 0,
  }).format(amount)
}

export function formatPercent(achieved: number, target: number) {
  if (target === 0) return 0
  return Math.round((achieved / target) * 100)
}
