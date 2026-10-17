import { useEffect, type ReactNode } from 'react'
import { photoURL } from '../lib/supabase'
import { categoryEmoji, type ItemCategory } from '../lib/types'

/** Remote photo with a category icon when there is none. */
export function Thumb({ path, category, large = false }: { path: string | null | undefined; category: ItemCategory; large?: boolean }) {
  const url = photoURL(path)
  return (
    <div className={large ? 'thumb lg' : 'thumb'} aria-hidden="true">
      {url ? <img src={url} alt="" loading="lazy" /> : <span>{categoryEmoji[category]}</span>}
    </div>
  )
}

export function Spinner({ inline = false }: { inline?: boolean }) {
  return <div className={inline ? 'spinner inline' : 'spinner'} role="status" aria-label="Loading" />
}

export function EmptyState({ icon, title, children, action }: { icon: string; title: string; children?: ReactNode; action?: ReactNode }) {
  return (
    <div className="empty">
      <div className="icon" aria-hidden="true">{icon}</div>
      <h3>{title}</h3>
      {children && <p>{children}</p>}
      {action}
    </div>
  )
}

export function Stat({ value, label }: { value: string; label: string }) {
  return (
    <div className="stat">
      <b>{value}</b>
      <span>{label}</span>
    </div>
  )
}

interface ConfirmProps {
  open: boolean
  title: string
  message?: string
  confirmLabel: string
  destructive?: boolean
  onConfirm: () => void
  onCancel: () => void
}

/** A confirmation sheet, like the iOS confirmation dialog. */
export function Confirm({ open, title, message, confirmLabel, destructive = false, onConfirm, onCancel }: ConfirmProps) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onCancel()
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open, onCancel])
  if (!open) return null
  return (
    <div className="dialog-backdrop" onClick={onCancel}>
      <div className="dialog" role="dialog" aria-modal="true" aria-labelledby="dialog-title" onClick={(e) => e.stopPropagation()}>
        <h3 id="dialog-title">{title}</h3>
        {message && <p className="muted small">{message}</p>}
        <div className="actions">
          <button className={destructive ? 'btn danger block' : 'btn primary block'} onClick={onConfirm}>
            {confirmLabel}
          </button>
          <button className="btn block" onClick={onCancel}>
            Cancel
          </button>
        </div>
      </div>
    </div>
  )
}
