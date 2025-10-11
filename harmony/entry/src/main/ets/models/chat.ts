import { normalizeDate } from '../utils/dates';
import { HandleSummary, MessageModel, parseMessage } from './message';

export interface ChatSummary {
  guid: string;
  displayName?: string;
  participants: HandleSummary[];
  lastMessage?: MessageModel;
  hasUnreadMessage: boolean;
  pinIndex?: number;
}

function parseParticipants(json: unknown): HandleSummary[] {
  if (!Array.isArray(json)) {
    return [];
  }
  return json
    .map(item => item as Record<string, unknown>)
    .filter(item => !!item)
    .map(item => {
      const address = typeof item['address'] === 'string' ? item['address'] as string : '';
      const displayName = typeof item['displayName'] === 'string' ? item['displayName'] as string : undefined;
      const firstName = typeof item['firstName'] === 'string' ? item['firstName'] as string : undefined;
      const lastName = typeof item['lastName'] === 'string' ? item['lastName'] as string : undefined;
      let initials = typeof item['initials'] === 'string' ? item['initials'] as string : undefined;
      if (!initials) {
        const fallbackSource = displayName ?? address;
        initials = fallbackSource
          .split(/\s+/)
          .filter(token => token.length > 0)
          .map(token => token[0])
          .join('')
          .substring(0, 2)
          .toUpperCase();
      }
      return {
        address,
        displayName,
        firstName,
        lastName,
        initials,
      } as HandleSummary;
    });
}

export function computeChatTitle(chat: ChatSummary): string {
  if (chat.displayName && chat.displayName.trim().length > 0) {
    return chat.displayName;
  }
  const names = chat.participants
    .map(participant => participant.displayName ?? participant.address)
    .filter(name => !!name && name.trim().length > 0);
  if (names.length === 0) {
    return 'Unnamed Chat';
  }
  return names.join(', ');
}

export function computeChatSubtitle(chat: ChatSummary): string {
  const message = chat.lastMessage;
  if (!message) {
    return 'No messages yet';
  }
  if (message.text && message.text.trim().length > 0) {
    return message.text.trim();
  }
  if (message.hasAttachments) {
    return 'Attachment';
  }
  return 'Message';
}

export function parseChat(json: Record<string, unknown>): ChatSummary {
  const guid = typeof json['guid'] === 'string' ? json['guid'] as string : '';
  const displayName = typeof json['displayName'] === 'string' ? json['displayName'] as string : undefined;
  const hasUnreadValue = json['hasUnreadMessage'];
  const hasUnreadMessage = typeof hasUnreadValue === 'boolean'
    ? hasUnreadValue
    : typeof hasUnreadValue === 'number'
      ? hasUnreadValue === 1
      : typeof hasUnreadValue === 'string'
        ? ['true', '1'].includes(hasUnreadValue)
        : false;
  const lastMessageJson = json['lastMessage'] as Record<string, unknown> | undefined;
  const lastMessage = lastMessageJson ? parseMessage(lastMessageJson) : undefined;
  if (lastMessage && !lastMessage.dateCreated && typeof json['latestMessageDate'] !== 'undefined') {
    lastMessage.dateCreated = normalizeDate(json['latestMessageDate']);
  }
  const pinIndex = typeof json['_pinIndex'] === 'number' ? json['_pinIndex'] as number : undefined;
  return {
    guid,
    displayName,
    participants: parseParticipants(json['participants']),
    lastMessage,
    hasUnreadMessage,
    pinIndex,
  };
}
