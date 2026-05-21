import api from './api';

export type AnnouncementAttachment = {
  id: number;
  originalName: string;
  linkLabel: string;
  /** Từ server — dùng để hiển thị ảnh inline */
  contentType?: string | null;
};

export type Announcement = {
  id: number;
  title: string;
  body: string;
  category: string;
  categoryLabel: string;
  displayDate: string | null;
  priority: string;
  authorUsername: string;
  publishedAt: string;
  expiresAt: string;
  attachments: AnnouncementAttachment[];
};

export async function fetchAnnouncements(category?: string) {
  const { data } = await api.get<Announcement[]>('/v1/announcements', {
    params: category ? { category } : {},
  });
  return data;
}

export type CreateAnnouncementPayload = {
  title: string;
  body: string;
  category: string;
  displayDate?: string | null;
  priority?: string;
  linkLabels?: string[];
};

export async function createAnnouncementJson(payload: CreateAnnouncementPayload) {
  const { data } = await api.post<Announcement>('/v1/announcements', {
    title: payload.title,
    body: payload.body,
    category: payload.category,
    displayDate: payload.displayDate || null,
    priority: payload.priority ?? 'NORMAL',
    linkLabels: payload.linkLabels ?? [],
  });
  return data;
}

export async function createAnnouncementWithFiles(
  payload: CreateAnnouncementPayload,
  files: File[],
) {
  const linkLabels =
    payload.linkLabels && payload.linkLabels.length === files.length
      ? payload.linkLabels
      : files.map(() => 'tại đây');
  const body = {
    title: payload.title,
    body: payload.body,
    category: payload.category,
    displayDate: payload.displayDate || null,
    priority: payload.priority ?? 'NORMAL',
    linkLabels,
  };
  const fd = new FormData();
  fd.append('data', new Blob([JSON.stringify(body)], { type: 'application/json' }));
  for (const f of files) {
    fd.append('files', f);
  }
  const { data } = await api.post<Announcement>('/v1/announcements', fd, {
    transformRequest: [(data, headers) => {
      delete headers['Content-Type'];
      return data;
    }],
  });
  return data;
}

export async function deleteAnnouncement(id: number) {
  await api.delete(`/v1/announcements/${id}`);
}

export function downloadAnnouncementAttachment(attachmentId: number, originalName: string) {
  return api
    .get(`/v1/announcements/attachments/${attachmentId}/file`, {
      responseType: 'blob',
    })
    .then((res) => {
      const url = window.URL.createObjectURL(new Blob([res.data]));
      const a = document.createElement('a');
      a.href = url;
      a.download = originalName;
      a.rel = 'noopener';
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    });
}

/** Mở PDF/ảnh trong tab mới (inline) */
export async function openAnnouncementAttachmentInline(attachmentId: number) {
  const res = await api.get(`/v1/announcements/attachments/${attachmentId}/file`, {
    responseType: 'blob',
  });
  const ct = res.headers['content-type'] || 'application/octet-stream';
  const url = window.URL.createObjectURL(new Blob([res.data], { type: ct }));
  window.open(url, '_blank', 'noopener,noreferrer');
  window.setTimeout(() => window.URL.revokeObjectURL(url), 60_000);
}
