import { normalizeDate } from '../utils/dates';

export interface HandleSummary {
  address: string;
  displayName?: string;
  firstName?: string;
  lastName?: string;
  initials?: string;
}

export interface MessageModel {
  guid: string;
  text: string;
  isFromMe: boolean;
  dateCreated: Date;
  handle?: HandleSummary;
  hasAttachments: boolean;
}

function extractHandle(json: Record<string, unknown> | undefined): HandleSummary | undefined {
  if (!json) {
    return undefined;
  }
  const address = typeof json['address'] === 'string' ? json['address'] as string : '';
  const displayName = typeof json['displayName'] === 'string' ? json['displayName'] as string : undefined;
  const firstName = typeof json['firstName'] === 'string' ? json['firstName'] as string : undefined;
  const lastName = typeof json['lastName'] === 'string' ? json['lastName'] as string : undefined;
  let initials = typeof json['initials'] === 'string' ? json['initials'] as string : undefined;
  if (!initials && displayName) {
    initials = displayName
      .split(' ')
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
  };
}

export function parseMessage(json: Record<string, unknown>): MessageModel {
  const guid = typeof json['guid'] === 'string' ? json['guid'] as string : '';
  const text = typeof json['text'] === 'string' ? json['text'] as string :
    typeof json['message'] === 'string' ? json['message'] as string : '';
  const isFromMeValue = json['isFromMe'];
  const isFromMe = typeof isFromMeValue === 'boolean'
    ? isFromMeValue
    : typeof isFromMeValue === 'number'
      ? isFromMeValue === 1
      : typeof isFromMeValue === 'string'
        ? ['true', '1'].includes(isFromMeValue)
        : false;
  const dateRaw = json['dateCreated'] ?? json['dateModified'] ?? json['date'];
  const dateCreated = normalizeDate(dateRaw);
  const attachments = Array.isArray(json['attachments']) ? json['attachments'] : [];
  const handle = extractHandle(json['handle'] as Record<string, unknown> | undefined);
  return {
    guid,
    text,
    isFromMe,
    dateCreated,
    handle,
    hasAttachments: attachments.length > 0,
  };
}
