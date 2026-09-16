import AssignmentOutlinedIcon from '@mui/icons-material/AssignmentOutlined';
import BiotechOutlinedIcon from '@mui/icons-material/BiotechOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import DraftsOutlinedIcon from '@mui/icons-material/DraftsOutlined';
import EditOutlinedIcon from '@mui/icons-material/EditOutlined';
import FilterAltOutlinedIcon from '@mui/icons-material/FilterAltOutlined';
import InboxOutlinedIcon from '@mui/icons-material/InboxOutlined';
import InsightsOutlinedIcon from '@mui/icons-material/InsightsOutlined';
import LocalHospitalOutlinedIcon from '@mui/icons-material/LocalHospitalOutlined';
import RefreshOutlinedIcon from '@mui/icons-material/RefreshOutlined';
import VisibilityOutlinedIcon from '@mui/icons-material/VisibilityOutlined';
import UndoOutlinedIcon from '@mui/icons-material/UndoOutlined';
import VolunteerActivismOutlinedIcon from '@mui/icons-material/VolunteerActivismOutlined';
import {
  Alert,
  Avatar,
  Box,
  Button,
  Chip,
  CircularProgress,
  IconButton,
  LinearProgress,
  MenuItem,
  Paper,
  Stack,
  Tab,
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import { QtktEvaluationDialog } from '../components/qtkt/QtktEvaluationDialog';
import { QtktScoringPanel } from '../components/qtkt/QtktScoringPanel';
import { HandHygieneComplianceReportPanel } from '../components/qtkt/compliance/HandHygieneComplianceReportPanel';
import { QtktTechnicalComplianceReportPanel } from '../components/qtkt/compliance/QtktTechnicalComplianceReportPanel';
import { GdskComplianceReportPanel } from '../components/qtkt/compliance/GdskComplianceReportPanel';
import { MonthPickerField } from '../components/ui/DateTimeFields';
import { useAuth } from '../context/AuthContext';
import { extractApiErrorMessage } from '../services/approvalSignatureService';
import * as qtkt from '../services/qtktEvaluationService';

const ACCENT = '#0f766e';
const INK = '#0f172a';

function currentYearMonth() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function monthRange(ym: string) {
  const [y, m] = ym.split('-').map(Number);
  const from = `${y}-${String(m).padStart(2, '0')}-01`;
  const last = new Date(y, m, 0).getDate();
  const to = `${y}-${String(m).padStart(2, '0')}-${String(last).padStart(2, '0')}`;
  return { from, to };
}

function formatDate(iso: string) {
  const [y, m, d] = iso.split('-');
  return y && m && d ? `${d}/${m}/${y}` : iso;
}

function formatMonthLabel(ym: string) {
  const [y, m] = ym.split('-');
  if (!y || !m) return ym;
  return `Tháng ${Number(m)}/${y}`;
}

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

function statusMeta(status: string) {
  if (status === 'SUBMITTED') return { label: 'Đã gửi', color: '#15803d', soft: '#ecfdf5' };
  if (status === 'DRAFT') return { label: 'Nháp', color: '#b45309', soft: '#fffbeb' };
  return { label: 'Đã hủy', color: '#64748b', soft: '#f8fafc' };
}

function scoreTone(pct: number) {
  if (pct >= 90) return '#15803d';
  if (pct >= 70) return ACCENT;
  if (pct >= 50) return '#b45309';
  return '#be123c';
}

function KpiCard({
  icon,
  label,
  value,
  hint,
  color,
}: {
  icon: ReactNode;
  label: string;
  value: number | string;
  hint: string;
  color: string;
}) {
  return (
    <Paper
      elevation={0}
      sx={{
        p: 1.75,
        borderRadius: 2.75,
        border: `1px solid ${alpha(color, 0.16)}`,
        background: `linear-gradient(145deg, ${alpha(color, 0.09)} 0%, #fff 62%)`,
        minHeight: 98,
        display: 'flex',
        flexDirection: 'column',
        gap: 0.85,
      }}
    >
      <Stack direction="row" spacing={1.1} alignItems="center">
        <Box
          sx={{
            width: 34,
            height: 34,
            borderRadius: 1.5,
            display: 'grid',
            placeItems: 'center',
            bgcolor: alpha(color, 0.14),
            color,
            flexShrink: 0,
          }}
        >
          {icon}
        </Box>
        <Typography variant="caption" color="text.secondary" fontWeight={700} sx={{ letterSpacing: '0.02em' }}>
          {label}
        </Typography>
      </Stack>
      <Typography
        fontWeight={850}
        sx={{ fontSize: '1.65rem', lineHeight: 1, letterSpacing: '-0.045em', color: INK }}
      >
        {value}
      </Typography>
      <Typography variant="caption" color="text.secondary" sx={{ lineHeight: 1.3 }}>
        {hint}
      </Typography>
    </Paper>
  );
}

function EmptyListState({ monthLabel }: { monthLabel: string }) {
  return (
    <Paper
      elevation={0}
      sx={{
        py: { xs: 5, md: 6.5 },
        px: 3,
        borderRadius: 3,
        border: `1px dashed ${alpha(ACCENT, 0.28)}`,
        bgcolor: alpha(ACCENT, 0.03),
        textAlign: 'center',
      }}
    >
      <Box
        sx={{
          width: 56,
          height: 56,
          mx: 'auto',
          mb: 1.5,
          borderRadius: '50%',
          display: 'grid',
          placeItems: 'center',
          bgcolor: alpha(ACCENT, 0.1),
          color: ACCENT,
        }}
      >
        <InboxOutlinedIcon />
      </Box>
      <Typography variant="subtitle1" fontWeight={800} sx={{ mb: 0.5 }}>
        Chưa có phiếu trong {monthLabel}
      </Typography>
      <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 420, mx: 'auto' }}>
        Thử đổi tháng / quy trình / trạng thái, hoặc tạo phiếu mới từ bảng chấm điểm phía trên (nếu bạn là Trưởng khoa).
      </Typography>
    </Paper>
  );
}

