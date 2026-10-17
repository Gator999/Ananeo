import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { EmptyState, Spinner, Thumb } from '../components/ui'
import { needsYou, reservation, stage, type Pickup } from '../lib/types'
import { useChat } from '../services/chat'
import { usePickups } from '../services/pickups'

/** The Pickups tab: everything you're giving or getting, from the first request to a confirmed handoff. */
export function Pickups() {
  const pickups = usePickups()
  const chat = useChat()
  const [error, setError] = useState<string>()

  const load = () => {
    pickups
      .refresh()
      .then(() => setError(undefined))
      .catch((e: Error) => setError(e.message))
    chat.refresh().catch(() => {})
  }

  useEffect(load, []) // eslint-disable-line react-hooks/exhaustive-deps

  const giving = pickups.all.filter((p) => p.isGiver && stage(p) !== 'done')
  const getting = pickups.all.filter((p) => !p.isGiver && stage(p) !== 'done')
  const done = pickups.all.filter((p) => stage(p) === 'done')

  return (
    <>
      <div className="row between">
        <h1>Pickups</h1>
        <button className="btn sm" onClick={load}>Refresh</button>
      </div>
      {error && pickups.all.length === 0 ? (
        <EmptyState icon="📡" title="Couldn't Load Pickups" action={<button className="btn" onClick={load}>Try Again</button>}>
          {error}
        </EmptyState>
      ) : !pickups.hasLoaded ? (
        <Spinner />
      ) : pickups.all.length === 0 ? (
        <EmptyState icon="🔁" title="No Pickups Yet">
          <Link to="/app/browse">Ask for something in Browse</Link>, or <Link to="/app/give">give something away</Link>. Requests and handoffs show up here.
        </EmptyState>
      ) : (
        <>
          <Section title="Giving" items={giving} />
          <Section title="Getting" items={getting} />
          <Section title="Done" items={done} />
        </>
      )}
    </>
  )
}

/** Items waiting on you come first. */
function Section({ title, items }: { title: string; items: Pickup[] }) {
  if (items.length === 0) return null
  const ordered = [...items.filter(needsYou), ...items.filter((p) => !needsYou(p))]
  return (
    <>
      <div className="section-title">{title}</div>
      <div className="list">
        {ordered.map((pickup) => (
          <PickupRow key={pickup.id} pickup={pickup} />
        ))}
      </div>
    </>
  )
}

export function summaryLine(pickup: Pickup): string {
  const name = reservation(pickup)?.otherName ?? pickup.requests[0]?.otherName ?? 'Someone'
  switch (stage(pickup)) {
    case 'open':
      if (!pickup.isGiver) return `Asked ${name}. Waiting to hear back.`
      return pickup.requests.length === 1 ? `${name} asked for it` : `${pickup.requests.length} people asked for it`
    case 'reserved': {
      const handoff = reservation(pickup)?.handoff
      if (!handoff) return 'Reserved'
      if (handoff.confirmedByMe) return `Waiting for ${name} to confirm`
      if (handoff.confirmedByThem) return `${name} confirmed. Confirm yours.`
      return pickup.isGiver ? `Reserved for ${name}` : 'Reserved for you'
    }
    case 'done':
      return pickup.isGiver ? `Given to ${name}` : `Received from ${name}`
    case 'unavailable':
      return 'No longer available'
  }
}

function PickupRow({ pickup }: { pickup: Pickup }) {
  const chat = useChat()
  const unread = chat.unreadIn(pickup)
  const yours = needsYou(pickup)
  return (
    <Link to={`/app/pickups/${pickup.id}`} className="list-row">
      <Thumb path={pickup.photo} category={pickup.category} />
      <div className="grow">
        <div className="truncate">{pickup.title}</div>
        <div className="caption" style={yours ? { color: 'var(--accent-strong)', fontWeight: 600 } : undefined}>
          {summaryLine(pickup)}
        </div>
      </div>
      {unread > 0 && <span className="count" aria-label={`${unread} unread messages`}>💬 {unread}</span>}
      <span className="chev" aria-hidden="true">›</span>
    </Link>
  )
}
