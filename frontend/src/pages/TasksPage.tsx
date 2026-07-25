import { useCallback, useEffect, useMemo, useState } from 'react'
import { Plus, Trash2 } from 'lucide-react'
import { PageHeader, FormField, inputClass, selectClass } from '../components/ui/PageHeader'
import { Button } from '../components/ui/Button'
import { Badge } from '../components/ui/Badge'
import { Modal } from '../components/ui/Modal'
import { Card } from '../components/ui/Card'
import { Table } from '../components/ui/Table'
import { useApp } from '../context/AppContext'
import { STATUS_COLORS, TASK_TYPE_LABELS } from '../data/mockData'
import type { TaskType } from '../types'
import { fetchRoutes, type DbRoute } from '../api/routes'
import {
  fetchUsers,
  formatRouteColumn,
  isRouteNoSelected,
  parseRouteColumn,
  type DbLoginUser,
} from '../api/users'
import { createTask, deleteTask, fetchTasks, type DbTask } from '../api/tasks'
import { AssignedRoutesMultiSelect } from '../components/ui/AssignedRoutesMultiSelect'
import { RouteTargetCell } from '../components/ui/RouteTargetCell'

function isActiveExecutive(flag: string): boolean {
  return (flag ?? '').trim().toUpperCase() === 'A'
}

type TaskStatus = 'pending' | 'in_progress' | 'completed'

const TASK_STATUS_LABELS: Record<TaskStatus, string> = {
  pending: 'Pending',
  in_progress: 'In Progress',
  completed: 'Completed',
}

function normalizeTaskStatus(value: string): TaskStatus {
  const text = (value ?? '').trim().toLowerCase().replace(/\s+/g, '_')
  if (text === 'completed' || text === 'complete' || text === 'done') {
    return 'completed'
  }
  if (
    text === 'in_progress' ||
    text === 'inprogress' ||
    text === 'progress' ||
    text === 'started'
  ) {
    return 'in_progress'
  }
  return 'pending'
}

const TASK_TYPES: { value: TaskType; label: string }[] = [
  { value: 'missing_customer_followup', label: 'Missing Customer Follow-up' },
  { value: 'outstanding_collection_followup', label: 'Outstanding Collection Follow-up' },
  { value: 'new_product_introduction', label: 'New Product Introduction' },
  { value: 'product_replacement_campaign', label: 'Product Replacement Campaign' },
  { value: 'customer_visit_campaign', label: 'Customer Visit Campaign' },
  { value: 'own_products', label: 'Own Products' },
  { value: 'market_research', label: 'Market Research' },
]

