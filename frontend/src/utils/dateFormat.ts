/** Định dạng hiển thị ngày Việt Nam: ngày/tháng/năm (dd/MM/yyyy). */

const ISO_DATE = /^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T\s].*)?$/;
const DMY_DATE = /^(\d{1,2})[/.](\d{1,2})[/.](\d{4})(?:\s.*)?$/;

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

function fromParts(year: number, month: number, day: number, empty: string): string {
  if (!year || month < 1 || month > 12 || day < 1 || day > 31) return empty;
  const d = new Date(year, month - 1, day);
  if (d.getFullYear() !== year || d.getMonth() !== month - 1 || d.getDate() !== day) {
    return empty;
  }
  return `${pad2(day)}/${pad2(month)}/${year}`;
}

/** `2026-05-18` hoặc `2026-05-18T00:00:00` → `18/05/2026`. */
export function formatDateVi(iso?: string | number | null | Date, empty = '—'): string {
  if (iso == null) return empty;
  if (iso instanceof Date) {
    if (Number.isNaN(iso.getTime())) return empty;
    return fromParts(iso.getFullYear(), iso.getMonth() + 1, iso.getDate(), empty);
  }
  if (typeof iso === 'number' && Number.isFinite(iso)) {
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return empty;
    return fromParts(d.getFullYear(), d.getMonth() + 1, d.getDate(), empty);
  }

  const raw = String(iso).trim();
  if (!raw) return empty;

  // Đã đúng dạng ngày/tháng/năm
  const dmy = raw.match(DMY_DATE);
  if (dmy) {
    return fromParts(Number(dmy[3]), Number(dmy[2]), Number(dmy[1]), empty);
  }

  const m = raw.match(ISO_DATE);
  if (m) {
    return fromParts(Number(m[1]), Number(m[2]), Number(m[3]), empty);
  }

  // Timestamp / chuỗi Date khác
  const d = new Date(raw);
  if (!Number.isNaN(d.getTime()) && /\d{4}/.test(raw)) {
    return fromParts(d.getFullYear(), d.getMonth() + 1, d.getDate(), empty);
  }

  return raw;
}

/** Ngày giờ → `18/05/2026 14:30` (theo giờ máy). */
export function formatDateTimeVi(iso?: string | null | Date, empty = '—'): string {
  if (iso == null) return empty;
  const raw = iso instanceof Date ? iso.toISOString() : String(iso).trim();
  if (!raw) return empty;

  const d = iso instanceof Date ? iso : new Date(raw);
  if (Number.isNaN(d.getTime())) {
    return formatDateVi(raw, empty);
  }
  const dd = pad2(d.getDate());
  const mm = pad2(d.getMonth() + 1);
  const yyyy = d.getFullYear();
  const hh = pad2(d.getHours());
  const mi = pad2(d.getMinutes());
  if (/^\d{4}-\d{1,2}-\d{1,2}$/.test(raw.slice(0, 10)) && !/[T\s]/.test(raw.slice(10)) && raw.length <= 10) {
    return `${dd}/${mm}/${yyyy}`;
  }
  // Chỉ ngày ISO kèm midnight → không hiện giờ nếu không có phần giờ hữu ích
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw.slice(0, 10)) && (raw.length <= 10 || /T00:00:00/.test(raw))) {
    return `${dd}/${mm}/${yyyy}`;
  }
  return `${dd}/${mm}/${yyyy} ${hh}:${mi}`;
}

/**
 * Nếu giá trị là ngày ISO (yyyy-MM-dd…) thì đổi sang dd/MM/yyyy;
 * chuỗi khác giữ nguyên.
 */
export function formatMaybeDate(value: unknown, empty = '—'): string {
  if (value == null) return empty;
  if (value instanceof Date) return formatDateVi(value, empty);
  if (typeof value === 'number') return formatDateVi(value, empty);
  const s = String(value).trim();
  if (!s) return empty;
  if (ISO_DATE.test(s) || DMY_DATE.test(s)) {
    return formatDateVi(s, empty);
  }
  // Chuỗi có vẻ là ngày (chứa năm 19xx/20xx và dấu phân cách)
  if (/^\d{4}[-/]\d{1,2}[-/]\d{1,2}/.test(s) || /^\d{1,2}[-/.]\d{1,2}[-/.]\d{4}/.test(s)) {
    return formatDateVi(s, empty);
  }
  return s;
}
