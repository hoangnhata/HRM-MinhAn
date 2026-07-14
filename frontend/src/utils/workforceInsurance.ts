export function isMaternityLeaveInsurance(value: unknown): boolean {
  if (value == null) return false;
  const text = String(value).trim();
  if (!text) return false;
  const normalized = text.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase();
  return normalized.includes('thai san');
}
