import type { Session } from '@supabase/supabase-js'
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { errorMessage, isLocalBackend, supabase } from '../lib/supabase'

export type AuthState = { kind: 'loading' } | { kind: 'signedOut' } | { kind: 'signedIn'; userID: string }

interface AuthContextValue {
  state: AuthState
  userID: string | undefined
  /** Emails a sign-in link, and a code when the project's email template includes one. */
  sendCode: (email: string) => Promise<void>
  verifyCode: (email: string, code: string) => Promise<void>
  signInWith: (provider: 'apple' | 'google') => Promise<void>
  /** Local stack only: password sign-in for throwaway test accounts. Not in production builds. */
  devSignIn: (email: string, password: string, name: string) => Promise<void>
  signOut: () => Promise<void>
  /** Permanently deletes the account and everything it owns, then signs out. */
  deleteAccount: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

function stateFrom(session: Session | null): AuthState {
  return session ? { kind: 'signedIn', userID: session.user.id } : { kind: 'signedOut' }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ kind: 'loading' })

  useEffect(() => {
    // The stored session, if any, arrives first. Magic links land here too, via the URL hash.
    const { data } = supabase.auth.onAuthStateChange((_event, session) => setState(stateFrom(session)))
    supabase.auth.getSession().then(({ data: { session } }) => setState(stateFrom(session)))
    return () => data.subscription.unsubscribe()
  }, [])

  const redirectTo = () => `${window.location.origin}/app/browse`

  const sendCode = useCallback(async (email: string) => {
    const { error } = await supabase.auth.signInWithOtp({
      email,
      options: { emailRedirectTo: redirectTo(), shouldCreateUser: true },
    })
    if (error) throw new Error(error.message)
  }, [])

  const verifyCode = useCallback(async (email: string, code: string) => {
    const { error } = await supabase.auth.verifyOtp({ email, token: code, type: 'email' })
    if (error) throw new Error(error.message)
  }, [])

  const signInWith = useCallback(async (provider: 'apple' | 'google') => {
    const { error } = await supabase.auth.signInWithOAuth({ provider, options: { redirectTo: redirectTo() } })
    if (error) throw new Error(error.message)
  }, [])

  const devSignIn = useCallback(async (email: string, password: string, name: string) => {
    if (!import.meta.env.DEV || !isLocalBackend) throw new Error('Developer sign-in only works against the local stack.')
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (!error) return
    // Local email signups are auto-confirmed, so a brand new account signs in right away.
    const { error: signUpError } = await supabase.auth.signUp({ email, password, options: { data: { full_name: name } } })
    if (signUpError) throw new Error(signUpError.message)
  }, [])

  const signOut = useCallback(async () => {
    const { error } = await supabase.auth.signOut()
    if (error) throw new Error(error.message)
  }, [])

  const deleteAccount = useCallback(async () => {
    const { error } = await supabase.auth.getUser().then(() => supabase.rpc('delete_account'))
    if (error) throw new Error(`Couldn't delete your account: ${errorMessage(error)}`)
    await supabase.auth.signOut({ scope: 'local' })
  }, [])

  const value = useMemo<AuthContextValue>(
    () => ({
      state,
      userID: state.kind === 'signedIn' ? state.userID : undefined,
      sendCode,
      verifyCode,
      signInWith,
      devSignIn,
      signOut,
      deleteAccount,
    }),
    [state, sendCode, verifyCode, signInWith, devSignIn, signOut, deleteAccount],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextValue {
  const value = useContext(AuthContext)
  if (!value) throw new Error('useAuth needs an AuthProvider')
  return value
}
