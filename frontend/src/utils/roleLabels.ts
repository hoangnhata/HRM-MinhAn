/** Nhãn hiển thị vai trò */
export function getRoleLabel(role: string | undefined, positionTitle?: string | null): string {
  if (!role) return '—';
  if (role === 'ADMIN') return 'Quản trị viên';
  if (role === 'EMPLOYEE') return 'Nhân viên';
  if (role === 'HR') return 'HCNS 1';
  if (role === 'HR2') return 'HCNS 2';
  if (role === 'HEAD_HR') return 'Trưởng phòng HCNS';
  if (role === 'HEAD_NURSING') return 'Trưởng phòng Điều dưỡng';
  if (role === 'HEAD_DEPARTMENT') {
    const folded = (positionTitle ?? '')
      .normalize('NFD')
      .replace(/\p{M}/gu, '')
      .replace(/đ/gi, 'd')
      .toLowerCase();
    if (folded.includes('dieu duong') || folded.includes('ddt')) {
      return 'Điều dưỡng trưởng';
    }
    if (positionTitle?.trim()) {
      return 'Trưởng khoa / phòng';
    }
    return 'Trưởng khoa / Điều dưỡng trưởng';
  }
  if (role === 'DIRECTOR') return 'Giám đốc';
  return role;
}
