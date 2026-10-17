import { useCallback, useEffect, useState } from 'react'

export interface Coordinate {
  latitude: number
  longitude: number
}

export type LocationStatus =
  | { kind: 'needsPermission' }
  | { kind: 'denied'; message: string }
  | { kind: 'unsupported' }
  | { kind: 'locating' }
  | { kind: 'ready'; coordinate: Coordinate }

const STORAGE_KEY = 'ananeo.location'

function remembered(): Coordinate | undefined {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return undefined
    const parsed = JSON.parse(raw) as Partial<Coordinate>
    if (typeof parsed.latitude === 'number' && typeof parsed.longitude === 'number') return parsed as Coordinate
  } catch {
    // Storage is unavailable or blocked. Ask again.
  }
  return undefined
}

function remember(coordinate: Coordinate) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(coordinate))
  } catch {
    // Not important enough to surface.
  }
}

/**
 * One-shot approximate location from the browser, like the iOS app's when-in-use request.
 * The last good fix is remembered on this device so the feed can show right away next visit.
 */
export function useLocation(): LocationStatus & { request: () => void } {
  const [status, setStatus] = useState<LocationStatus>(() => {
    if (typeof navigator === 'undefined' || !('geolocation' in navigator)) return { kind: 'unsupported' }
    const last = remembered()
    return last ? { kind: 'ready', coordinate: last } : { kind: 'needsPermission' }
  })

  const request = useCallback(() => {
    if (!('geolocation' in navigator)) {
      setStatus({ kind: 'unsupported' })
      return
    }
    setStatus((s) => (s.kind === 'ready' ? s : { kind: 'locating' }))
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const coordinate = { latitude: position.coords.latitude, longitude: position.coords.longitude }
        remember(coordinate)
        setStatus({ kind: 'ready', coordinate })
      },
      (error) => {
        setStatus((s) => {
          // Keep an old fix rather than blanking the feed on a transient failure.
          if (s.kind === 'ready' && error.code !== error.PERMISSION_DENIED) return s
          return error.code === error.PERMISSION_DENIED
            ? { kind: 'denied', message: 'Location is blocked for this site. Allow it in your browser settings to browse nearby.' }
            : { kind: 'denied', message: error.message || "Couldn't find your location." }
        })
      },
      { maximumAge: 5 * 60 * 1000, timeout: 15000, enableHighAccuracy: false },
    )
  }, [])

  // Refresh a remembered location silently, without prompting someone who never granted access.
  useEffect(() => {
    if (status.kind === 'ready' && 'permissions' in navigator) {
      navigator.permissions
        .query({ name: 'geolocation' })
        .then((p) => {
          if (p.state === 'granted') request()
        })
        .catch(() => {})
    }
    // Only on mount.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return { ...status, request }
}
