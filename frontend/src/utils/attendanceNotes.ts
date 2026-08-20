/**
 * Chuẩn hoá ghi chú ngày công (chuỗi nối bằng `;`) để hiển thị rõ ràng.
 */

export type AttendanceNoteKind =
  | 'sync'
  | 'deployment_ot'
  | 'deployment_inside'
  | 'leave'
  | 'unpaid'
  | 'business_trip'
  | 'explanation'
  | 'update'
  | 'other';

export type ParsedAttendanceNote = {
  kind: AttendanceNoteKind;
  /** Tiêu đề ngắn (vd. Điều động làm thêm ×1.5) */
  title: string;
  /** Khung giờ (vd. 06:20–06:45) */
  timeRange?: string;
  /** Phần giờ thực → giờ công (vd. 0.42h → 0.63h công) */
  hoursLine?: string;
  /** Phân bổ sáng/chiều/ngoài giờ */
  breakdown?: string;
  /** Lý do / mô tả công việc */
  reason?: string;
  /** Mã tham chiếu đơn (vd. DD:54) */
  ref?: string;
  /** true nếu là điều động đã gắn mã đơn duyệt */
  approved?: boolean;
  raw: string;
};

const REF_RE = /\[(DD(?:TC)?:\d+)\]\s*$/i;
const TIME_RANGE_RE = /(\d{1,2}:\d{2}\s*[–\-—]\s*\d{1,2}:\d{2})/;
const BREAKDOWN_RE = /\(([^)]*sáng[^)]*)\)/i;
const COEFF_RE = /×\s*([\d.,]+)/;

function classifySimple(text: string): AttendanceNoteKind | null {
  const t = text.toLowerCase();
  if (t.includes('đồng bộ máy chấm')) return 'sync';
  if (t.includes('nghỉ phép') || t.startsWith('phép')) return 'leave';
  if (t.includes('không lương')) return 'unpaid';
  if (t.includes('công tác')) return 'business_trip';
  if (t.includes('giải trình')) return 'explanation';
  if (t.includes('cập nhật công')) return 'update';
  return null;
}

function stripRef(text: string): { body: string; ref?: string } {
  const m = text.match(REF_RE);
  if (!m || m.index == null) return { body: text.trim() };
  return {
    body: text.slice(0, m.index).trim(),
    ref: m[1],
  };
}

function parseDeployment(body: string, kind: 'deployment_ot' | 'deployment_inside', defaultTitle: string): ParsedAttendanceNote {
  const coeff = body.match(COEFF_RE)?.[1];
  const title = coeff ? `${defaultTitle} ×${coeff}` : defaultTitle;
  const timeRange = body.match(TIME_RANGE_RE)?.[1]?.replace(/\s+/g, ' ').trim();

  let breakdown: string | undefined;
  const bd = body.match(BREAKDOWN_RE);
  if (bd) breakdown = bd[1].trim();

  let hoursLine: string | undefined;
  if (timeRange) {
    const afterTime = body.slice(body.indexOf(timeRange) + timeRange.length);
    const hoursMatch = afterTime.match(/·\s*([^(]+?)(?=\s*\(|$)/);
    if (hoursMatch) {
      hoursLine = hoursMatch[1].trim().replace(/\s*[—-]\s*$/, '').trim();
      if (!hoursLine) hoursLine = undefined;
    } else {
      // Điều động trong ca: "... — 0.5 công (...)"
      const dashHours = afterTime.match(/[—-]\s*([^(]+?)(?=\s*\(|$)/);
      if (dashHours) {
        hoursLine = dashHours[1].trim();
        if (!hoursLine) hoursLine = undefined;
      }
    }
  }

  let reason: string | undefined;
  if (breakdown) {
    const afterBd = body.slice(body.indexOf(`(${breakdown})`) + breakdown.length + 2).trim();
    reason = afterBd.replace(/^:\s*/, '').trim() || undefined;
  } else {
    const colonParts = body.split(':');
    if (colonParts.length >= 3) {
      // title: time... : reason  OR title: rest
      const last = colonParts[colonParts.length - 1].trim();
      // Avoid treating time fragments as reason
      if (last && !/^\d{1,2}$/.test(last) && !TIME_RANGE_RE.test(last)) {
        // If last segment looks like a reason (has letters beyond time/hours tokens)
        if (/[A-Za-zÀ-ỹ]/.test(last) && !/^\d/.test(last.replace(/^[·\s]+/, ''))) {
          reason = last;
        }
      }
    }
  }

  return {
    kind,
    title,
    timeRange,
    hoursLine,
    breakdown,
    reason,
    raw: body,
  };
}

function parseOne(rawPart: string): ParsedAttendanceNote | null {
  const raw = rawPart.trim();
  if (!raw) return null;

  const { body, ref } = stripRef(raw);

  if (/^điều động làm thêm/i.test(body)) {
    return {
      ...parseDeployment(body, 'deployment_ot', 'Điều động làm thêm'),
      ref,
      approved: Boolean(ref) || /\[DD(?:TC)?:/i.test(body),
      raw,
    };
  }

  if (/^điều động trong ca/i.test(body)) {
    return {
      ...parseDeployment(body, 'deployment_inside', 'Điều động trong ca'),
      ref,
      approved: Boolean(ref) || /\[DD(?:TC)?:/i.test(body),
      raw,
    };
  }

  const simple = classifySimple(body);
  if (simple === 'sync') {
    return { kind: 'sync', title: 'Đồng bộ máy chấm công', ref, raw };
  }
  if (simple) {
    return { kind: simple, title: body, ref, raw };
  }

  return { kind: 'other', title: body, ref, raw };
}

/** Tách ghi chú ngày công thành các mục đọc được. */
export function parseAttendanceNotes(note?: string | null): ParsedAttendanceNote[] {
  if (!note?.trim()) return [];
  return note
    .split(';')
    .map((p) => parseOne(p))
    .filter((x): x is ParsedAttendanceNote => Boolean(x));
}

export function attendanceNoteKindLabel(kind: AttendanceNoteKind): string {
  switch (kind) {
    case 'sync':
      return 'Đồng bộ';
    case 'deployment_ot':
      return 'Điều động OT';
    case 'deployment_inside':
      return 'Điều động trong ca';
    case 'leave':
      return 'Nghỉ phép';
    case 'unpaid':
      return 'Không lương';
    case 'business_trip':
      return 'Công tác';
    case 'explanation':
      return 'Giải trình';
    case 'update':
      return 'Cập nhật công';
    default:
      return 'Ghi chú';
  }
}

/** Phiên bản text gọn (tooltip / bảng tháng). */
export function formatAttendanceNotesPlain(note?: string | null): string {
  const items = parseAttendanceNotes(note);
  if (!items.length) return note?.trim() || '';
  return items
    .map((n) => {
      const bits = [n.title];
      if (n.timeRange) bits.push(n.timeRange);
      if (n.hoursLine) bits.push(n.hoursLine);
      if (n.reason) bits.push(n.reason);
      if (n.ref) bits.push(`[${n.ref}]`);
      return bits.join(' · ');
    })
    .join('\n');
}
