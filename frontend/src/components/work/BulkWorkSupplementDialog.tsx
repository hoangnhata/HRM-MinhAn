import GroupAddOutlinedIcon from '@mui/icons-material/GroupAddOutlined';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import WbSunnyOutlinedIcon from '@mui/icons-material/WbSunnyOutlined';
import WbTwilightIcon from '@mui/icons-material/WbTwilight';
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
import { FormSection, InfoBanner, SelectableChip, WorkRequestDialogShell } from './WorkRequestFormUi';
import * as att from '../../services/attendanceService';
import * as employeeService from '../../services/employeeService';
import { scheduleForDate } from '../../utils/shiftSchedule';

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved?: () => void;
  initialDepartmentId?: number | '';
  initialWorkDate?: string;
};

type Mode = 'DUTY' | 'QUANG_TRUNG';

const ACCENT_DUTY = '#5b4bb4';
const fieldSx = dateTimeFieldSx;

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

export function BulkWorkSupplementDialog({
  open,
  onClose,
  onSaved,
  initialDepartmentId = '',
  initialWorkDate,
}: Props) {
  const theme = useTheme();
  const [mode, setMode] = useState<Mode>('DUTY');
  const accent = mode === 'DUTY' ? ACCENT_DUTY : theme.palette.success.main;

  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [departmentId, setDepartmentId] = useState<number | ''>('');
  const [employees, setEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  /** Công trực: loại ca riêng từng NV (chỉ dùng khi đã tick) */
  const [dutyShiftByEmp, setDutyShiftByEmp] = useState<Record<number, string>>({});
  const [employeesLoading, setEmployeesLoading] = useState(false);

  const [workDate, setWorkDate] = useState(initialWorkDate || todayIso());

  const [types, setTypes] = useState<att.DutyShiftTypeOption[]>([]);
  const [quickDutyType, setQuickDutyType] = useState('');
  const [dutyNote, setDutyNote] = useState('');

  const [updateKind, setUpdateKind] = useState('MORNING_SUPPLEMENT');
  const [reason, setReason] = useState('');
  const [morningStart, setMorningStart] = useState('07:00');
  const [morningEnd, setMorningEnd] = useState('12:00');
  const [afternoonStart, setAfternoonStart] = useState('14:00');
  const [afternoonEnd, setAfternoonEnd] = useState('17:00');

  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [result, setResult] = useState<att.BulkSupplementResult | null>(null);

  const isFullDay = updateKind === 'FULL_DAY_SUPPLEMENT';

  const dutyItems = useMemo(() => {
    return Array.from(selectedIds)
      .map((employeeId) => ({
        employeeId,
        shiftTypeCode: (dutyShiftByEmp[employeeId] || '').trim(),
      }))
      .filter((x) => x.shiftTypeCode);
  }, [selectedIds, dutyShiftByEmp]);

  const submitCount = mode === 'DUTY' ? dutyItems.length : selectedIds.size;

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setResult(null);
    setMode('DUTY');
    setQuickDutyType('');
    setDutyNote('');
    setDutyShiftByEmp({});
    setUpdateKind('MORNING_SUPPLEMENT');
    setReason('');
    setWorkDate(initialWorkDate || todayIso());
    setDepartmentId(initialDepartmentId === '' ? '' : Number(initialDepartmentId));
    setSelectedIds(new Set());
    const sch = scheduleForDate(initialWorkDate || todayIso());
    setMorningStart(sch.morningStart);
    setMorningEnd(sch.morningEnd);
    setAfternoonStart(sch.afternoonStart);
    setAfternoonEnd(sch.afternoonEnd);

    employeeService.fetchDepartments().then(setDepartments).catch(() => setDepartments([]));
    att.fetchDutyShiftTypes().then(setTypes).catch(() => setTypes([]));
  }, [open, initialDepartmentId, initialWorkDate]);

  useEffect(() => {
    if (!open || departmentId === '') {
      setEmployees([]);
      setSelectedIds(new Set());
      setDutyShiftByEmp({});
      return;
    }
    setEmployeesLoading(true);
    employeeService
      .fetchEmployees({
        page: 0,
        size: 500,
        departmentId: Number(departmentId),
      })
      .then((page) => {
        const list = (page.content ?? []).filter((e) => e.status !== 'TERMINATED');
        setEmployees(list);
        setSelectedIds(new Set());
        setDutyShiftByEmp({});
      })
      .catch(() => {
        setEmployees([]);
        setSelectedIds(new Set());
        setDutyShiftByEmp({});
      })
      .finally(() => setEmployeesLoading(false));
  }, [open, departmentId]);

  useEffect(() => {
    if (!open) return;
    const sch = scheduleForDate(workDate);
    setMorningStart(sch.morningStart);
    setMorningEnd(sch.morningEnd);
    setAfternoonStart(sch.afternoonStart);
    setAfternoonEnd(sch.afternoonEnd);
  }, [workDate, updateKind, open]);

  function toggleId(id: number) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
        setDutyShiftByEmp((m) => {
          const copy = { ...m };
          delete copy[id];
          return copy;
        });
      } else {
        next.add(id);
      }
      return next;
    });
  }

  function selectAll() {
    setSelectedIds(new Set(employees.map((e) => e.id)));
  }

  function clearAll() {
    setSelectedIds(new Set());
    setDutyShiftByEmp({});
  }

  function setEmpDutyType(id: number, code: string) {
    setDutyShiftByEmp((m) => ({ ...m, [id]: code }));
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (code) next.add(id);
      return next;
    });
  }

  function applyQuickDutyType() {
    if (!quickDutyType) return;
    setDutyShiftByEmp((m) => {
      const next = { ...m };
      selectedIds.forEach((id) => {
        next[id] = quickDutyType;
      });
      return next;
    });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setResult(null);
    if (departmentId === '') {
      setErr('Chọn khoa/phòng.');
      return;
    }
    if (!workDate) {
      setErr('Chọn ngày.');
      return;
    }

    if (mode === 'DUTY') {
      if (selectedIds.size === 0) {
        setErr('Tick ít nhất một nhân viên.');
        return;
      }
      const missing = Array.from(selectedIds).filter((id) => !(dutyShiftByEmp[id] || '').trim());
      if (missing.length > 0) {
        setErr(`Còn ${missing.length} người đã tick nhưng chưa chọn loại ca trực.`);
        return;
      }
      if (dutyItems.length === 0) {
        setErr('Chọn loại ca trực cho từng nhân viên.');
        return;
      }
    } else if (selectedIds.size === 0) {
      setErr('Chọn ít nhất một nhân viên.');
      return;
    }

    setLoading(true);
    try {
      let res: att.BulkSupplementResult;
      if (mode === 'DUTY') {
        res = await att.bulkUpsertDutyShifts({
          workDate,
          note: dutyNote.trim() || undefined,
          items: dutyItems,
        });
      } else {
        const ids = Array.from(selectedIds);
        const payload: Parameters<typeof att.bulkApplyQuangTrungSupplement>[0] = {
          employeeIds: ids,
          workDate,
          updateKind: updateKind as att.QuangTrungSupplementBody['updateKind'],
          reason: reason.trim(),
          requestedStart: updateKind === 'AFTERNOON_SUPPLEMENT' ? afternoonStart : morningStart,
          requestedEnd: updateKind === 'AFTERNOON_SUPPLEMENT' ? afternoonEnd : morningEnd,
        };
        if (isFullDay) {
          payload.requestedStart = morningStart;
          payload.requestedEnd = morningEnd;
          payload.requestedAfternoonStart = afternoonStart;
          payload.requestedAfternoonEnd = afternoonEnd;
        }
        res = await att.bulkApplyQuangTrungSupplement(payload);
      }
      setResult(res);
      if (res.successCount > 0) onSaved?.();
    } catch {
      setErr('Lưu hàng loạt thất bại. Kiểm tra quyền và thử lại.');
    } finally {
      setLoading(false);
    }
  }

  const sch = scheduleForDate(workDate);
  const scheduleHint = isFullDay
    ? `${sch.seasonLabel}: ${sch.morningStart}–${sch.morningEnd} · ${sch.afternoonStart}–${sch.afternoonEnd}`
    : updateKind === 'AFTERNOON_SUPPLEMENT'
      ? `Ca chiều: ${sch.afternoonStart} – ${sch.afternoonEnd}`
      : `Ca sáng: ${sch.morningStart} – ${sch.morningEnd}`;

  return (
    <WorkRequestDialogShell
      open={open}
      onClose={onClose}
      loading={loading}
      accent={accent}
      icon={mode === 'DUTY' ? <NightsStayIcon /> : <GroupAddOutlinedIcon />}
      overline="Bổ sung hàng loạt"
      title={mode === 'DUTY' ? 'Công trực theo khoa' : 'Công Quang Trung theo khoa'}
      description={
        mode === 'DUTY'
          ? 'Tick nhân viên và chọn loại ca trực riêng từng người (có thể gán nhanh cùng loại rồi chỉnh lại).'
          : 'Chọn khoa/phòng và nhân viên — áp dụng cùng ngày / cùng giờ QT một lần lưu.'
      }
      formId="bulk-work-supplement-form"
      submitLabel={loading ? 'Đang lưu…' : `Lưu cho ${submitCount} nhân viên`}
      error={err}
      onSubmit={handleSubmit}
      maxWidth="md"
    >
      <FormSection title="Loại bổ sung">
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
          <SelectableChip
            selected={mode === 'DUTY'}
            label="Công trực"
            onClick={() => {
              setMode('DUTY');
              setResult(null);
              setErr(null);
            }}
          />
          <SelectableChip
            selected={mode === 'QUANG_TRUNG'}
            label="Công Quang Trung"
            onClick={() => {
              setMode('QUANG_TRUNG');
              setResult(null);
              setErr(null);
            }}
          />
        </Stack>
      </FormSection>

      <FormSection title="Ngày & khoa/phòng">
        <Grid container spacing={1.75}>
          <Grid item xs={12} sm={6}>
            <DatePickerField label="Ngày áp dụng" required value={workDate} onChange={setWorkDate} sx={fieldSx} />
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
        title={mode === 'DUTY' ? 'Nhân viên & loại ca trực' : 'Nhân viên'}
        subtitle={
          departmentId === ''
            ? 'Chọn khoa/phòng để tải danh sách.'
            : mode === 'DUTY'
              ? `${dutyItems.length} người đã chọn đủ loại ca · ${selectedIds.size} đang tick`
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
            Không có nhân viên đang làm việc trong khoa này.
          </Typography>
        ) : (
          <>
            <Stack direction="row" spacing={1} sx={{ mb: 1 }} flexWrap="wrap" useFlexGap alignItems="center">
              <Button size="small" onClick={selectAll} sx={{ borderRadius: 2 }}>
                Chọn tất cả
              </Button>
              <Button size="small" onClick={clearAll} sx={{ borderRadius: 2 }}>
                Bỏ chọn
              </Button>
              {mode === 'DUTY' && types.length > 0 && (
                <>
                  <TextField
                    select
                    size="small"
                    label="Gán nhanh loại ca"
                    value={quickDutyType}
                    onChange={(e) => setQuickDutyType(e.target.value)}
                    sx={{ ...fieldSx, minWidth: 200 }}
                  >
                    <MenuItem value="">— Chọn loại —</MenuItem>
                    {types.map((t) => (
                      <MenuItem key={t.code} value={t.code}>
                        {t.label}
                      </MenuItem>
                    ))}
                  </TextField>
                  <Button
                    size="small"
                    variant="outlined"
                    disabled={!quickDutyType || selectedIds.size === 0}
                    onClick={applyQuickDutyType}
                    sx={{ borderRadius: 2 }}
                  >
                    Áp dụng cho đã tick
                  </Button>
                </>
              )}
            </Stack>

            {mode === 'DUTY' && (
              <InfoBanner>
                Tick người cần bổ sung, rồi chọn <strong>loại ca trực riêng</strong> từng dòng. Có thể dùng «Gán
                nhanh» rồi sửa lại từng người.
              </InfoBanner>
            )}

            <List
              dense
              sx={{
                maxHeight: mode === 'DUTY' ? 360 : 220,
                overflow: 'auto',
                border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                borderRadius: 2,
                mt: mode === 'DUTY' ? 1.5 : 0,
              }}
            >
              {employees.map((emp) => {
                const checked = selectedIds.has(emp.id);
                return (
                  <ListItem
                    key={emp.id}
                    alignItems="flex-start"
                    sx={{
                      py: 1,
                      borderBottom: `1px solid ${alpha(theme.palette.divider, 0.6)}`,
                      bgcolor: checked ? alpha(accent, 0.04) : 'transparent',
                      gap: 1,
                      flexWrap: { xs: 'wrap', sm: 'nowrap' },
                    }}
                  >
                    <ListItemIcon sx={{ minWidth: 36, mt: 0.5 }}>
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
                      secondary={emp.employeeCode || emp.positionTitle || undefined}
                      primaryTypographyProps={{ fontWeight: checked ? 700 : 500, fontSize: '0.875rem' }}
                      sx={{ flex: '1 1 140px', minWidth: 120 }}
                    />
                    {mode === 'DUTY' && (
                      <TextField
                        select
                        size="small"
                        label="Loại ca trực"
                        disabled={!checked}
                        value={dutyShiftByEmp[emp.id] || ''}
                        onChange={(e) => setEmpDutyType(emp.id, e.target.value)}
                        sx={{ ...fieldSx, minWidth: { xs: '100%', sm: 260 }, flex: '1 1 260px' }}
                      >
                        <MenuItem value="">— Chọn loại ca —</MenuItem>
                        {types.map((t) => (
                          <MenuItem key={t.code} value={t.code}>
                            {t.label}
                            {t.grantsWorkUnits ? ' (+0,33 công)' : ' (không công)'}
                          </MenuItem>
                        ))}
                      </TextField>
                    )}
                  </ListItem>
                );
              })}
            </List>
          </>
        )}
      </FormSection>

      {mode === 'DUTY' ? (
        <FormSection title="Ghi chú chung" subtitle="Tuỳ chọn — gắn cùng một ghi chú cho mọi ca lưu lần này.">
          <TextField
            fullWidth
            size="small"
            multiline
            minRows={2}
            label="Ghi chú (tuỳ chọn)"
            value={dutyNote}
            onChange={(e) => setDutyNote(e.target.value)}
            sx={fieldSx}
          />
        </FormSection>
      ) : (
        <>
          <FormSection title="Loại bổ sung Quang Trung" subtitle={scheduleHint}>
            <Stack spacing={1}>
              {att.QUANG_TRUNG_KIND_OPTIONS.map((o) => (
                <SelectableChip
                  key={o.value}
                  selected={updateKind === o.value}
                  label={o.label}
                  onClick={() => setUpdateKind(o.value)}
                />
              ))}
            </Stack>
          </FormSection>
          <FormSection title="Khung giờ công" subtitle="Áp dụng chung cho mọi NV đã chọn.">
            <Box
              sx={{
                p: 2,
                borderRadius: 2.5,
                bgcolor: alpha(accent, 0.05),
                border: `1px dashed ${alpha(accent, 0.25)}`,
              }}
            >
              <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 2 }}>
                <LocationOnOutlinedIcon sx={{ fontSize: 18, color: accent }} />
                <Typography variant="body2" color="text.secondary">
                  {scheduleHint}
                </Typography>
              </Stack>
              {isFullDay ? (
                <Grid container spacing={2}>
                  <Grid item xs={12} md={6}>
                    <ShiftTimes
                      title="Ca sáng"
                      icon={<WbSunnyOutlinedIcon sx={{ fontSize: 18, color: accent }} />}
                      accent={accent}
                      start={morningStart}
                      end={morningEnd}
                      onStartChange={setMorningStart}
                      onEndChange={setMorningEnd}
                    />
                  </Grid>
                  <Grid item xs={12} md={6}>
                    <ShiftTimes
                      title="Ca chiều"
                      icon={<WbTwilightIcon sx={{ fontSize: 18, color: accent }} />}
                      accent={accent}
                      start={afternoonStart}
                      end={afternoonEnd}
                      onStartChange={setAfternoonStart}
                      onEndChange={setAfternoonEnd}
                    />
                  </Grid>
                </Grid>
              ) : updateKind === 'AFTERNOON_SUPPLEMENT' ? (
                <ShiftTimes
                  title="Ca chiều"
                  icon={<WbTwilightIcon sx={{ fontSize: 18, color: accent }} />}
                  accent={accent}
                  start={afternoonStart}
                  end={afternoonEnd}
                  onStartChange={setAfternoonStart}
                  onEndChange={setAfternoonEnd}
                />
              ) : (
                <ShiftTimes
                  title="Ca sáng"
                  icon={<WbSunnyOutlinedIcon sx={{ fontSize: 18, color: accent }} />}
                  accent={accent}
                  start={morningStart}
                  end={morningEnd}
                  onStartChange={setMorningStart}
                  onEndChange={setMorningEnd}
                />
              )}
            </Box>
          </FormSection>
          <FormSection title="Lý do" subtitle="Tuỳ chọn">
            <TextField
              fullWidth
              size="small"
              multiline
              minRows={2}
              placeholder="Ví dụ: Làm việc tại cơ sở Quang Trung…"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              sx={fieldSx}
            />
          </FormSection>
        </>
      )}

      {result && (
        <Alert
          severity={result.failureCount === 0 ? 'success' : result.successCount === 0 ? 'error' : 'warning'}
          variant="outlined"
          sx={{ borderRadius: 2 }}
        >
          <Typography variant="body2" fontWeight={700}>
            Thành công {result.successCount} · Lỗi {result.failureCount}
          </Typography>
          {result.failureCount > 0 && (
            <Box component="ul" sx={{ m: 0, pl: 2, mt: 1 }}>
              {result.results
                .filter((r) => !r.ok)
                .slice(0, 8)
                .map((r) => (
                  <li key={r.employeeId}>
                    <Typography variant="caption">
                      {r.employeeName || `NV#${r.employeeId}`}: {r.message}
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

function ShiftTimes({
  title,
  icon,
  accent,
  start,
  end,
  onStartChange,
  onEndChange,
}: {
  title: string;
  icon: React.ReactNode;
  accent: string;
  start: string;
  end: string;
  onStartChange: (v: string) => void;
  onEndChange: (v: string) => void;
}) {
  return (
    <Box
      sx={{
        p: 1.75,
        borderRadius: 2,
        bgcolor: alpha(accent, 0.04),
        border: `1px solid ${alpha(accent, 0.16)}`,
        height: '100%',
      }}
    >
      <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.5 }}>
        {icon}
        <Typography variant="subtitle2" fontWeight={700}>
          {title}
        </Typography>
      </Stack>
      <Grid container spacing={1.5}>
        <Grid item xs={6}>
          <TimePickerField required label="Vào ca" value={start} onChange={onStartChange} sx={fieldSx} />
        </Grid>
        <Grid item xs={6}>
          <TimePickerField required label="Ra ca" value={end} onChange={onEndChange} sx={fieldSx} />
        </Grid>
      </Grid>
    </Box>
  );
}
