/** Trưởng khoa/phòng, gồm Trưởng phòng HCNS. */
export function isHeadDepartmentRole(role?: string | null): boolean {
  return role === 'HEAD_DEPARTMENT' || role === 'HEAD_HR';
}

/** HCNS 2, gồm Trưởng phòng HCNS. */
export function isHr2Role(role?: string | null): boolean {
  return role === 'HR2' || role === 'HEAD_HR';
}

/** HEAD_HR được coi như vừa HEAD_DEPARTMENT vừa HR2 khi khớp danh sách quyền. */
export function roleAllows(userRole: string | undefined | null, allowed: string): boolean {
  if (!userRole) return false;
  if (userRole === allowed) return true;
  return userRole === 'HEAD_HR' && (allowed === 'HEAD_DEPARTMENT' || allowed === 'HR2');
}

export function roleAllowsAny(
  userRole: string | undefined | null,
  allowed: readonly string[],
): boolean {
  return allowed.some((role) => roleAllows(userRole, role));
}
