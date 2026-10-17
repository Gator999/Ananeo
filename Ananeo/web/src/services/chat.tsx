import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import { errorCode, errorMessage, supabase } from '../lib/supabase'
import type { ChatSummary, Message, Pickup, PickupRequest } from '../lib/types'
import { useAuth } from './auth'

/**
 * Chat between the giver and a requester, one conversation per pickup request.
 * Keeps an inbox summary per request so the Pickups tab can show the latest message and unread counts.
 */
interface ChatContextValue {
  /** Keyed by pickup request (conversation) ID. Requests with no messages have no entry. */
  summaries: Record<string, ChatSummary>
  summaryFor: (request: PickupRequest) => ChatSummary | undefined
  unreadIn: (pickup: Pickup) => number
  unreadAcross: (pickups: Pickup[]) => number
  refresh: () => Promise<void>
  /** The most recent messages, oldest first. */
  messages: (conversationID: string, limit?: number) => Promise<Message[]>
  /** Sends a message. The server stamps the sender and time. */
  send: (body: string, conversationID: string) => Promise<Message>
  /** Marks the conversation read up to now. */
  markRead: (conversationID: string) => Promise<void>
  /**
   * Calls `onMessage` for each new message in one conversation. Row level security decides what arrives.
   * Returns a function that stops listening.
   */
  listen: (conversationID: string, onMessage: (message: Message) => void) => () => void
}

const ChatContext = createContext<ChatContextValue | null>(null)

interface Row {
  conversation_id: string
  last_body: string
  last_sender_is_me: boolean
  last_at: string
  unread_count: number
}

export class BlockedError extends Error {
  constructor() {
    super("You can't message this person.")
  }
}

function subscribe(conversationID: string | null, onMessage: (message: Message) => void): () => void {
  const channel = supabase
    .channel(`messages-${conversationID ?? 'all'}-${crypto.randomUUID()}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'messages',
        ...(conversationID ? { filter: `conversation_id=eq.${conversationID}` } : {}),
      },
      (payload) => onMessage(payload.new as Message),
    )
    .subscribe()
  return () => {
    supabase.removeChannel(channel).catch(() => {})
  }
}

export function ChatProvider({ children }: { children: ReactNode }) {
  const { userID } = useAuth()
  const [summaries, setSummaries] = useState<Record<string, ChatSummary>>({})

  const refresh = useCallback(async () => {
    const { data, error } = await supabase.rpc('my_chats')
    if (error) throw new Error(errorMessage(error))
    const next: Record<string, ChatSummary> = {}
    for (const row of (data ?? []) as Row[]) {
      next[row.conversation_id] = {
        lastBody: row.last_body,
        lastSenderIsMe: row.last_sender_is_me,
        lastAt: row.last_at,
        unreadCount: row.unread_count,
      }
    }
    setSummaries(next)
  }, [])

  // Keep the inbox current while signed in, through one realtime channel on messages.
  useEffect(() => {
    setSummaries({})
    if (!userID) return
    refresh().catch(() => {})
    return subscribe(null, () => {
      refresh().catch(() => {})
    })
  }, [userID, refresh])

  const messages = useCallback(async (conversationID: string, limit = 200) => {
    const { data, error } = await supabase
      .from('messages')
      .select()
      .eq('conversation_id', conversationID)
      .order('created_at', { ascending: false })
      .limit(limit)
    if (error) throw new Error(errorMessage(error))
    return ((data ?? []) as Message[]).reverse()
  }, [])

  const send = useCallback(async (body: string, conversationID: string) => {
    const { data, error } = await supabase.from('messages').insert({ conversation_id: conversationID, body }).select().single()
    // Blocked, or the request was withdrawn since the chat opened.
    if (error && errorCode(error) === '42501') throw new BlockedError()
    if (error) throw new Error(errorMessage(error))
    return data as Message
  }, [])

  const markRead = useCallback(async (conversationID: string) => {
    const { error } = await supabase.rpc('mark_conversation_read', { p_conversation_id: conversationID })
    if (error) return
    setSummaries((current) => {
      const summary = current[conversationID]
      if (!summary || summary.unreadCount === 0) return current
      return { ...current, [conversationID]: { ...summary, unreadCount: 0 } }
    })
  }, [])

  const listen = useCallback((conversationID: string, onMessage: (message: Message) => void) => subscribe(conversationID, onMessage), [])

  const value = useMemo<ChatContextValue>(() => {
    const unreadIn = (pickup: Pickup) => pickup.requests.reduce((sum, r) => sum + (summaries[r.id]?.unreadCount ?? 0), 0)
    return {
      summaries,
      summaryFor: (request) => summaries[request.id],
      unreadIn,
      unreadAcross: (pickups) => pickups.reduce((sum, p) => sum + unreadIn(p), 0),
      refresh,
      messages,
      send,
      markRead,
      listen,
    }
  }, [summaries, refresh, messages, send, markRead, listen])

  return <ChatContext.Provider value={value}>{children}</ChatContext.Provider>
}

export function useChat(): ChatContextValue {
  const value = useContext(ChatContext)
  if (!value) throw new Error('useChat needs a ChatProvider')
  return value
}
