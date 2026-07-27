const API_BASE = import.meta.env.VITE_API_URL ?? ''

const TOKEN_KEY = 'crgs-admin-token'
const SESSION_KEY = 'crgs-admin-session'

export function getAccessToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setAccessToken(token: string | null) {
  if (token) localStorage.setItem(TOKEN_KEY, token)
  else localStorage.removeItem(TOKEN_KEY)
}

export function clearAuthStorage() {
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(SESSION_KEY)
}

function authHeaders(json = true): HeadersInit {
  const headers: Record<string, string> = {}
  if (json) headers['Content-Type'] = 'application/json'
  const token = getAccessToken()
  if (token) headers.Authorization = `Bearer ${token}`
  return headers
}

async function parseError(response: Response): Promise<string> {
  const body = (await response.json().catch(() => null)) as { error?: string } | null
  if (response.status === 401) {
    clearAuthStorage()
  }
  return body?.error ?? `Request failed (${response.status})`
}

export async function apiGet<T>(
  path: string,
  params?: Record<string, string | number | undefined>
): Promise<T> {
  const url = new URL(`${API_BASE}${path}`, window.location.origin)

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== '') {
        url.searchParams.set(key, String(value))
      }
    }
  }

  const response = await fetch(url.toString(), {
    headers: authHeaders(false),
  })

  if (!response.ok) {
    throw new Error(await parseError(response))
  }

  return response.json() as Promise<T>
}

export async function apiPost<T>(path: string, body: unknown): Promise<T> {
  const url = new URL(`${API_BASE}${path}`, window.location.origin)

  const response = await fetch(url.toString(), {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify(body),
  })

  if (!response.ok) {
    throw new Error(await parseError(response))
  }

  return response.json() as Promise<T>
}

export async function apiPatch<T>(path: string, body: unknown): Promise<T> {
  const url = new URL(`${API_BASE}${path}`, window.location.origin)

  const response = await fetch(url.toString(), {
    method: 'PATCH',
    headers: authHeaders(),
    body: JSON.stringify(body),
  })

  if (!response.ok) {
    throw new Error(await parseError(response))
  }

  return response.json() as Promise<T>
}

export async function apiDelete<T>(path: string, body?: unknown): Promise<T> {
  const url = new URL(`${API_BASE}${path}`, window.location.origin)

  const response = await fetch(url.toString(), {
    method: 'DELETE',
    headers: body !== undefined ? authHeaders() : authHeaders(false),
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })

  if (!response.ok) {
    throw new Error(await parseError(response))
  }

  return response.json() as Promise<T>
}
