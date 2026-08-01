import { apiDelete, apiGet, apiPatch, apiPost } from './client'
import type { TaskType } from '../types'
import { fetchAllPages } from './paginate'

export interface DbTask {
  type: TaskType | string
  employeeCode: string
  routeNo: string
  status: string
  dueDate: string
}

export interface TasksResponse {
  count: number
  offset?: number
  limit?: number
  has_more?: boolean
  tasks: DbTask[]
}

export interface CreateTaskPayload {
  type: TaskType | string
  /** Custom label when Task Type is Other; stored in CRGS_TASK.TYPE */
  otherType?: string
  employeeCode: string
  routeNo: string
  dueDate: string
}

export interface CreateTaskResponse {
  type: TaskType | string
  employeeCode: string
  routeNo: string
  dueDate: string
}

export interface DeleteTaskPayload {
  type: TaskType | string
  employeeCode: string
  routeNo: string
  dueDate: string
}

export interface FetchTasksParams {
  employeeCode?: string
  type?: TaskType | string
  limit?: number
  offset?: number
}

export function fetchTasks(params: FetchTasksParams = {}) {
  return apiGet<TasksResponse>('/api/tasks', {
    employeeCode: params.employeeCode,
    type: params.type,
    limit: params.limit ?? 100,
    offset: params.offset ?? 0,
  })
}

export async function fetchAllTasks(
  params: Omit<FetchTasksParams, 'limit' | 'offset'> = {}
) {
  const tasks = await fetchAllPages<DbTask>({
    pageSize: 500,
    itemsKey: 'tasks',
    fetchPage: ({ limit, offset }) =>
      fetchTasks({ ...params, limit, offset }) as Promise<Record<string, unknown>>,
  })
  return { count: tasks.length, tasks }
}

export function createTask(payload: CreateTaskPayload) {
  return apiPost<CreateTaskResponse>('/api/tasks', payload)
}

export function deleteTask(payload: DeleteTaskPayload) {
  return apiDelete<{ deleted: number }>('/api/tasks', payload)
}

export interface UpdateTaskStatusPayload {
  type: TaskType | string
  employeeCode: string
  routeNo: string
  dueDate: string
  status: string
}

export interface UpdateTaskStatusResponse {
  type: TaskType | string
  employeeCode: string
  routeNo: string
  dueDate: string
  status: string
  updated: number
}

export function updateTaskStatus(payload: UpdateTaskStatusPayload) {
  return apiPatch<UpdateTaskStatusResponse>('/api/tasks/status', payload)
}