function groupStatusMeta(evals: qtkt.QtktEvaluation[]) {
  const hasSubmitted = evals.some((e) => e.status === 'SUBMITTED');
  const hasDraft = evals.some((e) => e.status === 'DRAFT');
  const submitted = evals.filter((e) => e.status === 'SUBMITTED');
  const avg =
    submitted.length > 0
      ? submitted.reduce((s, e) => s + Number(e.totalScore), 0) / submitted.length
      : null;
  const avgHint = avg != null ? ` · TB ${avg.toFixed(2)}` : '';
  if (hasSubmitted && hasDraft) return { label: `${evals.length} phiếu`, sub: `Có nháp${avgHint}`, color: '#0284c7', soft: '#f0f9ff' };
  if (hasSubmitted) return { label: `${evals.length} phiếu`, sub: `TB ${avg!.toFixed(2)} đ`, color: '#15803d', soft: '#ecfdf5' };
  if (hasDraft) return { label: `${evals.length} phiếu`, sub: 'Nháp', color: '#b45309', soft: '#fffbeb' };
  return { label: `${evals.length} phiếu`, sub: '', color: '#64748b', soft: '#f8fafc' };
}

function EmployeeEvalCard({
  evals,
  canCreate,
  onView,
  onEdit,
}: {
  evals: qtkt.QtktEvaluation[];
  canCreate: boolean;
  onView: (row: qtkt.QtktEvaluation) => void;
  onEdit: (row: qtkt.QtktEvaluation) => void;
}) {
  const sorted = useMemo(
    () =>
      [...evals].sort((a, b) => {
        const proc = a.procedureName.localeCompare(b.procedureName, 'vi');
        if (proc !== 0) return proc;
        return (a.checkContextLabel ?? '').localeCompare(b.checkContextLabel ?? '', 'vi');
      }),
    [evals],
  );
  const [selectedId, setSelectedId] = useState(sorted[0]?.id ?? 0);
  useEffect(() => {
    if (!sorted.some((e) => e.id === selectedId)) {
      setSelectedId(sorted[0]?.id ?? 0);
    }
  }, [sorted, selectedId]);

  const row = sorted.find((e) => e.id === selectedId) ?? sorted[0];
  if (!row) return null;

  const groupSt = groupStatusMeta(sorted);
  const rowSt = statusMeta(row.status);
  const pct = row.maxScore > 0 ? Math.round((row.totalScore / row.maxScore) * 100) : 0;
  const tone = scoreTone(pct);
  const canEdit = row.canEdit === true;
  const multi = sorted.length > 1;

  return (
    <Paper
      elevation={0}
      sx={{
        position: 'relative',
        borderRadius: 3,
        border: `1px solid ${alpha(INK, 0.08)}`,
        bgcolor: '#fff',
        overflow: 'hidden',
        transition: 'transform 0.14s ease, box-shadow 0.14s ease, border-color 0.14s ease',
        '&:hover': {
          transform: 'translateY(-2px)',
          borderColor: alpha(ACCENT, 0.32),
          boxShadow: `0 16px 36px ${alpha(INK, 0.08)}`,
        },
      }}
    >
      <Box
        sx={{
          px: 1.75,
          pt: 1.6,
          pb: 1.35,
          background: `linear-gradient(135deg, ${alpha(ACCENT, 0.09)} 0%, ${alpha(groupSt.color, 0.04)} 45%, #fff 100%)`,
          borderBottom: `1px solid ${alpha(INK, 0.05)}`,
        }}
      >
        <Stack direction="row" spacing={1.2} alignItems="center">
          <Avatar
            sx={{
              width: 44,
              height: 44,
              fontSize: 14,
              fontWeight: 850,
              bgcolor: '#fff',
              color: ACCENT,
              border: `1.5px solid ${alpha(ACCENT, 0.22)}`,
              boxShadow: `0 4px 12px ${alpha(ACCENT, 0.12)}`,
            }}
          >
            {initials(row.employeeName)}
          </Avatar>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography variant="subtitle2" fontWeight={850} noWrap sx={{ lineHeight: 1.2, letterSpacing: '-0.01em' }}>
              {row.employeeName}
            </Typography>
            <Typography variant="caption" color="text.secondary" noWrap sx={{ display: 'block', mt: 0.15 }}>
              {row.employeeCode ? `${row.employeeCode} · ` : ''}
              {row.departmentName}
            </Typography>
          </Box>
          <Stack alignItems="flex-end" spacing={0.35} sx={{ flexShrink: 0 }}>
            <Chip
              size="small"
              label={groupSt.label}
              sx={{
                height: 22,
                fontWeight: 800,
                bgcolor: groupSt.soft,
                color: groupSt.color,
                border: `1px solid ${alpha(groupSt.color, 0.18)}`,
              }}
            />
            {groupSt.sub && (
              <Typography variant="caption" fontWeight={700} sx={{ color: groupSt.color, fontSize: '0.68rem' }}>
                {groupSt.sub}
              </Typography>
            )}
          </Stack>
        </Stack>
      </Box>

      <Stack spacing={1.25} sx={{ p: 1.75 }}>
        {multi ? (
          <TextField
            select
            size="small"
            fullWidth
            label="Chọn phiếu"
            value={row.id}
            onChange={(e) => setSelectedId(Number(e.target.value))}
            sx={{
              '& .MuiOutlinedInput-root': {
                borderRadius: 2,
                bgcolor: alpha(ACCENT, 0.035),
                '& fieldset': { borderColor: alpha(ACCENT, 0.18) },
                '&:hover fieldset': { borderColor: alpha(ACCENT, 0.35) },
              },
            }}
            SelectProps={{
              renderValue: () => (
                <Stack direction="row" spacing={0.75} alignItems="center" sx={{ minWidth: 0 }}>
                  <BiotechOutlinedIcon sx={{ fontSize: 17, color: ACCENT, flexShrink: 0 }} />
                  <Typography variant="body2" fontWeight={750} sx={{ color: ACCENT }} noWrap>
                    {qtkt.qtktEvalDisplayLabel(row)}
                  </Typography>
                </Stack>
              ),
            }}
          >
            {sorted.map((ev) => {
              const st = statusMeta(ev.status);
              return (
                <MenuItem key={ev.id} value={ev.id}>
                  <Stack direction="row" spacing={1} alignItems="center" sx={{ width: '100%', minWidth: 0 }}>
                    <BiotechOutlinedIcon sx={{ fontSize: 16, color: ACCENT }} />
                    <Box sx={{ flex: 1, minWidth: 0 }}>
                      <Typography variant="body2" fontWeight={700} noWrap>
                        {qtkt.qtktEvalDisplayLabel(ev)}
                      </Typography>
                      <Typography variant="caption" color="text.secondary">
                        {Number(ev.totalScore).toFixed(2)}/{Number(ev.maxScore).toFixed(0)} · {formatDate(ev.evalDate)} · {st.label}
                      </Typography>
                    </Box>
                  </Stack>
                </MenuItem>
              );
            })}
          </TextField>
        ) : (
          <Box
            sx={{
              display: 'flex',
              alignItems: 'center',
              gap: 0.85,
              px: 1.15,
              py: 0.85,
              borderRadius: 2,
              bgcolor: alpha(ACCENT, 0.05),
              border: `1px solid ${alpha(ACCENT, 0.12)}`,
            }}
          >
            <BiotechOutlinedIcon sx={{ fontSize: 17, color: ACCENT, flexShrink: 0 }} />
            <Typography variant="body2" fontWeight={750} sx={{ color: ACCENT, lineHeight: 1.3 }} noWrap>
              {qtkt.qtktEvalDisplayLabel(row)}
            </Typography>
          </Box>
        )}

        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: '1fr auto',
            gap: 1.25,
            alignItems: 'center',
            p: 1.25,
            borderRadius: 2.25,
            bgcolor: alpha(INK, 0.02),
            border: `1px solid ${alpha(INK, 0.06)}`,
          }}
        >
          <Box sx={{ minWidth: 0 }}>
            <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mb: 0.85 }}>
              <Chip
                size="small"
                label={rowSt.label}
                sx={{
                  height: 22,
                  fontWeight: 750,
                  bgcolor: rowSt.soft,
                  color: rowSt.color,
                  border: `1px solid ${alpha(rowSt.color, 0.18)}`,
                }}
              />
              <Typography variant="caption" color="text.secondary" fontWeight={650}>
                {formatDate(row.evalDate)}
              </Typography>
            </Stack>
            <Typography variant="caption" color="text.secondary" fontWeight={650} display="block" sx={{ mb: 0.45 }}>
              Mức đạt
            </Typography>
            <LinearProgress
              variant="determinate"
              value={Math.min(100, pct)}
              sx={{
                height: 7,
                borderRadius: 99,
                bgcolor: alpha(tone, 0.12),
                '& .MuiLinearProgress-bar': { borderRadius: 99, bgcolor: tone },
              }}
            />
            {(row.createdByName || row.createdByUsername || row.submittedAt) && (
              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.7, lineHeight: 1.3 }}>
                {row.createdByName || row.createdByUsername
                  ? `Người chấm: ${row.createdByName || row.createdByUsername}`
                  : ''}
                {row.submittedAt
                  ? `${row.createdByName || row.createdByUsername ? ' · ' : ''}Gửi ${formatDate(row.submittedAt.slice(0, 10))}`
                  : ''}
              </Typography>
            )}
          </Box>
          <Box
            sx={{
              minWidth: 72,
              px: 1,
              py: 0.85,
              borderRadius: 2,
              textAlign: 'center',
              bgcolor: alpha(tone, 0.08),
              border: `1px solid ${alpha(tone, 0.18)}`,
            }}
          >
            <Typography fontWeight={850} sx={{ fontSize: '1.15rem', lineHeight: 1, letterSpacing: '-0.04em', color: tone }}>
              {Number(row.totalScore).toFixed(1)}
            </Typography>
            <Typography variant="caption" color="text.secondary" fontWeight={700} sx={{ fontSize: '0.65rem' }}>
              / {Number(row.maxScore).toFixed(0)} · {pct}%
            </Typography>
          </Box>
        </Box>

        <Stack
          direction="row"
          spacing={1}
          justifyContent="flex-end"
          sx={{
            pt: 0.25,
            borderTop: `1px dashed ${alpha(INK, 0.08)}`,
          }}
        >
          <Tooltip title="Xem phiếu">
            <IconButton
              size="small"
              onClick={() => onView(row)}
              sx={{
                width: 36,
                height: 36,
                color: ACCENT,
                border: `1px solid ${alpha(ACCENT, 0.22)}`,
                borderRadius: 1.75,
                bgcolor: '#fff',
                '&:hover': { bgcolor: alpha(ACCENT, 0.08) },
              }}
            >
              <VisibilityOutlinedIcon sx={{ fontSize: 18 }} />
            </IconButton>
          </Tooltip>
          {canEdit && (
            <Tooltip title="Chỉnh sửa">
              <IconButton
                size="small"
                onClick={() => onEdit(row)}
                sx={{
                  width: 36,
                  height: 36,
                  color: '#fff',
                  bgcolor: ACCENT,
                  borderRadius: 1.75,
                  boxShadow: `0 6px 14px ${alpha(ACCENT, 0.28)}`,
                  '&:hover': { bgcolor: ACCENT, filter: 'brightness(0.93)' },
                }}
              >
                <EditOutlinedIcon sx={{ fontSize: 18 }} />
              </IconButton>
            </Tooltip>
          )}
        </Stack>
      </Stack>
    </Paper>
  );
}

