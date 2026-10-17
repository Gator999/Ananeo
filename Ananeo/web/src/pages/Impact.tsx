import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Confirm, Stat } from '../components/ui'
import { lbs } from '../lib/format'
import { errorMessage } from '../lib/supabase'
import type { CommunityImpact, Impact as MyImpact } from '../lib/types'
import { useAuth } from '../services/auth'
import { fetchCommunityImpact, fetchMyImpact, useListings } from '../services/listings'
import { usePickups } from '../services/pickups'

/** Personal and community totals, counted only from handoffs both sides confirmed. */
export function Impact() {
  const auth = useAuth()
  const listings = useListings()
  const pickups = usePickups()
  const [mine, setMine] = useState<MyImpact>({ items_given: 0, items_received: 0, kg_diverted: 0 })
  const [community, setCommunity] = useState<CommunityImpact>({ items_kept_moving: 0, kg_diverted: 0 })
  const [error, setError] = useState<string>()
  const [confirmingDelete, setConfirmingDelete] = useState(false)
  const [accountError, setAccountError] = useState<string>()

  useEffect(() => {
    let cancelled = false
    Promise.all([fetchMyImpact(), fetchCommunityImpact()])
      .then(([m, c]) => {
        if (cancelled) return
        setMine(m)
        setCommunity(c)
        setError(undefined)
      })
      .catch((e: Error) => {
        if (!cancelled) setError(`Couldn't load totals: ${e.message}`)
      })
    return () => {
      cancelled = true
    }
  }, [listings.revision, pickups.revision])

  const account = async (action: () => Promise<void>) => {
    setConfirmingDelete(false)
    setAccountError(undefined)
    try {
      await action()
    } catch (e) {
      setAccountError(errorMessage(e))
    }
  }

  return (
    <div className="stack" style={{ maxWidth: 640 }}>
      <h1>Your Impact</h1>

      <div className="section-title">You</div>
      <div className="card">
        <div className="stats">
          <Stat value={String(mine.items_given)} label="Items given" />
          <Stat value={String(mine.items_received)} label="Items received" />
          <Stat value={lbs(mine.kg_diverted)} label="Kept from landfill" />
        </div>
      </div>
      {error ? (
        <p className="error">{error}</p>
      ) : mine.items_given + mine.items_received === 0 ? (
        <p className="caption">Your totals grow each time a handoff is confirmed by both people.</p>
      ) : null}

      <div className="section-title">Everyone on Ananeo</div>
      <div className="card">
        <div className="stats">
          <Stat value={String(community.items_kept_moving)} label="Items kept moving" />
          <Stat value={lbs(community.kg_diverted, 0)} label="Kept from landfill" />
        </div>
      </div>
      <p className="caption">
        Only handoffs confirmed by both people count. <Link to="/#methodology">How the numbers work.</Link>
      </p>

      <div className="section-title">Account</div>
      <div className="list">
        <Link className="list-row" to="/terms">Terms of Use</Link>
        <button className="list-row" onClick={() => account(auth.signOut)}>Sign Out</button>
        <button className="list-row" style={{ color: 'var(--danger)' }} onClick={() => setConfirmingDelete(true)}>Delete Account</button>
      </div>
      {accountError && <p className="error">{accountError}</p>}

      <Confirm
        open={confirmingDelete}
        title="Delete your account?"
        message="Your listings, messages, and impact history will be permanently removed."
        confirmLabel="Delete Account"
        destructive
        onConfirm={() => account(auth.deleteAccount)}
        onCancel={() => setConfirmingDelete(false)}
      />
    </div>
  )
}
