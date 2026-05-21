/** Nhãn hiển thị vai trò */
export function getRoleLabel(role: string | undefined): string {
  if (!role) return '—';
  if (role === 'ADMIN') return 'Quản trị viên';
  if (role === 'EMPLOYEE') return 'Nhân viên';
  if (role === 'HR') return 'P. HCNS';
  if (role === 'HEAD_DEPARTMENT') return 'Trưởng khoa / phòng';
  if (role === 'HEAD_NURSING') return 'Điều dưỡng trưởng';
  return role;
}
