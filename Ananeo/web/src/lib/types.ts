// These mirror the Postgres enums in supabase/migrations and the Swift models in Ananeo/Models.
// Raw values must match the database exactly.

export const CATEGORIES = ['furniture', 'clothing', 'electronics', 'tools', 'books', 'household', 'materials', 'other'] as const
export type ItemCategory = (typeof CATEGORIES)[number]

export const CONDITIONS = ['like_new', 'good', 'worn', 'needs_repair', 'for_parts'] as const
export type ItemCondition = (typeof CONDITIONS)[number]

export const MODES = ['give', 'swap', 'parts'] as const
export type ItemMode = (typeof MODES)[number]

export type ItemStatus = 'available' | 'reserved' | 'handed_off' | 'removed'

export type PlaceKind = 'donation' | 'repair' | 'ewaste' | 'textile'

export const categoryTitle: Record<ItemCategory, string> = {
  furniture: 'Furniture',
  clothing: 'Clothing',
  electronics: 'Electronics',
  tools: 'Tools',
  books: 'Books',
  household: 'Household',
  materials: 'Materials',
  other: 'Other',
}

export const categoryEmoji: Record<ItemCategory, string> = {
  furniture: '🛋️',
  clothing: '👕',
  electronics: '💻',
  tools: '🔧',
  books: '📚',
  household: '🏠',
  materials: '📦',
  other: '🔹',
}

export const conditionTitle: Record<ItemCondition, string> = {
  like_new: 'Like new',
  good: 'Good',
  worn: 'Worn',
  needs_repair: 'Needs repair',
  for_parts: 'For parts',
}

/** Short label shown on a listing, e.g. "Free". */
export const modeTitle: Record<ItemMode, string> = { give: 'Free', swap: 'Swap', parts: 'Parts' }
/** Longer label used when choosing how to offer an item. */
export const modePickerTitle: Record<ItemMode, string> = { give: 'Give away', swap: 'Swap', parts: 'Parts' }

export const placeKindTitle: Record<PlaceKind, string> = {
  donation: 'Donation',
  repair: 'Repair',
  ewaste: 'E-waste',
  textile: 'Textiles',
}

/** A listing as returned by `nearby_items` or a select on `items`. */
export interface Listing {
  id: string
  owner_id: string
  title: string
  details: string
  category: ItemCategory
  condition: ItemCondition
  mode: ItemMode
  status: ItemStatus
  wants: string | null
  est_kg: number
  photos: string[]
  created_at: string
  /** Present only in nearby results. Already fuzzed by the server. */
  distance_km?: number
}

/** What the Give form collects before posting. */
export interface ListingDraft {
  title: string
  details: string
  category: ItemCategory
  condition: ItemCondition
  mode: ItemMode
  wants: string
}

export const emptyDraft: ListingDraft = {
  title: '',
  details: '',
  category: 'household',
  condition: 'good',
  mode: 'give',
  wants: '',
}

export interface Impact {
  items_given: number
  items_received: number
  kg_diverted: number
}

export interface CommunityImpact {
  items_kept_moving: number
  kg_diverted: number
}

export interface Place {
  id: string
  kind: PlaceKind
  name: string
  address: string
  accepts: ItemCategory[]
  hours: string | null
  website: string | null
  verified: boolean
  latitude: number
  longitude: number
  distance_km: number
}

/** One chat message on a pickup request. */
export interface Message {
  id: string
  conversation_id: string
  sender_id: string
  body: string
  created_at: string
}

/** The latest message on a request and how many from the other person are unread. */
export interface ChatSummary {
  lastBody: string
  lastSenderIsMe: boolean
  lastAt: string
  unreadCount: number
}

/** A reservation, seen from the signed-in user's side. */
export interface Handoff {
  id: string
  confirmedByMe: boolean
  confirmedByThem: boolean
  completedAt: string | null
}

/** One person's request for an item. */
export interface PickupRequest {
  id: string
  /** The requester when you're giving, the giver when you're getting. */
  otherUserID: string
  otherName: string
  requestedAt: string
  /** Present only when the item is reserved for or was handed off to this request. */
  handoff: Handoff | null
}

export type PickupStage = 'open' | 'reserved' | 'done' | 'unavailable'

/** An item the signed-in user is giving or getting, from the first request to a confirmed handoff. */
export interface Pickup {
  /** The item's ID. */
  id: string
  title: string
  category: ItemCategory
  photo: string | null
  status: ItemStatus
  isGiver: boolean
  /** Givers see everyone who asked, oldest first. Receivers see only their own request. */
  requests: PickupRequest[]
}

/** The request the item is reserved for or was handed off to, when it's yours to see. */
export function reservation(pickup: Pickup): PickupRequest | undefined {
  return pickup.requests.find((r) => r.handoff !== null)
}

export function stage(pickup: Pickup): PickupStage {
  const handoff = reservation(pickup)?.handoff
  if (handoff) return handoff.completedAt === null ? 'reserved' : 'done'
  return pickup.status === 'available' ? 'open' : 'unavailable'
}

/** True when the next step is the signed-in user's: choosing someone, or confirming a handoff. */
export function needsYou(pickup: Pickup): boolean {
  switch (stage(pickup)) {
    case 'open':
      return pickup.isGiver
    case 'reserved':
      return reservation(pickup)?.handoff?.confirmedByMe === false
    default:
      return false
  }
}
