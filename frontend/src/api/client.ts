const API_BASE = import.meta.env.VITE_API_URL ?? ''

const TOKEN_KEY = 'crgs-admin-token'
const SESSION_KEY = 'crgs-admin-session'

/** Abort slow requests so hung tunnel/API calls don't freeze the UI. */
const DEFAULT_TIMEOUT_MS = 30_000

type AuthExpiredListener = () => void
const authExpiredListeners = new Set<AuthExpiredListener>()

/** Paths that may return 401 without ending an existing session. */
function isPublicAuthPath(path: string): boolean {
  return path === '/api/auth/login' || path.startsWith('/api/auth/login?')
}

/**
 * Prefer sessionStorage so the JWT is not persisted across browser restarts.
 * Migrates any legacy localStorage token once, then clears it.
 */
export function getAccessToken(): string | null {
  const sessionToken = sessionStorage.getItem(TOKEN_KEY)
  if (sessionToken) return sessionToken
  const legacy = localStorage.getItem(TOKEN_KEY)
  if (legacy) {
    sessionStorage.setItem(TOKEN_KEY, legacy)
    localStorage.removeItem(TOKEN_KEY)
    return legacy
  }
  return null
}

export function setAccessToken(token: string | null) {
  localStorage.removeItem(TOKEN_KEY)
  if (token) sessionStorage.setItem(TOKEN_KEY, token)
  else sessionStorage.removeItem(TOKEN_KEY)
}

export function clearAuthStorage() {
  sessionStorage.removeItem(TOKEN_KEY)
  sessionStorage.removeItem(SESSION_KEY)
  localStorage.removeItem(TOKEN_KEY)
  localStorage.removeItem(SESSION_KEY)
}

/** Subscribe to forced logout (expired/invalid token). Returns unsubscribe. */
export function onAuthExpired(listener: AuthExpiredListener): () => void {
  authExpiredListeners.add(listener)
  return () => {
    authExpiredListeners.delete(listener)
  }
}

function notifyAuthExpired() {
  for (const listener of [...authExpiredListeners]) {
    try {
      listener()
    } catch {
      // Listener errors must not break request handling.
    }
  }
}

/** Clear storage and notify UI to log out immediately. */
export function handleUnauthorizedSession() {
  clearAuthStorage()
  notifyAuthExpired()
}

function authHeaders(json = true): HeadersInit {
  const headers: Record<string, string> = {}
  if (json) headers['Content-Type'] = 'application/json'
  const token = getAccessToken()
  if (token) headers.Authorization = `Bearer ${token}`
  return headers
}

function buildUrl(
  path: string,
  params?: Record<string, string | number | undefined>
): string {
  const url = new URL(`${API_BASE}${path}`, window.location.origin)
  if (params) {
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== '') {
        url.searchParams.set(key, String(value))
      }
    }
  }
  return url.toString()
}

async function parseError(response: Response, path: string): Promise<string> {
  const body = (await response.json().catch(() => null)) as { error?: string } | null
  if (response.status === 401 && !isPublicAuthPath(path)) {
    handleUnauthorizedSession()
  }
  return body?.error ?? `Request failed (${response.status})`
}

async function request<T>(
  path: string,
  init: RequestInit,
  params?: Record<string, string | number | undefined>
): Promise<T> {
  const controller = new AbortController()
  const timer = window.setTimeout(() => controller.abort(), DEFAULT_TIMEOUT_MS)

  try {
    const response = await fetch(buildUrl(path, params), {
      ...init,
      signal: controller.signal,
    })

    if (!response.ok) {
      throw new Error(await parseError(response, path))
    }

    return response.json() as Promise<T>
  } catch (error) {
    if (error instanceof DOMException && error.name === 'AbortError') {
      throw new Error('Request timed out. Check API / network and try again.')
    }
    throw error
  } finally {
    window.clearTimeout(timer)
  }
}

export async function apiGet<T>(
  path: string,
  params?: Record<string, string | number | undefined>
): Promise<T> {
  return request<T>(path, { headers: authHeaders(false) }, params)
}

export async function apiPost<T>(path: string, body: unknown): Promise<T> {
  return request<T>(path, {
    method: 'POST',
    headers: authHeaders(),
    body: JSON.stringify(body),
  })
}

export async function apiPatch<T>(path: string, body: unknown): Promise<T> {
  return request<T>(path, {
    method: 'PATCH',
    headers: authHeaders(),
    body: JSON.stringify(body),
  })
}

export async function apiDelete<T>(path: string, body?: unknown): Promise<T> {
  return request<T>(path, {
    method: 'DELETE',
    headers: body !== undefined ? authHeaders() : authHeaders(false),
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })
}
