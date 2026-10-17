import { useState } from 'react'
import { Link } from 'react-router-dom'
import { EmptyState, Spinner } from '../components/ui'
import { errorMessage } from '../lib/supabase'
import { TERMS_LAST_UPDATED, TERMS_SECTIONS } from '../lib/terms'
import { useAuth } from '../services/auth'
import { useTerms } from '../services/terms'

/** The full text of the terms. Sections get anchors so the Give form can link straight to the prohibited list. */
export function TermsContent() {
  return (
    <div className="stack" style={{ gap: 20 }}>
      <p className="caption" style={{ margin: 0 }}>Last updated {TERMS_LAST_UPDATED}</p>
      {TERMS_SECTIONS.map((section) => (
        <section key={section.title} id={section.title === "What You Can't List" ? 'prohibited' : undefined}>
          <h3>{section.title}</h3>
          {section.blocks.map((block, i) =>
            block.kind === 'paragraph' ? (
              <p key={i}>{block.text}</p>
            ) : (
              <ul key={i} style={{ margin: '0 0 0.8em', paddingLeft: 22 }}>
                {block.items.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            ),
          )}
        </section>
      ))}
    </div>
  )
}

/** Public page at /terms, linked from the landing page and the account section. */
export function TermsPage() {
  return (
    <div className="landing">
      <header>
        <div className="inner">
          <Link to="/" className="brand"><img src="/app-icon.png" alt="" /> Ananeo</Link>
          <Link to="/app" className="btn primary cta">Open the app</Link>
        </div>
      </header>
      <main className="band" style={{ maxWidth: 720 }}>
        <h1>Terms of Use</h1>
        <div className="card">
          <TermsContent />
        </div>
      </main>
    </div>
  )
}

/** Shown after sign-in until the person accepts the current terms. */
export function TermsAcceptance() {
  const terms = useTerms()
  const auth = useAuth()
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string>()

  if (terms.status.kind === 'checking') return <Spinner />
  if (terms.status.kind === 'failed') {
    return (
      <div className="signin">
        <EmptyState icon="📡" title="Couldn't Load Your Account" action={<button className="btn" onClick={terms.reset}>Try Again</button>}>
          {terms.status.message}
        </EmptyState>
      </div>
    )
  }

  const accept = async () => {
    setError(undefined)
    setWorking(true)
    try {
      await terms.accept()
    } catch (e) {
      setError(`Couldn't save that: ${errorMessage(e)}`)
    } finally {
      setWorking(false)
    }
  }

  return (
    <div className="shell">
      <div className="topbar">
        <div className="topbar-inner">
          <span className="brand"><img src="/app-icon.png" alt="" /> Ananeo</span>
          <span className="spacer" />
          <span className="page-title">Terms of Use</span>
        </div>
      </div>
      <main className="content narrow" style={{ paddingBottom: 160 }}>
        <div className="card">
          <TermsContent />
        </div>
      </main>
      <div className="composer" style={{ position: 'fixed', bottom: 0, left: 0, right: 0, padding: 12, flexDirection: 'column', alignItems: 'stretch', gap: 8, borderTop: '1px solid var(--line)' }}>
        <p className="caption center" style={{ margin: 0 }}>
          By choosing I Agree, you accept these terms, including zero tolerance for objectionable content and abusive behavior.
        </p>
        {error && <p className="error center" style={{ margin: 0 }}>{error}</p>}
        <button className="btn primary lg" disabled={working} onClick={accept} style={{ maxWidth: 640, width: '100%', alignSelf: 'center' }}>
          {working ? <Spinner inline /> : 'I Agree'}
        </button>
        <button className="btn plain sm" onClick={() => auth.signOut().catch(() => {})} style={{ alignSelf: 'center' }}>
          Sign Out
        </button>
      </div>
    </div>
  )
}
