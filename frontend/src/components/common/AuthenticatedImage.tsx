import { useEffect, useState } from 'react'
import { getAccessToken } from '../../api/client'

type Props = {
  src: string
  alt: string
  className?: string
}

/** Load API images that require Bearer auth (img src cannot send Authorization). */
export function AuthenticatedImage({ src, alt, className }: Props) {
  const [objectUrl, setObjectUrl] = useState<string | null>(null)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    let cancelled = false
    let createdUrl: string | null = null

    async function load() {
      setFailed(false)
      setObjectUrl(null)
      try {
        const token = getAccessToken()
        const response = await fetch(src, {
          headers: token ? { Authorization: `Bearer ${token}` } : {},
        })
        if (!response.ok) throw new Error('Image fetch failed')
        const blob = await response.blob()
        if (cancelled) return
        createdUrl = URL.createObjectURL(blob)
        setObjectUrl(createdUrl)
      } catch {
        if (!cancelled) setFailed(true)
      }
    }

    void load()
    return () => {
      cancelled = true
      if (createdUrl) URL.revokeObjectURL(createdUrl)
    }
  }, [src])

  if (failed) {
    return (
      <div className={className}>
        <span className="text-xs text-gray-400">Image unavailable</span>
      </div>
    )
  }

  if (!objectUrl) {
    return <div className={className} aria-busy="true" />
  }

  return <img src={objectUrl} alt={alt} className={className} />
}
