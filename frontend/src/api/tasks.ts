import { apiDelete, apiGet, apiPatch, apiPost } from './client'
import type { TaskType } from '../types'

export interface DbTask {
  type: TaskType
  employeeCode: string
  routeNo: string
  status: string
  dueDate: string
}

export interface TasksResponse {
  count: number
  tasks: DbTask[]
}

export interface CreateTaskPayload {
  type: TaskType
  employeeCode: string
  routeNo: string
  dueDate: string
}

export interface CreateTaskResponse {
  type: TaskType
  employeeCode: string
  routeNo: string
  dueDate: string
}

export interface DeleteTaskPayload {
  type: TaskType
  employeeCode: string
  routeNo: string
  dueDate: string
}

export function fetchTasks(params?: { employeeCode?: string }) {
  return apiGet<TasksResponse>('/api/tasks', params)
}

export function createTask(payload: CreateTaskPayload) {
  return apiPost<CreateTaskResponse>('/api/tasks', payload)
}

export function deleteTask(payload: DeleteTaskPayload) {
  return apiDelete<{ deleted: number }>('/api/tasks', payload)
}

export interface UpdateTaskStatusPayload {
  type: TaskType
  employeeCode: string
  routeNo: string
  dueDate: string
  status: string
}

export interface UpdateTaskStatusResponse {
  type: TaskType
  employeeCode: string
  routeNo: string
  dueDate: string
  status: string
  updated: number
}

export function updateTaskStatus(payload: UpdateTaskStatusPayload) {
  return apiPatch<UpdateTaskStatusResponse>('/api/tasks/status', payload)
}
