import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { EmptyState, Spinner, Thumb } from '../components/ui'
import { distanceLabelKm } from '../lib/format'
import { useLocation, type Coordinate } from '../lib/geo'
import { CATEGORIES, categoryTitle, conditionTitle, modeTitle, type ItemCategory, type Listing } from '../lib/types'
import { useListings } from '../services/listings'

/** The Browse tab: listings near you, closest first. */
export function Browse() {
  const location = useLocation()

  useEffect(() => {
    if (location.kind === 'needsPermission') location.request()
    // Ask once when the tab opens.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <>
      <h1>Browse</h1>
      {location.kind === 'ready' && <NearbyFeed coordinate={location.coordinate} />}
      {location.kind === 'locating' && (
        <div className="empty">
          <Spinner />
          Finding your area…
        </div>
      )}
      {location.kind === 'needsPermission' && (
        <EmptyState
          icon="📍"
          title="See What's Nearby"
          action={
            <button className="btn primary" onClick={location.request}>
              Use My Location
            </button>
          }
        >
          Ananeo uses your approximate location to show items you can pick up.
        </EmptyState>
      )}
      {location.kind === 'denied' && (
        <EmptyState
          icon="🚫"
          title="Location Is Off"
          action={
            <button className="btn" onClick={location.request}>
              Try Again
            </button>
          }
        >
          {location.message}
        </EmptyState>
      )}
      {location.kind === 'unsupported' && (
        <EmptyState icon="🚫" title="Location Unavailable">
          This browser can't share a location. Try another browser to browse items nearby.
        </EmptyState>
      )}
    </>
  )
}

function NearbyFeed({ coordinate }: { coordinate: Coordinate }) {
  const listings = useListings()
  const [category, setCategory] = useState<ItemCategory | null>(null)
  const [radius, setRadius] = useState(10)
  const [appliedRadius, setAppliedRadius] = useState(10)
  const [results, setResults] = useState<Listing[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string>()
  const [reloads, setReloads] = useState(0)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    listings
      .nearby(coordinate, appliedRadius, category)
      .then((rows) => {
        if (cancelled) return
        setResults(rows)
        setError(undefined)
      })
      .catch((e: Error) => {
        if (!cancelled) setError(e.message)
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [coordinate, appliedRadius, category, listings.revision, listings, reloads])

  return (
    <>
      <div className="chips" role="group" aria-label="Category">
        <button className="chip" aria-pressed={category === null} onClick={() => setCategory(null)}>
          All
        </button>
        {CATEGORIES.map((c) => (
          <button key={c} className="chip" aria-pressed={category === c} onClick={() => setCategory(c)}>
            {categoryTitle[c]}
          </button>
        ))}
      </div>
      <label className="field" style={{ margin: '10px 0 16px' }}>
        <span>Within {radius} mi</span>
        <input
          type="range"
          min={1}
          max={25}
          step={1}
          value={radius}
          onChange={(e) => setRadius(Number(e.target.value))}
          // Search only when the slider is released, not on every tick.
          onMouseUp={() => setAppliedRadius(radius)}
          onTouchEnd={() => setAppliedRadius(radius)}
          onKeyUp={() => setAppliedRadius(radius)}
        />
      </label>

      <div className="section-title">Nearby</div>
      {error ? (
        <EmptyState
          icon="📡"
          title="Couldn't Load Items"
          action={
            <button className="btn" onClick={() => setReloads((n) => n + 1)}>
              Try Again
            </button>
          }
        >
          {error}
        </EmptyState>
      ) : loading && results.length === 0 ? (
        <Spinner />
      ) : results.length === 0 ? (
        <EmptyState icon="🗂️" title="Nothing Nearby Yet">
          Try a wider distance or another category, or be the first to give something.
        </EmptyState>
      ) : (
        <div className="list">
          {results.map((listing) => (
            <ListingRow key={listing.id} listing={listing} />
          ))}
        </div>
      )}
    </>
  )
}

export function ListingRow({ listing }: { listing: Listing }) {
  const distance = distanceLabelKm(listing.distance_km)
  const flagged = listing.condition === 'needs_repair' || listing.condition === 'for_parts'
  return (
    <Link to={`/app/browse/${listing.id}`} state={{ listing }} className="list-row">
      <Thumb path={listing.photos[0]} category={listing.category} />
      <div className="grow">
        <div className="truncate">{listing.title}</div>
        <div className="caption">
          {distance}
          {flagged && ` · ${conditionTitle[listing.condition]}`}
        </div>
      </div>
      <span className="badge">{modeTitle[listing.mode]}</span>
    </Link>
  )
}
