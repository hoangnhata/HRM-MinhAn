import type { RelatedRequestKind } from './MyRelatedRequestsSection';

export type EmployeeRelatedTabKey =
  | 'seminar'
  | 'training'
  | 'main-duty'
  | 'probation'
  | 'transfer'
  | 'young-child'
  | 'shift-config';

export const EMPLOYEE_RELATED_TABS: {
  kind: RelatedRequestKind;
  tabKey: EmployeeRelatedTabKey;
  label: string;
  description: string;
}[] = [
  {
    kind: 'seminar',
    tabKey: 'seminar',
    label: 'Hội thảo / công tác',
    description:
      'Phiếu đề xuất cử bạn tham gia hội thảo hoặc công tác — theo dõi trạng thái duyệt của Giám đốc.',
  },
  {
    kind: 'training',
    tabKey: 'training',
    label: 'Đào tạo',
    description:
      'Phiếu đề xuất cử bạn đi đào tạo, bồi dưỡng — theo dõi quá trình duyệt.',
  },
  {
    kind: 'main-duty',
    tabKey: 'main-duty',
    label: 'Trực chính',
    description:
      'Đơn được trực chính do Trưởng khoa / Điều dưỡng trưởng lập — chờ Giám đốc duyệt.',
  },
  {
    kind: 'probation',
    tabKey: 'probation',
    label: 'Chuyển chính thức',
    description: 'Đơn đề nghị chuyển bạn lên chính thức — theo dõi tiến trình duyệt.',
  },
  {
    kind: 'transfer',
    tabKey: 'transfer',
    label: 'Luân chuyển',
    description: 'Đề nghị luân chuyển phòng ban có liên quan đến bạn.',
  },
  {
    kind: 'young-child',
    tabKey: 'young-child',
    label: 'Nuôi con nhỏ',
    description: 'Đề xuất bật/tắt chế độ nuôi con nhỏ do Trưởng khoa lập cho bạn.',
  },
  {
    kind: 'shift-config',
    tabKey: 'shift-config',
    label: 'Chỉnh ca sáng/chiều',
    description: 'Đề xuất chỉnh giờ ca sáng/chiều theo mùa do Trưởng khoa lập cho bạn.',
  },
];

export function employeeTabIndexForKey(
  tabKey: string,
  indices: Record<EmployeeRelatedTabKey, number>,
): number {
  if (tabKey in indices) {
    return indices[tabKey as EmployeeRelatedTabKey];
  }
  return -1;
}

export function employeeTabKeyForKind(kind: RelatedRequestKind): EmployeeRelatedTabKey {
  return EMPLOYEE_RELATED_TABS.find((t) => t.kind === kind)?.tabKey ?? 'seminar';
}
