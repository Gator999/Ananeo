import { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom'
import { Confirm, EmptyState, Spinner } from '../components/ui'
import { distanceLabelKm, relativeTime } from '../lib/format'
import { errorMessage, photoURL, supabase } from '../lib/supabase'
import { categoryEmoji, categoryTitle, conditionTitle, modeTitle, type Listing } from '../lib/types'
import { useAuth } from '../services/auth'
import { useListings } from '../services/listings'
import { usePickups } from '../services/pickups'

export function ListingDetail() {
  const { id } = useParams()
  const location = useLocation()
  const navigate = useNavigate()
  const { userID } = useAuth()
  const listings = useListings()
  const pickups = usePickups()

  // Browse passes the listing along, so the page is instant. A shared link loads it instead.
  const passed = (location.state as { listing?: Listing } | null)?.listing
  const [listing, setListing] = useState<Listing | undefined>(passed?.id === id ? passed : undefined)
  const [loadError, setLoadError] = useState<string>()
  const [confirmingRemove, setConfirmingRemove] = useState(false)
  const [working, setWorking] = useState(false)
  const [error, setError] = useState<string>()

  useEffect(() => {
    if (listing || !id) return
    supabase
      .from('items')
      .select()
      .eq('id', id)
      .maybeSingle()
      .then(({ data, error }) => {
        if (error) setLoadError(errorMessage(error))
        else if (!data) setLoadError('This listing is no longer available.')
        else setListing(data as Listing)
      })
  }, [id, listing])

  if (loadError) return <EmptyState icon="🗂️" title="Listing Unavailable">{loadError}</EmptyState>
  if (!listing) return <Spinner />

  const isMine = userID === listing.owner_id
  const pickup = pickups.pickupFor(listing.id)
  const hasRequested = pickup?.isGiver === false
  const requestCount = isMine ? (pickup?.requests.length ?? 0) : 0
  const photos = listing.photos.map(photoURL).filter((u): u is string => Boolean(u))

  const request = async () => {
    setError(undefined)
    setWorking(true)
    try {
      await pickups.request(listing)
    } catch (e) {
      setError(`Couldn't send your request: ${errorMessage(e)}`)
    } finally {
      setWorking(false)
    }
  }

  const remove = async () => {
    setConfirmingRemove(false)
    setWorking(true)
    try {
      await listings.remove(listing)
      navigate('/app/browse')
    } catch (e) {
      setError(`Couldn't remove: ${errorMessage(e)}`)
    } finally {
      setWorking(false)
    }
  }

  return (
    <div className="stack" style={{ maxWidth: 640 }}>
      <Link to="/app/browse" className="btn plain" style={{ alignSelf: 'flex-start', paddingLeft: 0 }}>
        ‹ Browse
      </Link>

      <div className="card pad-0">
        <div className="hero-photo">
          {photos.length === 0 ? (
            <div className="placeholder" aria-hidden="true">{categoryEmoji[listing.category]}</div>
          ) : (
            <>
              <div className="pager">
                {photos.map((url, i) => (
                  <img key={url} src={url} alt={`${listing.title}, photo ${i + 1}`} />
                ))}
              </div>
              {photos.length > 1 && (
                <div className="dots" aria-hidden="true">
                  {photos.map((url) => (
                    <span key={url} />
                  ))}
                </div>
              )}
            </>
          )}
        </div>
        <div style={{ padding: 16 }}>
          <h2 style={{ marginBottom: 6 }}>{listing.title}</h2>
          <div className="row">
            <span className="badge">{modeTitle[listing.mode]}</span>
            <span className="badge">{conditionTitle[listing.condition]}</span>
          </div>
          {listing.details && <p style={{ marginTop: 12, whiteSpace: 'pre-wrap' }}>{listing.details}</p>}
        </div>
      </div>

      <div className="section-title">Details</div>
      <div className="list">
        <div className="labeled"><span>Category</span><span>{categoryTitle[listing.category]}</span></div>
        {listing.distance_km !== undefined && (
          <div className="labeled"><span>Distance</span><span>{distanceLabelKm(listing.distance_km)}</span></div>
        )}
        {listing.wants && <div className="labeled"><span>Wants in return</span><span>{listing.wants}</span></div>}
        <div className="labeled"><span>Listed</span><span>{relativeTime(listing.created_at)}</span></div>
      </div>

      <div className="stack" style={{ marginTop: 8 }}>
        {isMine ? (
          <button className="btn danger" disabled={working} onClick={() => setConfirmingRemove(true)}>
            Remove Listing
          </button>
        ) : hasRequested ? (
          <div className="notice">✓ Requested</div>
        ) : (
          <button className="btn primary lg" disabled={working} onClick={request}>
            ✋ Request Pickup
          </button>
        )}
        {error ? (
          <p className="error">{error}</p>
        ) : requestCount > 0 ? (
          <p className="caption">
            {requestCount === 1 ? '1 person asked for this.' : `${requestCount} people asked for this.`}{' '}
            <Link to={`/app/pickups/${listing.id}`}>Choose who gets it in Pickups.</Link>
          </p>
        ) : hasRequested ? (
          <p className="caption">
            <Link to={`/app/pickups/${listing.id}`}>Follow along in Pickups.</Link> If the giver chooses you, you'll both confirm the handoff there.
          </p>
        ) : !isMine ? (
          <p className="caption">The giver chooses who gets it from everyone who asks.</p>
        ) : null}
      </div>

      <Confirm
        open={confirmingRemove}
        title="Remove this listing?"
        message="It will no longer be visible to anyone."
        confirmLabel="Remove Listing"
        destructive
        onConfirm={remove}
        onCancel={() => setConfirmingRemove(false)}
      />
    </div>
  )
}