export function TasksPage() {
  const { syncExecutivesFromDb } = useApp()
  const [dbExecutives, setDbExecutives] = useState<DbLoginUser[]>([])
  const [dbRoutes, setDbRoutes] = useState<DbRoute[]>([])
  const [dbTasks, setDbTasks] = useState<DbTask[]>([])
  const [routesLoading, setRoutesLoading] = useState(true)
  const [executivesLoading, setExecutivesLoading] = useState(true)
  const [tasksLoading, setTasksLoading] = useState(true)
  const [tasksError, setTasksError] = useState<string | null>(null)
  const [submitting, setSubmitting] = useState(false)
  const [deletingKey, setDeletingKey] = useState<string | null>(null)
  const [formError, setFormError] = useState<string | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [filter, setFilter] = useState<string>('all')

  const [form, setForm] = useState({
    type: 'missing_customer_followup' as TaskType,
    employeeCode: '',
    routeNos: [] as string[],
    dueDate: '',
    notes: '',
  })

  const activeExecutives = useMemo(
    () => dbExecutives.filter((e) => isActiveExecutive(e.flag)),
    [dbExecutives]
  )

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

  const loadTasks = useCallback(async () => {
    setTasksLoading(true)
    setTasksError(null)
    try {
      const data = await fetchTasks()
      setDbTasks(data.tasks)
    } catch (err) {
      setDbTasks([])
      setTasksError(err instanceof Error ? err.message : 'Failed to load tasks')
    } finally {
      setTasksLoading(false)
    }
  }, [])

  useEffect(() => {
    loadExecutives()
    loadRoutes()
    loadTasks()
  }, [loadExecutives, loadRoutes, loadTasks])

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

  const selectedEmployeeCode = form.employeeCode

  const assignedRoutes = useMemo(
    () => getAssignedRoutes(selectedEmployeeCode),
    [getAssignedRoutes, selectedEmployeeCode]
  )

  const filteredTasks =
    filter === 'all' ? dbTasks : dbTasks.filter((t) => t.type === filter)

  const getExecutiveNameByCode = (employeeCode: string) => {
    if (!employeeCode) return 'Unassigned'
    const code = employeeCode.trim().toUpperCase()
    return (
      dbExecutives.find((u) => u.employeecode.trim().toUpperCase() === code)?.username ??
      employeeCode
    )
  }

  const getRouteNamesFromNos = (routeNo: string) => {
    const routeNos = parseRouteColumn(routeNo)
    return routeNos.map((no) => {
      const match = dbRoutes.find((r) => isRouteNoSelected([no], r.routeno))
      return match?.routename ?? `Route ${no}`
    })
  }

  const taskKey = (task: DbTask, index: number) =>
    `${task.employeeCode}-${task.type}-${task.routeNo}-${task.dueDate}-${index}`

  const handleDeleteTask = async (task: DbTask, index: number) => {
    const key = taskKey(task, index)
    const label = TASK_TYPE_LABELS[task.type] ?? task.type
    if (!window.confirm(`Delete task "${label}" for ${getExecutiveNameByCode(task.employeeCode)}?`)) {
      return
    }
    setDeletingKey(key)
    setTasksError(null)
    try {
      await deleteTask({
        type: task.type,
        employeeCode: task.employeeCode,
        routeNo: task.routeNo,
        dueDate: String(task.dueDate).slice(0, 10),
      })
      await loadTasks()
    } catch (err) {
      setTasksError(err instanceof Error ? err.message : 'Failed to delete task')
    } finally {
      setDeletingKey(null)
    }
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormError(null)

    if (!selectedEmployeeCode) {
      setFormError('Select an executive')
      return
    }
    if (assignedRoutes.length > 0 && form.routeNos.length === 0) {
      setFormError('Select at least one route')
      return
    }
    if (form.routeNos.length === 0) {
      setFormError('Route is required')
      return
    }

    setSubmitting(true)
    try {
      await createTask({
        type: form.type,
        employeeCode: selectedEmployeeCode,
        routeNo: formatRouteColumn(form.routeNos),
        dueDate: form.dueDate,
      })
      await loadTasks()
      setForm({
        type: 'missing_customer_followup',
        employeeCode: '',
        routeNos: [],
        dueDate: '',
        notes: '',
      })
      setModalOpen(false)
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to create task')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <div className="flex-1 overflow-auto min-h-0">
      <PageHeader
        title="Task Management"
        description="Create and assign follow-up, collection, visit, and product campaigns to executives"
        action={
          <Button onClick={() => setModalOpen(true)}>
            <Plus size={16} />
            Create Task
          </Button>
        }
      />

      <div className="flex flex-wrap gap-2 mb-6">
        <button
          onClick={() => setFilter('all')}
          className={`px-3 py-1.5 rounded-lg text-sm font-medium ${
            filter === 'all' ? 'bg-primary-600 text-white' : 'bg-gray-100 text-gray-600'
          }`}
        >
          All ({dbTasks.length})
        </button>
        {TASK_TYPES.map((tt) => (
          <button
            key={tt.value}
            onClick={() => setFilter(tt.value)}
            className={`px-3 py-1.5 rounded-lg text-sm font-medium ${
              filter === tt.value ? 'bg-primary-600 text-white' : 'bg-gray-100 text-gray-600'
            }`}
          >
            {tt.label.split(' ').slice(0, 2).join(' ')} (
            {dbTasks.filter((t) => t.type === tt.value).length})
          </button>
        ))}
      </div>

      <Card>
        {tasksError && (
          <p className="mb-4 text-sm text-red-600">{tasksError}</p>
        )}
        <Table
          columns={[
            { key: 'type', label: 'Type' },
            { key: 'executive', label: 'Executive' },
            { key: 'route', label: 'Route' },
            { key: 'status', label: 'Status' },
            { key: 'due', label: 'Due Date' },
            { key: 'actions', label: '' },
          ]}
        >
          {tasksLoading ? (
            <tr>
              <td colSpan={6} className="px-4 py-8 text-center text-gray-400">
                Loading tasks...
              </td>
            </tr>
          ) : filteredTasks.length === 0 ? (
            <tr>
              <td colSpan={6} className="px-4 py-8 text-center text-gray-400">
                No tasks found
              </td>
            </tr>
          ) : (
            filteredTasks.map((task, index) => {
              const key = taskKey(task, index)
              return (
                <tr key={key} className="hover:bg-gray-50">
                  <td className="px-4 py-3 text-xs text-gray-600">{TASK_TYPE_LABELS[task.type]}</td>
                  <td className="px-4 py-3">{getExecutiveNameByCode(task.employeeCode)}</td>
                  <td className="px-4 py-3 text-gray-600 text-sm">
                    <RouteTargetCell routeNames={getRouteNamesFromNos(task.routeNo)} />
                  </td>
                  <td className="px-4 py-3">
                    {(() => {
                      const status = normalizeTaskStatus(task.status)
                      return (
                        <Badge
                          label={TASK_STATUS_LABELS[status]}
                          className={STATUS_COLORS[status]}
                        />
                      )
                    })()}
                  </td>
                  <td className="px-4 py-3 text-gray-600">{task.dueDate}</td>
                  <td className="px-4 py-3 text-right">
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="text-red-600 hover:bg-red-50 hover:text-red-700"
                      disabled={deletingKey === key}
                      onClick={() => handleDeleteTask(task, index)}
                      aria-label="Delete task"
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

      <Modal open={modalOpen} onClose={() => setModalOpen(false)} title="Create Task" wide>
        <form onSubmit={handleSubmit} className="space-y-4">
          {formError && (
            <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-lg px-3 py-2">
              {formError}
            </p>
          )}
          <FormField label="Task Type" required>
            <select
              className={selectClass}
              value={form.type}
              onChange={(e) =>
                setForm({ ...form, type: e.target.value as TaskType })
              }
            >
              {TASK_TYPES.map((tt) => (
                <option key={tt.value} value={tt.value}>
                  {tt.label}
                </option>
              ))}
            </select>
          </FormField>
          <FormField label="Assign Executive" required>
            <select
              className={selectClass}
              value={form.employeeCode}
              onChange={(e) =>
                setForm({ ...form, employeeCode: e.target.value, routeNos: [] })
              }
              required
              disabled={executivesLoading}
            >
              <option value="">
                {executivesLoading ? 'Loading executives...' : 'Select executive'}
              </option>
              {activeExecutives.map((ex) => (
                <option key={ex.employeecode} value={ex.employeecode}>
                  {ex.username}
                  {ex.employeecode ? ` (${ex.employeecode})` : ''}
                </option>
              ))}
            </select>
          </FormField>
          <FormField label="Assigned Routes" required>
            <AssignedRoutesMultiSelect
              employeeCode={selectedEmployeeCode}
              routesLoading={routesLoading}
              assignedRoutes={assignedRoutes}
              value={form.routeNos}
              onChange={(routeNos) => setForm({ ...form, routeNos })}
            />
          </FormField>
          <FormField label="Due Date" required>
            <input
              type="date"
              className={inputClass}
              value={form.dueDate}
              onChange={(e) => setForm({ ...form, dueDate: e.target.value })}
              required
            />
          </FormField>

          <FormField label="Notes">
            <textarea
              className={inputClass + ' resize-none h-20'}
              value={form.notes}
              onChange={(e) => setForm({ ...form, notes: e.target.value })}
            />
          </FormField>

          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" variant="secondary" onClick={() => setModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Creating...' : 'Create Task'}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
