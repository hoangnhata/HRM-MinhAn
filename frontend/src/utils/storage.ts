const TOKEN_KEY = 'minhan_hrm_token';
const USER_KEY = 'minhan_hrm_user';

export type StoredUser = {
  username: string;
  role: string;
  employeeId: number | null;
  fullName: string;
  email?: string;
  mustChangePassword?: boolean;
  /** true = chưa có chữ ký, bắt buộc tạo sau đổi MK */
  mustSetSignature?: boolean;
  /** false = NV thử việc chưa có ngày vào làm chính thức */
  canViewSalary?: boolean;
  employeeStatus?: string | null;
  /** Phòng ban của hồ sơ NV liên kết (trưởng khoa/ĐDT dùng để lọc nhân lực) */
  departmentId?: number | null;
  /** Tên phòng ban (dùng trong các form đề xuất của bản thân) */
  departmentName?: string | null;
  /** Phân biệt Điều dưỡng trưởng với các trưởng khoa/phòng dùng chung role. */
  positionTitle?: string | null;
  /** Có quyền xử lý các bước duyệt của Ban Giám đốc. */
  directorApprovalEnabled?: boolean;
  /** Được xem menu báo cáo nhân lực (cấp bởi Admin). */
  reportViewEnabled?: boolean;
  /** Trưởng khoa chỉ quản lý bộ phận (không cả khoa). */
  workUnitScoped?: boolean;
  /** Bộ phận của hồ sơ NV liên kết (khi workUnitScoped). */
  workUnitDetail?: string | null;
};

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function setAuth(token: string, user: StoredUser): void {
  localStorage.setItem(TOKEN_KEY, token);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

export function clearAuth(): void {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
  // Phiên mở khóa lương luôn gắn với một phiên đăng nhập và không được dùng lại
  // sau khi đăng xuất hoặc JWT hết hạn.
  sessionStorage.removeItem('minhan_salary_access');
  sessionStorage.removeItem('minhan_salary_access_expiry');
}

export function getStoredUser(): StoredUser | null {
  const raw = localStorage.getItem(USER_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as StoredUser;
  } catch {
    return null;
  }
}
