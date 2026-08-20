import {
  Alert,
  Box,
  CircularProgress,
  Stack,
  Typography,
} from '@mui/material';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { DepartmentTransferDetailDialog } from './DepartmentTransferDetailDialog';
import { MainDutyAuthorizationDetailDialog } from './MainDutyAuthorizationDetailDialog';
import { ProbationConversionDetailDialog } from './ProbationConversionDetailDialog';
import { SeminarProposalDetailDialog } from './SeminarProposalDetailDialog';
import { TrainingProposalDetailDialog } from './TrainingProposalDetailDialog';
import { YoungChildRequestDetailDialog } from './YoungChildRequestDetailDialog';
import { ShiftConfigChangeDetailDialog } from './ShiftConfigChangeDetailDialog';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';
import { RequestListTable, formatRequestSubject, type RequestListRow } from './requests/RequestListTable';
import * as dts from '../services/departmentTransferService';
import * as mda from '../services/mainDutyAuthorizationService';
import * as pcs from '../services/probationConversionService';
import * as sps from '../services/seminarProposalService';
import * as tps from '../services/trainingProposalService';
import * as ycs from '../services/youngChildRequestService';
import * as scc from '../services/shiftConfigChangeRequestService';
import { formatDateVi } from '../utils/dateFormat';
import { EMPLOYEE_RELATED_TABS, employeeTabKeyForKind } from './employeeRelatedRequestsMeta';

export type RelatedRequestKind =
  | 'seminar'
  | 'training'
  | 'main-duty'
  | 'probation'
  | 'transfer'
  | 'young-child'
  | 'shift-config';

type RelatedItem = {
  kind: RelatedRequestKind;
  id: number;
  title: string;
  subtitle: string;
  department?: string | null;
  status: string;
  statusLabel: string;
  statusColor: 'default' | 'warning' | 'success' | 'error' | 'info';
  sortAt: string;
  requestAt?: string | null;
  submittedAt?: string | null;
};

const KIND_LABEL: Record<RelatedRequestKind, string> = {
  seminar: 'Hội thảo',
  training: 'Đào tạo',
  'main-duty': 'Trực chính',
  probation: 'Chuyển chính thức',
  transfer: 'Luân chuyển',
  'young-child': 'Nuôi con nhỏ',
  'shift-config': 'Chỉnh ca sáng/chiều',
};

type Props = {
  employeeId?: number | null;
  filterKind?: RelatedRequestKind | 'all';
  /** Tab riêng — ẩn tiêu đề chung, luôn hiện khung trống gọn */
  embedded?: boolean;
  emptyLabel?: string;
};

