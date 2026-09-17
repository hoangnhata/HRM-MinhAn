import api from './api';

export type NursingDailyReport = {
  id: number;
  departmentId: number;
  departmentCode?: string | null;
  departmentName: string;
  reportDate: string;
  totalStaff: number;
  workingStaff: number;
  plannedLeave: number;
  unplannedLeave: number;
  maternityLeave: number;
  longLeave: number;
  dutyAfternoonOff: number;
  externalMission: number;
  inpatients: number;
  inpatientsCareLevel1: number;
  inpatientsCareLevel2: number;
  inpatientsCareLevel3: number;
  outpatients: number;
  paraclinical: number;
  surgery: number;
  dischargedYesterday: number;
  actualBeds: number;
  plannedBeds: number;
  inpatientTreatmentDays: number;
  falls: number;
  newPressureUlcers: number;
  idMixups: number;
  medicationErrors: number;
  status?: 'DRAFT' | 'SUBMITTED';
  submittedAt?: string | null;
  canEdit?: boolean;
  canRecall?: boolean;
  createdByUsername?: string | null;
  updatedByUsername?: string | null;
  createdAt?: string | null;
  updatedAt?: string | null;
};

export type NursingDailyReportDepartment = {
  id: number;
  code?: string | null;
  name: string;
};

export type NursingDailyReportDayRow = {
  departmentId: number;
  departmentCode?: string | null;
  departmentName: string;
  reportDate: string;
  submitted: boolean;
  hasDraft?: boolean;
  canEdit?: boolean;
  canRecall?: boolean;
  report: NursingDailyReport | null;
};

export type NursingDailyReportPayload = {
  departmentId: number;
  reportDate: string;
  totalStaff: number;
  workingStaff: number;
  plannedLeave: number;
  unplannedLeave: number;
  maternityLeave: number;
  longLeave: number;
  dutyAfternoonOff: number;
  externalMission: number;
  inpatients: number;
  inpatientsCareLevel1: number;
  inpatientsCareLevel2: number;
  inpatientsCareLevel3: number;
  outpatients: number;
  paraclinical: number;
  surgery: number;
  dischargedYesterday: number;
  actualBeds: number;
  plannedBeds: number;
  inpatientTreatmentDays: number;
  falls: number;
  newPressureUlcers: number;
  idMixups: number;
  medicationErrors: number;
  submit?: boolean;
};

export const emptyNursingDailyPayload = (
  departmentId: number,
  reportDate: string,
): NursingDailyReportPayload => ({
  departmentId,
  reportDate,
  totalStaff: 0,
  workingStaff: 0,
  plannedLeave: 0,
  unplannedLeave: 0,
  maternityLeave: 0,
  longLeave: 0,
  dutyAfternoonOff: 0,
  externalMission: 0,
  inpatients: 0,
  inpatientsCareLevel1: 0,
  inpatientsCareLevel2: 0,
  inpatientsCareLevel3: 0,
  outpatients: 0,
  paraclinical: 0,
  surgery: 0,
  dischargedYesterday: 0,
  actualBeds: 0,
  plannedBeds: 0,
  inpatientTreatmentDays: 0,
  falls: 0,
  newPressureUlcers: 0,
  idMixups: 0,
  medicationErrors: 0,
});

export function payloadFromReport(r: NursingDailyReport): NursingDailyReportPayload {
  return {
    departmentId: r.departmentId,
    reportDate: r.reportDate,
    totalStaff: r.totalStaff,
    workingStaff: r.workingStaff,
    plannedLeave: r.plannedLeave,
    unplannedLeave: r.unplannedLeave,
    maternityLeave: r.maternityLeave,
    longLeave: r.longLeave,
    dutyAfternoonOff: r.dutyAfternoonOff,
    externalMission: r.externalMission,
    inpatients: r.inpatients,
    inpatientsCareLevel1: r.inpatientsCareLevel1 ?? 0,
    inpatientsCareLevel2: r.inpatientsCareLevel2 ?? 0,
    inpatientsCareLevel3: r.inpatientsCareLevel3 ?? 0,
    outpatients: r.outpatients,
    paraclinical: r.paraclinical,
    surgery: r.surgery,
    dischargedYesterday: r.dischargedYesterday,
    actualBeds: r.actualBeds,
    plannedBeds: r.plannedBeds,
    inpatientTreatmentDays: r.inpatientTreatmentDays,
    falls: r.falls,
    newPressureUlcers: r.newPressureUlcers,
    idMixups: r.idMixups,
    medicationErrors: r.medicationErrors,
  };
}

export async function fetchNursingDailyDepartments() {
  const { data } = await api.get<NursingDailyReportDepartment[]>('/v1/nursing-daily-reports/departments');
  return data;
}

export async function fetchNursingDailyDayRows(date: string, departmentId?: number) {
  const { data } = await api.get<NursingDailyReportDayRow[]>('/v1/nursing-daily-reports', {
    params: { date, ...(departmentId != null ? { departmentId } : {}) },
  });
  return data;
}

/** Các ngày trong tháng (đến hôm nay) — theo dõi đã nộp / chưa nộp. yearMonth = YYYY-MM */
export async function fetchNursingDailyMonthRows(yearMonth: string, departmentId?: number) {
  const { data } = await api.get<NursingDailyReportDayRow[]>('/v1/nursing-daily-reports/month', {
    params: { yearMonth, ...(departmentId != null ? { departmentId } : {}) },
  });
  return data;
}

export async function fetchNursingDailyReportById(id: number) {
  const { data } = await api.get<NursingDailyReport>(`/v1/nursing-daily-reports/${id}`);
  return data;
}

export async function fetchNursingDailyReportByDeptDate(departmentId: number, date: string) {
  const { data } = await api.get<NursingDailyReport | null>('/v1/nursing-daily-reports/by', {
    params: { departmentId, date },
  });
  return data;
}

export async function createNursingDailyReport(body: NursingDailyReportPayload) {
  const { data } = await api.post<NursingDailyReport>('/v1/nursing-daily-reports', body);
  return data;
}

export async function updateNursingDailyReport(id: number, body: NursingDailyReportPayload) {
  const { data } = await api.put<NursingDailyReport>(`/v1/nursing-daily-reports/${id}`, body);
  return data;
}

export async function recallNursingDailyReport(id: number) {
  const { data } = await api.post<NursingDailyReport>(`/v1/nursing-daily-reports/${id}/recall`);
  return data;
}

export async function deleteNursingDailyReport(id: number) {
  await api.delete(`/v1/nursing-daily-reports/${id}`);
}
