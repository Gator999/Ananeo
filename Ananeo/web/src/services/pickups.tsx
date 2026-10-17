import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { errorCode, errorMessage, supabase } from '../lib/supabase'
import { needsYou, type Handoff, type ItemCategory, type ItemStatus, type Listing, type Pickup, type PickupRequest } from '../lib/types'
import { useAuth } from './auth'

/**
 * Pickup requests, reservations, and two-sided handoff confirmation.
 * Keeps the signed-in user's pickups so the tab, its detail screens, and listing pages agree.
 */
interface PickupsContextValue {
  all: Pickup[]
  hasLoaded: boolean
  /** Bumped after any change so impact totals know to reload. */
  revision: number
  needsYouCount: number
  pickupFor: (itemID: string) => Pickup | undefined
  refresh: () => Promise<void>
  /** Asks the owner for an item. Asking twice is harmless. */
  request: (listing: Listing) => Promise<void>
  /** Withdraws a request. If the item was reserved for you, the giver can choose someone else. */
  withdraw: (pickup: Pickup) => Promise<void>
  /** Reserves the item for one person. It leaves the Browse feed until the handoff or a cancel. */
  reserve: (pickup: Pickup, request: PickupRequest) => Promise<void>
  /** Makes the item available again. Everyone's requests stay open. */
  cancelReservation: (pickup: Pickup) => Promise<void>
  /** Confirms your half of the handoff. Once both people confirm, the item counts toward impact. */
  confirm: (handoff: Handoff) => Promise<void>
}

const PickupsContext = createContext<PickupsContextValue | null>(null)

/** One row per request, as returned by `my_pickups`. */
interface Row {
  request_id: string
  item_id: string
  title: string
  category: ItemCategory
  photo: string | null
  item_status: ItemStatus
  is_giver: boolean
  other_user_id: string
  other_name: string
  requested_at: string
  handoff_id: string | null
  confirmed_by_me: boolean
  confirmed_by_them: boolean
  completed_at: string | null
}

/** Groups rows by item, keeping the server's most-recent-first order. */
export function groupRows(rows: Row[]): Pickup[] {
  const order: string[] = []
  const byItem = new Map<string, Row[]>()
  for (const row of rows) {
    if (!byItem.has(row.item_id)) {
      order.push(row.item_id)
      byItem.set(row.item_id, [])
    }
    byItem.get(row.item_id)!.push(row)
  }
  return order.flatMap((itemID) => {
    const itemRows = byItem.get(itemID)
    const first = itemRows?.[0]
    if (!itemRows || !first) return []
    const requests: PickupRequest[] = itemRows
      .map((row) => ({
        id: row.request_id,
        otherUserID: row.other_user_id,
        otherName: row.other_name,
        requestedAt: row.requested_at,
        handoff: row.handoff_id
          ? { id: row.handoff_id, confirmedByMe: row.confirmed_by_me, confirmedByThem: row.confirmed_by_them, completedAt: row.completed_at }
          : null,
      }))
      .sort((a, b) => a.requestedAt.localeCompare(b.requestedAt))
    return [
      {
        id: itemID,
        title: first.title,
        category: first.category,
        photo: first.photo,
        status: first.item_status,
        isGiver: first.is_giver,
        requests,
      },
    ]
  })
}

export class UnavailableError extends Error {
  constructor() {
    super('This item is no longer available.')
  }
}

export function PickupsProvider({ children }: { children: ReactNode }) {
  const { userID } = useAuth()
  const [all, setAll] = useState<Pickup[]>([])
  const [hasLoaded, setHasLoaded] = useState(false)
  const [revision, setRevision] = useState(0)
  const owner = useRef(userID)

  const refresh = useCallback(async () => {
    const { data, error } = await supabase.rpc('my_pickups')
    if (error) throw new Error(errorMessage(error))
    setAll(groupRows((data ?? []) as Row[]))
    setHasLoaded(true)
  }, [])

  // One account's pickups must never show for the next.
  useEffect(() => {
    if (owner.current !== userID) {
      owner.current = userID
      setAll([])
      setHasLoaded(false)
    }
    if (userID) refresh().catch(() => {})
  }, [userID, refresh])

  /** The write already succeeded, so a failed reload only leaves the list stale until the next refresh. */
  const changed = useCallback(async () => {
    setRevision((r) => r + 1)
    await refresh().catch(() => {})
  }, [refresh])

  const request = useCallback(
    async (listing: Listing) => {
      const { error } = await supabase.from('conversations').insert({ item_id: listing.id, giver_id: listing.owner_id })
      if (error) {
        const code = errorCode(error)
        // 23505: already asked, maybe from another device. 42501: reserved or taken down since the feed loaded.
        if (code === '42501') throw new UnavailableError()
        if (code !== '23505') throw new Error(errorMessage(error))
      }
      await changed()
    },
    [changed],
  )

  const rpc = useCallback(
    async (fn: string, params: Record<string, string>) => {
      const { error } = await supabase.rpc(fn, params)
      if (error) throw new Error(errorMessage(error))
      await changed()
    },
    [changed],
  )

  const withdraw = useCallback((pickup: Pickup) => rpc('withdraw_request', { p_item_id: pickup.id }), [rpc])
  const reserve = useCallback(
    (pickup: Pickup, req: PickupRequest) => rpc('reserve_item', { p_item_id: pickup.id, p_receiver_id: req.otherUserID }),
    [rpc],
  )
  const cancelReservation = useCallback((pickup: Pickup) => rpc('cancel_reservation', { p_item_id: pickup.id }), [rpc])
  const confirm = useCallback((handoff: Handoff) => rpc('confirm_handoff', { p_handoff_id: handoff.id }), [rpc])

  const value = useMemo<PickupsContextValue>(
    () => ({
      all,
      hasLoaded,
      revision,
      needsYouCount: all.filter(needsYou).length,
      pickupFor: (itemID) => all.find((p) => p.id === itemID),
      refresh,
      request,
      withdraw,
      reserve,
      cancelReservation,
      confirm,
    }),
    [all, hasLoaded, revision, refresh, request, withdraw, reserve, cancelReservation, confirm],
  )

  return <PickupsContext.Provider value={value}>{children}</PickupsContext.Provider>
}

export function usePickups(): PickupsContextValue {
  const value = useContext(PickupsContext)
  if (!value) throw new Error('usePickups needs a PickupsProvider')
  return value
}
