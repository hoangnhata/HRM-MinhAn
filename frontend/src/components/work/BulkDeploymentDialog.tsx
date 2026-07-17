import SwapHorizOutlinedIcon from '@mui/icons-material/SwapHorizOutlined';
import {
  Alert,
  Box,
  Button,
  Checkbox,
  CircularProgress,
  Grid,
  List,
  ListItem,
  ListItemIcon,
  ListItemText,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { DatePickerField, TimePickerField, dateTimeFieldSx } from '../ui/DateTimeFields';
import { FormSection, InfoBanner, WorkRequestDialogShell } from './WorkRequestFormUi';
import * as att from '../../services/attendanceService';
import * as employeeService from '../../services/employeeService';
import { scheduleForDate, type ShiftScheduleInfo } from '../../utils/shiftSchedule';

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved?: () => void;
  initialDepartmentId?: number | '';
  initialWorkDate?: string;
  periodYear?: number;
  periodMonth?: number;
};

type TimeMode = 'OUTSIDE' | 'INSIDE';
type InsideScope = 'MORNING' | 'AFTERNOON' | 'FULL_DAY';

type EmpDeployConfig = {
  timeMode: TimeMode;
  insideScope: InsideScope;
  startTime: string;
  endTime: string;
  morningStart: string;
  morningEnd: string;
  afternoonStart: string;
  afternoonEnd: string;
};

const ACCENT = '#0f766e';
const fieldSx = dateTimeFieldSx;

type RowResult = { employeeId: number; employeeName: string; ok: boolean; message: string };

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function endOfMonthIso(fromIso?: string): string {
  const base = fromIso ? new Date(`${fromIso}T12:00:00`) : new Date();
  const last = new Date(base.getFullYear(), base.getMonth() + 1, 0);
  return last.toISOString().slice(0, 10);
}

function monthStartIso(year: number, month: number): string {
  return `${year}-${String(month).padStart(2, '0')}-01`;
}

function deployMaxDate(periodYear?: number, periodMonth?: number): string {
  const today = todayIso();
  if (periodYear && periodMonth) {
    const monthEnd = endOfMonthIso(monthStartIso(periodYear, periodMonth));
    const [ty, tm] = today.split('-').map(Number);
    if (periodYear < ty || (periodYear === ty && periodMonth < tm)) return monthEnd;
    if (periodYear === ty && periodMonth === tm) return endOfMonthIso(today);
    return monthEnd;
  }
  return endOfMonthIso(today);
}

function toMinutes(t: string): number {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + (m || 0);
}

function overtimeHours(start: string, end: string): number {
  if (!start || !end) return 0;
  let mins = toMinutes(end) - toMinutes(start);
  if (mins === 0) return 0;
  if (mins < 0) mins += 24 * 60;
  return mins / 60;
}

function withinShift(start: string, end: string, shiftStart: string, shiftEnd: string): boolean {
  if (!start || !end) return false;
  const s = toMinutes(start);
  const e = toMinutes(end);
  return e > s && s >= toMinutes(shiftStart) && e <= toMinutes(shiftEnd);
}

function defaultConfig(schedule: ShiftScheduleInfo): EmpDeployConfig {
  return {
    timeMode: 'OUTSIDE',
    insideScope: 'MORNING',
    startTime: '18:00',
    endTime: '21:00',
    morningStart: schedule.morningStart.slice(0, 5),
    morningEnd: schedule.morningEnd.slice(0, 5),
    afternoonStart: schedule.afternoonStart.slice(0, 5),
    afternoonEnd: schedule.afternoonEnd.slice(0, 5),
  };
}

function fmtTime(t: string) {
  return t.slice(0, 5);
}

