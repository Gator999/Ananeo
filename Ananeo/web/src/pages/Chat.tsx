import { useEffect, useRef, useState, type FormEvent, type KeyboardEvent } from 'react'
import { Link, useParams } from 'react-router-dom'
import { EmptyState, Spinner } from '../components/ui'
import { timeOfDay } from '../lib/format'
import { errorMessage } from '../lib/supabase'
import type { Message } from '../lib/types'
import { useChat } from '../services/chat'
import { usePickups } from '../services/pickups'

/** Chat between the giver and one requester, about one item. New messages arrive live. */
export function Chat() {
  const { itemID, requestID } = useParams()
  const pickups = usePickups()
  const chat = useChat()

  const pickup = itemID ? pickups.pickupFor(itemID) : undefined
  const request = pickup?.requests.find((r) => r.id === requestID)

  const [messages, setMessages] = useState<Message[]>([])
  const [loaded, setLoaded] = useState(false)
  const [draft, setDraft] = useState('')
  const [sending, setSending] = useState(false)
  const [error, setError] = useState<string>()
  const bottom = useRef<HTMLDivElement>(null)

  const otherUserID = request?.otherUserID

  // Load the history, then append new messages until the screen goes away.
  useEffect(() => {
    if (!requestID || !otherUserID) return
    let cancelled = false
    const append = (message: Message) => {
      let added = false
      setMessages((current) => {
        // Your own messages come back over realtime too, so skip ones already shown.
        if (current.some((m) => m.id === message.id)) return current
        added = true
        return [...current, message]
      })
      return added
    }
    chat
      .messages(requestID)
      .then((history) => {
        if (cancelled) return
        setMessages(history)
        setError(undefined)
        setLoaded(true)
        chat.markRead(requestID)
      })
      .catch((e: Error) => {
        if (!cancelled) {
          setError(e.message)
          setLoaded(true)
        }
      })
    const stop = chat.listen(requestID, (message) => {
      if (append(message) && message.sender_id === otherUserID) chat.markRead(requestID)
    })
    return () => {
      cancelled = true
      stop()
    }
    // chat's functions are stable; re-run only when the conversation changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [requestID, otherUserID])

  useEffect(() => {
    bottom.current?.scrollIntoView({ block: 'end' })
  }, [messages.length, loaded])

  if (!pickup || !request) {
    return <EmptyState icon="🗂️" title="No Longer in Pickups" action={<Link className="btn" to="/app/pickups">Back to Pickups</Link>} />
  }

  const trimmed = draft.trim()

  const send = async (e?: FormEvent) => {
    e?.preventDefault()
    if (!trimmed || sending) return
    setError(undefined)
    setSending(true)
    try {
      const message = await chat.send(trimmed, request.id)
      setMessages((current) => (current.some((m) => m.id === message.id) ? current : [...current, message]))
      setDraft('')
    } catch (err) {
      setError(errorMessage(err))
    } finally {
      setSending(false)
    }
  }

  const onKey = (e: KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      send()
    }
  }

  return (
    <div className="chat">
      <div className="row">
        <Link to={`/app/pickups/${pickup.id}`} className="btn plain" style={{ paddingLeft: 0 }}>‹ Back</Link>
        <div className="grow center">
          <div style={{ fontWeight: 700 }}>{request.otherName}</div>
          <div className="caption truncate">{pickup.title}</div>
        </div>
        <span style={{ width: 64 }} />
      </div>

      <div className="chat-log">
        {!loaded ? (
          <Spinner />
        ) : messages.length === 0 ? (
          <EmptyState icon="💬" title="No Messages Yet">
            Sort out when and where to meet. Keep exact addresses until you've agreed on a time.
          </EmptyState>
        ) : (
          messages.map((message) => {
            const mine = message.sender_id !== request.otherUserID
            return (
              <div key={message.id} className={mine ? 'bubble mine' : 'bubble'}>
                <p>{message.body}</p>
                <span className="caption">{timeOfDay(message.created_at)}</span>
              </div>
            )
          })
        )}
        <div ref={bottom} />
      </div>

      <form className="composer" onSubmit={send}>
        <textarea
          className="input grow"
          rows={1}
          placeholder="Message"
          aria-label="Message"
          value={draft}
          maxLength={2000}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={onKey}
        />
        <button className="btn primary" disabled={!trimmed || sending} aria-label="Send">
          {sending ? <Spinner inline /> : '↑'}
        </button>
      </form>
      {error && <p className="error">{error}</p>}
    </div>
  )
}
