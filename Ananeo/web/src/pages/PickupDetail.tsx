import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { Confirm, EmptyState, Thumb } from '../components/ui'
import { monthDay, relativeTime } from '../lib/format'
import { errorMessage } from '../lib/supabase'
import { categoryTitle, reservation, stage, type Handoff, type Pickup, type PickupRequest } from '../lib/types'
import { useChat } from '../services/chat'
import { usePickups } from '../services/pickups'

type Dialog = { kind: 'reserve'; request: PickupRequest } | { kind: 'handoff' } | { kind: 'cancel' } | { kind: 'withdraw' } | null

/** One pickup from either side: choose who gets it, confirm the handoff, or step back. */
export function PickupDetail() {
  const { itemID } = useParams()
  const pickups = usePickups()
  const navigate = useNavigate()
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string>()
  const [dialog, setDialog] = useState<Dialog>(null)

  const pickup = itemID ? pickups.pickupFor(itemID) : undefined
  if (!pickup) {
    return (
      <EmptyState icon="🗂️" title="No Longer in Pickups" action={<Link className="btn" to="/app/pickups">Back to Pickups</Link>} />
    )
  }

  const held = reservation(pickup)
  const name = held?.otherName ?? pickup.requests[0]?.otherName ?? 'them'
  const current = stage(pickup)

  const perform = async (action: () => Promise<void>, then?: () => void) => {
    setDialog(null)
    setError(undefined)
    setWorking(true)
    try {
      await action()
      then?.()
    } catch (e) {
      setError(errorMessage(e))
    } finally {
      setWorking(false)
    }
  }

  // The pickup leaves the list afterward, so go back to it.
  const withdraw = () => perform(() => pickups.withdraw(pickup), () => navigate('/app/pickups'))

  return (
    <div className="stack" style={{ maxWidth: 640 }}>
      <Link to="/app/pickups" className="btn plain" style={{ alignSelf: 'flex-start', paddingLeft: 0 }}>‹ Pickups</Link>
      <div className="card row">
        <Thumb path={pickup.photo} category={pickup.category} large />
        <div className="grow">
          <h2 style={{ margin: 0 }}>{pickup.title}</h2>
          <div className="muted small">{categoryTitle[pickup.category]}</div>
        </div>
      </div>

      <fieldset disabled={working} style={{ border: 0, padding: 0, margin: 0 }} className="stack">
        {pickup.isGiver ? (
          <Giving pickup={pickup} setDialog={setDialog} />
        ) : (
          <Getting pickup={pickup} setDialog={setDialog} onRemove={withdraw} />
        )}
        <Messages pickup={pickup} />
      </fieldset>

      {error && <p className="error">{error}</p>}

      <Confirm
        open={dialog?.kind === 'reserve'}
        title={`Reserve for ${dialog?.kind === 'reserve' ? dialog.request.otherName : 'them'}?`}
        message="It comes off Browse while it's reserved. You can cancel if plans fall through."
        confirmLabel="Reserve"
        onConfirm={() => dialog?.kind === 'reserve' && perform(() => pickups.reserve(pickup, dialog.request))}
        onCancel={() => setDialog(null)}
      />
      <Confirm
        open={dialog?.kind === 'handoff'}
        title={pickup.isGiver ? `Did ${name} pick it up?` : 'Did you get it?'}
        message="Once you both confirm, it counts toward your impact. This can't be undone."
        confirmLabel={pickup.isGiver ? 'Yes, Handed Off' : 'Yes, I Got It'}
        onConfirm={() => {
          const handoff = held?.handoff
          if (handoff) perform(() => pickups.confirm(handoff))
        }}
        onCancel={() => setDialog(null)}
      />
      <Confirm
        open={dialog?.kind === 'cancel'}
        title="Cancel the reservation?"
        message="It goes back on Browse, and you can choose someone else."
        confirmLabel="Cancel Reservation"
        destructive
        onConfirm={() => perform(() => pickups.cancelReservation(pickup))}
        onCancel={() => setDialog(null)}
      />
      <Confirm
        open={dialog?.kind === 'withdraw'}
        title={current === 'reserved' ? 'Back out of this pickup?' : 'Withdraw your request?'}
        message={`${name} can give it to someone else.`}
        confirmLabel={current === 'reserved' ? 'Back Out' : 'Withdraw Request'}
        destructive
        onConfirm={withdraw}
        onCancel={() => setDialog(null)}
      />
    </div>
  )
}

