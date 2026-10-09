/**
 * Khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa – Y sĩ
 * + Dược sĩ chỉ khoa YHCT; Nhân viên khoa YHCT hoặc Khoa khám bệnh
 * (đồng bộ backend NursingBlockClassifier).
 *
 * Không gồm nhân sự thuộc phòng loại trừ khỏi Trưởng phòng ĐD:
 * Kế hoạch tổng hợp, Kinh doanh/Phát triển, Phòng Điều dưỡng.
 */

function normalize(positionTitle?: string | null): string {
  if (!positionTitle) return '';
  return positionTitle
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/đ/g, 'd')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Không gồm Dược sĩ / Nhân viên — gắn khoa đặc thù. */
const BLOCK =
  /dieu\s*duong|\bdd\b|ho\s*sinh|ky\s*thuat\s*vien|\bktv\b|y\s*ta|\bnurse\b|thu\s*ky\s*y\s*khoa|thu\s*ky\s*ykhoa|medical\s*secretar|midwife|technici|\by\s*s[iy]\b|assistant\s*physician|physician\s*assistant/;

const PHARMACIST = /duoc\s*si|\bduocsy\b|pharmacist/;
const STAFF = /\bnhan\s*vien\b/;
const TRADITIONAL_MEDICINE_DEPT = /y\s*hoc\s*co\s*truyen|\byhct\b/;
const OUTPATIENT_DEPT = /khoa\s*kham\s*benh|^kham\s*benh$/;
/** Đồng bộ EXCLUDED_NURSING_HEAD_DEPT + Phòng Điều dưỡng trên backend. */
const EXCLUDED_NURSING_HEAD_DEPT =
  /ke\s*hoach\s*tong\s*hop|kinh\s*doanh|phat\s*trien|^phong\s+dieu\s+duong$/;

function isExcludedNursingHeadDepartment(departmentName?: string | null): boolean {
  const dept = normalize(departmentName);
  return Boolean(dept && EXCLUDED_NURSING_HEAD_DEPT.test(dept));
}

/**
 * True nếu thuộc phạm vi Trưởng phòng ĐD (chức danh khối + không thuộc phòng loại trừ;
 * «Dược sĩ» chỉ YHCT; «Nhân viên» YHCT hoặc Khoa khám bệnh).
 */
export function isNursingBlockTitle(
  positionTitle?: string | null,
  departmentName?: string | null,
): boolean {
  if (isExcludedNursingHeadDepartment(departmentName)) {
    return false;
  }
  const title = normalize(positionTitle);
  if (!title) return false;
  if (BLOCK.test(title)) return true;
  const dept = normalize(departmentName);
  if (STAFF.test(title) && (TRADITIONAL_MEDICINE_DEPT.test(dept) || OUTPATIENT_DEPT.test(dept))) {
    return true;
  }
  return PHARMACIST.test(title) && TRADITIONAL_MEDICINE_DEPT.test(dept);
}

export type FlowStep = { label: string; hint: string };

function flowPerson(...candidates: Array<string | null | undefined>): string | null {
  for (const c of candidates) {
    const t = c?.trim();
    if (t) return t;
  }
  return null;
}

/** Luồng duyệt trên chi tiết đơn — hint = tên người gửi/nhận từng bước. */
export function workRequestDetailFlow(request: {
  requestType: string;
  status: string;
  positionTitle?: string | null;
  departmentName?: string | null;
  employeeName?: string | null;
  flowSubmitterName?: string | null;
  flowHeadName?: string | null;
  flowNursingHeadName?: string | null;
  flowHrName?: string | null;
  flowDirectorName?: string | null;
  headReviewerName?: string | null;
  nursingHeadReviewerName?: string | null;
  hrReviewerName?: string | null;
  directorReviewerName?: string | null;
  headSkipped?: boolean;
  nursingHeadSkipped?: boolean;
  hrSkipped?: boolean;
}): { steps: FlowStep[]; activeIndex: number } {
  const submitter =
    flowPerson(request.flowSubmitterName, request.employeeName) || 'Nhân viên';
  const head =
    flowPerson(request.headReviewerName, request.flowHeadName) || 'Trưởng khoa / ĐD trưởng';
  const nursing =
    flowPerson(request.nursingHeadReviewerName, request.flowNursingHeadName) ||
    'Trưởng phòng Điều dưỡng';
  const hr = flowPerson(request.hrReviewerName, request.flowHrName) || 'Hành chính nhân sự';
  const director =
    flowPerson(request.directorReviewerName, request.flowDirectorName) || 'Duyệt cuối';

  const nursingBlock = isNursingBlockTitle(request.positionTitle, request.departmentName);
  const deployment = request.requestType === 'DEPLOYMENT';
  // Bước mà chính người làm đơn là người duyệt đã được bỏ qua ở backend — không hiển thị nữa.
  const keyed: { key: FlowStage; step: FlowStep }[] = [
    { key: 'submit', step: { label: deployment ? 'Lập đơn' : 'Gửi đơn', hint: submitter } },
    ...(deployment || request.headSkipped
      ? []
      : [{ key: 'head' as FlowStage, step: { label: 'Lãnh đạo duyệt', hint: head } }]),
    ...(deployment && nursingBlock && !request.nursingHeadSkipped
      ? [{ key: 'nursing' as FlowStage, step: { label: 'Trưởng phòng ĐD', hint: nursing } }]
      : []),
    ...(request.hrSkipped ? [] : [{ key: 'hr' as FlowStage, step: { label: 'HCNS duyệt', hint: hr } }]),
    { key: 'director', step: { label: 'Giám đốc duyệt', hint: director } },
  ];

  const activeKey = workRequestFlowStage(request.status);
  let activeIndex = keyed.findIndex((s) => s.key === activeKey);
  if (activeIndex < 0) {
    activeIndex = activeKey === 'director' ? keyed.length - 1 : 0;
  }
  return { steps: keyed.map((s) => s.step), activeIndex };
}

