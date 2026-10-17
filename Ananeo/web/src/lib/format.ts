/** The database works in kilometers. The site shows miles, like the iOS app. */
export const KM_PER_MILE = 1.609344

export function milesFromKm(km: number): number {
  return km / KM_PER_MILE
}

export function kmFromMiles(miles: number): number {
  return miles * KM_PER_MILE
}

/** Listing locations are fuzzed by up to a quarter mile, so short distances read as approximate. */
export function distanceLabel(miles: number): string {
  if (miles < 0.3) return 'Under ¼ mi'
  if (miles < 10) return `About ${miles.toFixed(1)} mi`
  return `About ${miles.toFixed(0)} mi`
}

export function distanceLabelKm(km: number | undefined): string | undefined {
  return km === undefined ? undefined : distanceLabel(milesFromKm(km))
}

const relative = new Intl.RelativeTimeFormat('en', { numeric: 'auto' })

/** "3 hours ago", "yesterday", "last month". */
export function relativeTime(iso: string, now = Date.now()): string {
  const seconds = Math.round((new Date(iso).getTime() - now) / 1000)
  const abs = Math.abs(seconds)
  if (abs < 60) return 'just now'
  if (abs < 3600) return relative.format(Math.round(seconds / 60), 'minute')
  if (abs < 86400) return relative.format(Math.round(seconds / 3600), 'hour')
  if (abs < 86400 * 30) return relative.format(Math.round(seconds / 86400), 'day')
  if (abs < 86400 * 365) return relative.format(Math.round(seconds / (86400 * 30)), 'month')
  return relative.format(Math.round(seconds / (86400 * 365)), 'year')
}

export function timeOfDay(iso: string): string {
  return new Date(iso).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
}

export function monthDay(iso: string): string {
  return new Date(iso).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })
}

export function kg(value: number, digits = 1): string {
  return `${Number(value).toFixed(digits)} kg`
}
