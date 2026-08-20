/**
 * Khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa (đồng bộ backend NursingBlockClassifier).
 * Dùng để hiển thị bước duyệt Trưởng phòng Điều dưỡng trên form lập đơn.
 */

function normalize(positionTitle?: string | null): string {
  if (!positionTitle) return '';
  return positionTitle
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .replace(/đ/g, 'd');
}

const BLOCK =
  /dieu\s*duong|\bdd\b|ho\s*sinh|ky\s*thuat\s*vien|\bktv\b|y\s*ta|\bnurse\b|thu\s*ky\s*y\s*khoa|thu\s*ky\s*ykhoa|medical\s*secretar|midwife|technici/;

/** True nếu chức danh thuộc khối ĐD–KTV–HS–Thư ký y khoa. */
export function isNursingBlockTitle(positionTitle?: string | null): boolean {
  const norm = normalize(positionTitle);
  return Boolean(norm && BLOCK.test(norm));
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

  const nursingBlock = isNursingBlockTitle(request.positionTitle);
  let steps: FlowStep[];
  if (request.requestType === 'DEPLOYMENT') {
    steps = nursingBlock
      ? [
          { label: 'Lập đơn', hint: submitter },
          { label: 'Trưởng phòng ĐD', hint: nursing },
          { label: 'HCNS duyệt', hint: hr },
          { label: 'Giám đốc duyệt', hint: director },
        ]
      : [
          { label: 'Lập đơn', hint: submitter },
          { label: 'HCNS duyệt', hint: hr },
          { label: 'Giám đốc duyệt', hint: director },
        ];
  } else {
    steps = [
      { label: 'Gửi đơn', hint: submitter },
      { label: 'Lãnh đạo duyệt', hint: head },
      { label: 'HCNS duyệt', hint: hr },
      { label: 'Giám đốc duyệt', hint: director },
    ];
  }

  return { steps, activeIndex: workRequestFlowActiveIndex(request.status, request.requestType, nursingBlock, steps.length) };
}

function workRequestFlowActiveIndex(
  status: string,
  requestType: string,
  nursingBlock: boolean,
  stepCount: number,
): number {
  const last = Math.max(0, stepCount - 1);
  if (status === 'APPROVED') return last;
  if (status === 'WITHDRAWN') return 0;

  if (requestType === 'DEPLOYMENT') {
    if (nursingBlock) {
      if (status === 'PENDING_NURSING_HEAD' || status === 'NURSING_HEAD_REJECTED') return 1;
      if (status === 'PENDING_HR' || status === 'HR_REJECTED') return 2;
      if (status === 'PENDING_DIRECTOR' || status === 'DIRECTOR_REJECTED') return 3;
      return 0;
    }
    if (status === 'PENDING_HR' || status === 'HR_REJECTED') return 1;
    if (status === 'PENDING_DIRECTOR' || status === 'DIRECTOR_REJECTED') return 2;
    return 0;
  }

  if (status === 'PENDING_HEAD' || status === 'HEAD_REJECTED') return 1;
  if (status === 'PENDING_NURSING_HEAD' || status === 'NURSING_HEAD_REJECTED') return 1;
  if (status === 'PENDING_HR' || status === 'HR_REJECTED') return 2;
  if (status === 'PENDING_DIRECTOR' || status === 'DIRECTOR_REJECTED') return 3;
  return 0;
}

/** Quy trình điều động: khối ĐD thêm bước Trưởng phòng Điều dưỡng. */
export function deploymentFlowSteps(positionTitle?: string | null): FlowStep[] {
  if (isNursingBlockTitle(positionTitle)) {
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
export function probationFlowSteps(positionTitle?: string | null): FlowStep[] {
  if (isNursingBlockTitle(positionTitle)) {
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
export function mainDutyFlowSteps(positionTitle?: string | null): FlowStep[] {
  if (isNursingBlockTitle(positionTitle)) {
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