type FlowStage = 'submit' | 'head' | 'nursing' | 'hr' | 'director';

/** Bước đang chờ theo trạng thái đơn. */
function workRequestFlowStage(status: string): FlowStage {
  switch (status) {
    case 'APPROVED':
    case 'APPROVED_NO_FINE':
    case 'PENDING_DIRECTOR':
    case 'DIRECTOR_REJECTED':
      return 'director';
    case 'PENDING_HEAD':
    case 'HEAD_REJECTED':
      return 'head';
    case 'PENDING_NURSING_HEAD':
    case 'NURSING_HEAD_REJECTED':
      return 'nursing';
    case 'PENDING_HR':
    case 'HR_REJECTED':
      return 'hr';
    default:
      return 'submit';
  }
}

/** Các bước hiển thị khi gửi đơn công mới — bỏ bước mà chính người gửi là người duyệt. */
export function workRequestSubmitSteps(role?: string | null): FlowStep[] {
  // Trưởng phòng Điều dưỡng lập đơn: bỏ bước lãnh đạo — chỉ HCNS → Giám đốc.
  const isHead = role === 'HEAD_DEPARTMENT' || role === 'HEAD_HR' || role === 'HEAD_NURSING';
  const isHr = role === 'HR2' || role === 'HEAD_HR';
  return [
    { label: 'Gửi đơn', hint: 'Nhân viên' },
    ...(isHead ? [] : [{ label: 'Lãnh đạo duyệt', hint: 'Trưởng khoa / ĐD trưởng' }]),
    ...(isHr ? [] : [{ label: 'HCNS duyệt', hint: 'Hành chính nhân sự' }]),
    { label: 'Giám đốc duyệt', hint: 'Duyệt cuối' },
  ];
}

/** Quy trình điều động: khối ĐD thêm bước Trưởng phòng Điều dưỡng. */
export function deploymentFlowSteps(
  positionTitle?: string | null,
  departmentName?: string | null,
): FlowStep[] {
  if (isNursingBlockTitle(positionTitle, departmentName)) {
    return [
      { label: 'Lập đơn', hint: 'Trưởng khoa / ĐD trưởng khoa' },
      { label: 'Trưởng phòng ĐD', hint: 'Trưởng phòng Điều dưỡng' },
      { label: 'HCNS duyệt', hint: 'Hành chính nhân sự' },
      { label: 'Giám đốc duyệt', hint: 'Duyệt khung · chờ giờ chấm trong ca' },
    ];
  }
  return [
    { label: 'Lập đơn', hint: 'Trưởng khoa / ĐD trưởng khoa' },
    { label: 'HCNS duyệt', hint: 'Hành chính nhân sự' },
    { label: 'Giám đốc duyệt', hint: 'Duyệt khung · chờ giờ chấm trong ca' },
  ];
}

/** Quy trình lên chính thức. */
export function probationFlowSteps(
  positionTitle?: string | null,
  departmentName?: string | null,
): FlowStep[] {
  if (isNursingBlockTitle(positionTitle, departmentName)) {
    return [
      { label: 'Lập đơn', hint: 'Trưởng khoa / ĐD trưởng khoa' },
      { label: 'Trưởng phòng ĐD', hint: 'Trưởng phòng Điều dưỡng' },
      { label: 'HCNS duyệt', hint: 'Hành chính nhân sự' },
      { label: 'Giám đốc duyệt', hint: 'Ban Giám đốc' },
    ];
  }
  return [
    { label: 'Lập đơn', hint: 'Trưởng khoa / ĐD trưởng khoa' },
    { label: 'HCNS duyệt', hint: 'Hành chính nhân sự' },
    { label: 'Giám đốc duyệt', hint: 'Ban Giám đốc' },
  ];
}

/** Quy trình trực chính (trưởng khoa lập → bỏ qua bước chờ trưởng khoa). */
export function mainDutyFlowSteps(
  positionTitle?: string | null,
  departmentName?: string | null,
): FlowStep[] {
  if (isNursingBlockTitle(positionTitle, departmentName)) {
    return [
      { label: 'Lập đơn', hint: 'Trưởng khoa / ĐD trưởng khoa' },
      { label: 'Trưởng phòng ĐD', hint: 'Trưởng phòng Điều dưỡng' },
      { label: 'Giám đốc', hint: 'Duyệt cuối' },
    ];
  }
  return [
    { label: 'Lập đơn', hint: 'Trưởng khoa' },
    { label: 'Giám đốc', hint: 'Duyệt cuối' },
  ];
}
