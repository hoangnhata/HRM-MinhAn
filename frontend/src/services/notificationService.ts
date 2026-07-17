import DescriptionOutlinedIcon from '@mui/icons-material/DescriptionOutlined';
import NotificationsNoneOutlinedIcon from '@mui/icons-material/NotificationsNoneOutlined';
import PaymentsOutlinedIcon from '@mui/icons-material/PaymentsOutlined';
import ScheduleOutlinedIcon from '@mui/icons-material/ScheduleOutlined';
import TrendingUpOutlinedIcon from '@mui/icons-material/TrendingUpOutlined';
import type { SvgIconComponent } from '@mui/icons-material';
import api from './api';

export type AppNotification = {
  id: number;
  category: string;
  title: string;
  message: string;
  read: boolean;
  createdAt: string;
  relatedEmployeeId: number | null;
  relatedAnnouncementId?: number | null;
  sensitive?: boolean;
  actionPath?: string | null;
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

const CATEGORY_META: Record<
  string,
  { icon: SvgIconComponent; accent: string; label: string }
> = {
  ANNOUNCEMENT: { icon: NotificationsNoneOutlinedIcon, accent: '#64748b', label: 'Thông báo' },
  ATTENDANCE: { icon: ScheduleOutlinedIcon, accent: '#d97706', label: 'Công / đơn công' },
  PAYROLL: { icon: PaymentsOutlinedIcon, accent: '#2563eb', label: 'Bảng lương' },
  SALARY_ADJUSTMENT: { icon: TrendingUpOutlinedIcon, accent: '#7c3aed', label: 'Nâng bậc lương' },
  SALARY_REVIEW: { icon: TrendingUpOutlinedIcon, accent: '#7c3aed', label: 'Xét nâng lương' },
  INTERNAL: { icon: DescriptionOutlinedIcon, accent: '#64748b', label: 'Nội bộ' },
  SYSTEM: { icon: NotificationsNoneOutlinedIcon, accent: '#64748b', label: 'Hệ thống' },
  DEPARTMENT_TRANSFER: { icon: DescriptionOutlinedIcon, accent: '#0d9488', label: 'Luân chuyển' },
  PROBATION_CONVERSION: { icon: DescriptionOutlinedIcon, accent: '#15803d', label: 'Chuyển chính thức' },
  YOUNG_CHILD: { icon: DescriptionOutlinedIcon, accent: '#c026d3', label: 'Nuôi con nhỏ' },
};

export function notificationMeta(category: string) {
  return (
    CATEGORY_META[category] ?? {
      icon: NotificationsNoneOutlinedIcon,
      accent: '#64748b',
      label: 'Thông báo',
    }
  );
}

export function resolveNotificationPath(n: AppNotification): string {
  if (n.actionPath) {
    return n.actionPath;
  }
  switch (n.category) {
    case 'ANNOUNCEMENT':
      return '/';
    case 'DEPARTMENT_TRANSFER':
      return n.title.includes('chờ') ? '/requests?tab=transfers' : '/employees/official';
    case 'PROBATION_CONVERSION':
      if (n.title.includes('Đã lên') || n.title.includes('Áp dụng')) {
        return '/employees/official';
      }
      return '/requests?tab=probation-conversions';
    case 'YOUNG_CHILD':
      return '/requests?tab=young-child';
    case 'ATTENDANCE':
      return n.title.includes('chờ duyệt') ? '/requests?tab=approve' : '/requests?tab=mine';
    case 'PAYROLL':
    case 'SALARY_ADJUSTMENT':
    case 'SALARY_REVIEW':
      return '/salary';
    case 'INTERNAL':
      return '/profile';
    default:
      return '/';
  }
}

export function formatNotificationTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const now = new Date();
  const diffMs = now.getTime() - d.getTime();
  const diffMin = Math.floor(diffMs / 60000);
  if (diffMin < 1) return 'Vừa xong';
  if (diffMin < 60) return `${diffMin} phút trước`;
  const diffHr = Math.floor(diffMin / 60);
  if (diffHr < 24) return `${diffHr} giờ trước`;
  const diffDay = Math.floor(diffHr / 24);
  if (diffDay < 7) return `${diffDay} ngày trước`;
  return d.toLocaleString('vi-VN', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}
