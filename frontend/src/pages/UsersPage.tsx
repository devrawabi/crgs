import { useState, useMemo, useEffect, useCallback } from 'react'
import { Loader2, Plus, UserCheck, UserX, Pencil, Route } from 'lucide-react'
import { PageHeader, FormField, inputClass } from '../components/ui/PageHeader'
import { Button } from '../components/ui/Button'
import { Badge } from '../components/ui/Badge'
import { Modal } from '../components/ui/Modal'
import { Card } from '../components/ui/Card'
import { Table } from '../components/ui/Table'
import { useApp } from '../context/AppContext'
import { useAuth } from '../context/AuthContext'
import { assignUserRoutes, createUser, fetchAllUsers, isRouteNoSelected, parseRouteColumn, toggleRouteNo, updateUserStatus, type DbLoginUser } from '../api/users'
import { fetchDesignations, type DbDesignation } from '../api/designations'
import { fetchAllRoutes, type DbRoute } from '../api/routes'
import { STATUS_COLORS } from '../data/mockData'
import { canAssignRoleCode } from '../lib/roleAccess'
import type { User } from '../types'

const emptyForm = { username: '', employeeCode: '', password: '', roleCode: '' }

export function UsersPage() {
  const { user: authUser } = useAuth()
  const {
    updateUser,
    assignRoutesByEmployeeCode,
    syncExecutivesFromDb,
    getUserByEmployeeCode,
  } = useApp()
  const [executives, setExecutives] = useState<DbLoginUser[]>([])
  const [dbRoutes, setDbRoutes] = useState<DbRoute[]>([])
  const [designations, setDesignations] = useState<DbDesignation[]>([])
  const [listLoading, setListLoading] = useState(true)
  const [routesLoading, setRoutesLoading] = useState(true)
  const [designationsLoading, setDesignationsLoading] = useState(true)
  const [listError, setListError] = useState<string | null>(null)
  const [routesError, setRoutesError] = useState<string | null>(null)
  const [designationsError, setDesignationsError] = useState<string | null>(null)
  const [modalOpen, setModalOpen] = useState(false)
  const [assignModalOpen, setAssignModalOpen] = useState(false)
  const [editUser, setEditUser] = useState<User | null>(null)
  const [assignExecutive, setAssignExecutive] = useState<User | null>(null)
  const [form, setForm] = useState(emptyForm)
  const [selectedRouteNos, setSelectedRouteNos] = useState<string[]>([])
  const [routeSearch, setRouteSearch] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [assignSubmitting, setAssignSubmitting] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)
  const [assignError, setAssignError] = useState<string | null>(null)
  const [statusUpdating, setStatusUpdating] = useState<string | null>(null)

  const loadExecutives = useCallback(async () => {
    setListLoading(true)
    setListError(null)

    try {
      const data = await fetchAllUsers()
      setExecutives(data.users)
      syncExecutivesFromDb(data.users)
    } catch (err) {
      setExecutives([])
      setListError(err instanceof Error ? err.message : 'Failed to load executives')
    } finally {
      setListLoading(false)
    }
  }, [syncExecutivesFromDb])

  const loadRoutes = useCallback(async () => {
    setRoutesLoading(true)
    setRoutesError(null)

    try {
      const data = await fetchAllRoutes()
      setDbRoutes(data.routes)
    } catch (err) {
      setDbRoutes([])
      setRoutesError(err instanceof Error ? err.message : 'Failed to load routes')
    } finally {
      setRoutesLoading(false)
    }
  }, [])

  const loadDesignations = useCallback(async () => {
    setDesignationsLoading(true)
    setDesignationsError(null)

    try {
      const data = await fetchDesignations()
      setDesignations(data.designations)
    } catch (err) {
      setDesignations([])
      setDesignationsError(err instanceof Error ? err.message : 'Failed to load designations')
    } finally {
      setDesignationsLoading(false)
    }
  }, [])

  useEffect(() => {
    loadExecutives()
    loadRoutes()
    loadDesignations()
  }, [loadExecutives, loadRoutes, loadDesignations])

  const openCreate = () => {
    setEditUser(null)
    setForm(emptyForm)
    setFormError(null)
    setModalOpen(true)
  }

  const openEdit = (employeeCode: string) => {
    const user = getUserByEmployeeCode(employeeCode)
    const dbUser = executives.find((e) => e.employeecode === employeeCode)
    if (!user) return
    setEditUser(user)
    setForm({
      username: user.username,
      employeeCode: user.employeeCode,
      password: '',
      roleCode: dbUser ? String(dbUser.rolecode) : '',
    })
    setFormError(null)
    setModalOpen(true)
  }

  const openAssignRoutes = (employeeCode: string) => {
    const dbUser = executives.find((e) => e.employeecode === employeeCode)
    const contextUser = getUserByEmployeeCode(employeeCode)
    if (!dbUser) return

    const routeNos = parseRouteColumn(dbUser.route)
    setAssignExecutive(
      contextUser ?? {
        id: dbUser.employeecode,
        username: dbUser.username,
        employeeCode: dbUser.employeecode,
        password: '',
        role: 'sales_executive',
        status: dbUser.flag?.toUpperCase() === 'A' ? 'active' : 'inactive',
        routeIds: [],
        assignedRouteNos: routeNos,
        createdAt: '',
      }
    )
    setSelectedRouteNos([...routeNos])
    setRouteSearch('')
    setAssignError(null)
    setAssignModalOpen(true)
  }

  const filteredRoutes = useMemo(() => {
    const q = routeSearch.trim().toLowerCase()
    if (!q) return dbRoutes
    return dbRoutes.filter(
      (r) =>
        r.routename.toLowerCase().includes(q) ||
        String(r.routeno).toLowerCase().includes(q)
    )
  }, [dbRoutes, routeSearch])

  const assignableDesignations = useMemo(
    () =>
      designations.filter((item) =>
        canAssignRoleCode(authUser?.roleCode, item.rolecode)
      ),
    [designations, authUser?.roleCode]
  )

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setFormError(null)

    if (editUser) {
      updateUser(editUser.id, {
        username: form.username,
        employeeCode: form.employeeCode,
        ...(form.password ? { password: form.password } : {}),
        role: 'sales_executive',
      })
      setModalOpen(false)
      return
    }

    if (!form.roleCode) {
      setFormError('Designation is required')
      return
    }
    if (!canAssignRoleCode(authUser?.roleCode, form.roleCode)) {
      setFormError('Only role code 1 can create users with role code 1 or 9')
      return
    }

    setSubmitting(true)
    try {
      await createUser({
        username: form.username.trim(),
        employeeCode: form.employeeCode.trim(),
        password: form.password,
        roleCode: form.roleCode,
      })

      await loadExecutives()
      setModalOpen(false)
    } catch (err) {
      setFormError(err instanceof Error ? err.message : 'Failed to create account')
    } finally {
      setSubmitting(false)
    }
  }

  const handleAssignRoutes = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!assignExecutive) return

    setAssignSubmitting(true)
    setAssignError(null)

    try {
      await assignUserRoutes({
        employeeCode: assignExecutive.employeeCode,
        routeNos: selectedRouteNos,
      })
      assignRoutesByEmployeeCode(assignExecutive.employeeCode, selectedRouteNos)
      setExecutives((prev) =>
        prev.map((exec) =>
          exec.employeecode === assignExecutive.employeeCode
            ? { ...exec, route: selectedRouteNos.join(',') || null }
            : exec
        )
      )
      setAssignModalOpen(false)
      setAssignExecutive(null)
    } catch (err) {
      setAssignError(err instanceof Error ? err.message : 'Failed to save route assignments')
    } finally {
      setAssignSubmitting(false)
    }
  }

  const handleToggleStatus = async (executive: DbLoginUser) => {
    const isActive = executive.flag?.toUpperCase() === 'A'
    const newFlag = isActive ? 'D' : 'A'

    setStatusUpdating(executive.employeecode)
    setListError(null)

    try {
      await updateUserStatus({
        employeeCode: executive.employeecode,
        flag: newFlag,
      })

      const updatedExecutives = executives.map((exec) =>
        exec.employeecode === executive.employeecode ? { ...exec, flag: newFlag } : exec
      )
      setExecutives(updatedExecutives)
      syncExecutivesFromDb(updatedExecutives)
    } catch (err) {
      setListError(err instanceof Error ? err.message : 'Failed to update user status')
    } finally {
      setStatusUpdating(null)
    }
  }

  const toggleRoute = (routeno: string) => {
    setSelectedRouteNos((nos) => toggleRouteNo(nos, routeno))
  }

  const selectAllVisible = () => {
    const visibleNos = filteredRoutes.map((r) => r.routeno)
    const allSelected = visibleNos.every((no) => isRouteNoSelected(selectedRouteNos, no))
    if (allSelected) {
      setSelectedRouteNos((nos) =>
        nos.filter((no) => !visibleNos.some((visibleNo) => isRouteNoSelected([no], visibleNo)))
      )
    } else {
      setSelectedRouteNos((nos) => {
        const next = [...nos]
        for (const visibleNo of visibleNos) {
          if (!isRouteNoSelected(next, visibleNo)) {
            next.push(String(visibleNo))
          }
        }
        return next.map((no) => String(no))
      })
    }
  }

  return (
    <div className="flex-1 overflow-auto min-h-0">
      <PageHeader
        title="User Management"
        description="Create and manage Sales Executive accounts and assign routes"
        action={
          <Button onClick={openCreate}>
            <Plus size={16} />
            Create Executive
          </Button>
        }
      />

      <Card>
        {listError && (
          <div className="mb-4 rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
            {listError}
          </div>
        )}

        {listLoading ? (
          <div className="flex items-center justify-center gap-2 py-12 text-sm text-gray-500">
            <Loader2 size={18} className="animate-spin" />
            Loading executives...
          </div>
        ) : executives.length === 0 ? (
          <p className="text-center text-sm text-gray-400 py-8">No executives found</p>
        ) : (
        <Table
          columns={[
            { key: 'username', label: 'Username' },
            { key: 'employeeCode', label: 'Employee Code' },
            { key: 'designation', label: 'Designation' },
            { key: 'routes', label: 'Assigned Routes' },
            { key: 'status', label: 'Status' },
            { key: 'actions', label: 'Actions' },
          ]}
        >
          {executives.map((executive) => {
            const contextUser = getUserByEmployeeCode(executive.employeecode)
            const assignedRouteNos = parseRouteColumn(executive.route)
            const status = executive.flag?.toUpperCase() === 'A' ? 'active' : 'inactive'

            return (
            <tr key={executive.employeecode} className="hover:bg-gray-50">
              <td className="px-4 py-3 font-medium text-gray-900">{executive.username}</td>
              <td className="px-4 py-3 text-gray-600">{executive.employeecode}</td>
              <td className="px-4 py-3 text-gray-600">
                {executive.designation || '—'}
              </td>
              <td className="px-4 py-3">
                <div className="flex flex-wrap gap-1">
                  {assignedRouteNos.length === 0 ? (
                    <span className="text-gray-400 text-xs">No routes</span>
                  ) : (
                    <Badge
                      label={`${assignedRouteNos.length} route${assignedRouteNos.length === 1 ? '' : 's'}`}
                      className="bg-primary-50 text-primary-700"
                    />
                  )}
                </div>
              </td>
              <td className="px-4 py-3">
                <Badge label={status} className={STATUS_COLORS[status]} />
              </td>
              <td className="px-4 py-3">
                <div className="flex items-center gap-2">
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => openAssignRoutes(executive.employeecode)}
                    title="Assign routes"
                    disabled={status === 'inactive'}
                  >
                    <Route size={14} className="text-primary-600" />
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => handleToggleStatus(executive)}
                    title={status === 'active' ? 'Deactivate' : 'Activate'}
                    disabled={statusUpdating === executive.employeecode}
                  >
                    {status === 'active' ? (
                      <UserX size={14} className="text-red-500" />
                    ) : (
                      <UserCheck size={14} className="text-green-500" />
                    )}
                  </Button>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => openEdit(executive.employeecode)}
                    disabled={!contextUser}
                  >
                    <Pencil size={14} />
                  </Button>
                </div>
              </td>
            </tr>
            )
          })}
        </Table>
        )}
      </Card>

      <Modal
        open={modalOpen}
        onClose={() => setModalOpen(false)}
        title={editUser ? 'Edit Sales Executive' : 'Create Sales Executive'}
      >
        <form onSubmit={handleSubmit} className="space-y-4">
          {formError && (
            <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {formError}
            </div>
          )}
          <FormField label="Username" required>
            <input
              className={inputClass}
              value={form.username}
              onChange={(e) => setForm({ ...form, username: e.target.value })}
              autoComplete="username"
              required
            />
          </FormField>
          <FormField label="Employee Code" required>
            <input
              className={inputClass}
              value={form.employeeCode}
              onChange={(e) => setForm({ ...form, employeeCode: e.target.value })}
              required
            />
          </FormField>
          <FormField label="Password" required={!editUser}>
            <input
              type="password"
              className={inputClass}
              value={form.password}
              onChange={(e) => setForm({ ...form, password: e.target.value })}
              autoComplete="new-password"
              placeholder={editUser ? 'Leave blank to keep current password' : undefined}
              required={!editUser}
            />
          </FormField>
          {!editUser && (
            <FormField label="Designation" required>
              <select
                className={inputClass}
                value={form.roleCode}
                onChange={(e) => setForm({ ...form, roleCode: e.target.value })}
                required
                disabled={designationsLoading || Boolean(designationsError)}
              >
                <option value="">
                  {designationsLoading
                    ? 'Loading designations...'
                    : designationsError
                      ? 'Failed to load designations'
                      : 'Select designation'}
                </option>
                {assignableDesignations.map((item) => (
                  <option key={item.rolecode} value={item.rolecode}>
                    {item.designation}
                  </option>
                ))}
              </select>
              {designationsError && (
                <p className="mt-1 text-xs text-red-600">{designationsError}</p>
              )}
              {!designationsError &&
                authUser?.roleCode !== '1' &&
                designations.length > assignableDesignations.length && (
                  <p className="mt-1 text-xs text-gray-500">
                    Role codes 1 and 9 can only be assigned by role code 1.
                  </p>
                )}
            </FormField>
          )}
          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" variant="secondary" onClick={() => setModalOpen(false)} disabled={submitting}>
              Cancel
            </Button>
            <Button
              type="submit"
              disabled={
                submitting ||
                (!editUser &&
                  (designationsLoading ||
                    Boolean(designationsError) ||
                    assignableDesignations.length === 0))
              }
            >
              {submitting ? (
                <>
                  <Loader2 size={16} className="animate-spin" />
                  Creating...
                </>
              ) : editUser ? (
                'Save Changes'
              ) : (
                'Create Account'
              )}
            </Button>
          </div>
        </form>
      </Modal>

      <Modal
        open={assignModalOpen}
        onClose={() => setAssignModalOpen(false)}
        title={`Assign Routes — ${assignExecutive?.username ?? ''}`}
        wide
      >
        <form onSubmit={handleAssignRoutes} className="space-y-4">
          {(routesError || assignError) && (
            <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
              {assignError ?? routesError}
            </div>
          )}

          <div className="flex items-center gap-3">
            <input
              className={inputClass}
              placeholder="Search routes by name or code..."
              value={routeSearch}
              onChange={(e) => setRouteSearch(e.target.value)}
              disabled={routesLoading}
            />
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={selectAllVisible}
              disabled={routesLoading || filteredRoutes.length === 0}
            >
              {filteredRoutes.every((r) => isRouteNoSelected(selectedRouteNos, r.routeno))
                ? 'Deselect All'
                : 'Select All'}
            </Button>
          </div>

          <p className="text-sm text-gray-500">
            {selectedRouteNos.length} route{selectedRouteNos.length !== 1 ? 's' : ''} selected
          </p>

          <div className="max-h-72 overflow-y-auto border border-gray-200 rounded-lg p-2">
            {routesLoading ? (
              <div className="flex items-center justify-center gap-2 py-8 text-sm text-gray-500">
                <Loader2 size={18} className="animate-spin" />
                Loading routes...
              </div>
            ) : filteredRoutes.length === 0 ? (
              <p className="text-sm text-gray-400 text-center py-8">No routes match your search</p>
            ) : (
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                {filteredRoutes.map((route) => {
                  const checked = isRouteNoSelected(selectedRouteNos, route.routeno)
                  return (
                    <label
                      key={route.routeno}
                      className={`flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-colors ${
                        checked
                          ? 'border-primary-500 bg-primary-50'
                          : 'border-gray-200 hover:border-gray-300 hover:bg-gray-50'
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={checked}
                        onChange={() => toggleRoute(route.routeno)}
                        className="rounded text-primary-600 shrink-0"
                      />
                      <div className="flex-1 min-w-0">
                        <p className="text-sm font-medium text-gray-900 truncate">
                          {route.routename}
                        </p>
                        <p className="text-xs text-gray-500">{route.routeno}</p>
                      </div>
                    </label>
                  )
                })}
              </div>
            )}
          </div>

          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" variant="secondary" onClick={() => setAssignModalOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={routesLoading || assignSubmitting}>
              {assignSubmitting ? (
                <>
                  <Loader2 size={16} className="animate-spin" />
                  Saving...
                </>
              ) : (
                'Save Assignments'
              )}
            </Button>
          </div>
        </form>
      </Modal>
    </div>
  )
}
