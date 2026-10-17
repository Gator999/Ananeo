import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { isConfigured } from '../lib/supabase'
import type { CommunityImpact } from '../lib/types'
import { fetchCommunityImpact } from '../services/listings'

const WEIGHTS: [string, string][] = [
  ['Furniture', '25 kg'],
  ['Materials', '5 kg'],
  ['Electronics', '3 kg'],
  ['Tools', '2 kg'],
  ['Household', '1.5 kg'],
  ['Books', '0.8 kg'],
  ['Clothing', '0.5 kg'],
  ['Other', '1 kg'],
]

/** The public site at ananeo.app: what Ananeo is, how it works, and how the impact numbers are counted. */
export function Landing() {
  const [community, setCommunity] = useState<CommunityImpact>()
  useEffect(() => {
    if (isConfigured) fetchCommunityImpact().then(setCommunity).catch(() => {})
  }, [])

  return (
    <div className="landing">
      <header>
        <div className="inner">
          <Link to="/" className="brand"><img src="/app-icon.png" alt="" /> Ananeo</Link>
          <nav aria-label="Site">
            <a href="#how">How it works</a>
            <a href="#pillars">What you can do</a>
            <a href="#methodology">Impact</a>
            <a href="#safety">Safety</a>
          </nav>
          <Link to="/app" className="btn primary cta">Open the app</Link>
        </div>
      </header>

      <section className="hero">
        <div>
          <h1>Give More. Waste Less. <em>Keep It Moving.</em></h1>
          <p className="lede">
            Ananeo connects people who have things they no longer need with neighbors who can use them. No prices, no checkout, no
            shipping. Just useful things finding their next use, a short walk away.
          </p>
          <div className="actions">
            <Link to="/app" className="btn primary lg">Open the app</Link>
            <a href="#how" className="btn lg">See how it works</a>
          </div>
          <p className="caption" style={{ marginTop: 14 }}>
            Works in your browser today. The iOS app is in testing.
          </p>
        </div>
        <div className="phone" aria-hidden="true">
          <div className="screen">
            <b style={{ fontSize: '1.1rem' }}>Browse</b>
            <div className="mock-row"><div className="thumb">🛋️</div><div><b>Oak bookshelf</b><small>About 0.8 mi · Free</small></div></div>
            <div className="mock-row"><div className="thumb">💻</div><div><b>Monitor, needs a cable</b><small>About 1.2 mi · Parts</small></div></div>
            <div className="mock-row"><div className="thumb">📚</div><div><b>Box of paperbacks</b><small>About 2.0 mi · Swap</small></div></div>
            <div className="mock-row"><div className="thumb">🔧</div><div><b>Cordless drill</b><small>About 3.4 mi · Free</small></div></div>
          </div>
        </div>
      </section>

      <section className="impact-band">
        <div className="band">
          <div className="stats">
            <div className="stat"><b>{community ? community.items_kept_moving.toLocaleString() : '—'}</b><span>Items kept moving</span></div>
            <div className="stat"><b>{community ? `${Math.round(community.kg_diverted).toLocaleString()} kg` : '—'}</b><span>Kept out of landfill</span></div>
          </div>
          <p className="caption center" style={{ marginTop: 12 }}>Live totals. Only handoffs confirmed by both people are counted.</p>
        </div>
      </section>

      <section className="band" id="how">
        <h2>How it works</h2>
        <p className="sub">Post in under a minute. The giver chooses who gets it. Both people confirm the handoff.</p>
        <div className="grid three">
          <div className="card step"><div className="num">1</div><div><h3>Give</h3><p className="muted">Snap a few photos, pick a category, and post. Your listing shows an approximate area, never your address.</p></div></div>
          <div className="card step"><div className="num">2</div><div><h3>Request</h3><p className="muted">Neighbors nearby ask for it. You pick one, and the two of you sort out a time in chat.</p></div></div>
          <div className="card step"><div className="num">3</div><div><h3>Hand off</h3><p className="muted">Once you both confirm, the item counts toward your impact and the community total.</p></div></div>
        </div>
      </section>

      <section className="band" id="pillars">
        <h2>Six ways to keep things moving</h2>
        <p className="sub">Ananeo is not a marketplace. Each feature answers one question: does this help an item find its next use?</p>
        <div className="grid three">
          <div className="card feature"><div className="icon">🎁</div><h3>Give</h3><p>Furniture, clothes, tools, books, materials. If it's useful, someone nearby wants it.</p></div>
          <div className="card feature"><div className="icon">🔁</div><h3>Exchange</h3><p>Mark a listing as open to swap and say what you'd like in return. No money changes hands.</p></div>
          <div className="card feature"><div className="icon">📍</div><h3>Donate</h3><p>A map of donation centers, thrift stores, e-waste drop-offs, and textile bins, filtered by what they accept.</p></div>
          <div className="card feature"><div className="icon">🔧</div><h3>Repair and repurpose</h3><p>List things that need a fix, or offer them for parts and materials. Broken isn't worthless.</p></div>
          <div className="card feature"><div className="icon">🌱</div><h3>Impact</h3><p>Items given, items received, and kilograms kept out of landfill, for you and for everyone.</p></div>
          <div className="card feature"><div className="icon">🏘️</div><h3>Community challenges</h3><p>Move-out week, campus drives, building clear-outs. Join one and watch the shared progress bar move.</p></div>
        </div>
      </section>

      <section className="band" id="methodology">
        <h2>How the impact numbers work</h2>
        <p className="sub">Published so partners can trust the totals. Inflated numbers help no one.</p>
        <div className="grid two">
          <div className="card">
            <h3>What counts</h3>
            <p className="muted small">An item counts once, and only after both the giver and the receiver confirm the handoff in the app. Listings, requests, and reservations never count on their own. Removed listings never count.</p>
            <h3>Weight estimates</h3>
            <p className="muted small">Every item carries a weight estimate in kilograms, set from its category when it's listed. A weight band you can set yourself is planned. Totals are the sum of those estimates over confirmed handoffs.</p>
            <h3>What we don't claim</h3>
            <p className="muted small">No CO₂-equivalent figures yet. When they come, they'll use the EPA WARM factors and be labeled as estimates.</p>
          </div>
          <div className="card">
            <h3>Default weight by category</h3>
            <table className="plain">
              <thead><tr><th>Category</th><th>Estimate per item</th></tr></thead>
              <tbody>
                {WEIGHTS.map(([category, weight]) => (
                  <tr key={category}><td>{category}</td><td>{weight}</td></tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>

      <section className="band" id="safety">
        <h2>Safety and privacy</h2>
        <div className="grid three">
          <div className="card feature"><div className="icon">🗺️</div><h3>Approximate locations only</h3><p>Every listing's location is offset by up to a quarter mile before it's stored. The exact point is never saved.</p></div>
          <div className="card feature"><div className="icon">💬</div><h3>Addresses stay in chat</h3><p>Share where to meet only when you're ready, and only with the person you chose.</p></div>
          <div className="card feature"><div className="icon">🛡️</div><h3>Report and block</h3><p>Zero tolerance for objectionable content. Report a listing or a person, block anyone, delete your account any time.</p></div>
        </div>
      </section>

      <footer>
        <div className="inner">
          <span>© {new Date().getFullYear()} Ananeo. <em>Ananeo</em> is from the Greek ανανέωση, "renewal."</span>
          <span><Link to="/app">Open the app</Link> · <a href="#methodology">Impact methodology</a></span>
        </div>
      </footer>
    </div>
  )
}
