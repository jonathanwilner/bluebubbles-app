export function normalizeDate(value: unknown): Date {
  if (value instanceof Date) {
    return value;
  }
  if (typeof value === 'number') {
    if (value > 1_000_000_000_000) {
      return new Date(value);
    }
    return new Date(value * 1000);
  }
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (!trimmed) {
      return new Date(0);
    }
    const asNumber = Number(trimmed);
    if (!Number.isNaN(asNumber)) {
      return normalizeDate(asNumber);
    }
    const parsed = Date.parse(trimmed);
    if (!Number.isNaN(parsed)) {
      return new Date(parsed);
    }
  }
  return new Date(0);
}

export function formatRelativeTime(date: Date): string {
  const now = Date.now();
  const difference = now - date.getTime();
  const seconds = Math.floor(difference / 1000);
  if (seconds < 60) {
    return 'Just now';
  }
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) {
    return `${minutes} min`;
  }
  const hours = Math.floor(minutes / 60);
  if (hours < 24) {
    return `${hours} hr`;
  }
  const days = Math.floor(hours / 24);
  if (days < 7) {
    return `${days} d`;
  }
  const weeks = Math.floor(days / 7);
  if (weeks < 4) {
    return `${weeks} wk`;
  }
  return date.toLocaleDateString();
}

export function formatTimestamp(date: Date): string {
  const formatter = new Intl.DateTimeFormat('default', {
    hour: 'numeric',
    minute: '2-digit',
  });
  return formatter.format(date);
}
