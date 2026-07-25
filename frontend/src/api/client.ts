const API_BASE = import.meta.env.VITE_API_URL ?? ''

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

  const response = await fetch(url.toString())

  if (!response.ok) {
    const body = (await response.json().catch(() => null)) as { error?: string } | null
    throw new Error(body?.error ?? `Request failed (${response.status})`)
  }

  return response.json() as Promise<T>
}

export async function apiPost<T>(path: string, body: unknown): Promise<T> {
  const url = new URL(`${API_BASE}${path}`, window.location.origin)

  const response = await fetch(url.toString(), {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })

  if (!response.ok) {
    const responseBody = (await response.json().catch(() => null)) as { error?: string } | null
    throw new Error(responseBody?.error ?? `Request failed (${response.status})`)
  }

  return response.json() as Promise<T>
}

export async function apiPatch<T>(path: string, body: unknown): Promise<T> {
  const url = new URL(`${API_BASE}${path}`, window.location.origin)

  const response = await fetch(url.toString(), {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })

  if (!response.ok) {
    const responseBody = (await response.json().catch(() => null)) as { error?: string } | null
    throw new Error(responseBody?.error ?? `Request failed (${response.status})`)
  }

  return response.json() as Promise<T>
}

export async function apiDelete<T>(path: string, body?: unknown): Promise<T> {
  const url = new URL(`${API_BASE}${path}`, window.location.origin)

  const response = await fetch(url.toString(), {
    method: 'DELETE',
    headers: body !== undefined ? { 'Content-Type': 'application/json' } : undefined,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  })

  if (!response.ok) {
    const responseBody = (await response.json().catch(() => null)) as { error?: string } | null
    throw new Error(responseBody?.error ?? `Request failed (${response.status})`)
  }

  return response.json() as Promise<T>
}
