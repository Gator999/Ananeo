import { Link, NavLink, Navigate, Outlet, useLocation } from 'react-router-dom'
import { Spinner } from '../components/ui'
import { isConfigured } from '../lib/supabase'
import { useAuth } from '../services/auth'
import { useChat } from '../services/chat'
import { usePickups } from '../services/pickups'

const TABS = [
  { to: '/app/browse', label: 'Browse', icon: '🔍' },
  { to: '/app/give', label: 'Give', icon: '➕' },
  { to: '/app/pickups', label: 'Pickups', icon: '🔁' },
  { to: '/app/donate', label: 'Donate', icon: '📍' },
  { to: '/app/impact', label: 'Impact', icon: '🌱' },
]

/** Signed-in layout: a top bar with navigation on wide screens, a tab bar on phones. */
export function AppShell() {
  const { state } = useAuth()
  const pickups = usePickups()
  const chat = useChat()
  const location = useLocation()

  if (!isConfigured) {
    return (
      <div className="signin">
        <div className="card stack">
          <h2>Backend not configured</h2>
          <p className="muted">
            This build has no Supabase URL or key. Set <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_KEY</code> where the site is
            built, then deploy again. See <code>web/README.md</code>.
          </p>
        </div>
      </div>
    )
  }
  if (state.kind === 'loading') return <Spinner />
  if (state.kind === 'signedOut') return <Navigate to="/app/sign-in" replace state={{ from: location.pathname }} />

  const badge = pickups.needsYouCount + chat.unreadAcross(pickups.all)

  return (
    <div className="shell">
      <div className="topbar">
        <div className="topbar-inner">
          <Link to="/" className="brand">
            <img src="/app-icon.png" alt="" /> Ananeo
          </Link>
          <nav className="topnav" aria-label="Sections">
            {TABS.map((tab) => (
              <NavLink key={tab.to} to={tab.to} className={({ isActive }) => (isActive ? 'active' : '')}>
                {tab.label}
                {tab.label === 'Pickups' && badge > 0 && <span className="count">{badge}</span>}
              </NavLink>
            ))}
          </nav>
          <span className="spacer" />
        </div>
      </div>
      <main className="content">
        <Outlet />
      </main>
      <nav className="tabbar" aria-label="Sections">
        {TABS.map((tab) => (
          <NavLink key={tab.to} to={tab.to} className={({ isActive }) => (isActive ? 'active' : '')}>
            <span className="ico" aria-hidden="true">{tab.icon}</span>
            {tab.label}
            {tab.label === 'Pickups' && badge > 0 && <span className="count">{badge}</span>}
          </NavLink>
        ))}
      </nav>
    </div>
  )
}