function validateConfig(cfg: EmpDeployConfig, schedule: ShiftScheduleInfo): string | null {
  if (cfg.timeMode === 'OUTSIDE') {
    if (overtimeHours(cfg.startTime, cfg.endTime) <= 0) {
      return 'Giờ ngoài ca không hợp lệ';
    }
    return null;
  }
  if (cfg.insideScope === 'MORNING' || cfg.insideScope === 'FULL_DAY') {
    if (!withinShift(cfg.morningStart, cfg.morningEnd, schedule.morningStart, schedule.morningEnd)) {
      return `Giờ sáng phải trong ${fmtTime(schedule.morningStart)}–${fmtTime(schedule.morningEnd)}`;
    }
  }
  if (cfg.insideScope === 'AFTERNOON' || cfg.insideScope === 'FULL_DAY') {
    if (
      !withinShift(
        cfg.afternoonStart,
        cfg.afternoonEnd,
        schedule.afternoonStart,
        schedule.afternoonEnd,
      )
    ) {
      return `Giờ chiều phải trong ${fmtTime(schedule.afternoonStart)}–${fmtTime(schedule.afternoonEnd)}`;
    }
  }
  return null;
}

async function submitDeploy(
  empId: number,
  workDate: string,
  reason: string,
  cfg: EmpDeployConfig,
) {
  if (cfg.timeMode === 'OUTSIDE') {
    await att.submitWorkRequest({
      requestType: 'DEPLOYMENT',
      employeeId: empId,
      workDate,
      shiftScope: 'FULL_DAY',
      reason,
      requestedStart: cfg.startTime.slice(0, 5),
      requestedEnd: cfg.endTime.slice(0, 5),
    });
    return;
  }
  if (cfg.insideScope === 'MORNING') {
    await att.submitWorkRequest({
      requestType: 'DEPLOYMENT',
      employeeId: empId,
      workDate,
      shiftScope: 'MORNING',
      reason,
      requestedStart: cfg.morningStart.slice(0, 5),
      requestedEnd: cfg.morningEnd.slice(0, 5),
    });
    return;
  }
  if (cfg.insideScope === 'AFTERNOON') {
    await att.submitWorkRequest({
      requestType: 'DEPLOYMENT',
      employeeId: empId,
      workDate,
      shiftScope: 'AFTERNOON',
      reason,
      requestedStart: cfg.afternoonStart.slice(0, 5),
      requestedEnd: cfg.afternoonEnd.slice(0, 5),
    });
    return;
  }
  await att.submitWorkRequest({
    requestType: 'DEPLOYMENT',
    employeeId: empId,
    workDate,
    shiftScope: 'FULL_DAY',
    reason,
    requestedStart: cfg.morningStart.slice(0, 5),
    requestedEnd: cfg.morningEnd.slice(0, 5),
    requestedAfternoonStart: cfg.afternoonStart.slice(0, 5),
    requestedAfternoonEnd: cfg.afternoonEnd.slice(0, 5),
  });
}

function configSummary(cfg: EmpDeployConfig): string {
  if (cfg.timeMode === 'OUTSIDE') {
    return `Ngoài ca ${fmtTime(cfg.startTime)}–${fmtTime(cfg.endTime)}`;
  }
  if (cfg.insideScope === 'MORNING') {
    return `Trong ca sáng ${fmtTime(cfg.morningStart)}–${fmtTime(cfg.morningEnd)}`;
  }
  if (cfg.insideScope === 'AFTERNOON') {
    return `Trong ca chiều ${fmtTime(cfg.afternoonStart)}–${fmtTime(cfg.afternoonEnd)}`;
  }
  return `Trong ca cả ngày ${fmtTime(cfg.morningStart)}–${fmtTime(cfg.morningEnd)} + ${fmtTime(cfg.afternoonStart)}–${fmtTime(cfg.afternoonEnd)}`;
}

