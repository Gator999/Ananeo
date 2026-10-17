import { useState, type FormEvent } from 'react'
import { Link, Navigate, useLocation } from 'react-router-dom'
import { Spinner } from '../components/ui'
import { isConfigured, isLocalBackend, signInMethods } from '../lib/supabase'
import { useAuth } from '../services/auth'

export function SignIn() {
  const auth = useAuth()
  const location = useLocation()
  const from = (location.state as { from?: string } | null)?.from ?? '/app/browse'

  const [email, setEmail] = useState('')
  const [code, setCode] = useState('')
  const [sent, setSent] = useState(false)
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string>()

  const emailEnabled = signInMethods.includes('email')
  const providers = signInMethods.filter((m) => m !== 'email')

  if (auth.state.kind === 'signedIn') return <Navigate to={from} replace />
  if (auth.state.kind === 'loading') return <Spinner />

  const run = async (action: () => Promise<void>) => {
    setError(undefined)
    setWorking(true)
    try {
      await action()
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setWorking(false)
    }
  }

  const sendCode = (e: FormEvent) => {
    e.preventDefault()
    run(async () => {
      await auth.sendCode(email.trim())
      setSent(true)
    })
  }

  const verify = (e: FormEvent) => {
    e.preventDefault()
    run(() => auth.verifyCode(email.trim(), code.trim()))
  }

  return (
    <div className="signin">
      <div className="card stack">
        <img className="logo" src="/app-icon.png" alt="" />
        <h1 className="center" style={{ marginBottom: 0 }}>Ananeo</h1>
        <p className="center muted" style={{ marginTop: 0 }}>
          Give More. Waste Less.
          <br />
          Keep It Moving.
        </p>

        {!isConfigured && <p className="notice warn">This build has no backend configured. See web/README.md.</p>}

        {providers.length > 0 && (
          <div className="stack">
            {providers.includes('apple') && (
              <button type="button" className="btn apple block lg" disabled={working} onClick={() => run(() => auth.signInWith('apple'))}>
                 Continue with Apple
              </button>
            )}
            {providers.includes('google') && (
              <button type="button" className="btn block lg" disabled={working} onClick={() => run(() => auth.signInWith('google'))}>
                <GoogleMark /> Continue with Google
              </button>
            )}
          </div>
        )}

        {emailEnabled && providers.length > 0 && <div className="divider">or</div>}

        {emailEnabled && sent ? (
          <form className="stack" onSubmit={verify}>
            <p className="notice">
              Check <b>{email}</b>. Open the link on this device, or enter the 6-digit code if your email has one.
            </p>
            <label className="field">
              <span>Code</span>
              <input
                className="input code-input"
                inputMode="numeric"
                autoComplete="one-time-code"
                pattern="[0-9]{6}"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                placeholder="••••••"
              />
            </label>
            <button className="btn primary block" disabled={working || code.length !== 6}>
              {working ? <Spinner inline /> : 'Continue'}
            </button>
            <button type="button" className="btn plain block" disabled={working} onClick={() => setSent(false)}>
              Use a different email
            </button>
          </form>
        ) : emailEnabled ? (
          <form className="stack" onSubmit={sendCode}>
            <label className="field">
              <span>Email</span>
              <input
                className="input"
                type="email"
                autoComplete="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="you@example.com"
              />
            </label>
            <button className="btn primary block" disabled={working || !email.includes('@')}>
              {working ? <Spinner inline /> : 'Continue with Email'}
            </button>
          </form>
        ) : null}

        {providers.length === 0 && !emailEnabled && <p className="notice warn">No sign-in method is enabled for this build.</p>}

        {error && <p className="error center">{error}</p>}
        <p className="caption center">Your exact location is never shown to other people.</p>
        {import.meta.env.DEV && isLocalBackend && <DevSignIn run={run} working={working} />}
        <p className="caption center">
          <Link to="/">About Ananeo</Link>
        </p>
      </div>
    </div>
  )
}

function GoogleMark() {
  return (
    <svg width="18" height="18" viewBox="0 0 48 48" aria-hidden="true">
      <path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9.1 3.6l6.8-6.8C35.8 2.4 30.3 0 24 0 14.6 0 6.5 5.4 2.6 13.3l7.9 6.1C12.4 13.7 17.7 9.5 24 9.5z" />
      <path fill="#4285F4" d="M46.5 24.5c0-1.6-.1-3.1-.4-4.5H24v9h12.7c-.6 3-2.3 5.5-4.8 7.2l7.7 6c4.5-4.2 6.9-10.3 6.9-17.7z" />
      <path fill="#FBBC05" d="M10.5 28.6A14.5 14.5 0 0 1 9.7 24c0-1.6.3-3.1.8-4.6l-7.9-6.1A24 24 0 0 0 0 24c0 3.9.9 7.5 2.6 10.7l7.9-6.1z" />
      <path fill="#34A853" d="M24 48c6.5 0 11.9-2.1 15.9-5.8l-7.7-6c-2.1 1.4-4.9 2.3-8.2 2.3-6.3 0-11.6-4.2-13.5-10l-7.9 6.1C6.5 42.6 14.6 48 24 48z" />
    </svg>
  )
}

/** Local stack only: the same throwaway accounts scripts/dev-simulator.sh uses. Stripped from production builds. */
function DevSignIn({ run, working }: { run: (action: () => Promise<void>) => Promise<void>; working: boolean }) {
  const auth = useAuth()
  const [name, setName] = useState('Dev Tester')
  const [email, setEmail] = useState('dev@ananeo.test')
  const [password, setPassword] = useState('local-dev-3ffdb31b88f264d6')
  return (
    <form
      className="stack"
      style={{ borderTop: '1px dashed var(--line)', paddingTop: 12 }}
      onSubmit={(e) => {
        e.preventDefault()
        run(() => auth.devSignIn(email, password, name))
      }}
    >
      <p className="caption" style={{ margin: 0 }}>Developer sign-in (local stack only)</p>
      <input className="input" aria-label="Name" value={name} onChange={(e) => setName(e.target.value)} />
      <input className="input" aria-label="Dev email" value={email} onChange={(e) => setEmail(e.target.value)} />
      <input className="input" aria-label="Dev password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
      <button className="btn block" disabled={working}>
        Sign in as test account
      </button>
    </form>
  )
}
