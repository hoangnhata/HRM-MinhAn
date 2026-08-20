import FactCheckOutlinedIcon from '@mui/icons-material/FactCheckOutlined';
import PersonSearchOutlinedIcon from '@mui/icons-material/PersonSearchOutlined';
import SaveOutlinedIcon from '@mui/icons-material/SaveOutlined';
import SendOutlinedIcon from '@mui/icons-material/SendOutlined';
import {
  Alert,
  Box,
  Button,
  Chip,
  LinearProgress,
  MenuItem,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { Fragment, useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { isHeadDepartmentRole } from '../utils/roleAccess';
import * as employeeService from '../services/employeeService';
import * as att from '../services/attendanceService';
import * as ne from '../services/nursingEvaluationService';
import { extractApiErrorMessage, ensureHasSignature } from '../services/approvalSignatureService';
import { MonthPickerField } from './ui/DateTimeFields';
import { RequestFlowSteps } from './work/WorkRequestFormUi';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from './requests/RequestListFilters';

/** Chuẩn công tháng dùng để nhận diện thiếu công khi đánh giá. */
const STANDARD_MONTH_WORK_UNITS = 26;

type AttendanceEvalStats = {
  totalWorkUnits: number;
  lateMinutesTotal: number;
  lateEarlyTimes: number;
  missingWorkUnits: number;
  isShortWork: boolean;
};

/** Làm tròn công (tránh lỗi số thực 23.99999999). */
function roundWorkUnits(n: number): number {
  return Math.round((Number(n) || 0) * 100) / 100;
}

function formatWorkUnits(n: number): string {
  const v = roundWorkUnits(n);
  if (Number.isInteger(v)) return String(v);
  return v.toFixed(2).replace(/\.?0+$/, '') || '0';
}

export type NursingEvaluationEditFocus = {
  employeeId: number;
  periodYear: number;
  periodMonth: number;
};

type Props = {
  editFocus?: NursingEvaluationEditFocus | null;
  onEditFocusConsumed?: () => void;
  onDataMutated?: () => void;
};

type RowState = { points: string; note: string };

type RosterItem = employeeService.EmployeeSummary & {
  evalStatus: string;
};

function defaultRows(groups: ne.CriterionGroup[]): Record<string, RowState> {
  const out: Record<string, RowState> = {};
  for (const g of groups) {
    const extra = Boolean(g.bonus || g.penalty || g.id.startsWith('VI_') || g.id.startsWith('VII_'));
    out[g.id] = { points: extra ? '0' : '', note: '' };
  }
  return out;
}

function currentYearMonth(): string {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
}

function filledCount(groups: ne.CriterionGroup[], rows: Record<string, RowState>): { filled: number; total: number } {
  let filled = 0;
  let total = 0;
  for (const g of groups) {
    const extra = Boolean(g.bonus || g.penalty || g.id.startsWith('VI_') || g.id.startsWith('VII_'));
    if (extra) continue;
    total += 1;
    const v = rows[g.id]?.points;
    if (v != null && v !== '' && Number.isFinite(Number(v))) filled += 1;
  }
  return { filled, total };
}

export function NursingEvaluationPanel({ editFocus, onEditFocusConsumed, onDataMutated }: Props) {
  const theme = useTheme();
  const accent = theme.palette.primary.main;
  const { user } = useAuth();
  const canScore = user?.role === 'ADMIN' || isHeadDepartmentRole(user?.role);
  const canViewRoster = canScore;

  const [period, setPeriod] = useState(currentYearMonth);
  const year = Number(period.slice(0, 4));
  const month = Number(period.slice(5, 7));

  const [template, setTemplate] = useState<ne.NursingTemplate | null>(null);
  const [roster, setRoster] = useState<employeeService.EmployeeSummary[]>([]);
  const [periodStatus, setPeriodStatus] = useState<Map<number, ne.NursingPeriodStatusRow>>(new Map());
  const [employeeId, setEmployeeId] = useState<number | ''>('');
  const [rows, setRows] = useState<Record<string, RowState>>({});
  const [comments, setComments] = useState('');
  const [err, setErr] = useState<string | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [attStats, setAttStats] = useState<AttendanceEvalStats | null>(null);
  const [attStatsLoading, setAttStatsLoading] = useState(false);
  const [attStatsErr, setAttStatsErr] = useState<string | null>(null);

  const groups = template?.criteriaGroups ?? [];

  const loadMeta = useCallback(async () => {
    setLoading(true);
    try {
      const [tpl, list, status] = await Promise.all([
        ne.fetchNursingTemplate(ne.MA2026_EVAL_TEMPLATE_CODE),
        canViewRoster ? employeeService.fetchEvaluationRoster() : Promise.resolve([]),
        canViewRoster
          ? ne.fetchNursingPeriodStatus(year, month, ne.MA2026_EVAL_TEMPLATE_CODE)
          : Promise.resolve([]),
      ]);
      setTemplate(tpl);
      setRoster(list);
      setPeriodStatus(new Map(status.map((s) => [s.employeeId, s])));
      setRows((prev) => (Object.keys(prev).length ? prev : defaultRows(tpl.criteriaGroups)));
    } catch {
      setErr('Không tải được mẫu / danh sách nhân viên khối ĐD.');
    } finally {
      setLoading(false);
    }
  }, [canViewRoster, year, month]);

  useEffect(() => {
    void loadMeta();
  }, [loadMeta]);

  useEffect(() => {
    if (!editFocus) return;
    setPeriod(
      `${editFocus.periodYear}-${String(editFocus.periodMonth).padStart(2, '0')}`,
    );
    setEmployeeId(editFocus.employeeId);
    onEditFocusConsumed?.();
  }, [editFocus, onEditFocusConsumed]);

  useEffect(() => {
    if (!employeeId || !template) return;
    let cancelled = false;
    ne.fetchNursingHistory(Number(employeeId))
      .then((hist) => {
        if (cancelled) return;
        const match = hist.find(
          (h) => Number(h.periodYear) === year && Number(h.periodMonth) === month,
        );
        const base = defaultRows(template.criteriaGroups);
        if (match?.scores && typeof match.scores === 'object') {
          const scores = match.scores as Record<string, Record<string, unknown>>;
          for (const g of template.criteriaGroups) {
            const part = scores[g.id];
            if (!part) continue;
            const pts = part.points ?? part.truongKhoa ?? part.ddt;
            base[g.id] = {
              points: pts != null && pts !== '' ? String(pts) : base[g.id].points,
              note:
                part.note != null
                  ? String(part.note)
                  : part.truongKhoaNote != null
                    ? String(part.truongKhoaNote)
                    : '',
            };
          }
        }
        setRows(base);
        setComments(match?.comments != null ? String(match.comments) : '');
      })
      .catch(() => {
        /* keep defaults */
      });
    return () => {
      cancelled = true;
    };
  }, [employeeId, year, month, template]);

  useEffect(() => {
    if (!employeeId) {
      setAttStats(null);
      setAttStatsErr(null);
      return;
    }
    let cancelled = false;
    setAttStatsLoading(true);
    setAttStatsErr(null);
    att
      .fetchMonthDetail(Number(employeeId), year, month)
      .then((detail) => {
        if (cancelled) return;
        const days = detail.days ?? [];
        const lateEarlyTimes = days.filter(
          (d) => !d.lateMinutesExempt && Number(d.lateMinutes || 0) > 0,
        ).length;
        const totalWorkUnits = roundWorkUnits(Number(detail.totalWorkUnits ?? 0));
        const lateMinutesTotal = Math.round(Number(detail.lateMinutesTotal ?? 0));
        const missingWorkUnits = roundWorkUnits(
          Math.max(0, STANDARD_MONTH_WORK_UNITS - totalWorkUnits),
        );
        setAttStats({
          totalWorkUnits,
          lateMinutesTotal,
          lateEarlyTimes,
          missingWorkUnits,
          isShortWork: totalWorkUnits < STANDARD_MONTH_WORK_UNITS - 0.001,
        });
      })
      .catch(() => {
        if (cancelled) return;
        setAttStats(null);
        setAttStatsErr('Không tải được thống kê công tháng này.');
      })
      .finally(() => {
        if (!cancelled) setAttStatsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [employeeId, year, month]);

  const rosterItems: RosterItem[] = useMemo(
    () =>
      roster.map((e) => ({
        ...e,
        evalStatus: periodStatus.get(e.id)?.status || 'NONE',
      })),
    [roster, periodStatus],
  );

  const departmentOptions = useMemo(
    () =>
      [...new Set(rosterItems.map((e) => (e.departmentName || '').trim()).filter(Boolean))].sort((a, b) =>
        a.localeCompare(b, 'vi'),
      ),
    [rosterItems],
  );

  const filteredRoster = useMemo(
    () =>
      applyRequestListFilters(rosterItems, filters, {
        searchText: (e) =>
          [e.fullName, e.employeeCode, e.positionTitle, e.departmentName].map((x) => String(x || '')).join(' '),
        dateValue: () => null,
        statusValue: (e) => ne.nursingEvalStatusFilterGroup(e.evalStatus),
        departmentValue: (e) => e.departmentName || '',
      }),
    [rosterItems, filters],
  );

  const selectedEmp = useMemo(
    () => roster.find((e) => e.id === employeeId),
    [roster, employeeId],
  );

  const selectedStatus = employeeId !== '' ? periodStatus.get(Number(employeeId)) : undefined;

  const previewTotal = useMemo(() => {
    let base = 0;
    let bonus = 0;
    let penalty = 0;
    for (const g of groups) {
      const v = Number(rows[g.id]?.points);
      if (!Number.isFinite(v)) continue;
      if (g.bonus || g.id.startsWith('VI_')) bonus += v;
      else if (g.penalty || g.id.startsWith('VII_')) penalty += v;
      else base += v;
    }
    return Math.max(0, base + bonus - penalty);
  }, [groups, rows]);

  const progress = useMemo(() => {
    const { filled, total } = filledCount(groups, rows);
    return total ? Math.round((filled / total) * 100) : 0;
  }, [groups, rows]);

  const sections = useMemo(() => {
    const map = new Map<string, ne.CriterionGroup[]>();
    for (const g of groups) {
      const key = g.section || 'Khác';
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(g);
    }
    return [...map.entries()];
  }, [groups]);

  const rosterStats = useMemo(() => {
    const done = rosterItems.filter((e) => e.evalStatus === 'APPROVED').length;
    const pending = rosterItems.filter((e) => e.evalStatus.startsWith('PENDING_')).length;
    const none = rosterItems.filter((e) => e.evalStatus === 'NONE').length;
    return { done, pending, none, total: rosterItems.length };
  }, [rosterItems]);

  async function save(submitForReview: boolean) {
    if (!employeeId || !template) return;
    if (!canScore) {
      setErr('Chỉ Trưởng khoa / ĐDT khoa (khối Điều dưỡng) được lập phiếu đánh giá.');
      return;
    }
    setSaving(true);
    setErr(null);
    setMsg(null);
    try {
      if (submitForReview) {
        await ensureHasSignature();
      }
      const scores: Record<string, number> = {};
      const notes: Record<string, string> = {};
      for (const g of groups) {
        const raw = rows[g.id]?.points;
        const n = Number(raw);
        if (!Number.isFinite(n)) {
          throw new Error(`Thiếu điểm: ${g.title}`);
        }
        scores[g.id] = n;
        const note = (rows[g.id]?.note || '').trim();
        if (note) notes[g.id] = note;
      }
      await ne.submitNursingEvaluation({
        employeeId: Number(employeeId),
        periodYear: year,
        periodMonth: month,
        templateCode: template.code,
        scores,
        notes: Object.keys(notes).length ? notes : undefined,
        comments: comments.trim() || undefined,
        submitForReview,
      });
      setMsg(
        submitForReview
          ? 'Đã gửi Trưởng phòng ĐD duyệt (kèm chữ ký).'
          : 'Đã lưu nháp.',
      );
      onDataMutated?.();
      await loadMeta();
    } catch (e) {
      setErr(extractApiErrorMessage(e, e instanceof Error ? e.message : 'Lưu thất bại.'));
    } finally {
      setSaving(false);
    }
  }

  if (loading && !template) {
    return (
      <Box sx={{ py: 3 }}>
        <LinearProgress sx={{ borderRadius: 1 }} />
        <Typography variant="body2" color="text.secondary" sx={{ mt: 1.5 }}>
          Đang tải mẫu đánh giá…
        </Typography>
      </Box>
    );
  }

  return (
    <Box>
      <RequestFlowSteps
        accent={accent}
        steps={[
          { label: 'Lập + chấm', hint: 'Trưởng khoa / ĐDT' },
          { label: 'Trưởng phòng ĐD', hint: 'Xem + ký duyệt' },
          { label: 'HCNS duyệt', hint: 'Ký duyệt' },
          { label: 'Giám đốc', hint: 'Ký duyệt cuối' },
        ]}
      />

      <Box
        sx={{
          mt: 2,
          p: { xs: 2, sm: 2.5 },
          borderRadius: 3,
          border: `1px solid ${alpha(accent, 0.14)}`,
          bgcolor: alpha(theme.palette.background.paper, 0.98),
          boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
        }}
      >
        <Stack
          direction={{ xs: 'column', md: 'row' }}
          spacing={2}
          alignItems={{ md: 'flex-start' }}
          justifyContent="space-between"
          sx={{ mb: 2 }}
        >
          <Stack direction="row" spacing={1.25} alignItems="center">
            <Box
              sx={{
                width: 40,
                height: 40,
                borderRadius: 2,
                display: 'grid',
                placeItems: 'center',
                bgcolor: alpha(accent, 0.12),
                color: accent,
              }}
            >
              <FactCheckOutlinedIcon fontSize="small" />
            </Box>
            <Box>
              <Typography variant="subtitle1" fontWeight={800} letterSpacing="-0.01em">
                Lập phiếu đánh giá
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Chấm theo mẫu Excel MA 2026 — khối ĐD–KTV–HS–Thư ký
              </Typography>
            </Box>
          </Stack>
          <MonthPickerField
            size="small"
            label="Kỳ đánh giá"
            value={period}
            onChange={(v) => {
              setPeriod(v);
              setEmployeeId('');
            }}
            sx={{ width: { xs: '100%', sm: 220 } }}
          />
        </Stack>

        {canViewRoster && (
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mb: 1.75 }}>
            <Chip size="small" label={`${rosterStats.total} NV khối`} sx={{ fontWeight: 700 }} />
            <Chip size="small" color="default" variant="outlined" label={`${rosterStats.none} chưa có phiếu`} sx={{ fontWeight: 650 }} />
            <Chip size="small" color="warning" variant="outlined" label={`${rosterStats.pending} chờ duyệt`} sx={{ fontWeight: 650 }} />
            <Chip size="small" color="success" variant="outlined" label={`${rosterStats.done} đã duyệt`} sx={{ fontWeight: 650 }} />
          </Stack>
        )}

        {template?.note && (
          <Alert severity="info" sx={{ mb: 2, borderRadius: 2 }}>
            {template.note}
          </Alert>
        )}

        {canViewRoster && (
          <Box sx={{ mb: 1.5 }}>
            <RequestListFilters
              value={filters}
              onChange={setFilters}
              title="Tìm nhân viên để chấm"
              hideDateFilters
              resultCount={filteredRoster.length}
              resultCountLabel="NV"
              searchPlaceholder="Tìm tên, mã NV, chức danh…"
              statusOptions={ne.NURSING_EVAL_ROSTER_STATUS_OPTIONS}
              departmentOptions={departmentOptions}
            />
          </Box>
        )}

        {canViewRoster && (
          <Box
            sx={{
              mb: 2,
              maxHeight: 220,
              overflowY: 'auto',
              borderRadius: 2.5,
              border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
              bgcolor: alpha(theme.palette.primary.main, 0.02),
            }}
          >
            {filteredRoster.length === 0 ? (
              <Stack alignItems="center" spacing={1} sx={{ py: 3, px: 2 }}>
                <PersonSearchOutlinedIcon color="disabled" />
                <Typography variant="body2" color="text.secondary">
                  Không có nhân viên khớp bộ lọc.
                </Typography>
              </Stack>
            ) : (
              filteredRoster.map((e) => {
                const active = employeeId === e.id;
                const st = e.evalStatus;
                const label =
                  st === 'NONE' ? 'Chưa có phiếu' : ne.NURSING_EVAL_STATUS_LABEL[st] || st;
                return (
                  <Box
                    key={e.id}
                    onClick={() => setEmployeeId(e.id)}
                    sx={{
                      px: 1.75,
                      py: 1.1,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 1.25,
                      borderBottom: `1px solid ${alpha(theme.palette.divider, 0.7)}`,
                      bgcolor: active ? alpha(accent, 0.1) : 'transparent',
                      borderLeft: active ? `3px solid ${accent}` : '3px solid transparent',
                      transition: 'background-color 0.15s',
                      '&:hover': { bgcolor: alpha(accent, active ? 0.12 : 0.05) },
                    }}
                  >
                    <Box sx={{ flex: 1, minWidth: 0 }}>
                      <Typography variant="body2" fontWeight={750} noWrap>
                        {e.fullName}
                      </Typography>
                      <Typography variant="caption" color="text.secondary" noWrap display="block">
                        {[e.departmentName, e.positionTitle].filter(Boolean).join(' · ') || '—'}
                      </Typography>
                    </Box>
                    <Chip
                      size="small"
                      color={st === 'NONE' ? 'default' : ne.nursingEvalStatusColor(st)}
                      variant={active ? 'filled' : 'outlined'}
                      label={label}
                      sx={{ height: 22, fontWeight: 650, borderRadius: '6px', maxWidth: 160 }}
                    />
                  </Box>
                );
              })
            )}
          </Box>
        )}

        {err && (
          <Alert severity="error" sx={{ mb: 1.5, borderRadius: 2 }} onClose={() => setErr(null)}>
            {err}
          </Alert>
        )}
        {msg && (
          <Alert severity="success" sx={{ mb: 1.5, borderRadius: 2 }} onClose={() => setMsg(null)}>
            {msg}
          </Alert>
        )}

        {employeeId === '' && canViewRoster && (
          <Alert severity="info" sx={{ borderRadius: 2 }}>
            Chọn nhân viên từ danh sách phía trên để xem hoặc lập phiếu đánh giá.
          </Alert>
        )}

        {selectedEmp && (
          <>
            <Stack
              direction={{ xs: 'column', sm: 'row' }}
              spacing={1.25}
              alignItems={{ sm: 'center' }}
              justifyContent="space-between"
              sx={{
                mb: 2,
                p: 1.75,
                borderRadius: 2.5,
                bgcolor: alpha(accent, 0.06),
                border: `1px solid ${alpha(accent, 0.14)}`,
              }}
            >
              <Box>
                <Typography variant="subtitle2" fontWeight={800}>
                  {selectedEmp.fullName}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {[selectedEmp.departmentName, selectedEmp.positionTitle].filter(Boolean).join(' · ')}
                </Typography>
              </Box>
              <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                <Chip
                  size="small"
                  color={
                    selectedStatus?.status
                      ? ne.nursingEvalStatusColor(selectedStatus.status)
                      : 'default'
                  }
                  label={
                    selectedStatus?.status
                      ? ne.NURSING_EVAL_STATUS_LABEL[selectedStatus.status] || selectedStatus.status
                      : 'Chưa có phiếu'
                  }
                  sx={{ fontWeight: 700 }}
                />
                <Chip
                  size="small"
                  color="primary"
                  label={`Tạm tính: ${previewTotal} điểm`}
                  sx={{ fontWeight: 800 }}
                />
              </Stack>
            </Stack>

            {(attStatsLoading || attStats || attStatsErr) && (
              <Box
                sx={{
                  mb: 2,
                  p: 1.75,
                  borderRadius: 2.5,
                  border: `1px solid ${alpha(
                    attStats?.isShortWork ? theme.palette.error.main : theme.palette.info.main,
                    0.22,
                  )}`,
                  bgcolor: alpha(
                    attStats?.isShortWork ? theme.palette.error.main : theme.palette.info.main,
                    0.05,
                  ),
                }}
              >
                <Typography variant="caption" fontWeight={800} color="text.secondary" sx={{ mb: 1, display: 'block' }}>
                  Thống kê công tháng {String(month).padStart(2, '0')}/{year}
                </Typography>
                {attStatsLoading && <LinearProgress sx={{ borderRadius: 1, mb: 1 }} />}
                {attStatsErr && (
                  <Alert severity="warning" sx={{ borderRadius: 2 }}>
                    {attStatsErr}
                  </Alert>
                )}
                {attStats && (
                  <>
                    <Box
                      sx={{
                        display: 'grid',
                        gap: 1.25,
                        gridTemplateColumns: {
                          xs: '1fr 1fr',
                          sm: 'repeat(4, minmax(0, 1fr))',
                        },
                      }}
                    >
                      <Box
                        sx={{
                          p: 1.25,
                          borderRadius: 2,
                          bgcolor: '#fff',
                          border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                        }}
                      >
                        <Typography variant="caption" color="text.secondary" fontWeight={700}>
                          Số công
                        </Typography>
                        <Typography
                          variant="h6"
                          fontWeight={900}
                          color={attStats.isShortWork ? 'error.main' : 'primary.main'}
                          sx={{ lineHeight: 1.2, mt: 0.25 }}
                        >
                          {formatWorkUnits(attStats.totalWorkUnits)}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          Chuẩn {STANDARD_MONTH_WORK_UNITS} công
                        </Typography>
                      </Box>
                      <Box
                        sx={{
                          p: 1.25,
                          borderRadius: 2,
                          bgcolor: '#fff',
                          border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                        }}
                      >
                        <Typography variant="caption" color="text.secondary" fontWeight={700}>
                          Phút muộn / về sớm
                        </Typography>
                        <Typography
                          variant="h6"
                          fontWeight={900}
                          color={attStats.lateMinutesTotal > 0 ? 'warning.dark' : 'text.primary'}
                          sx={{ lineHeight: 1.2, mt: 0.25 }}
                        >
                          {attStats.lateMinutesTotal}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          Tổng phút trong tháng
                        </Typography>
                      </Box>
                      <Box
                        sx={{
                          p: 1.25,
                          borderRadius: 2,
                          bgcolor: '#fff',
                          border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                        }}
                      >
                        <Typography variant="caption" color="text.secondary" fontWeight={700}>
                          Số lần muộn / về sớm
                        </Typography>
                        <Typography
                          variant="h6"
                          fontWeight={900}
                          color={attStats.lateEarlyTimes > 0 ? 'warning.dark' : 'text.primary'}
                          sx={{ lineHeight: 1.2, mt: 0.25 }}
                        >
                          {attStats.lateEarlyTimes}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          Ngày có phút muộn/về sớm
                        </Typography>
                      </Box>
                      <Box
                        sx={{
                          p: 1.25,
                          borderRadius: 2,
                          bgcolor: '#fff',
                          border: `1px solid ${alpha(
                            attStats.isShortWork ? theme.palette.error.main : theme.palette.success.main,
                            0.35,
                          )}`,
                        }}
                      >
                        <Typography variant="caption" color="text.secondary" fontWeight={700}>
                          Thiếu công
                        </Typography>
                        <Typography
                          variant="h6"
                          fontWeight={900}
                          color={attStats.isShortWork ? 'error.main' : 'success.main'}
                          sx={{ lineHeight: 1.2, mt: 0.25 }}
                        >
                          {attStats.isShortWork ? formatWorkUnits(attStats.missingWorkUnits) : '0'}
                        </Typography>
                        <Typography variant="caption" color="text.secondary">
                          {attStats.isShortWork
                            ? `Thiếu so với ${STANDARD_MONTH_WORK_UNITS} công`
                            : 'Đủ công chuẩn'}
                        </Typography>
                      </Box>
                    </Box>
                    {attStats.isShortWork && (
                      <Alert severity="error" sx={{ mt: 1.25, borderRadius: 2 }}>
                        Thiếu công: {formatWorkUnits(attStats.totalWorkUnits)}/{STANDARD_MONTH_WORK_UNITS} công
                        (thiếu {formatWorkUnits(attStats.missingWorkUnits)} công) — lưu ý khi chấm tiêu chí tuân thủ
                        thời gian làm việc.
                      </Alert>
                    )}
                  </>
                )}
              </Box>
            )}

            <Box sx={{ mb: 1.5 }}>
              <Stack direction="row" justifyContent="space-between" sx={{ mb: 0.5 }}>
                <Typography variant="caption" fontWeight={700} color="text.secondary">
                  Tiến độ chấm tiêu chí
                </Typography>
                <Typography variant="caption" fontWeight={800} color="primary.main">
                  {progress}%
                </Typography>
              </Stack>
              <LinearProgress
                variant="determinate"
                value={progress}
                sx={{
                  height: 8,
                  borderRadius: 99,
                  bgcolor: alpha(accent, 0.1),
                  '& .MuiLinearProgress-bar': { borderRadius: 99, bgcolor: accent },
                }}
              />
            </Box>

            <TableContainer
              sx={{
                border: `1px solid ${alpha(theme.palette.divider, 0.95)}`,
                borderRadius: 2.5,
                mb: 2,
                overflowX: 'auto',
                maxWidth: '100%',
              }}
            >
              <Table
                size="small"
                sx={{
                  tableLayout: 'fixed',
                  width: '100%',
                }}
              >
                <colgroup>
                  <col style={{ width: 44 }} />
                  <col />
                  <col style={{ width: 280 }} />
                </colgroup>
                <TableHead>
                  <TableRow sx={{ bgcolor: accent }}>
                    <TableCell sx={{ color: '#fff', fontWeight: 800, px: 1 }}>STT</TableCell>
                    <TableCell sx={{ color: '#fff', fontWeight: 800 }}>Tiêu chí</TableCell>
                    <TableCell sx={{ color: '#fff', fontWeight: 800 }}>Điểm đạt</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {sections.map(([section, items]) => (
                    <Fragment key={`sec-${section}`}>
                      <TableRow>
                        <TableCell
                          colSpan={3}
                          sx={{ bgcolor: alpha(accent, 0.1), fontWeight: 800, color: theme.palette.primary.dark }}
                        >
                          {section}
                          {items[0]?.sectionPoints != null ? ` (${items[0].sectionPoints} điểm)` : ''}
                        </TableCell>
                      </TableRow>
                      {items.map((g) => {
                        const selectedOpt = g.options.find(
                          (o) => String(o.points) === String(rows[g.id]?.points ?? ''),
                        );
                        const selectedLabel = selectedOpt
                          ? `${selectedOpt.points} — ${selectedOpt.label}`
                          : '';
                        return (
                          <TableRow
                            key={g.id}
                            sx={{
                              '&:nth-of-type(even)': { bgcolor: alpha(accent, 0.02) },
                              '&:hover': { bgcolor: alpha(accent, 0.04) },
                            }}
                          >
                            <TableCell sx={{ verticalAlign: 'middle', px: 1 }}>
                              <Typography variant="body2" fontWeight={700} color="text.secondary">
                                {g.no || ''}
                              </Typography>
                            </TableCell>
                            <TableCell sx={{ verticalAlign: 'middle', pr: 1.5 }}>
                              <Typography variant="body2" fontWeight={650} sx={{ whiteSpace: 'normal' }}>
                                {g.title}
                              </Typography>
                            </TableCell>
                            <TableCell sx={{ overflow: 'hidden', verticalAlign: 'middle', width: 280, maxWidth: 280 }}>
                              <TextField
                                select
                                size="small"
                                fullWidth
                                disabled={!canScore}
                                value={rows[g.id]?.points ?? ''}
                                onChange={(e) =>
                                  setRows((prev) => ({
                                    ...prev,
                                    [g.id]: { ...prev[g.id], points: e.target.value },
                                  }))
                                }
                                SelectProps={{
                                  displayEmpty: true,
                                  renderValue: (selected) => {
                                    const v = String(selected ?? '');
                                    if (!v) {
                                      return (
                                        <Typography variant="body2" color="text.secondary" noWrap>
                                          — Chọn điểm —
                                        </Typography>
                                      );
                                    }
                                    const text = selectedLabel || v;
                                    return (
                                      <Typography
                                        component="span"
                                        variant="body2"
                                        title={text}
                                        noWrap
                                        sx={{ display: 'block', maxWidth: '100%', pr: 0.5 }}
                                      >
                                        {text}
                                      </Typography>
                                    );
                                  },
                                  MenuProps: {
                                    PaperProps: {
                                      sx: {
                                        maxWidth: 440,
                                        maxHeight: 360,
                                      },
                                    },
                                  },
                                }}
                                sx={{
                                  maxWidth: '100%',
                                  '& .MuiOutlinedInput-root': {
                                    bgcolor: '#fff',
                                    borderRadius: 2,
                                    maxWidth: '100%',
                                  },
                                  '& .MuiSelect-select': {
                                    overflow: 'hidden',
                                    textOverflow: 'ellipsis',
                                    whiteSpace: 'nowrap',
                                    display: 'block',
                                    boxSizing: 'border-box',
                                    pr: '32px !important',
                                  },
                                }}
                              >
                                <MenuItem value="">— Chọn điểm —</MenuItem>
                                {g.options.map((o) => (
                                  <MenuItem
                                    key={`${g.id}-${o.points}-${o.label}`}
                                    value={String(o.points)}
                                    sx={{
                                      whiteSpace: 'normal',
                                      alignItems: 'flex-start',
                                      py: 1.1,
                                    }}
                                  >
                                    <Typography variant="body2" sx={{ whiteSpace: 'normal', lineHeight: 1.45 }}>
                                      {o.points} — {o.label}
                                    </Typography>
                                  </MenuItem>
                                ))}
                              </TextField>
                            </TableCell>
                          </TableRow>
                        );
                      })}
                    </Fragment>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>

            <TextField
              fullWidth
              size="small"
              multiline
              minRows={2}
              label="Nhận xét chung"
              value={comments}
              disabled={!canScore}
              onChange={(e) => setComments(e.target.value)}
              sx={{
                mb: 2,
                '& .MuiOutlinedInput-root': { bgcolor: '#fff', borderRadius: 2 },
              }}
            />

            {canScore && (
              <Stack
                direction={{ xs: 'column', sm: 'row' }}
                spacing={1.25}
                justifyContent="flex-end"
                sx={{
                  pt: 1.5,
                  borderTop: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                }}
              >
                <Button
                  variant="outlined"
                  disabled={saving}
                  startIcon={<SaveOutlinedIcon />}
                  onClick={() => void save(false)}
                  sx={{ textTransform: 'none', fontWeight: 700, borderRadius: 2 }}
                >
                  Lưu nháp
                </Button>
                <Button
                  variant="contained"
                  disabled={saving}
                  startIcon={<SendOutlinedIcon />}
                  onClick={() => void save(true)}
                  sx={{
                    textTransform: 'none',
                    fontWeight: 800,
                    borderRadius: 2,
                    bgcolor: accent,
                    boxShadow: `0 8px 20px ${alpha(accent, 0.28)}`,
                    '&:hover': { bgcolor: accent, filter: 'brightness(0.94)' },
                  }}
                >
                  Gửi Trưởng phòng ĐD duyệt
                </Button>
              </Stack>
            )}
            {!canScore && (
              <Alert severity="info" sx={{ borderRadius: 2 }}>
                Bạn chỉ xem được phiếu trong khối; Trưởng khoa / ĐDT khoa lập, chấm và gửi Trưởng phòng ĐD duyệt.
              </Alert>
            )}
          </>
        )}
      </Box>
    </Box>
  );
}
