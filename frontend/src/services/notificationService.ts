import api from './api';

export type AppNotification = {
  id: number;
  category: string;
  title: string;
  message: string;
  read: boolean;
  createdAt: string;
  relatedEmployeeId: number | null;
  /** Thông báo toàn viện — mở trang chủ tại mục tương ứng */
  relatedAnnouncementId?: number | null;
  /** Bảng lương/công — hiển thị cảnh báo bảo mật */
  sensitive?: boolean;
};

export async function fetchNotifications() {
  const { data } = await api.get<AppNotification[]>('/v1/notifications');
  return data;
}

export async function fetchUnreadCount() {
  const { data } = await api.get<{ count: number }>('/v1/notifications/unread-count');
  return data.count;
}

export async function markRead(id: number) {
  await api.patch(`/v1/notifications/${id}/read`);
}
