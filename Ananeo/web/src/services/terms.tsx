import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { errorMessage, supabase } from '../lib/supabase'
import { TERMS_VERSION } from '../lib/terms'
import { useAuth } from './auth'

export type TermsStatus = { kind: 'checking' } | { kind: 'needed' } | { kind: 'accepted' } | { kind: 'failed'; message: string }

interface TermsContextValue {
  status: TermsStatus
  accept: () => Promise<void>
  /** Starts over, for a retry. */
  reset: () => void
}

const TermsContext = createContext<TermsContextValue | null>(null)

const key = (userID: string) => `ananeo.acceptedTermsVersion.${userID}`

function remembered(userID: string): number {
  try {
    return Number(localStorage.getItem(key(userID)) ?? 0) || 0
  } catch {
    return 0
  }
}

function remember(userID: string, version: number) {
  try {
    localStorage.setItem(key(userID), String(version))
  } catch {
    // Storage blocked. The server still has the answer next time.
  }
}

/**
 * Whether the signed-in person has accepted the current terms of use. Acceptance is recorded on
 * the server and remembered in this browser, so later visits don't wait on the network.
 */
export function TermsProvider({ children }: { children: ReactNode }) {
  const { userID } = useAuth()
  const [status, setStatus] = useState<TermsStatus>({ kind: 'checking' })
  const [attempt, setAttempt] = useState(0)

  useEffect(() => {
    setStatus({ kind: 'checking' })
    if (!userID) return
    if (remembered(userID) >= TERMS_VERSION) {
      setStatus({ kind: 'accepted' })
      return
    }
    let cancelled = false
    supabase
      .rpc('my_terms_version')
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) {
          setStatus({ kind: 'failed', message: errorMessage(error) })
          return
        }
        const version = Number(data ?? 0)
        remember(userID, version)
        setStatus(version >= TERMS_VERSION ? { kind: 'accepted' } : { kind: 'needed' })
      })
    return () => {
      cancelled = true
    }
  }, [userID, attempt])

  const accept = useCallback(async () => {
    if (!userID) return
    const { error } = await supabase.rpc('accept_terms', { p_version: TERMS_VERSION })
    if (error) throw new Error(errorMessage(error))
    remember(userID, TERMS_VERSION)
    setStatus({ kind: 'accepted' })
  }, [userID])

  const reset = useCallback(() => setAttempt((n) => n + 1), [])

  const value = useMemo(() => ({ status, accept, reset }), [status, accept, reset])
  return <TermsContext.Provider value={value}>{children}</TermsContext.Provider>
}

export function useTerms(): TermsContextValue {
  const value = useContext(TermsContext)
  if (!value) throw new Error('useTerms needs a TermsProvider')
  return value
}
