export function createTempGuid(): string {
  const random = Math.floor(Math.random() * 0xffffffff).toString(16).padStart(8, '0');
  const timestamp = Date.now().toString(16);
  return `${timestamp}-${random}`;
}