export function BulkDeploymentDialog({
  open,
  onClose,
  onSaved,
  initialDepartmentId = '',
  initialWorkDate,
  periodYear,
  periodMonth,
}: Props) {
  const theme = useTheme();
  const minDate =
    periodYear && periodMonth ? monthStartIso(periodYear, periodMonth) : undefined;
  const maxDate = deployMaxDate(periodYear, periodMonth);

  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [departmentId, setDepartmentId] = useState<number | ''>('');
  const [employees, setEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [configByEmp, setConfigByEmp] = useState<Record<number, EmpDeployConfig>>({});
  const [employeesLoading, setEmployeesLoading] = useState(false);

  const [workDate, setWorkDate] = useState(initialWorkDate || todayIso());
  const [reason, setReason] = useState('');

  const [quickMode, setQuickMode] = useState<TimeMode>('OUTSIDE');
  const [quickScope, setQuickScope] = useState<InsideScope>('MORNING');
  const [quickStart, setQuickStart] = useState('18:00');
  const [quickEnd, setQuickEnd] = useState('21:00');
  const [quickMorningStart, setQuickMorningStart] = useState('07:00');
  const [quickMorningEnd, setQuickMorningEnd] = useState('11:30');
  const [quickAfternoonStart, setQuickAfternoonStart] = useState('13:30');
  const [quickAfternoonEnd, setQuickAfternoonEnd] = useState('17:00');

  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [results, setResults] = useState<RowResult[] | null>(null);

  const schedule = useMemo(() => scheduleForDate(workDate), [workDate]);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setResults(null);
    setReason('');
    let d = initialWorkDate || todayIso();
    if (minDate && d < minDate) d = minDate;
    if (d > maxDate) d = maxDate;
    setWorkDate(d);
    setDepartmentId(initialDepartmentId === '' ? '' : Number(initialDepartmentId));
    setSelectedIds(new Set());
    setConfigByEmp({});
    const sch = scheduleForDate(d);
    setQuickMode('OUTSIDE');
    setQuickScope('MORNING');
    setQuickStart('18:00');
    setQuickEnd('21:00');
    setQuickMorningStart(sch.morningStart.slice(0, 5));
    setQuickMorningEnd(sch.morningEnd.slice(0, 5));
    setQuickAfternoonStart(sch.afternoonStart.slice(0, 5));
    setQuickAfternoonEnd(sch.afternoonEnd.slice(0, 5));
    employeeService.fetchDepartments().then(setDepartments).catch(() => setDepartments([]));
  }, [open, initialDepartmentId, initialWorkDate, minDate, maxDate]);

  useEffect(() => {
    if (!open || departmentId === '') {
      setEmployees([]);
      setSelectedIds(new Set());
      setConfigByEmp({});
      return;
    }
    setEmployeesLoading(true);
    employeeService
      .fetchEmployees({ page: 0, size: 500, departmentId: Number(departmentId) })
      .then((page) => {
        const list = (page.content ?? []).filter((e) => e.status !== 'TERMINATED');
        setEmployees(list);
        setSelectedIds(new Set());
        setConfigByEmp({});
      })
      .catch(() => {
        setEmployees([]);
        setSelectedIds(new Set());
        setConfigByEmp({});
      })
      .finally(() => setEmployeesLoading(false));
  }, [open, departmentId]);

  useEffect(() => {
    const sch = schedule;
    setQuickMorningStart(sch.morningStart.slice(0, 5));
    setQuickMorningEnd(sch.morningEnd.slice(0, 5));
    setQuickAfternoonStart(sch.afternoonStart.slice(0, 5));
    setQuickAfternoonEnd(sch.afternoonEnd.slice(0, 5));
    setConfigByEmp((prev) => {
      const next: Record<number, EmpDeployConfig> = {};
      for (const [id, cfg] of Object.entries(prev)) {
        next[Number(id)] = {
          ...cfg,
          morningStart: sch.morningStart.slice(0, 5),
          morningEnd: sch.morningEnd.slice(0, 5),
          afternoonStart: sch.afternoonStart.slice(0, 5),
          afternoonEnd: sch.afternoonEnd.slice(0, 5),
        };
      }
      return next;
    });
  }, [schedule]);

  function ensureConfig(id: number): EmpDeployConfig {
    return configByEmp[id] ?? defaultConfig(schedule);
  }

  function patchConfig(id: number, patch: Partial<EmpDeployConfig>) {
    setConfigByEmp((prev) => ({
      ...prev,
      [id]: { ...ensureConfig(id), ...patch },
    }));
  }

  function toggleId(id: number) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
        setConfigByEmp((cfgs) => ({
          ...cfgs,
          [id]: cfgs[id] ?? defaultConfig(schedule),
        }));
      }
      return next;
    });
  }

  function applyQuickToSelected() {
    const base: EmpDeployConfig = {
      timeMode: quickMode,
      insideScope: quickScope,
      startTime: quickStart,
      endTime: quickEnd,
      morningStart: quickMorningStart,
      morningEnd: quickMorningEnd,
      afternoonStart: quickAfternoonStart,
      afternoonEnd: quickAfternoonEnd,
    };
    setConfigByEmp((prev) => {
      const next = { ...prev };
      selectedIds.forEach((id) => {
        next[id] = { ...base };
      });
      return next;
    });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setResults(null);
    if (departmentId === '') {
      setErr('Chọn khoa/phòng.');
      return;
    }
    if (selectedIds.size === 0) {
      setErr('Chọn ít nhất một nhân viên.');
      return;
    }
    if (!reason.trim()) {
      setErr('Nhập nội dung điều động.');
      return;
    }
    if (workDate > maxDate) {
      setErr(`Chỉ điều động đến ${maxDate}.`);
      return;
    }
    if (minDate && workDate < minDate) {
      setErr(`Chọn ngày trong tháng đang xem (từ ${minDate}).`);
      return;
    }

    const targets = employees.filter((emp) => selectedIds.has(emp.id));
    for (const emp of targets) {
      const cfg = ensureConfig(emp.id);
      const v = validateConfig(cfg, schedule);
      if (v) {
        setErr(`${emp.fullName}: ${v}`);
        return;
      }
    }

    setLoading(true);
    const rows: RowResult[] = [];
    let okCount = 0;
    for (const emp of targets) {
      const cfg = ensureConfig(emp.id);
      try {
        await submitDeploy(emp.id, workDate, reason.trim(), cfg);
        rows.push({
          employeeId: emp.id,
          employeeName: emp.fullName,
          ok: true,
          message: configSummary(cfg),
        });
        okCount++;
      } catch (ex: unknown) {
        const msg =
          ex && typeof ex === 'object' && 'response' in ex
            ? String(
                (ex as { response?: { data?: { message?: string } } }).response?.data?.message ?? '',
              )
            : '';
        rows.push({
          employeeId: emp.id,
          employeeName: emp.fullName,
          ok: false,
          message: msg || 'Gửi thất bại',
        });
      }
    }
    setResults(rows);
    if (okCount > 0) onSaved?.();
    setLoading(false);
  }

  const successCount = results?.filter((r) => r.ok).length ?? 0;
  const failureCount = results?.filter((r) => !r.ok).length ?? 0;

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={ACCENT}
      icon={<SwapHorizOutlinedIcon />}
      overline="Bổ sung hàng loạt"
      title="Điều động hàng loạt"
      description="Chọn khoa — từng NV chọn riêng ngoài ca / trong ca và giờ. Nội dung điều động dùng chung."
      formId="bulk-deployment-form"
      submitLabel={loading ? 'Đang gửi…' : `Gửi điều động cho ${selectedIds.size} nhân viên`}
      error={err}
      onSubmit={handleSubmit}
      maxWidth="md"
    >
      <InfoBanner>
        Tick NV rồi chỉnh hình thức + giờ từng dòng. «Gán nhanh» áp dụng mẫu cho tất cả đã tick, rồi sửa lại từng
        người nếu cần. Trong ca có thể chỉ một phần giờ (vd sáng 07:00–09:00).
      </InfoBanner>

      <FormSection title="Ngày & khoa/phòng">
        <Grid container spacing={1.75}>
          <Grid item xs={12} sm={6}>
            <DatePickerField label="Ngày điều động" required value={workDate} onChange={setWorkDate} sx={fieldSx} />
          </Grid>
          <Grid item xs={12} sm={6}>
            <TextField
              select
              required
              fullWidth
              size="small"
              label="Khoa / phòng"
              value={departmentId}
              onChange={(e) => setDepartmentId(e.target.value === '' ? '' : Number(e.target.value))}
              sx={fieldSx}
            >
              <MenuItem value="">— Chọn —</MenuItem>
              {departments.map((d) => (
                <MenuItem key={d.id} value={d.id}>
                  {d.name}
                </MenuItem>
              ))}
            </TextField>
          </Grid>
        </Grid>
      </FormSection>

      <FormSection
        title="Nhân viên & hình thức từng người"
        subtitle={
          departmentId === ''
            ? 'Chọn khoa/phòng để tải danh sách.'
            : `${selectedIds.size}/${employees.length} đã chọn`
        }
      >
        {employeesLoading ? (
          <Box sx={{ py: 3, textAlign: 'center' }}>
            <CircularProgress size={28} />
          </Box>
        ) : departmentId === '' ? (
          <Typography variant="body2" color="text.secondary">
            Chưa chọn khoa/phòng.
          </Typography>
        ) : employees.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            Không có nhân viên trong khoa này.
          </Typography>
        ) : (
          <>
            <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mb: 1.5 }}>
              <Button
                size="small"
                onClick={() => {
                  const all = new Set(employees.map((e) => e.id));
                  setSelectedIds(all);
                  setConfigByEmp((prev) => {
                    const next = { ...prev };
                    employees.forEach((e) => {
                      if (!next[e.id]) next[e.id] = defaultConfig(schedule);
                    });
                    return next;
                  });
                }}
                sx={{ borderRadius: 2 }}
              >
                Chọn tất cả
              </Button>
              <Button
                size="small"
                onClick={() => {
                  setSelectedIds(new Set());
                }}
                sx={{ borderRadius: 2 }}
              >
                Bỏ chọn
              </Button>
            </Stack>

            <Box
              sx={{
                p: 1.5,
                mb: 1.5,
                borderRadius: 2,
                border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                bgcolor: alpha(ACCENT, 0.04),
              }}
            >
              <Typography variant="caption" fontWeight={700} display="block" sx={{ mb: 1 }}>
                Gán nhanh cho đã tick
              </Typography>
              <Grid container spacing={1.25} alignItems="center">
                <Grid item xs={12} sm={4}>
                  <TextField
                    select
                    fullWidth
                    size="small"
                    label="Hình thức"
                    value={quickMode}
                    onChange={(e) => setQuickMode(e.target.value as TimeMode)}
                    sx={fieldSx}
                  >
                    <MenuItem value="OUTSIDE">Ngoài ca</MenuItem>
                    <MenuItem value="INSIDE">Trong ca</MenuItem>
                  </TextField>
                </Grid>
                {quickMode === 'INSIDE' ? (
                  <>
                    <Grid item xs={12} sm={4}>
                      <TextField
                        select
                        fullWidth
                        size="small"
                        label="Buổi"
                        value={quickScope}
                        onChange={(e) => setQuickScope(e.target.value as InsideScope)}
                        sx={fieldSx}
                      >
                        <MenuItem value="MORNING">Ca sáng</MenuItem>
                        <MenuItem value="AFTERNOON">Ca chiều</MenuItem>
                        <MenuItem value="FULL_DAY">Cả ngày</MenuItem>
                      </TextField>
                    </Grid>
                    {(quickScope === 'MORNING' || quickScope === 'FULL_DAY') && (
                      <>
                        <Grid item xs={6} sm={2}>
                          <TimePickerField
                            label="Sáng từ"
                            value={quickMorningStart}
                            onChange={setQuickMorningStart}
                            sx={fieldSx}
                          />
                        </Grid>
                        <Grid item xs={6} sm={2}>
                          <TimePickerField
                            label="Sáng đến"
                            value={quickMorningEnd}
                            onChange={setQuickMorningEnd}
                            sx={fieldSx}
                          />
                        </Grid>
                      </>
                    )}
                    {(quickScope === 'AFTERNOON' || quickScope === 'FULL_DAY') && (
                      <>
                        <Grid item xs={6} sm={2}>
                          <TimePickerField
                            label="Chiều từ"
                            value={quickAfternoonStart}
                            onChange={setQuickAfternoonStart}
                            sx={fieldSx}
                          />
                        </Grid>
                        <Grid item xs={6} sm={2}>
                          <TimePickerField
                            label="Chiều đến"
                            value={quickAfternoonEnd}
                            onChange={setQuickAfternoonEnd}
                            sx={fieldSx}
                          />
                        </Grid>
                      </>
                    )}
                  </>
                ) : (
                  <>
                    <Grid item xs={6} sm={3}>
                      <TimePickerField label="Từ giờ" value={quickStart} onChange={setQuickStart} sx={fieldSx} />
                    </Grid>
                    <Grid item xs={6} sm={3}>
                      <TimePickerField label="Đến giờ" value={quickEnd} onChange={setQuickEnd} sx={fieldSx} />
                    </Grid>
                  </>
                )}
                <Grid item xs={12} sm="auto">
                  <Button
                    size="small"
                    variant="outlined"
                    disabled={selectedIds.size === 0}
                    onClick={applyQuickToSelected}
                    sx={{ borderRadius: 2 }}
                  >
                    Áp dụng cho đã tick
                  </Button>
                </Grid>
              </Grid>
            </Box>

            <List
              dense
              sx={{
                maxHeight: 420,
                overflow: 'auto',
                border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                borderRadius: 2,
              }}
            >
              {employees.map((emp) => {
                const checked = selectedIds.has(emp.id);
                const cfg = ensureConfig(emp.id);
                return (
                  <ListItem
                    key={emp.id}
                    alignItems="flex-start"
                    sx={{
                      py: 1.25,
                      flexDirection: 'column',
                      alignItems: 'stretch',
                      borderBottom: `1px solid ${alpha(theme.palette.divider, 0.6)}`,
                      bgcolor: checked ? alpha(ACCENT, 0.04) : 'transparent',
                      gap: 1,
                    }}
                  >
                    <Stack direction="row" alignItems="flex-start" spacing={0.5}>
                      <ListItemIcon sx={{ minWidth: 36, mt: 0.25 }}>
                        <Checkbox
                          edge="start"
                          checked={checked}
                          onChange={() => toggleId(emp.id)}
                          tabIndex={-1}
                          disableRipple
                        />
                      </ListItemIcon>
                      <ListItemText
                        primary={emp.fullName}
                        secondary={
                          checked
                            ? configSummary(cfg)
                            : emp.employeeCode || emp.positionTitle || undefined
                        }
                        primaryTypographyProps={{ fontWeight: checked ? 700 : 500, fontSize: '0.875rem' }}
                      />
                    </Stack>
                    {checked && (
                      <Box sx={{ pl: { xs: 0, sm: 4.5 }, width: '100%' }}>
                        <Grid container spacing={1}>
                          <Grid item xs={12} sm={4}>
                            <TextField
                              select
                              fullWidth
                              size="small"
                              label="Hình thức"
                              value={cfg.timeMode}
                              onChange={(e) =>
                                patchConfig(emp.id, { timeMode: e.target.value as TimeMode })
                              }
                              sx={fieldSx}
                            >
                              <MenuItem value="OUTSIDE">Ngoài ca</MenuItem>
                              <MenuItem value="INSIDE">Trong ca</MenuItem>
                            </TextField>
                          </Grid>
                          {cfg.timeMode === 'OUTSIDE' ? (
                            <>
                              <Grid item xs={6} sm={4}>
                                <TimePickerField
                                  label="Từ giờ"
                                  value={cfg.startTime}
                                  onChange={(v) => patchConfig(emp.id, { startTime: v })}
                                  sx={fieldSx}
                                />
                              </Grid>
                              <Grid item xs={6} sm={4}>
                                <TimePickerField
                                  label="Đến giờ"
                                  value={cfg.endTime}
                                  onChange={(v) => patchConfig(emp.id, { endTime: v })}
                                  sx={fieldSx}
                                />
                              </Grid>
                            </>
                          ) : (
                            <>
                              <Grid item xs={12} sm={4}>
                                <TextField
                                  select
                                  fullWidth
                                  size="small"
                                  label="Buổi"
                                  value={cfg.insideScope}
                                  onChange={(e) => {
                                    const scope = e.target.value as InsideScope;
                                    patchConfig(emp.id, {
                                      insideScope: scope,
                                      morningStart: schedule.morningStart.slice(0, 5),
                                      morningEnd: schedule.morningEnd.slice(0, 5),
                                      afternoonStart: schedule.afternoonStart.slice(0, 5),
                                      afternoonEnd: schedule.afternoonEnd.slice(0, 5),
                                    });
                                  }}
                                  sx={fieldSx}
                                >
                                  <MenuItem value="MORNING">Ca sáng</MenuItem>
                                  <MenuItem value="AFTERNOON">Ca chiều</MenuItem>
                                  <MenuItem value="FULL_DAY">Cả ngày</MenuItem>
                                </TextField>
                              </Grid>
                              {(cfg.insideScope === 'MORNING' || cfg.insideScope === 'FULL_DAY') && (
                                <>
                                  <Grid item xs={6} sm={2}>
                                    <TimePickerField
                                      label="Sáng từ"
                                      value={cfg.morningStart}
                                      onChange={(v) => patchConfig(emp.id, { morningStart: v })}
                                      sx={fieldSx}
                                    />
                                  </Grid>
                                  <Grid item xs={6} sm={2}>
                                    <TimePickerField
                                      label="Sáng đến"
                                      value={cfg.morningEnd}
                                      onChange={(v) => patchConfig(emp.id, { morningEnd: v })}
                                      sx={fieldSx}
                                    />
                                  </Grid>
                                </>
                              )}
                              {(cfg.insideScope === 'AFTERNOON' || cfg.insideScope === 'FULL_DAY') && (
                                <>
                                  <Grid item xs={6} sm={2}>
                                    <TimePickerField
                                      label="Chiều từ"
                                      value={cfg.afternoonStart}
                                      onChange={(v) => patchConfig(emp.id, { afternoonStart: v })}
                                      sx={fieldSx}
                                    />
                                  </Grid>
                                  <Grid item xs={6} sm={2}>
                                    <TimePickerField
                                      label="Chiều đến"
                                      value={cfg.afternoonEnd}
                                      onChange={(v) => patchConfig(emp.id, { afternoonEnd: v })}
                                      sx={fieldSx}
                                    />
                                  </Grid>
                                </>
                              )}
                            </>
                          )}
                        </Grid>
                      </Box>
                    )}
                  </ListItem>
                );
              })}
            </List>
          </>
        )}
      </FormSection>

      <FormSection title="Nội dung điều động" subtitle="Bắt buộc — dùng chung cho mọi NV đã chọn.">
        <TextField
          required
          fullWidth
          size="small"
          multiline
          minRows={3}
          placeholder="Ví dụ: Điều động hỗ trợ Khoa Cấp cứu…"
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          sx={fieldSx}
        />
      </FormSection>

      {results && (
        <Alert
          severity={failureCount === 0 ? 'success' : successCount === 0 ? 'error' : 'warning'}
          variant="outlined"
          sx={{ borderRadius: 2 }}
        >
          <Typography variant="body2" fontWeight={700}>
            Thành công {successCount} · Lỗi {failureCount}
          </Typography>
          {failureCount > 0 && (
            <Box component="ul" sx={{ m: 0, pl: 2, mt: 1 }}>
              {results
                .filter((r) => !r.ok)
                .slice(0, 8)
                .map((r) => (
                  <li key={r.employeeId}>
                    <Typography variant="caption">
                      {r.employeeName}: {r.message}
                    </Typography>
                  </li>
                ))}
            </Box>
          )}
        </Alert>
      )}
    </WorkRequestDialogShell>
  );
}
