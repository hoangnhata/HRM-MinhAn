import GroupAddOutlinedIcon from '@mui/icons-material/GroupAddOutlined';
import LocationOnOutlinedIcon from '@mui/icons-material/LocationOnOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import WbSunnyOutlinedIcon from '@mui/icons-material/WbSunnyOutlined';
import WbTwilightIcon from '@mui/icons-material/WbTwilight';
import SearchOutlinedIcon from '@mui/icons-material/SearchOutlined';
import {
  Alert,
  Box,
  Button,
  Checkbox,
  CircularProgress,
  Grid,
  InputAdornment,
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
  /** ADMIN làm việc theo phạm vi toàn viện, không khóa theo khoa/phòng. */
  hospitalWide?: boolean;
  /** Danh sách trang Công đã tải sẵn — giúp hộp thoại hiển thị ngay khi mở. */
  departmentOptions?: employeeService.DepartmentOption[];
  initialDepartmentId?: number | '';
  initialWorkDate?: string;
};

type Mode = 'DUTY' | 'QUANG_TRUNG';

const ACCENT_DUTY = '#5b4bb4';
const fieldSx = dateTimeFieldSx;

function normalizeSearch(value: string) {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase()
    .trim();
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function allowedDutyTypesForEmployee(
  emp: employeeService.EmployeeSummary,
  all: att.DutyShiftTypeOption[],
) {
  if (emp.mainDutyAuthorized) return all;
  return all.filter((t) => t.code === 'TK');
}

function allowedDutyTypesForSelection(
  emps: employeeService.EmployeeSummary[],
  selectedIds: Set<number>,
  all: att.DutyShiftTypeOption[],
) {
  const selected = emps.filter((e) => selectedIds.has(e.id));
  if (selected.length === 0) return all.filter((t) => t.code === 'TK');
  let allowed = all;
  for (const emp of selected) {
    const empAllowed = allowedDutyTypesForEmployee(emp, all);
    allowed = allowed.filter((t) => empAllowed.some((a) => a.code === t.code));
  }
  return allowed;
}

export function BulkWorkSupplementDialog({
  open,
  onClose,
  onSaved,
  hospitalWide = false,
  departmentOptions,
  initialDepartmentId = '',
  initialWorkDate,
}: Props) {
  const theme = useTheme();
  const [mode, setMode] = useState<Mode>('DUTY');
  const accent = mode === 'DUTY' ? ACCENT_DUTY : theme.palette.success.main;

  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [departmentsLoading, setDepartmentsLoading] = useState(false);
  const [departmentError, setDepartmentError] = useState<string | null>(null);
  const [departmentId, setDepartmentId] = useState<number | ''>('');
  const [employees, setEmployees] = useState<employeeService.EmployeeSummary[]>([]);
  const [employeeSearch, setEmployeeSearch] = useState('');
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  /** Công trực: loại ca riêng từng NV (chỉ dùng khi đã tick) */
  const [dutyShiftByEmp, setDutyShiftByEmp] = useState<Record<number, string>>({});
  const [dutyRoleByEmp, setDutyRoleByEmp] = useState<Record<number, string>>({});
  const [employeesLoading, setEmployeesLoading] = useState(false);

  const [workDate, setWorkDate] = useState(initialWorkDate || todayIso());

  const [types, setTypes] = useState<att.DutyShiftTypeOption[]>([]);
  const [quickDutyType, setQuickDutyType] = useState('');
  const [quickDutyRole, setQuickDutyRole] = useState('');
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
        roleTierCode: (dutyRoleByEmp[employeeId] || '').trim() || undefined,
      }))
      .filter((x) => x.shiftTypeCode);
  }, [selectedIds, dutyShiftByEmp, dutyRoleByEmp]);

  const quickDutyTypes = useMemo(
    () => allowedDutyTypesForSelection(employees, selectedIds, types),
    [employees, selectedIds, types],
  );
  const quickRoleTiers = useMemo(
    () => types.find((type) => type.code === quickDutyType)?.roleTiers ?? [],
    [types, quickDutyType],
  );
  const filteredEmployees = useMemo(() => {
    const query = normalizeSearch(employeeSearch);
    if (!query) return employees;
    return employees.filter((employee) =>
      normalizeSearch(`${employee.fullName} ${employee.employeeCode ?? ''} ${employee.departmentName ?? ''}`).includes(query),
    );
  }, [employees, employeeSearch]);

  const submitCount = mode === 'DUTY' ? dutyItems.length : selectedIds.size;

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setResult(null);
    setMode('DUTY');
    setQuickDutyType('');
    setQuickDutyRole('');
    setDutyNote('');
    setDutyShiftByEmp({});
    setDutyRoleByEmp({});
    setUpdateKind('MORNING_SUPPLEMENT');
    setReason('');
    setWorkDate(initialWorkDate || todayIso());
    setDepartmentId(hospitalWide || initialDepartmentId === '' ? '' : Number(initialDepartmentId));
    setEmployeeSearch('');
    setSelectedIds(new Set());
    const sch = scheduleForDate(initialWorkDate || todayIso());
    setMorningStart(sch.morningStart);
    setMorningEnd(sch.morningEnd);
    setAfternoonStart(sch.afternoonStart);
    setAfternoonEnd(sch.afternoonEnd);

    setDepartments(departmentOptions ?? []);
    setDepartmentError(null);
    setDepartmentsLoading(true);
    employeeService
      .fetchDepartments()
      .then((data) => {
        setDepartments(data);
        if (data.length === 0) {
          setDepartmentError('Hệ thống chưa có dữ liệu khoa/phòng.');
        }
      })
      .catch(() => {
        if (!departmentOptions?.length) {
          setDepartmentError('Không tải được danh sách khoa/phòng. Vui lòng đóng và mở lại hộp thoại.');
        }
      })
      .finally(() => setDepartmentsLoading(false));
    att.fetchDutyShiftTypes().then(setTypes).catch(() => setTypes([]));
  }, [open, hospitalWide, departmentOptions, initialDepartmentId, initialWorkDate]);

  useEffect(() => {
    if (!open || (!hospitalWide && departmentId === '')) {
      setEmployees([]);
      setSelectedIds(new Set());
      setDutyShiftByEmp({});
      setDutyRoleByEmp({});
      return;
    }
    setEmployeesLoading(true);
    employeeService
      .fetchEmployees({
        page: 0,
        size: hospitalWide ? 2000 : 500,
        ...(hospitalWide ? {} : { departmentId: Number(departmentId) }),
      })
      .then((page) => {
        const list = (page.content ?? []).filter((e) => e.status !== 'TERMINATED');
        setEmployees(list);
        setSelectedIds(new Set());
        setDutyShiftByEmp({});
        setDutyRoleByEmp({});
      })
      .catch(() => {
        setEmployees([]);
        setSelectedIds(new Set());
        setDutyShiftByEmp({});
        setDutyRoleByEmp({});
      })
      .finally(() => setEmployeesLoading(false));
  }, [open, hospitalWide, departmentId]);

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
        setDutyRoleByEmp((m) => {
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
    setSelectedIds((previous) => {
      const next = new Set(previous);
      filteredEmployees.forEach((employee) => next.add(employee.id));
      return next;
    });
  }

  function clearAll() {
    setSelectedIds(new Set());
    setDutyShiftByEmp({});
    setDutyRoleByEmp({});
  }

  function setEmpDutyType(id: number, code: string) {
    setDutyShiftByEmp((m) => ({ ...m, [id]: code }));
    setDutyRoleByEmp((m) => {
      const allowedRoles = types.find((type) => type.code === code)?.roleTiers ?? [];
      return allowedRoles.some((role) => role.code === m[id]) ? m : { ...m, [id]: '' };
    });
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (code) next.add(id);
      return next;
    });
  }

  function setEmpDutyRole(id: number, code: string) {
    setDutyRoleByEmp((current) => ({ ...current, [id]: code }));
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
    setDutyRoleByEmp((current) => {
      const next = { ...current };
      selectedIds.forEach((id) => {
        next[id] = quickDutyRole;
      });
      return next;
    });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErr(null);
    setResult(null);
    if (!hospitalWide && departmentId === '') {
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

      <FormSection title={hospitalWide ? 'Ngày & phạm vi' : 'Ngày & khoa/phòng'}>
        <Grid container spacing={1.75}>
          <Grid item xs={12} sm={6}>
            <DatePickerField label="Ngày áp dụng" required value={workDate} onChange={setWorkDate} sx={fieldSx} />
          </Grid>
          <Grid item xs={12} sm={6}>
            {hospitalWide ? (
              <TextField
                fullWidth
                size="small"
                label="Phạm vi nhân viên"
                value="Toàn viện"
                InputProps={{ readOnly: true }}
                helperText="Tài khoản ADMIN được chọn nhân viên ở mọi khoa/phòng"
                sx={fieldSx}
              />
            ) : (
              <TextField
                select
                required
                fullWidth
                size="small"
                label="Khoa / phòng"
                value={departmentId}
                onChange={(e) => setDepartmentId(e.target.value === '' ? '' : Number(e.target.value))}
                disabled={departmentsLoading && departments.length === 0}
                error={Boolean(departmentError && departments.length === 0)}
                helperText={departmentError}
                sx={fieldSx}
              >
                <MenuItem value="">— Chọn —</MenuItem>
                {departmentsLoading && departments.length === 0 && (
                  <MenuItem disabled>Đang tải danh sách khoa/phòng…</MenuItem>
                )}
                {departments.map((d) => (
                  <MenuItem key={d.id} value={d.id}>
                    {d.name}
                  </MenuItem>
                ))}
              </TextField>
            )}
          </Grid>
        </Grid>
      </FormSection>

      <FormSection
        title={mode === 'DUTY' ? 'Nhân viên & loại ca trực' : 'Nhân viên'}
        subtitle={
          !hospitalWide && departmentId === ''
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
        ) : !hospitalWide && departmentId === '' ? (
          <Typography variant="body2" color="text.secondary">
            Chưa chọn khoa/phòng.
          </Typography>
        ) : employees.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            {hospitalWide ? 'Không có nhân viên đang làm việc trong viện.' : 'Không có nhân viên đang làm việc trong khoa này.'}
          </Typography>
        ) : (
          <>
            <TextField
              fullWidth
              size="small"
              label="Tìm nhân viên"
              placeholder="Nhập tên hoặc mã nhân viên"
              value={employeeSearch}
              onChange={(event) => setEmployeeSearch(event.target.value)}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <SearchOutlinedIcon fontSize="small" />
                  </InputAdornment>
                ),
              }}
              sx={{ ...fieldSx, mb: 1.5 }}
            />
            <Stack direction="row" spacing={1} sx={{ mb: 1 }} flexWrap="wrap" useFlexGap alignItems="center">
              <Button size="small" onClick={selectAll} sx={{ borderRadius: 2 }}>
                {employeeSearch.trim() ? 'Chọn tất cả kết quả' : 'Chọn tất cả'}
              </Button>
              <Button size="small" onClick={clearAll} sx={{ borderRadius: 2 }}>
                Bỏ chọn
              </Button>
              {mode === 'DUTY' && quickDutyTypes.length > 0 && (
                <>
                  <TextField
                    select
                    size="small"
                    label="Gán nhanh loại ca"
                    value={quickDutyType}
                    onChange={(e) => {
                      setQuickDutyType(e.target.value);
                      setQuickDutyRole('');
                    }}
                    sx={{ ...fieldSx, minWidth: 200 }}
                  >
                    <MenuItem value="">— Chọn loại —</MenuItem>
                    {quickDutyTypes.map((t) => (
                      <MenuItem key={t.code} value={t.code}>
                        {t.label}
                      </MenuItem>
                    ))}
                  </TextField>
                  <TextField
                    select
                    size="small"
                    label="Gán nhanh vị trí"
                    value={quickDutyRole}
                    onChange={(e) => setQuickDutyRole(e.target.value)}
                    disabled={!quickDutyType}
                    sx={{ ...fieldSx, minWidth: 190 }}
                  >
                    <MenuItem value="">Tự nhận diện</MenuItem>
                    {quickRoleTiers.map((role) => (
                      <MenuItem key={role.code} value={role.code}>
                        {role.label}
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
                Tick người cần bổ sung, rồi chọn <strong>loại ca trực</strong> và{' '}
                <strong>vị trí trực</strong> từng dòng. Để “Tự nhận diện” nếu muốn hệ thống xác định vị trí theo
                chức danh.
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
              {filteredEmployees.length === 0 && (
                <ListItem>
                  <ListItemText
                    primary="Không tìm thấy nhân viên"
                    secondary="Kiểm tra lại tên hoặc mã nhân viên."
                  />
                </ListItem>
              )}
              {filteredEmployees.map((emp) => {
                const checked = selectedIds.has(emp.id);
                const rowTypes = allowedDutyTypesForEmployee(emp, types);
                const selectedType = rowTypes.find((type) => type.code === dutyShiftByEmp[emp.id]);
                const roleTiers = selectedType?.roleTiers ?? [];
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
                      secondary={[emp.employeeCode, hospitalWide ? emp.departmentName : emp.positionTitle].filter(Boolean).join(' · ') || undefined}
                      primaryTypographyProps={{ fontWeight: checked ? 700 : 500, fontSize: '0.875rem' }}
                      sx={{ flex: '1 1 140px', minWidth: 120 }}
                    />
                    {mode === 'DUTY' && (
                      <Stack
                        direction={{ xs: 'column', md: 'row' }}
                        spacing={1}
                        sx={{ flex: '1 1 440px', minWidth: { xs: '100%', sm: 360 } }}
                      >
                        <TextField
                          select
                          size="small"
                          label="Loại ca trực"
                          disabled={!checked}
                          value={dutyShiftByEmp[emp.id] || ''}
                          onChange={(e) => setEmpDutyType(emp.id, e.target.value)}
                          sx={{ ...fieldSx, minWidth: { xs: '100%', md: 230 }, flex: 1 }}
                        >
                          <MenuItem value="">— Chọn loại ca —</MenuItem>
                          {rowTypes.map((t) => (
                            <MenuItem key={t.code} value={t.code}>
                              {t.label}
                              {t.grantsWorkUnits ? ' (+0,33 công)' : ' (không công)'}
                            </MenuItem>
                          ))}
                        </TextField>
                        <TextField
                          select
                          size="small"
                          label="Vị trí trực"
                          disabled={!checked || !selectedType}
                          value={dutyRoleByEmp[emp.id] || ''}
                          onChange={(e) => setEmpDutyRole(emp.id, e.target.value)}
                          sx={{ ...fieldSx, minWidth: { xs: '100%', md: 180 }, flex: 1 }}
                        >
                          <MenuItem value="">Tự nhận diện</MenuItem>
                          {roleTiers.map((role) => (
                            <MenuItem key={role.code} value={role.code}>
                              {role.label}
                            </MenuItem>
                          ))}
                        </TextField>
                      </Stack>
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
