import api from './api';
import { fetchAccountMe } from './accountService';

/** Chuẩn hoá URL đầy đủ `/j1-api/v1/...` → path axios `/v1/...`. */
function toApiPath(url: string): string {
  const u = url.trim();
  if (u.startsWith('/j1-api')) return u.slice('/j1-api'.length) || '/';
  return u.startsWith('/') ? u : `/${u}`;
}

export function extractApiErrorMessage(e: unknown, fallback: string): string {
  const msg = (e as { response?: { data?: { message?: string } }; message?: string })?.response?.data
    ?.message;
  if (msg) return msg;
  const plain = (e as { message?: string })?.message;
  if (plain && plain !== 'Network Error') return plain;
  return fallback;
}

/** Kiểm tra user đã có chữ ký trước khi gọi API duyệt. */
export async function ensureHasSignature(): Promise<void> {
  const me = await fetchAccountMe();
  if (!me.hasSignature) {
    throw new Error(
      'Bạn chưa có chữ ký số. Vào menu tài khoản → Chữ ký số để tạo trước khi duyệt đơn.',
    );
  }
}

export async function fetchApprovalSignatureObjectUrl(
  signatureUrl: string | null | undefined,
): Promise<string | null> {
  if (!signatureUrl) return null;
  try {
    const { data } = await api.get<Blob>(toApiPath(signatureUrl), {
      responseType: 'blob',
      params: { _: Date.now() },
      headers: { 'Cache-Control': 'no-cache', Pragma: 'no-cache' },
    });
    if (!data || data.size === 0 || (data.type && data.type.includes('json'))) {
      return null;
    }
    return URL.createObjectURL(data);
  } catch {
    return null;
  }
}
