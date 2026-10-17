import { useState, type FormEvent } from 'react'
import { Link, Navigate, useLocation } from 'react-router-dom'
import { Spinner } from '../components/ui'
import { appleSignInEnabled, isConfigured, isLocalBackend } from '../lib/supabase'
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

        {sent ? (
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
        ) : (
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
            {appleSignInEnabled && (
              <>
                <div className="divider">or</div>
                <button type="button" className="btn apple block" disabled={working} onClick={() => run(auth.signInWithApple)}>
                   Continue with Apple
                </button>
              </>
            )}
          </form>
        )}

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
