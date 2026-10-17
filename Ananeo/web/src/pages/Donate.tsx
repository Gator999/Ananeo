import { useEffect, useState } from 'react'
import { EmptyState, Spinner } from '../components/ui'
import { distanceLabel, milesFromKm } from '../lib/format'
import { useLocation, type Coordinate } from '../lib/geo'
import { categoryTitle, placeKindTitle, type Place, type PlaceKind } from '../lib/types'
import { fetchNearbyPlaces } from '../services/listings'

const KINDS: PlaceKind[] = ['donation', 'repair', 'ewaste', 'textile']

/** Sample places shown until the launch city's places are seeded, matching the iOS app's placeholder list. */
const SAMPLE: Place[] = [
  { id: 'sample-1', kind: 'donation', name: 'Community Thrift', address: '120 Main St', accepts: ['clothing', 'books', 'household'], hours: null, website: null, verified: false, latitude: 0, longitude: 0, distance_km: 1.45 },
  { id: 'sample-2', kind: 'donation', name: 'Habitat ReStore', address: '48 Industrial Rd', accepts: ['furniture', 'tools', 'household', 'materials'], hours: null, website: null, verified: false, latitude: 0, longitude: 0, distance_km: 4.18 },
  { id: 'sample-3', kind: 'ewaste', name: 'E-Waste Depot', address: '900 Recycling Way', accepts: ['electronics'], hours: null, website: null, verified: false, latitude: 0, longitude: 0, distance_km: 6.76 },
]

/** Where things can go when no individual claims them: donation centers, repair shops, e-waste and textile drop-offs. */
export function Donate() {
  const location = useLocation()
  useEffect(() => {
    if (location.kind === 'needsPermission') location.request()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  return (
    <>
      <h1>Donate &amp; Repair</h1>
      <p className="muted">Places near you that take what Ananeo can't find a home for.</p>
      {location.kind === 'ready' ? (
        <PlacesList coordinate={location.coordinate} />
      ) : location.kind === 'locating' ? (
        <Spinner />
      ) : (
        <>
          {location.kind === 'needsPermission' && (
            <button className="btn primary" onClick={location.request}>📍 Use My Location</button>
          )}
          {location.kind === 'denied' && <p className="error">{location.message}</p>}
          <div className="section-title">Example places</div>
          <List places={SAMPLE} sample />
        </>
      )}
    </>
  )
}

function PlacesList({ coordinate }: { coordinate: Coordinate }) {
  const [kind, setKind] = useState<PlaceKind | null>(null)
  const [places, setPlaces] = useState<Place[]>()
  const [error, setError] = useState<string>()

  useEffect(() => {
    let cancelled = false
    fetchNearbyPlaces(coordinate, 25, kind)
      .then((rows) => {
        if (cancelled) return
        setPlaces(rows)
        setError(undefined)
      })
      .catch((e: Error) => {
        if (!cancelled) setError(e.message)
      })
    return () => {
      cancelled = true
    }
  }, [coordinate, kind])

  return (
    <>
      <div className="chips" role="group" aria-label="Kind">
        <button className="chip" aria-pressed={kind === null} onClick={() => setKind(null)}>All</button>
        {KINDS.map((k) => (
          <button key={k} className="chip" aria-pressed={kind === k} onClick={() => setKind(k)}>{placeKindTitle[k]}</button>
        ))}
      </div>
      <div className="section-title">Within 25 miles</div>
      {error ? (
        <EmptyState icon="📡" title="Couldn't Load Places">{error}</EmptyState>
      ) : !places ? (
        <Spinner />
      ) : places.length === 0 ? (
        <>
          <EmptyState icon="🗺️" title="No Places Listed Here Yet">
            Places are added city by city as Ananeo launches. Until then, here is what the list will look like.
          </EmptyState>
          <List places={SAMPLE} sample />
        </>
      ) : (
        <List places={places} />
      )}
    </>
  )
}

function List({ places, sample = false }: { places: Place[]; sample?: boolean }) {
  return (
    <div className="list">
      {places.map((place) => (
        <div className="list-row static" key={place.id}>
          <div className="grow">
            <div className="row">
              <b>{place.name}</b>
              <span className="badge neutral">{placeKindTitle[place.kind]}</span>
              {place.verified && <span className="badge">Verified</span>}
              {sample && <span className="badge neutral">Example</span>}
            </div>
            <div className="small muted">{place.address}</div>
            <div className="caption">
              {distanceLabel(milesFromKm(place.distance_km))}
              {place.accepts.length > 0 && ` · accepts ${place.accepts.map((c) => categoryTitle[c]).join(', ')}`}
              {place.hours && ` · ${place.hours}`}
            </div>
            {place.website && (
              <a className="small" href={place.website} target="_blank" rel="noreferrer">Website</a>
            )}
          </div>
        </div>
      ))}
    </div>
  )
}
