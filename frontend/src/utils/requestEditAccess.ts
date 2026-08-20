/** Kiểm tra đơn còn chờ duyệt và người dùng được phép chỉnh sửa. */

import type { WorkRequest } from '../services/attendanceService';
import type { StoredUser } from './storage';

export function isPendingRequestStatus(status?: string | null): boolean {
  return Boolean(status && status.startsWith('PENDING'));
}

export function canEditWorkRequest(
  request: Pick<
    WorkRequest,
    'status' | 'requestType' | 'employeeId' | 'headReviewerUsername'
  >,
  user?: Pick<StoredUser, 'username' | 'role' | 'employeeId'> | null,
): boolean {
  if (!isPendingRequestStatus(request.status)) return false;
  if (user?.role === 'ADMIN') return true;
  if (request.requestType === 'DEPLOYMENT') {
    const username = user?.username?.trim();
    const head = request.headReviewerUsername?.trim();
    return Boolean(username && head && username === head);
  }
  return user?.employeeId != null && user.employeeId === request.employeeId;
}

export function canEditOwnPendingRequest(
  row: { status?: string | null; requestedByUsername?: string | null },
  user?: { username?: string | null; role?: string | null } | null,
): boolean {
  if (!isPendingRequestStatus(row.status ?? undefined)) return false;
  if (user?.role === 'ADMIN') return true;
  const username = user?.username?.trim();
  const owner = row.requestedByUsername?.trim();
  return Boolean(username && owner && username === owner);
}
