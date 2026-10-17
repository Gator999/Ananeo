import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const key = import.meta.env.VITE_SUPABASE_KEY as string | undefined

/** True when the build is missing its backend settings. The app shows setup help instead of crashing. */
export const isConfigured = Boolean(url && key)

/** True when pointed at the local `supabase start` stack. */
export const isLocalBackend = Boolean(url && /^(https?:\/\/)?(127\.0\.0\.1|localhost)/.test(url))

export type SignInMethod = 'email' | 'apple' | 'google'

/** Which sign-in buttons to show, from VITE_SIGN_IN_METHODS (comma separated). Defaults to email only. */
export const signInMethods: SignInMethod[] = ((import.meta.env.VITE_SIGN_IN_METHODS as string | undefined) ?? 'email')
  .split(',')
  .map((m) => m.trim().toLowerCase())
  .filter((m): m is SignInMethod => m === 'email' || m === 'apple' || m === 'google')

export const supabase = createClient(url ?? 'http://127.0.0.1:54321', key ?? 'missing')

export const PHOTO_BUCKET = 'item-photos'
export const MAX_PHOTOS = 5

export function photoURL(path: string | null | undefined): string | undefined {
  if (!path) return undefined
  return supabase.storage.from(PHOTO_BUCKET).getPublicUrl(path).data.publicUrl
}

/** Supabase errors carry a Postgres code; the app reads it to tell "taken" from "offline". */
export function errorCode(error: unknown): string | undefined {
  if (error && typeof error === 'object' && 'code' in error) return String((error as { code: unknown }).code)
  return undefined
}

export function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message
  if (error && typeof error === 'object' && 'message' in error) return String((error as { message: unknown }).message)
  return String(error)
}
