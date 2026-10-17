import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react'
import type { Coordinate } from '../lib/geo'
import { kmFromMiles } from '../lib/format'
import { MAX_PHOTOS, PHOTO_BUCKET, errorMessage, supabase } from '../lib/supabase'
import type { CommunityImpact, Impact, ItemCategory, Listing, ListingDraft, Place, PlaceKind } from '../lib/types'

/** Reads and writes listings and their photos. `revision` bumps after any change so feeds reload. */
interface ListingsContextValue {
  revision: number
  nearby: (coordinate: Coordinate, radiusMiles: number, category: ItemCategory | null) => Promise<Listing[]>
  create: (draft: ListingDraft, photos: Blob[], at: Coordinate) => Promise<void>
  remove: (listing: Listing) => Promise<void>
}

const ListingsContext = createContext<ListingsContextValue | null>(null)

export async function fetchNearby(coordinate: Coordinate, radiusMiles: number, category: ItemCategory | null): Promise<Listing[]> {
  const { data, error } = await supabase.rpc('nearby_items', {
    lat: coordinate.latitude,
    lng: coordinate.longitude,
    radius_km: kmFromMiles(radiusMiles),
    only_category: category,
    max_results: 100,
  })
  if (error) throw new Error(errorMessage(error))
  return (data ?? []) as Listing[]
}

export async function fetchMyImpact(): Promise<Impact> {
  const { data, error } = await supabase.rpc('my_impact')
  if (error) throw new Error(errorMessage(error))
  const row = (data as Impact[] | null)?.[0]
  return row ? { ...row, kg_diverted: Number(row.kg_diverted) } : { items_given: 0, items_received: 0, kg_diverted: 0 }
}

export async function fetchCommunityImpact(): Promise<CommunityImpact> {
  const { data, error } = await supabase.rpc('community_impact')
  if (error) throw new Error(errorMessage(error))
  const row = (data as CommunityImpact[] | null)?.[0]
  return row ? { ...row, kg_diverted: Number(row.kg_diverted) } : { items_kept_moving: 0, kg_diverted: 0 }
}

export async function fetchNearbyPlaces(coordinate: Coordinate, radiusMiles: number, kind: PlaceKind | null): Promise<Place[]> {
  const { data, error } = await supabase.rpc('nearby_places', {
    lat: coordinate.latitude,
    lng: coordinate.longitude,
    radius_km: kmFromMiles(radiusMiles),
    only_kind: kind,
    max_results: 100,
  })
  if (error) throw new Error(errorMessage(error))
  return (data ?? []) as Place[]
}

export function ListingsProvider({ children }: { children: ReactNode }) {
  const [revision, setRevision] = useState(0)

  const create = useCallback(async (draft: ListingDraft, photos: Blob[], at: Coordinate) => {
    const {
      data: { user },
    } = await supabase.auth.getUser()
    if (!user) throw new Error('Sign in to post an item.')
    // Storage policies compare against auth.uid()::text, which is lowercase.
    const folder = user.id.toLowerCase()
    const storage = supabase.storage.from(PHOTO_BUCKET)
    const uploaded: string[] = []

    try {
      for (const photo of photos.slice(0, MAX_PHOTOS)) {
        const path = `${folder}/${crypto.randomUUID()}.jpg`
        const { error } = await storage.upload(path, photo, { contentType: 'image/jpeg' })
        if (error) throw new Error(error.message)
        uploaded.push(path)
      }
      const wants = draft.wants.trim()
      const { error } = await supabase.from('items').insert({
        title: draft.title.trim(),
        details: draft.details.trim(),
        category: draft.category,
        condition: draft.condition,
        mode: draft.mode,
        wants: draft.mode === 'swap' && wants ? wants : null,
        // Exact point as EWKT. The database fuzzes it before storing.
        location: `SRID=4326;POINT(${at.longitude} ${at.latitude})`,
        photos: uploaded,
      })
      if (error) throw new Error(errorMessage(error))
    } catch (error) {
      // Don't leave orphan photos behind if the listing itself failed.
      if (uploaded.length) await storage.remove(uploaded).catch(() => {})
      throw error
    }
    setRevision((r) => r + 1)
  }, [])

  /** Hides a listing from everyone. The row stays so history and impact remain intact. */
  const remove = useCallback(async (listing: Listing) => {
    const { error } = await supabase.from('items').update({ status: 'removed' }).eq('id', listing.id)
    if (error) throw new Error(errorMessage(error))
    setRevision((r) => r + 1)
  }, [])

  const value = useMemo(() => ({ revision, nearby: fetchNearby, create, remove }), [revision, create, remove])
  return <ListingsContext.Provider value={value}>{children}</ListingsContext.Provider>
}

export function useListings(): ListingsContextValue {
  const value = useContext(ListingsContext)
  if (!value) throw new Error('useListings needs a ListingsProvider')
  return value
}