export default function QtktEvaluationsPage() {
  const { user } = useAuth();
  const canCreate =
    user?.role === 'ADMIN' || user?.role === 'HEAD_DEPARTMENT' || user?.role === 'HEAD_NURSING';
  const isOffice = user?.role === 'ADMIN' || user?.role === 'HEAD_NURSING';

  const [tab, setTab] = useState(0);
  const [template, setTemplate] = useState<qtkt.QtktTemplate | null>(null);
  const [employees, setEmployees] = useState<qtkt.QtktEmployee[]>([]);
  const [departments, setDepartments] = useState<qtkt.QtktDepartment[]>([]);
  const [rows, setRows] = useState<qtkt.QtktEvaluation[]>([]);
  const [yearMonth, setYearMonth] = useState(currentYearMonth());
  const [departmentId, setDepartmentId] = useState<number | ''>('');
  const [procedureCode, setProcedureCode] = useState('');
  const [status, setStatus] = useState(isOffice ? 'SUBMITTED' : '');
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [active, setActive] = useState<qtkt.QtktEvaluation | null>(null);
  const [readOnly, setReadOnly] = useState(false);
  const [listKey, setListKey] = useState(0);

  const { from, to } = useMemo(() => monthRange(yearMonth), [yearMonth]);
  const monthLabel = useMemo(() => formatMonthLabel(yearMonth), [yearMonth]);

  const reloadMeta = useCallback(async () => {
    const [t, emps, deps] = await Promise.all([
      qtkt.fetchQtktTemplate(),
      qtkt.fetchQtktEmployees(),
      qtkt.fetchQtktDepartments(),
    ]);
    setTemplate(t);
    setEmployees(emps);
    setDepartments(deps);
  }, []);

  const reloadList = useCallback(async () => {
    const data = await qtkt.fetchQtktEvaluations({
      from,
      to,
      departmentId: departmentId === '' ? undefined : departmentId,
      procedureCode: procedureCode || undefined,
      status: status || undefined,
    });
    setRows(data);
  }, [from, to, departmentId, procedureCode, status]);

  const reload = useCallback(async () => {
    if (tab >= 1) return;
    setLoading(true);
    setErr(null);
    try {
      await reloadMeta();
      await reloadList();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Không tải được dữ liệu đánh giá QTKT.'));
    } finally {
      setLoading(false);
    }
  }, [reloadMeta, reloadList, tab]);

  useEffect(() => {
    if (tab >= 1) return;
    void reload();
  }, [reload, listKey, tab]);

  const submittedCount = useMemo(() => rows.filter((r) => r.status === 'SUBMITTED').length, [rows]);
  const draftCount = useMemo(() => rows.filter((r) => r.status === 'DRAFT').length, [rows]);
  const cancelledCount = useMemo(() => rows.filter((r) => r.status === 'CANCELLED').length, [rows]);
  const avgScore = useMemo(() => {
    const scored = rows.filter((r) => r.status === 'SUBMITTED');
    if (scored.length === 0) return null;
    const sum = scored.reduce((acc, r) => acc + Number(r.totalScore), 0);
    return sum / scored.length;
  }, [rows]);

  const employeeGroups = useMemo(() => {
    const map = new Map<number, qtkt.QtktEvaluation[]>();
    for (const row of rows) {
      const list = map.get(row.employeeId) ?? [];
      list.push(row);
      map.set(row.employeeId, list);
    }
    return [...map.values()].sort((a, b) =>
      a[0].employeeName.localeCompare(b[0].employeeName, 'vi'),
    );
  }, [rows]);

  const roleHint = isOffice
    ? 'Phạm vi toàn khối Điều dưỡng — lọc theo khoa / quy trình / trạng thái'
    : 'Phạm vi khoa của bạn — theo dõi phiếu đã chấm và trạng thái gửi';

  function openRow(row: qtkt.QtktEvaluation, viewOnly: boolean) {
    setActive(row);
    setReadOnly(viewOnly || row.canEdit === false);
    setDialogOpen(true);
  }

  return (
    <Box>
      <PageHeader
        overline="Điều dưỡng"
        title="Đánh giá quy trình kỹ thuật"
        description="Trưởng khoa / Điều dưỡng trưởng khoa chấm điểm NV theo checklist QTKT. Trưởng phòng Điều dưỡng xem và tổng hợp toàn khối."
        actions={
          <Chip
            size="small"
            color="primary"
            variant="outlined"
            label="4 quy trình · thang 10"
            sx={{ fontWeight: 700 }}
          />
        }
      />

      {canCreate && (
        <QtktScoringPanel
          onDataMutated={() => {
            setListKey((k) => k + 1);
          }}
        />
      )}

      <Paper
        elevation={0}
        sx={{
          mb: 2.25,
          borderRadius: 3.25,
          border: `1px solid ${alpha(INK, 0.08)}`,
          bgcolor: '#fff',
          overflow: 'hidden',
          boxShadow: `0 10px 30px ${alpha(INK, 0.035)}`,
        }}
      >
        <Box
          sx={{
            px: { xs: 1.75, md: 2.25 },
            pt: 1.75,
            pb: 0.5,
            background: `linear-gradient(120deg, ${alpha(ACCENT, 0.08)} 0%, #fff 48%, ${alpha('#0e7490', 0.04)} 100%)`,
            borderBottom: `1px solid ${alpha(INK, 0.06)}`,
          }}
        >
          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            justifyContent="space-between"
            alignItems={{ sm: 'center' }}
            spacing={1}
            sx={{ mb: 0.5 }}
          >
            <Box>
              <Typography variant="subtitle1" fontWeight={850} sx={{ letterSpacing: '-0.02em' }}>
                Quản lý phiếu đánh giá
              </Typography>
              <Typography variant="caption" color="text.secondary">
                {roleHint}
              </Typography>
            </Box>
            <Chip
              size="small"
              icon={<FilterAltOutlinedIcon sx={{ fontSize: '16px !important' }} />}
              label={monthLabel}
              sx={{
                fontWeight: 750,
                bgcolor: alpha(ACCENT, 0.1),
                color: ACCENT,
                border: `1px solid ${alpha(ACCENT, 0.18)}`,
                '& .MuiChip-icon': { color: ACCENT },
              }}
            />
          </Stack>

          <Tabs
            value={tab}
            onChange={(_, v) => setTab(v)}
            variant="scrollable"
            scrollButtons="auto"
            sx={{
              minHeight: 44,
              '& .MuiTab-root': {
                fontWeight: 750,
                textTransform: 'none',
                minHeight: 44,
                px: 1.5,
              },
              '& .MuiTabs-indicator': { height: 3, borderRadius: 99, bgcolor: ACCENT },
            }}
          >
            <Tab
              icon={<AssignmentOutlinedIcon sx={{ fontSize: 18 }} />}
              iconPosition="start"
              label="Danh sách phiếu"
            />
            <Tab
              icon={<LocalHospitalOutlinedIcon sx={{ fontSize: 18 }} />}
              iconPosition="start"
              label="BC vệ sinh tay"
            />
            <Tab
              icon={<BiotechOutlinedIcon sx={{ fontSize: 18 }} />}
              iconPosition="start"
              label="BC tuân thủ QTKT"
            />
            <Tab
              icon={<VolunteerActivismOutlinedIcon sx={{ fontSize: 18 }} />}
              iconPosition="start"
              label="BC tư vấn GDSK"
            />
          </Tabs>
        </Box>

        {tab === 0 && (
        <Stack
          direction="row"
          spacing={1.1}
          alignItems="center"
          sx={{
            px: { xs: 1.75, md: 2.25 },
            py: 1.65,
            bgcolor: alpha(INK, 0.012),
          }}
        >
          <Box
              sx={{
                flex: 1,
                minWidth: 0,
                display: 'grid',
                gap: 1.1,
                gridTemplateColumns: isOffice
                  ? {
                      xs: 'minmax(140px, 1fr) minmax(120px, 1.1fr)',
                      sm: 'minmax(150px, 1.05fr) minmax(140px, 1.15fr) minmax(160px, 1.35fr) minmax(120px, 0.9fr)',
                    }
                  : {
                      xs: 'minmax(140px, 1fr) minmax(120px, 1fr)',
                      sm: 'minmax(160px, 1.1fr) minmax(180px, 1.4fr) minmax(130px, 0.95fr)',
                    },
              }}
            >
              <MonthPickerField
                label="Tháng đánh giá"
                value={yearMonth}
                onChange={setYearMonth}
                size="small"
                fullWidth
                sx={{ bgcolor: '#fff', borderRadius: 1.5 }}
              />
              {isOffice && (
                <TextField
                  select
                  size="small"
                  fullWidth
                  label="Khoa"
                  value={departmentId}
                  onChange={(e) => setDepartmentId(e.target.value === '' ? '' : Number(e.target.value))}
                  sx={{ bgcolor: '#fff', borderRadius: 1.5 }}
                >
                  <MenuItem value="">Tất cả khoa</MenuItem>
                  {departments.map((d) => (
                    <MenuItem key={d.id} value={d.id}>
                      {d.name}
                    </MenuItem>
                  ))}
                </TextField>
              )}
              <TextField
                select
                size="small"
                fullWidth
                label="Quy trình"
                value={procedureCode}
                onChange={(e) => setProcedureCode(e.target.value)}
                sx={{ bgcolor: '#fff', borderRadius: 1.5 }}
              >
                <MenuItem value="">Tất cả quy trình</MenuItem>
                {(template?.procedures ?? []).map((p) => (
                  <MenuItem key={p.code} value={p.code}>
                    {p.name}
                  </MenuItem>
                ))}
              </TextField>
              <TextField
                select
                size="small"
                fullWidth
                label="Trạng thái"
                value={status}
                onChange={(e) => setStatus(e.target.value)}
                sx={{ bgcolor: '#fff', borderRadius: 1.5 }}
              >
                <MenuItem value="">Tất cả</MenuItem>
                <MenuItem value="SUBMITTED">Đã gửi</MenuItem>
                <MenuItem value="DRAFT">Nháp</MenuItem>
                <MenuItem value="CANCELLED">Đã hủy</MenuItem>
              </TextField>
            </Box>
          <Tooltip title="Tải lại dữ liệu">
            <span>
              <IconButton
                onClick={() => void reload()}
                disabled={loading}
                size="small"
                sx={{
                  flexShrink: 0,
                  border: `1px solid ${alpha(ACCENT, 0.28)}`,
                  color: ACCENT,
                  borderRadius: 1.75,
                  bgcolor: '#fff',
                  '&:hover': { bgcolor: alpha(ACCENT, 0.06) },
                }}
              >
                <RefreshOutlinedIcon fontSize="small" />
              </IconButton>
            </span>
          </Tooltip>
        </Stack>
        )}
      </Paper>

      {err && tab === 0 && (
        <Alert severity="error" sx={{ mb: 2, borderRadius: 2.5 }}>
          {err}
        </Alert>
      )}

      {loading && !template && tab === 0 ? (
        <Box sx={{ py: 8, textAlign: 'center' }}>
          <CircularProgress size={32} sx={{ color: ACCENT }} />
        </Box>
      ) : tab === 0 ? (
        <Stack spacing={2}>
          <Box
            sx={{
              display: 'grid',
              gridTemplateColumns: {
                xs: '1fr 1fr',
                md: 'repeat(4, 1fr)',
              },
              gap: 1.25,
            }}
          >
            <KpiCard
              icon={<CheckCircleOutlineIcon fontSize="small" />}
              label="Đã gửi"
              value={submittedCount}
              hint={`Phiếu đã chuyển Trưởng phòng ĐD · ${monthLabel}`}
              color="#15803d"
            />
            <KpiCard
              icon={<DraftsOutlinedIcon fontSize="small" />}
              label="Nháp"
              value={draftCount}
              hint="Phiếu đang soạn / chưa gửi"
              color="#b45309"
            />
            <KpiCard
              icon={<AssignmentOutlinedIcon fontSize="small" />}
              label="Tổng phiếu"
              value={rows.length}
              hint={cancelledCount > 0 ? `Gồm ${cancelledCount} đã hủy` : 'Theo bộ lọc hiện tại'}
              color={ACCENT}
            />
            <KpiCard
              icon={<InsightsOutlinedIcon fontSize="small" />}
              label="Điểm TB đã gửi"
              value={avgScore == null ? '—' : avgScore.toFixed(2)}
              hint="Trung bình điểm các phiếu đã gửi"
              color="#0e7490"
            />
          </Box>

          {loading ? (
            <LinearProgress
              sx={{
                height: 3,
                borderRadius: 99,
                bgcolor: alpha(ACCENT, 0.1),
                '& .MuiLinearProgress-bar': { bgcolor: ACCENT },
              }}
            />
          ) : null}

          {rows.length === 0 && !loading ? (
            <EmptyListState monthLabel={monthLabel} />
          ) : (
            <Box
              sx={{
                display: 'grid',
                gridTemplateColumns: {
                  xs: '1fr',
                  sm: '1fr 1fr',
                  lg: 'repeat(3, 1fr)',
                },
                gap: 1.5,
              }}
            >
              {employeeGroups.map((evals) => (
                <EmployeeEvalCard
                  key={evals[0].employeeId}
                  evals={evals}
                  canCreate={canCreate}
                  onView={(row) => openRow(row, true)}
                  onEdit={(row) => openRow(row, false)}
                />
              ))}
            </Box>
          )}
        </Stack>
      ) : tab === 1 ? (
        <HandHygieneComplianceReportPanel />
      ) : tab === 2 ? (
        <QtktTechnicalComplianceReportPanel />
      ) : tab === 3 ? (
        <GdskComplianceReportPanel />
      ) : null}

      {dialogOpen && template && (
        <QtktEvaluationDialog
          open
          template={template}
          employees={employees}
          existing={active}
          readOnly={readOnly}
          onClose={() => setDialogOpen(false)}
          onSaved={() => void reload()}
        />
      )}
    </Box>
  );
}
