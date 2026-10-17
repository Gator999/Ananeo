import { useEffect, useRef, useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { Spinner } from '../components/ui'
import { useLocation } from '../lib/geo'
import { preparePhoto } from '../lib/photos'
import { MAX_PHOTOS, errorMessage } from '../lib/supabase'
import { CATEGORIES, CONDITIONS, MODES, categoryTitle, conditionTitle, emptyDraft, modePickerTitle, type ListingDraft } from '../lib/types'
import { useListings } from '../services/listings'

interface Photo {
  blob: Blob
  url: string
}

/** The Give tab: photograph something, describe it, and post it to people nearby. */
export function Give() {
  const listings = useListings()
  const location = useLocation()
  const navigate = useNavigate()
  const fileInput = useRef<HTMLInputElement>(null)

  const [draft, setDraft] = useState<ListingDraft>(emptyDraft)
  const [photos, setPhotos] = useState<Photo[]>([])
  const [loadingPhotos, setLoadingPhotos] = useState(false)
  const [posting, setPosting] = useState(false)
  const [error, setError] = useState<string>()

  useEffect(() => () => photos.forEach((p) => URL.revokeObjectURL(p.url)), [photos])

  const coordinate = location.kind === 'ready' ? location.coordinate : undefined
  const title = draft.title.trim()
  const canPost = title.length > 0 && title.length <= 80 && photos.length > 0 && coordinate !== undefined && !posting && !loadingPhotos

  const set = <K extends keyof ListingDraft>(key: K, value: ListingDraft[K]) => setDraft((d) => ({ ...d, [key]: value }))

  const addPhotos = async (files: FileList | null) => {
    if (!files?.length) return
    setError(undefined)
    setLoadingPhotos(true)
    try {
      const room = MAX_PHOTOS - photos.length
      const prepared: Photo[] = []
      for (const file of Array.from(files).slice(0, room)) {
        const blob = await preparePhoto(file)
        prepared.push({ blob, url: URL.createObjectURL(blob) })
      }
      setPhotos((p) => [...p, ...prepared])
    } catch (e) {
      setError(errorMessage(e))
    } finally {
      setLoadingPhotos(false)
      if (fileInput.current) fileInput.current.value = ''
    }
  }

  const removePhoto = (index: number) =>
    setPhotos((p) => {
      const removed = p[index]
      if (removed) URL.revokeObjectURL(removed.url)
      return p.filter((_, i) => i !== index)
    })

  const post = async (e: FormEvent) => {
    e.preventDefault()
    if (!coordinate) return
    setError(undefined)
    setPosting(true)
    try {
      await listings.create(
        draft,
        photos.map((p) => p.blob),
        coordinate,
      )
      setDraft(emptyDraft)
      setPhotos([])
      // After posting, show the feed so the new item is visible right away.
      navigate('/app/browse')
    } catch (err) {
      setError(`Couldn't post: ${errorMessage(err)}`)
    } finally {
      setPosting(false)
    }
  }

  return (
    <form className="stack" style={{ maxWidth: 640 }} onSubmit={post}>
      <h1>Give</h1>

      <div className="section-title">Photos</div>
      <div className="card">
        <div className="photo-strip">
          {photos.map((photo, i) => (
            <div className="photo" key={photo.url}>
              <img src={photo.url} alt={`Photo ${i + 1}`} />
              <button type="button" aria-label="Remove photo" onClick={() => removePhoto(i)}>
                ×
              </button>
            </div>
          ))}
          {photos.length < MAX_PHOTOS && (
            <button type="button" className="add" onClick={() => fileInput.current?.click()} disabled={loadingPhotos}>
              <span aria-hidden="true">{loadingPhotos ? <Spinner inline /> : '📷'}</span>
              <span>{photos.length ? 'Add more' : 'Add photos'}</span>
            </button>
          )}
        </div>
        <input
          ref={fileInput}
          type="file"
          accept="image/*"
          multiple
          className="sr-only"
          aria-label="Choose photos"
          onChange={(e) => addPhotos(e.target.files)}
        />
        <p className="caption" style={{ margin: '8px 0 0' }}>
          Up to {MAX_PHOTOS}. The first one is the cover. Photos are resized on your device and location data is stripped.
        </p>
      </div>

      <div className="section-title">What is it?</div>
      <div className="card stack">
        <label className="field">
          <span>Title</span>
          <input className="input" maxLength={80} value={draft.title} onChange={(e) => set('title', e.target.value)} placeholder="Oak bookshelf" />
        </label>
        <label className="field">
          <span>Description</span>
          <textarea className="input" maxLength={2000} value={draft.details} onChange={(e) => set('details', e.target.value)} placeholder="Size, any flaws, how heavy it is" />
        </label>
        <label className="field">
          <span>Category</span>
          <select className="input" value={draft.category} onChange={(e) => set('category', e.target.value as ListingDraft['category'])}>
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>{categoryTitle[c]}</option>
            ))}
          </select>
        </label>
        <label className="field">
          <span>Condition</span>
          <select className="input" value={draft.condition} onChange={(e) => set('condition', e.target.value as ListingDraft['condition'])}>
            {CONDITIONS.map((c) => (
              <option key={c} value={c}>{conditionTitle[c]}</option>
            ))}
          </select>
        </label>
      </div>

      <div className="section-title">Offer</div>
      <div className="card stack">
        <div className="segmented" role="group" aria-label="Offer">
          {MODES.map((m) => (
            <button type="button" key={m} aria-pressed={draft.mode === m} onClick={() => set('mode', m)}>
              {modePickerTitle[m]}
            </button>
          ))}
        </div>
        {draft.mode === 'swap' && (
          <label className="field">
            <span>What would you like in return?</span>
            <input className="input" maxLength={200} value={draft.wants} onChange={(e) => set('wants', e.target.value)} />
          </label>
        )}
      </div>

      <div className="section-title">Pickup Area</div>
      <div className="card stack">
        {location.kind === 'ready' && <p className="small" style={{ margin: 0 }}>📍 Shown as an approximate area, within about ¼ mile of where you are now.</p>}
        {location.kind === 'locating' && <p className="muted small" style={{ margin: 0 }}>Finding your area…</p>}
        {location.kind === 'needsPermission' && (
          <button type="button" className="btn" onClick={location.request}>📍 Use My Location</button>
        )}
        {location.kind === 'denied' && (
          <>
            <p className="error" style={{ margin: 0 }}>{location.message}</p>
            <button type="button" className="btn" onClick={location.request}>Try Again</button>
          </>
        )}
        {location.kind === 'unsupported' && <p className="error" style={{ margin: 0 }}>This browser can't share a location, so items can't be posted from it.</p>}
        <p className="caption" style={{ margin: 0 }}>Your exact address is never shown. Share it in a message only when you're ready.</p>
      </div>

      <button className="btn primary lg block" disabled={!canPost} style={{ marginTop: 8 }}>
        {posting ? <Spinner inline /> : 'Post Item'}
      </button>
      {error ? <p className="error center">{error}</p> : photos.length === 0 ? <p className="caption center">Add at least one photo.</p> : null}
    </form>
  )
}
