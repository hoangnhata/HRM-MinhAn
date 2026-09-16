import EditOutlinedIcon from '@mui/icons-material/EditOutlined';
import ExpandLessIcon from '@mui/icons-material/ExpandLess';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import FactCheckOutlinedIcon from '@mui/icons-material/FactCheckOutlined';
import PersonSearchOutlinedIcon from '@mui/icons-material/PersonSearchOutlined';
import ScienceOutlinedIcon from '@mui/icons-material/ScienceOutlined';
import VisibilityOutlinedIcon from '@mui/icons-material/VisibilityOutlined';
import {
  Alert,
  Box,
  Button,
  Chip,
  Collapse,
  IconButton,
  Stack,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { extractApiErrorMessage } from '../../services/approvalSignatureService';
import * as qtkt from '../../services/qtktEvaluationService';
import {
  applyRequestListFilters,
  EMPTY_REQUEST_FILTERS,
  RequestListFilters,
  type RequestListFilterState,
} from '../requests/RequestListFilters';
import { MonthPickerField } from '../ui/DateTimeFields';
import { QtktEvaluationDialog } from './QtktEvaluationDialog';

const ACCENT = '#0f766e';

const STATUS_OPTIONS = [
  { value: 'NONE', label: 'Chưa có phiếu' },
  { value: 'DRAFT', label: 'Nháp' },
  { value: 'SUBMITTED', label: 'Đã gửi' },
  { value: 'MIXED', label: 'Có nháp + đã gửi' },
];

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

function formatMonthLabel(ym: string) {
  const [y, m] = ym.split('-');
  if (!y || !m) return ym;
  return `Tháng ${Number(m)}/${y}`;
}

type EmpStatus = 'NONE' | 'DRAFT' | 'SUBMITTED' | 'MIXED';

type RosterItem = qtkt.QtktEmployee & { evalStatus: EmpStatus; evalCount: number };

function statusLabel(st: EmpStatus) {
  return STATUS_OPTIONS.find((o) => o.value === st)?.label ?? st;
}

function statusColor(st: EmpStatus): 'default' | 'warning' | 'success' | 'info' {
  if (st === 'SUBMITTED') return 'success';
  if (st === 'DRAFT') return 'warning';
  if (st === 'MIXED') return 'info';
  return 'default';
}

type Props = {
  onDataMutated?: () => void;
};

export function QtktScoringPanel({ onDataMutated }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const canScore = user?.role === 'ADMIN' || user?.role === 'HEAD_DEPARTMENT';

  const [expanded, setExpanded] = useState(false);
  const [period, setPeriod] = useState(currentYearMonth);
  const [template, setTemplate] = useState<qtkt.QtktTemplate | null>(null);
  const [employees, setEmployees] = useState<qtkt.QtktEmployee[]>([]);
  const [monthEvals, setMonthEvals] = useState<qtkt.QtktEvaluation[]>([]);
  const [employeeId, setEmployeeId] = useState<number | ''>('');
  const [filters, setFilters] = useState<RequestListFilterState>(EMPTY_REQUEST_FILTERS);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [dialogExisting, setDialogExisting] = useState<qtkt.QtktEvaluation | null>(null);
  const [dialogProcedure, setDialogProcedure] = useState<string | undefined>();
  const [dialogCheckContext, setDialogCheckContext] = useState<string | undefined>();
  const [readOnly, setReadOnly] = useState(false);

  const { from, to } = useMemo(() => monthRange(period), [period]);

  const load = useCallback(async () => {
    if (!canScore) return;
    setLoading(true);
    setErr(null);
    try {
      const [tpl, emps, evals] = await Promise.all([
        qtkt.fetchQtktTemplate(),
        qtkt.fetchQtktEmployees(),
        qtkt.fetchQtktEvaluations({ from, to }),
      ]);
      setTemplate(tpl);
      setEmployees(emps);
      setMonthEvals(evals.filter((e) => e.status !== 'CANCELLED'));
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Không tải được danh sách nhân viên / phiếu QTKT.'));
    } finally {
      setLoading(false);
    }
  }, [canScore, from, to]);

  useEffect(() => {
    void load();
  }, [load]);

  const statusByEmp = useMemo(() => {
    const map = new Map<number, { draft: number; submitted: number }>();
    for (const e of monthEvals) {
      const cur = map.get(e.employeeId) ?? { draft: 0, submitted: 0 };
      if (e.status === 'DRAFT') cur.draft += 1;
      if (e.status === 'SUBMITTED') cur.submitted += 1;
      map.set(e.employeeId, cur);
    }
    return map;
  }, [monthEvals]);

  const roster: RosterItem[] = useMemo(
    () =>
      employees.map((e) => {
        const st = statusByEmp.get(e.id);
        let evalStatus: EmpStatus = 'NONE';
        if (st) {
          if (st.draft > 0 && st.submitted > 0) evalStatus = 'MIXED';
          else if (st.submitted > 0) evalStatus = 'SUBMITTED';
          else if (st.draft > 0) evalStatus = 'DRAFT';
        }
        return {
          ...e,
          evalStatus,
          evalCount: (st?.draft ?? 0) + (st?.submitted ?? 0),
        };
      }),
    [employees, statusByEmp],
  );

  const rosterStats = useMemo(() => {
    let none = 0;
    let draft = 0;
    let submitted = 0;
    let mixed = 0;
    for (const r of roster) {
      if (r.evalStatus === 'NONE') none += 1;
      else if (r.evalStatus === 'DRAFT') draft += 1;
      else if (r.evalStatus === 'SUBMITTED') submitted += 1;
      else mixed += 1;
    }
    return { total: roster.length, none, draft, submitted, mixed };
  }, [roster]);

  const departmentOptions = useMemo(() => {
    const set = new Set<string>();
    for (const e of roster) {
      if (e.departmentName) set.add(e.departmentName);
    }
    return [...set].sort((a, b) => a.localeCompare(b, 'vi'));
  }, [roster]);

  const filteredRoster = useMemo(
    () =>
      applyRequestListFilters(roster, filters, {
        searchText: (e) =>
          [e.fullName, e.employeeCode, e.positionTitle, e.departmentName].filter(Boolean).join(' '),
        dateValue: () => null,
        statusValue: (e) => e.evalStatus,
        departmentValue: (e) => e.departmentName,
      }),
    [roster, filters],
  );

  const selectedEmp = useMemo(
    () => (employeeId === '' ? null : roster.find((e) => e.id === employeeId) ?? null),
    [employeeId, roster],
  );

  const empEvals = useMemo(() => {
    if (!selectedEmp) return [];
    return monthEvals
      .filter((e) => e.employeeId === selectedEmp.id)
      .sort((a, b) => {
        const proc = a.procedureName.localeCompare(b.procedureName, 'vi');
        if (proc !== 0) return proc;
        return (a.checkContextLabel ?? '').localeCompare(b.checkContextLabel ?? '', 'vi');
      });
  }, [selectedEmp, monthEvals]);

  const empAvgScore = useMemo(() => {
    const submitted = empEvals.filter((e) => e.status === 'SUBMITTED');
    if (submitted.length === 0) return null;
    return submitted.reduce((s, e) => s + Number(e.totalScore), 0) / submitted.length;
  }, [empEvals]);

  type CreateOption = {
    procedure: qtkt.QtktProcedure;
    hint: string;
  };

  const createOptions = useMemo((): CreateOption[] => {
    if (!template || !selectedEmp) return [];
    return template.procedures
      .filter((p) => qtkt.isProcedureAllowedForDepartment(p, selectedEmp.departmentName))
      .map((p) => ({
        procedure: p,
        hint: p.requiresPatientCode
          ? 'Nhập mã bệnh nhân · có thể tư vấn nhiều NB/ngày'
          : p.checkOptions
            ? `${p.checkOptions.hint || 'Chọn thời điểm trong phiếu'} · có thể lập nhiều phiếu/tháng`
            : 'Có thể lập nhiều phiếu trong tháng (mỗi ngày một phiếu)',
      }));
  }, [template, selectedEmp]);

  function openNew(procedureCode: string) {
    if (!selectedEmp) return;
    setDialogExisting(null);
    setDialogProcedure(procedureCode);
    setDialogCheckContext(undefined);
    setReadOnly(false);
    setDialogOpen(true);
  }

  function openExisting(ev: qtkt.QtktEvaluation, viewOnly: boolean) {
    setDialogExisting(ev);
    setDialogProcedure(ev.procedureCode);
    setReadOnly(viewOnly);
    setDialogOpen(true);
  }

  function toggleExpanded() {
    setExpanded((v) => !v);
  }

  if (!canScore) return null;

  const pendingDraft = rosterStats.draft + rosterStats.mixed;
  const doneSubmitted = rosterStats.submitted + rosterStats.mixed;

  return (
    <Box
      sx={{
        borderRadius: 3,
        bgcolor: '#fff',
        border: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
        boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
        mb: 2.5,
        overflow: 'hidden',
      }}
    >
      <Box
        sx={{
          px: { xs: 1.75, sm: 2.25 },
          py: 1.5,
          background: `linear-gradient(120deg, ${alpha(ACCENT, 0.08)} 0%, #fff 55%)`,
          borderBottom: expanded ? `1px solid ${alpha('#0f172a', 0.06)}` : 'none',
        }}
      >
        <Stack
          direction={{ xs: 'column', md: 'row' }}
          spacing={1.5}
          alignItems={{ md: 'center' }}
          justifyContent="space-between"
        >
          <Stack
            direction="row"
            spacing={1.25}
            alignItems="center"
            sx={{ minWidth: 0, cursor: 'pointer', flex: 1 }}
            onClick={toggleExpanded}
          >
            <Box
              sx={{
                width: 40,
                height: 40,
                borderRadius: 2,
                display: 'grid',
                placeItems: 'center',
                bgcolor: alpha(ACCENT, 0.12),
                color: ACCENT,
                flexShrink: 0,
              }}
            >
              <FactCheckOutlinedIcon fontSize="small" />
            </Box>
            <Box sx={{ minWidth: 0 }}>
              <Typography variant="subtitle1" fontWeight={800} letterSpacing="-0.01em">
                Lập phiếu đánh giá QTKT
              </Typography>
              <Typography variant="body2" color="text.secondary" noWrap>
                {expanded
                  ? 'Chấm theo checklist quy trình kỹ thuật — khối ĐD–KTV–HS–Thư ký'
                  : `${formatMonthLabel(period)} · ${rosterStats.total} NV · ${rosterStats.none} chưa có phiếu · ${doneSubmitted} đã gửi`}
              </Typography>
            </Box>
          </Stack>

          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
            {!expanded && (
              <>
                <Chip
                  size="small"
                  label={`${rosterStats.none} chưa có`}
                  sx={{ fontWeight: 650, bgcolor: alpha('#64748b', 0.08) }}
                />
                <Chip
                  size="small"
                  color="warning"
                  variant="outlined"
                  label={`${pendingDraft} nháp`}
                  sx={{ fontWeight: 650 }}
                />
                <Chip
                  size="small"
                  color="success"
                  variant="outlined"
                  label={`${doneSubmitted} đã gửi`}
                  sx={{ fontWeight: 650 }}
                />
              </>
            )}
            {expanded && (
              <Box onClick={(e) => e.stopPropagation()}>
                <MonthPickerField
                  size="small"
                  label="Tháng theo dõi"
                  value={period}
                  onChange={(v) => {
                    setPeriod(v);
                    setEmployeeId('');
                  }}
                  sx={{ width: { xs: '100%', sm: 200 } }}
                />
              </Box>
            )}
            <Button
              size="small"
              variant={expanded ? 'outlined' : 'contained'}
              onClick={toggleExpanded}
              endIcon={expanded ? <ExpandLessIcon /> : <ExpandMoreIcon />}
              sx={{
                borderRadius: 2,
                fontWeight: 750,
                textTransform: 'none',
                ...(expanded
                  ? { borderColor: alpha(ACCENT, 0.35), color: ACCENT }
                  : {
                      bgcolor: ACCENT,
                      boxShadow: `0 6px 14px ${alpha(ACCENT, 0.22)}`,
                      '&:hover': { bgcolor: ACCENT, filter: 'brightness(0.93)' },
                    }),
              }}
            >
              {expanded ? 'Thu gọn' : 'Mở lập phiếu'}
            </Button>
          </Stack>
        </Stack>
      </Box>

      <Collapse in={expanded} timeout="auto" unmountOnExit>
        <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mb: 1.75 }}>
            <Chip size="small" label={`${rosterStats.total} NV khối`} sx={{ fontWeight: 700 }} />
            <Chip
              size="small"
              color="default"
              variant="outlined"
              label={`${rosterStats.none} chưa có phiếu`}
              sx={{ fontWeight: 650 }}
            />
            <Chip
              size="small"
              color="warning"
              variant="outlined"
              label={`${pendingDraft} còn nháp`}
              sx={{ fontWeight: 650 }}
            />
            <Chip
              size="small"
              color="success"
              variant="outlined"
              label={`${doneSubmitted} đã gửi`}
              sx={{ fontWeight: 650 }}
            />
          </Stack>

          {template?.note && (
            <Alert severity="info" sx={{ mb: 2, borderRadius: 2 }}>
              {template.note}
            </Alert>
          )}

          {err && (
            <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }} onClose={() => setErr(null)}>
              {err}
            </Alert>
          )}

          <Box sx={{ mb: 1.5 }}>
            <RequestListFilters
              value={filters}
              onChange={setFilters}
              title="Tìm nhân viên để chấm"
              hideDateFilters
              resultCount={filteredRoster.length}
              resultCountLabel="NV"
              searchPlaceholder="Tìm tên, mã NV, chức danh…"
              statusOptions={STATUS_OPTIONS}
              departmentOptions={departmentOptions}
            />
          </Box>

          <Box
            sx={{
              mb: 2,
              borderRadius: 2.5,
              border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
              bgcolor: alpha(ACCENT, 0.02),
              overflow: 'hidden',
            }}
          >
            <Box
              sx={{
                maxHeight: 260,
                overflowY: 'auto',
                overflowX: 'hidden',
                // Giữ scrollbar nằm gọn trong khung, không đè góc bo
                scrollbarGutter: 'stable',
                scrollbarWidth: 'thin',
                scrollbarColor: `${alpha(ACCENT, 0.45)} ${alpha(ACCENT, 0.06)}`,
                '&::-webkit-scrollbar': {
                  width: 8,
                },
                '&::-webkit-scrollbar-track': {
                  marginBlock: 6,
                  background: alpha(ACCENT, 0.05),
                  borderRadius: 99,
                },
                '&::-webkit-scrollbar-thumb': {
                  backgroundColor: alpha(ACCENT, 0.4),
                  borderRadius: 99,
                  border: '2px solid transparent',
                  backgroundClip: 'padding-box',
                  '&:hover': {
                    backgroundColor: alpha(ACCENT, 0.55),
                    border: '2px solid transparent',
                    backgroundClip: 'padding-box',
                  },
                },
              }}
            >
            {loading ? (
              <Typography variant="body2" color="text.secondary" sx={{ p: 2 }}>
                Đang tải danh sách…
              </Typography>
            ) : filteredRoster.length === 0 ? (
              <Stack alignItems="center" spacing={1} sx={{ py: 3, px: 2 }}>
                <PersonSearchOutlinedIcon color="disabled" />
                <Typography variant="body2" color="text.secondary">
                  Không có nhân viên khớp bộ lọc.
                </Typography>
              </Stack>
            ) : (
              filteredRoster.map((e) => {
                const active = employeeId === e.id;
                return (
                  <Box
                    key={e.id}
                    onClick={() => setEmployeeId(e.id)}
                    sx={{
                      px: 1.75,
                      pr: 2.25,
                      py: 1.1,
                      cursor: 'pointer',
                      display: 'flex',
                      alignItems: 'center',
                      gap: 1.25,
                      borderBottom: `1px solid ${alpha(theme.palette.divider, 0.7)}`,
                      bgcolor: active ? alpha(ACCENT, 0.1) : 'transparent',
                      borderLeft: active ? `3px solid ${ACCENT}` : '3px solid transparent',
                      transition: 'background-color 0.15s',
                      '&:hover': { bgcolor: alpha(ACCENT, active ? 0.12 : 0.05) },
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
                      color={statusColor(e.evalStatus)}
                      variant={active ? 'filled' : 'outlined'}
                      label={
                        e.evalCount > 0
                          ? `${statusLabel(e.evalStatus)} · ${e.evalCount}`
                          : statusLabel(e.evalStatus)
                      }
                      sx={{ height: 22, fontWeight: 650, borderRadius: '6px', maxWidth: 180 }}
                    />
                  </Box>
                );
              })
            )}
            </Box>
          </Box>

          {employeeId === '' && (
            <Alert severity="info" sx={{ borderRadius: 2 }}>
              Chọn nhân viên từ danh sách phía trên để xem hoặc lập phiếu đánh giá quy trình kỹ thuật.
            </Alert>
          )}

          {selectedEmp && template && (
            <Box>
              <Stack
                direction={{ xs: 'column', sm: 'row' }}
                spacing={1.25}
                alignItems={{ sm: 'center' }}
                justifyContent="space-between"
                sx={{
                  mb: 2,
                  p: 1.75,
                  borderRadius: 2.5,
                  bgcolor: alpha(ACCENT, 0.06),
                  border: `1px solid ${alpha(ACCENT, 0.14)}`,
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
                <Stack direction="row" spacing={0.75} flexWrap="wrap" useFlexGap>
                <Chip
                  size="small"
                  color={statusColor(selectedEmp.evalStatus)}
                  label={statusLabel(selectedEmp.evalStatus)}
                  sx={{ fontWeight: 700 }}
                />
                {empAvgScore != null && (
                  <Chip
                    size="small"
                    variant="outlined"
                    label={`TB tháng: ${empAvgScore.toFixed(2)} đ`}
                    sx={{ fontWeight: 700, borderColor: alpha(ACCENT, 0.35), color: ACCENT }}
                  />
                )}
                </Stack>
              </Stack>

              {empEvals.length > 0 && (
                <Box sx={{ mb: createOptions.length > 0 ? 2 : 0 }}>
                  <Typography variant="subtitle2" fontWeight={800} sx={{ mb: 1 }}>
                    Phiếu trong tháng
                  </Typography>
                  <Stack spacing={1}>
                    {empEvals.map((ev) => {
                      const canEdit = ev.canEdit === true;
                      return (
                        <Box
                          key={ev.id}
                          sx={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: 1.25,
                            px: 1.5,
                            py: 1,
                            borderRadius: 2,
                            border: `1px solid ${alpha('#0f172a', 0.08)}`,
                            bgcolor: '#fafbfc',
                          }}
                        >
                          <ScienceOutlinedIcon sx={{ fontSize: 18, color: ACCENT }} />
                          <Box sx={{ flex: 1, minWidth: 0 }}>
                            <Typography variant="body2" fontWeight={750} noWrap>
                              {qtkt.qtktEvalDisplayLabel(ev)}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                              {ev.evalDate.split('-').reverse().join('/')} · {Number(ev.totalScore).toFixed(2)}/
                              {Number(ev.maxScore).toFixed(0)} điểm ·{' '}
                              {ev.status === 'SUBMITTED' ? 'Đã gửi' : ev.status === 'DRAFT' ? 'Nháp' : 'Đã hủy'}
                            </Typography>
                          </Box>
                          <Stack direction="row" spacing={0.35}>
                            <Tooltip title="Xem phiếu">
                              <IconButton
                                size="small"
                                onClick={() => openExisting(ev, true)}
                                sx={{
                                  color: ACCENT,
                                  border: `1px solid ${alpha(ACCENT, 0.22)}`,
                                  borderRadius: 1.5,
                                  bgcolor: '#fff',
                                  '&:hover': { bgcolor: alpha(ACCENT, 0.08) },
                                }}
                              >
                                <VisibilityOutlinedIcon sx={{ fontSize: 18 }} />
                              </IconButton>
                            </Tooltip>
                            {canEdit && (
                              <Tooltip title={ev.status === 'SUBMITTED' ? 'Chỉnh sửa phiếu đã gửi' : 'Chỉnh sửa nháp'}>
                                <IconButton
                                  size="small"
                                  onClick={() => openExisting(ev, false)}
                                  sx={{
                                    color: '#fff',
                                    bgcolor: ACCENT,
                                    borderRadius: 1.5,
                                    boxShadow: `0 4px 10px ${alpha(ACCENT, 0.25)}`,
                                    '&:hover': { bgcolor: ACCENT, filter: 'brightness(0.92)' },
                                  }}
                                >
                                  <EditOutlinedIcon sx={{ fontSize: 18 }} />
                                </IconButton>
                              </Tooltip>
                            )}
                          </Stack>
                        </Box>
                      );
                    })}
                  </Stack>
                </Box>
              )}

              {createOptions.length > 0 && (
                <>
                  <Typography variant="subtitle2" fontWeight={800} sx={{ mb: 1 }}>
                    Lập phiếu kiểm tra mới
                  </Typography>
                  <Box
                    sx={{
                      display: 'grid',
                      gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
                      gap: 1.15,
                    }}
                  >
                    {createOptions.map((opt) => (
                      <Box
                        key={opt.procedure.code}
                        onClick={() => openNew(opt.procedure.code)}
                        sx={{
                          p: 1.5,
                          borderRadius: 2.5,
                          cursor: 'pointer',
                          border: `1px solid ${alpha(ACCENT, 0.18)}`,
                          bgcolor: alpha(ACCENT, 0.04),
                          transition: 'transform 0.12s ease, box-shadow 0.12s ease',
                          '&:hover': {
                            transform: 'translateY(-1px)',
                            boxShadow: `0 8px 20px ${alpha(ACCENT, 0.12)}`,
                          },
                        }}
                      >
                        <Typography variant="subtitle2" fontWeight={800} sx={{ color: ACCENT }}>
                          {opt.procedure.name}
                        </Typography>
                        <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.35 }}>
                          {opt.procedure.durationMinutes} phút · tối đa {opt.procedure.maxTotal} điểm
                        </Typography>
                        <Typography variant="caption" fontWeight={650} display="block" sx={{ mt: 0.5, color: ACCENT }}>
                          {opt.hint}
                        </Typography>
                      </Box>
                    ))}
                  </Box>
                </>
              )}
            </Box>
          )}
        </Box>
      </Collapse>

      {dialogOpen && template && selectedEmp && (
        <QtktEvaluationDialog
          open
          template={template}
          employees={employees}
          existing={dialogExisting}
          readOnly={readOnly}
          presetEmployeeId={selectedEmp.id}
          presetProcedureCode={dialogProcedure}
          presetCheckContextCode={dialogCheckContext}
          presetEvalDate={
            period === currentYearMonth()
              ? new Date().toISOString().slice(0, 10)
              : `${period}-01`
          }
          onClose={() => setDialogOpen(false)}
          onSaved={() => {
            void load();
            onDataMutated?.();
          }}
        />
      )}
    </Box>
  );
}