function Giving({ pickup, setDialog }: { pickup: Pickup; setDialog: (d: Dialog) => void }) {
  const held = reservation(pickup)
  switch (stage(pickup)) {
    case 'open':
      return (
        <>
          <div className="section-title">Who Asked</div>
          <div className="list">
            {pickup.requests.map((request) => (
              <div className="list-row static" key={request.id}>
                <Requester request={request} />
                <button className="btn sm" style={{ marginLeft: 'auto' }} onClick={() => setDialog({ kind: 'reserve', request })}>
                  Reserve
                </button>
              </div>
            ))}
          </div>
          <p className="caption">Choose one person. You can cancel and choose someone else if plans fall through.</p>
        </>
      )
    case 'reserved': {
      if (!held?.handoff) return null
      const others = pickup.requests.filter((r) => r.id !== held.id)
      return (
        <>
          <div className="section-title">Reserved for {held.otherName}</div>
          <div className="list">
            <Status handoff={held.handoff} otherName={held.otherName} />
            {!held.handoff.confirmedByMe && (
              <button className="list-row" style={{ color: 'var(--accent-strong)', fontWeight: 600 }} onClick={() => setDialog({ kind: 'handoff' })}>
                ✓ Confirm Handoff
              </button>
            )}
            <button className="list-row" style={{ color: 'var(--danger)' }} onClick={() => setDialog({ kind: 'cancel' })}>
              Cancel Reservation
            </button>
          </div>
          <p className="caption">Confirm once {held.otherName} has it. When you've both confirmed, it counts toward your impact.</p>
          {others.length > 0 && (
            <>
              <div className="section-title">Also Asked</div>
              <div className="list">
                {others.map((r) => (
                  <div className="list-row static" key={r.id}><Requester request={r} /></div>
                ))}
              </div>
            </>
          )}
        </>
      )
    }
    case 'done':
      return held ? <Completed pickup={pickup} with={held} /> : null
    case 'unavailable':
      return <p className="notice">This item isn't available.</p>
  }
}

function Getting({ pickup, setDialog, onRemove }: { pickup: Pickup; setDialog: (d: Dialog) => void; onRemove: () => void }) {
  const giver = pickup.requests[0]?.otherName ?? 'The giver'
  const held = reservation(pickup)
  switch (stage(pickup)) {
    case 'open':
      return (
        <>
          <div className="section-title">Requested</div>
          <div className="list">
            <button className="list-row" style={{ color: 'var(--danger)' }} onClick={() => setDialog({ kind: 'withdraw' })}>Withdraw Request</button>
          </div>
          <p className="caption">{giver} chooses who gets it from everyone who asks.</p>
        </>
      )
    case 'reserved':
      if (!held?.handoff) return null
      return (
        <>
          <div className="section-title">Reserved for You</div>
          <div className="list">
            <Status handoff={held.handoff} otherName={giver} />
            {!held.handoff.confirmedByMe && (
              <button className="list-row" style={{ color: 'var(--accent-strong)', fontWeight: 600 }} onClick={() => setDialog({ kind: 'handoff' })}>
                ✓ Confirm Pickup
              </button>
            )}
            <button className="list-row" style={{ color: 'var(--danger)' }} onClick={() => setDialog({ kind: 'withdraw' })}>Back Out</button>
          </div>
          <p className="caption">Confirm once you have it. When you've both confirmed, it counts toward your impact.</p>
        </>
      )
    case 'done':
      return held ? <Completed pickup={pickup} with={held} /> : null
    case 'unavailable':
      return (
        <>
          <div className="list">
            <button className="list-row" onClick={onRemove}>Remove from Pickups</button>
          </div>
          <p className="caption">{giver} gave it to someone else or took it down.</p>
        </>
      )
  }
}

/** One chat per request. Givers see the reservation first, then everyone else who asked. */
function Messages({ pickup }: { pickup: Pickup }) {
  const chat = useChat()
  const held = reservation(pickup)
  const requests = held ? [held, ...pickup.requests.filter((r) => r.id !== held.id)] : pickup.requests
  if (requests.length === 0) return null
  return (
    <>
      <div className="section-title">Messages</div>
      <div className="list">
        {requests.map((request) => {
          const summary = chat.summaryFor(request)
          const preview = !summary ? `Message ${request.otherName}` : summary.lastSenderIsMe ? `You: ${summary.lastBody}` : summary.lastBody
          return (
            <Link key={request.id} to={`/app/pickups/${pickup.id}/chat/${request.id}`} className="list-row">
              <div className="grow">
                <div>{request.otherName}</div>
                <div className="caption truncate">{preview}</div>
              </div>
              {summary && summary.unreadCount > 0 && <span className="count">{summary.unreadCount}</span>}
              <span className="chev" aria-hidden="true">›</span>
            </Link>
          )
        })}
      </div>
    </>
  )
}

function Completed({ pickup, with: held }: { pickup: Pickup; with: PickupRequest }) {
  const completedAt = held.handoff?.completedAt
  return (
    <>
      <div className="list">
        <div className="labeled">
          <span>{pickup.isGiver ? `Given to ${held.otherName}` : `Received from ${held.otherName}`}</span>
          <span>{completedAt ? monthDay(completedAt) : ''}</span>
        </div>
      </div>
      <p className="caption">Thanks for keeping it moving.</p>
    </>
  )
}

function Requester({ request }: { request: PickupRequest }) {
  return (
    <div>
      <div>{request.otherName}</div>
      <div className="caption">Asked {relativeTime(request.requestedAt)}</div>
    </div>
  )
}

/** Who has confirmed so far. */
function Status({ handoff, otherName }: { handoff: Handoff; otherName: string }) {
  const row = (who: string, confirmed: boolean) => (
    <div className="labeled">
      <span>{who}</span>
      <span style={{ color: confirmed ? 'var(--accent-strong)' : 'var(--muted)' }}>{confirmed ? '✓ Confirmed' : '○ Not yet'}</span>
    </div>
  )
  return (
    <>
      {row('You', handoff.confirmedByMe)}
      {row(otherName, handoff.confirmedByThem)}
    </>
  )
}