export function MyRelatedRequestsSection({
  employeeId,
  filterKind = 'all',
  embedded = false,
  emptyLabel,
}: Props) {
  const [searchParams, setSearchParams] = useSearchParams();
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [items, setItems] = useState<RelatedItem[]>([]);
  const [openKind, setOpenKind] = useState<RelatedRequestKind | null>(null);
  const [openId, setOpenId] = useState<number | null>(null);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);

  const reload = useCallback(() => {
    if (!employeeId) {
      setItems([]);
      setLoading(false);
      return;
    }
    setLoading(true);

    const emptySeminars: sps.SeminarProposal[] = [];
    const emptyTrainings: tps.TrainingProposal[] = [];
    const emptyMainDuties: mda.MainDutyAuthorization[] = [];
    const emptyConversions: pcs.ProbationConversion[] = [];
    const emptyTransfers: dts.DepartmentTransfer[] = [];
    const emptyYoungChild: ycs.YoungChildRequest[] = [];
    const emptyShiftConfig: scc.ShiftConfigChangeRequest[] = [];

    const fetchSeminars =
      filterKind === 'all' || filterKind === 'seminar'
        ? sps.fetchRelatedSeminarProposals().catch(() => emptySeminars)
        : Promise.resolve(emptySeminars);
    const fetchTrainings =
      filterKind === 'all' || filterKind === 'training'
        ? tps.fetchRelatedTrainingProposals().catch(() => emptyTrainings)
        : Promise.resolve(emptyTrainings);
    const fetchMainDuties =
      filterKind === 'all' || filterKind === 'main-duty'
        ? mda.fetchRelatedMainDutyAuthorizations().catch(() => emptyMainDuties)
        : Promise.resolve(emptyMainDuties);
    const fetchConversions =
      filterKind === 'all' || filterKind === 'probation'
        ? pcs.fetchRelatedConversions().catch(() => emptyConversions)
        : Promise.resolve(emptyConversions);
    const fetchTransfers =
      filterKind === 'all' || filterKind === 'transfer'
        ? dts.fetchRelatedTransfers().catch(() => emptyTransfers)
        : Promise.resolve(emptyTransfers);
    const fetchYoungChild =
      filterKind === 'all' || filterKind === 'young-child'
        ? ycs.fetchRelatedYoungChildRequests().catch(() => emptyYoungChild)
        : Promise.resolve(emptyYoungChild);
    const fetchShiftConfig =
      filterKind === 'all' || filterKind === 'shift-config'
        ? scc.fetchRelatedShiftConfigChangeRequests().catch(() => emptyShiftConfig)
        : Promise.resolve(emptyShiftConfig);

    Promise.all([
      fetchSeminars,
      fetchTrainings,
      fetchMainDuties,
      fetchConversions,
      fetchTransfers,
      fetchYoungChild,
      fetchShiftConfig,
    ])
      .then(([seminars, trainings, mainDuties, conversions, transfers, youngChild, shiftConfigs]) => {
        const merged: RelatedItem[] = [
          ...seminars.map((r) => ({
            kind: 'seminar' as const,
            id: r.id,
            title: formatRequestSubject(r.employeeName, r.positionTitle),
            subtitle: `${r.seminarName} · ${r.location || '—'} · ${sps.formatSeminarDate(r.startDate)} → ${sps.formatSeminarDate(r.endDate)}`,
            department: r.proposingDepartment,
            status: r.status,
            statusLabel: sps.SEMINAR_STATUS_LABEL[r.status] || r.status,
            statusColor: sps.seminarStatusColor(r.status),
            sortAt: r.createdAt || r.startDate || '',
            requestAt: r.startDate,
            submittedAt: r.createdAt,
          })),
          ...trainings.map((r) => ({
            kind: 'training' as const,
            id: r.id,
            title: formatRequestSubject(r.employeeName, r.positionTitle),
            subtitle: `${r.courseName} · ${r.location || '—'} · ${r.plannedPeriod || '—'}`,
            department: r.proposingDepartment,
            status: r.status,
            statusLabel: tps.TRAINING_STATUS_LABEL[r.status] || r.status,
            statusColor: tps.trainingStatusColor(r.status),
            sortAt: r.createdAt || '',
            requestAt: r.createdAt,
            submittedAt: r.createdAt,
          })),
          ...mainDuties.map((r) => ({
            kind: 'main-duty' as const,
            id: r.id,
            title: formatRequestSubject(r.employeeName, r.positionTitle),
            subtitle: `Đơn trực chính (${r.formTypeLabel}) · hiệu lực ${mda.formatMainDutyDate(r.effectiveFrom)} · ${r.accompanyingPeriod || '—'}`,
            department: r.departmentName,
            status: r.status,
            statusLabel: mda.MAIN_DUTY_STATUS_LABEL[r.status] || r.status,
            statusColor: mda.mainDutyStatusColor(r.status),
            sortAt: r.createdAt || r.effectiveFrom || '',
            requestAt: r.effectiveFrom,
            submittedAt: r.createdAt,
          })),
          ...conversions.map((r) => ({
            kind: 'probation' as const,
            id: r.id,
            title: formatRequestSubject(r.employeeName, r.positionTitle),
            subtitle: `Chuyển chính thức · ngày ${pcs.formatConversionDate(r.officialDate)} · ${r.formTypeLabel || '—'}`,
            department: r.departmentName,
            status: r.status,
            statusLabel: pcs.CONVERSION_STATUS_LABEL[r.status] || r.status,
            statusColor: pcs.conversionStatusColor(r.status),
            sortAt: r.createdAt || r.officialDate || '',
            requestAt: r.officialDate,
            submittedAt: r.createdAt,
          })),
          ...transfers.map((r) => ({
            kind: 'transfer' as const,
            id: r.id,
            title: formatRequestSubject(r.employeeName, r.positionTitle),
            subtitle: `Luân chuyển → ${r.toDepartmentName} · ${r.fromDepartmentName} · hiệu lực ${dts.formatTransferDate(r.effectiveDate)}`,
            department: r.fromDepartmentName,
            status: r.status,
            statusLabel: dts.TRANSFER_STATUS_LABEL[r.status] || r.status,
            statusColor: dts.transferStatusColor(r.status),
            sortAt: r.createdAt || r.effectiveDate || '',
            requestAt: r.effectiveDate,
            submittedAt: r.createdAt,
          })),
          ...youngChild.map((r) => ({
            kind: 'young-child' as const,
            id: r.id,
            title: formatRequestSubject(r.employeeName, r.positionTitle),
            subtitle: `${r.enabled ? 'Đề xuất bật nuôi con nhỏ' : 'Đề xuất tắt nuôi con nhỏ'} · ${formatDateVi(r.startDate)} – ${formatDateVi(r.endDate)}`,
            department: r.departmentName,
            status: r.status,
            statusLabel: ycs.YOUNG_CHILD_STATUS_LABEL[r.status] || r.status,
            statusColor:
              (r.status === 'PENDING_HR'
                ? 'warning'
                : r.status === 'APPROVED'
                  ? 'success'
                  : r.status === 'REJECTED'
                    ? 'error'
                    : 'default') as RelatedItem['statusColor'],
            sortAt: r.createdAt || r.startDate,
            requestAt: r.startDate,
            submittedAt: r.createdAt,
          })),
          ...shiftConfigs.map((r) => ({
            kind: 'shift-config' as const,
            id: r.id,
            title: formatRequestSubject(r.employeeName, r.positionTitle),
            subtitle: `${r.seasonLabel || r.season} · sáng ${scc.formatShiftTimeRange(r.morningStart, r.morningEnd)} · chiều ${scc.formatShiftTimeRange(r.afternoonStart, r.afternoonEnd)}`,
            department: r.departmentName,
            status: r.status,
            statusLabel: scc.SHIFT_CONFIG_CHANGE_STATUS_LABEL[r.status] || r.status,
            statusColor:
              (r.status === 'PENDING_HR'
                ? 'warning'
                : r.status === 'APPROVED'
                  ? 'success'
                  : r.status === 'REJECTED'
                    ? 'error'
                    : 'default') as RelatedItem['statusColor'],
            sortAt: r.createdAt || '',
            requestAt: r.createdAt,
            submittedAt: r.createdAt,
          })),
        ];
        merged.sort((a, b) => (b.sortAt || '').localeCompare(a.sortAt || ''));
        setItems(merged);
        setErr(null);
      })
      .catch(() => {
        setItems([]);
        setErr('Không tải được các đơn liên quan đến bạn.');
      })
      .finally(() => setLoading(false));
  }, [employeeId, filterKind]);

  useEffect(() => {
    reload();
  }, [reload]);

  useEffect(() => {
    setFilters(EMPTY_REQUEST_FILTERS);
  }, [filterKind]);

  const visible = useMemo(() => {
    if (filterKind === 'all') return items;
    return items.filter((i) => i.kind === filterKind);
  }, [items, filterKind]);

  const filtered = useMemo(
    () =>
      applyRequestListFilters(visible, filters, {
        searchText: (item) =>
          [KIND_LABEL[item.kind], item.title, item.subtitle, item.department, item.statusLabel].join(
            ' ',
          ),
        dateValue: (item) => item.submittedAt,
        statusValue: (item) => item.status,
        departmentValue: (item) => item.department,
      }),
    [visible, filters],
  );

  const statusOptions = useMemo(() => {
    const map = new Map<string, string>();
    for (const item of visible) {
      if (!map.has(item.status)) {
        map.set(item.status, item.statusLabel);
      }
    }
    return [...map.entries()].map(([value, label]) => ({ value, label }));
  }, [visible]);

  const rows: RequestListRow[] = filtered.map((item) => ({
    id: `${item.kind}-${item.id}`,
    typeLabel: KIND_LABEL[item.kind],
    subject: item.title,
    department: item.department,
    summary: item.subtitle,
    statusLabel: item.statusLabel,
    statusColor: item.statusColor,
    dateLabel: item.requestAt
      ? formatDateVi(String(item.requestAt).slice(0, 10))
      : item.sortAt
        ? formatDateVi(String(item.sortAt).slice(0, 10))
        : undefined,
    submittedAtLabel: item.submittedAt
      ? formatDateVi(String(item.submittedAt).slice(0, 10))
      : undefined,
    pending: item.status.startsWith('PENDING'),
  }));

  const byRowId = useMemo(
    () => new Map(filtered.map((item) => [`${item.kind}-${item.id}`, item])),
    [filtered],
  );

  const openDetail = useCallback(
    (kind: RelatedRequestKind, id: number) => {
      setOpenKind(kind);
      setOpenId(id);
      const params = new URLSearchParams(searchParams);
      params.set('tab', employeeTabKeyForKind(kind));
      params.set('id', String(id));
      params.delete('kind');
      setSearchParams(params, { replace: true });
    },
    [searchParams, setSearchParams],
  );

  const closeDetail = useCallback(() => {
    setOpenKind(null);
    setOpenId(null);
    const params = new URLSearchParams(searchParams);
    params.delete('id');
    params.delete('kind');
    setSearchParams(params, { replace: true });
  }, [searchParams, setSearchParams]);

  useEffect(() => {
    const kindParam = searchParams.get('kind') as RelatedRequestKind | null;
    const tabParam = searchParams.get('tab');
    const idRaw = searchParams.get('id');
    const id = idRaw ? Number(idRaw) : NaN;
    if (!Number.isFinite(id) || id <= 0) return;

    let kind: RelatedRequestKind | null = kindParam;
    if (!kind && tabParam) {
      const fromTab = EMPLOYEE_RELATED_TABS.find((t) => t.tabKey === tabParam);
      kind = fromTab?.kind ?? null;
    }
    if (kind && (filterKind === 'all' || filterKind === kind)) {
      setOpenKind(kind);
      setOpenId(id);
    }
  }, [searchParams, filterKind]);

  if (!employeeId) return null;

  if (loading && items.length === 0) {
    return (
      <Box sx={{ py: embedded ? 4 : 3, textAlign: 'center' }}>
        <CircularProgress size={26} />
      </Box>
    );
  }

  if (!embedded && items.length === 0 && !err) {
    return null;
  }

  const emptyText =
    emptyLabel ??
    (filterKind !== 'all'
      ? `Không có đơn ${KIND_LABEL[filterKind].toLowerCase()} nào.`
      : 'Chưa có đơn liên quan đến bạn.');

  return (
    <Stack spacing={embedded ? 1.5 : 2}>
      {!embedded && (
        <Stack direction="row" alignItems="center" justifyContent="space-between" spacing={1}>
          <Typography variant="subtitle1" fontWeight={800}>
            Đơn liên quan đến bạn
          </Typography>
          <Typography variant="caption" color="text.secondary" fontWeight={600}>
            {visible.length} đơn
          </Typography>
        </Stack>
      )}

      {err && (
        <Alert severity="error" variant="outlined" sx={{ borderRadius: 2 }}>
          {err}
        </Alert>
      )}

      <RequestListTable
        rows={rows}
        loading={loading}
        emptyTitle={emptyText}
        emptyHint="Các đơn liên quan đến bạn sẽ xuất hiện tại đây."
        toolbar={
          <RequestListFilters
            value={filters}
            onChange={setFilters}
            statusOptions={statusOptions}
            resultCount={filtered.length}
            searchPlaceholder="Tìm theo loại đơn, nội dung…"
          />
        }
        onView={(row) => {
          const item = byRowId.get(String(row.id));
          if (item) openDetail(item.kind, item.id);
        }}
      />

      <SeminarProposalDetailDialog
        open={openKind === 'seminar'}
        proposalId={openKind === 'seminar' ? openId : null}
        onClose={closeDetail}
        onChanged={reload}
      />
      <TrainingProposalDetailDialog
        open={openKind === 'training'}
        proposalId={openKind === 'training' ? openId : null}
        onClose={closeDetail}
        onChanged={reload}
      />
      <MainDutyAuthorizationDetailDialog
        open={openKind === 'main-duty'}
        authorizationId={openKind === 'main-duty' ? openId : null}
        onClose={closeDetail}
        onChanged={reload}
      />
      <ProbationConversionDetailDialog
        open={openKind === 'probation'}
        conversionId={openKind === 'probation' ? openId : null}
        onClose={closeDetail}
        onChanged={reload}
      />
      <DepartmentTransferDetailDialog
        open={openKind === 'transfer'}
        transferId={openKind === 'transfer' ? openId : null}
        onClose={closeDetail}
        onChanged={reload}
      />
      <YoungChildRequestDetailDialog
        open={openKind === 'young-child'}
        requestId={openKind === 'young-child' ? openId : null}
        onClose={closeDetail}
        onChanged={reload}
      />
      <ShiftConfigChangeDetailDialog
        open={openKind === 'shift-config'}
        requestId={openKind === 'shift-config' ? openId : null}
        onClose={closeDetail}
        onChanged={reload}
      />
    </Stack>
  );
}

export function countRelatedByKind(items: RelatedItem[], kind: RelatedRequestKind | 'all') {
  if (kind === 'all') return items.length;
  return items.filter((i) => i.kind === kind).length;
}
