import AddCircleOutlineIcon from '@mui/icons-material/AddCircleOutline';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import CloudUploadOutlinedIcon from '@mui/icons-material/CloudUploadOutlined';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import DownloadOutlinedIcon from '@mui/icons-material/DownloadOutlined';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutline';
import EventBusyOutlinedIcon from '@mui/icons-material/EventBusyOutlined';
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';
import RefreshIcon from '@mui/icons-material/Refresh';
import SearchIcon from '@mui/icons-material/Search';
import TableChartOutlinedIcon from '@mui/icons-material/TableChartOutlined';
import WarningAmberIcon from '@mui/icons-material/WarningAmber';
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Checkbox,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControlLabel,
  IconButton,
  InputAdornment,
  LinearProgress,
  MenuItem,
  Paper,
  Snackbar,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import { DatePickerField } from '../components/ui/DateTimeFields';
import * as employeeService from '../services/employeeService';
import * as svc from '../services/manualLeaveService';

const ACCENT = '#0f766e';

function fmtDate(iso?: string | null) {
  if (!iso) return '—';
  const [y, m, d] = iso.split('-');
  return `${d}/${m}/${y}`;
}

function fmtRange(from?: string | null, to?: string | null) {
  if (!from) return '—';
  return !to || to === from ? fmtDate(from) : `${fmtDate(from)} → ${fmtDate(to)}`;
}

function daysInclusive(from: string, to: string) {
  const a = new Date(from + 'T00:00:00');
  const b = new Date(to + 'T00:00:00');
  if (Number.isNaN(a.getTime()) || Number.isNaN(b.getTime()) || b < a) return 0;
  return Math.round((b.getTime() - a.getTime()) / 86400000) + 1;
}

function errMsg(e: unknown, fallback: string) {
  return (e as { response?: { data?: { message?: string } } })?.response?.data?.message || fallback;
}

type Snack = { open: boolean; message: string; severity: 'success' | 'error' | 'info' };

const ROW_STATUS: Record<
  svc.ManualLeaveImportRowStatus,
  { label: string; color: 'success' | 'info' | 'warning' | 'error' }
> = {
  OK: { label: 'Hợp lệ', color: 'info' },
  CREATED: { label: 'Đã ghi nhận', color: 'success' },
  DUPLICATE: { label: 'Trùng', color: 'warning' },
  ERROR: { label: 'Lỗi', color: 'error' },
};

export default function ManualLeaveAdminPage() {
  const theme = useTheme();
  const nowYear = new Date().getFullYear();
  const [year, setYear] = useState(nowYear);
  const [items, setItems] = useState<svc.ManualLeave[]>([]);
  const [loading, setLoading] = useState(false);
  const [q, setQ] = useState('');
  const [snack, setSnack] = useState<Snack>({ open: false, message: '', severity: 'success' });
  const [manualOpen, setManualOpen] = useState(false);
  const [importOpen, setImportOpen] = useState(false);
  const [deleting, setDeleting] = useState<svc.ManualLeave | null>(null);
  const [deleteBusy, setDeleteBusy] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      setItems(await svc.listManualLeaves(year));
    } catch (e) {
      setSnack({ open: true, message: errMsg(e, 'Không tải được danh sách.'), severity: 'error' });
    } finally {
      setLoading(false);
    }
  }, [year]);

  useEffect(() => {
    void load();
  }, [load]);

  const filtered = useMemo(() => {
    const k = q.trim().toLowerCase();
    if (!k) return items;
    return items.filter(
      (x) =>
        x.employeeName.toLowerCase().includes(k) ||
        (x.employeeCode ?? '').toLowerCase().includes(k) ||
        (x.idCardNumber ?? '').toLowerCase().includes(k) ||
        (x.departmentName ?? '').toLowerCase().includes(k),
    );
  }, [items, q]);

  const stats = useMemo(() => {
    const emps = new Set(items.map((x) => x.employeeId));
    const days = items.reduce((s, x) => s + (x.days ?? 0), 0);
    return { entries: items.length, employees: emps.size, days };
  }, [items]);

  const yearOptions = useMemo(() => {
    const ys = new Set<number>([nowYear, nowYear - 1, nowYear - 2, year]);
    return Array.from(ys).sort((a, b) => b - a);
  }, [nowYear, year]);

  const handleDelete = async () => {
    if (!deleting) return;
    setDeleteBusy(true);
    try {
      const res = await svc.deleteManualLeave(deleting.id);
      setSnack({
        open: true,
        message: `Đã xoá ${deleting.days} ngày phép của ${deleting.employeeName} — còn ${res.balance.remainingDays}/${res.balance.entitlementDays} ngày phép ${res.balance.year}.`,
        severity: 'success',
      });
      setDeleting(null);
      void load();
    } catch (e) {
      setSnack({ open: true, message: errMsg(e, 'Không xoá được.'), severity: 'error' });
    } finally {
      setDeleteBusy(false);
    }
  };

  return (
    <Box>
      <PageHeader
        overline="Quản trị"
        title="Gắn ngày phép đã nghỉ"
        description="Ghi nhận phép năm nhân viên đã nghỉ trước khi dùng phần mềm để trừ vào hạn mức 12 ngày. Gắn tay từng người hoặc nhập hàng loạt từ Excel (Họ tên, CCCD, Từ ngày, Đến ngày)."
        actions={
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1}>
            <Button
              variant="outlined"
              startIcon={<TableChartOutlinedIcon />}
              onClick={() => setImportOpen(true)}
              sx={{ borderRadius: 2, fontWeight: 700 }}
            >
              Nhập từ Excel
            </Button>
            <Button
              variant="contained"
              startIcon={<AddCircleOutlineIcon />}
              onClick={() => setManualOpen(true)}
              sx={{
                borderRadius: 2,
                fontWeight: 700,
                bgcolor: ACCENT,
                '&:hover': { bgcolor: '#115e59' },
              }}
            >
              Gắn tay
            </Button>
          </Stack>
        }
      />

      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' },
          gap: 2,
          mb: 2.5,
        }}
      >
        <StatCard
          label={`Lượt gắn năm ${year}`}
          value={stats.entries}
          hint="bản ghi phép ngoài hệ thống"
        />
        <StatCard label="Nhân viên" value={stats.employees} hint="người có phép được gắn" />
        <StatCard label="Tổng ngày phép" value={stats.days} hint="đã trừ vào hạn mức" accent />
      </Box>

      <Paper
        variant="outlined"
        sx={{
          borderRadius: 3,
          overflow: 'hidden',
          borderColor: alpha(theme.palette.primary.main, 0.12),
        }}
      >
        <Stack
          direction={{ xs: 'column', md: 'row' }}
          spacing={1.5}
          alignItems={{ xs: 'stretch', md: 'center' }}
          justifyContent="space-between"
          sx={{ p: 2, borderBottom: `1px solid ${theme.palette.divider}` }}
        >
          <TextField
            size="small"
            placeholder="Tìm theo tên, CCCD, mã NV, khoa…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
            sx={{ minWidth: { md: 340 } }}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon fontSize="small" />
                </InputAdornment>
              ),
            }}
          />
          <Stack direction="row" spacing={1} alignItems="center">
            <TextField
              select
              size="small"
              label="Năm"
              value={year}
              onChange={(e) => setYear(Number(e.target.value))}
              sx={{ minWidth: 120 }}
            >
              {yearOptions.map((y) => (
                <MenuItem key={y} value={y}>
                  {y}
                </MenuItem>
              ))}
            </TextField>
            <Tooltip title="Tải lại">
              <IconButton onClick={() => void load()} disabled={loading}>
                <RefreshIcon />
              </IconButton>
            </Tooltip>
          </Stack>
        </Stack>
        {loading && <LinearProgress />}
        <TableContainer sx={{ overflowX: 'auto' }}>
          <Table size="small" sx={{ minWidth: 860 }}>
            <TableHead>
              <TableRow sx={{ '& th': { fontWeight: 700, bgcolor: alpha(ACCENT, 0.06) } }}>
                <TableCell>Nhân viên</TableCell>
                <TableCell>CCCD / Mã NV</TableCell>
                <TableCell>Khoa / phòng</TableCell>
                <TableCell>Khoảng nghỉ</TableCell>
                <TableCell align="center">Số ngày</TableCell>
                <TableCell>Ghi chú</TableCell>
                <TableCell>Người gắn</TableCell>
                <TableCell align="right" />
              </TableRow>
            </TableHead>
            <TableBody>
              {!loading && filtered.length === 0 && (
                <TableRow>
                  <TableCell colSpan={8}>
                    <Stack alignItems="center" spacing={1} sx={{ py: 5, color: 'text.secondary' }}>
                      <EventBusyOutlinedIcon sx={{ fontSize: 40, opacity: 0.4 }} />
                      <Typography variant="body2">
                        {items.length === 0
                          ? `Chưa có phép nào được gắn trong năm ${year}.`
                          : 'Không có kết quả phù hợp.'}
                      </Typography>
                    </Stack>
                  </TableCell>
                </TableRow>
              )}
              {filtered.map((x) => (
                <TableRow key={x.id} hover>
                  <TableCell>
                    <Typography variant="body2" fontWeight={700}>
                      {x.employeeName}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" sx={{ fontVariantNumeric: 'tabular-nums' }}>
                      {x.idCardNumber || x.employeeCode || '—'}
                    </Typography>
                    {x.idCardNumber && x.employeeCode && x.employeeCode !== x.idCardNumber && (
                      <Typography variant="caption" color="text.secondary">
                        Mã NV {x.employeeCode}
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" color="text.secondary">
                      {x.departmentName || '—'}
                    </Typography>
                  </TableCell>
                  <TableCell sx={{ whiteSpace: 'nowrap' }}>
                    {fmtRange(x.fromDate, x.toDate)}
                  </TableCell>
                  <TableCell align="center">
                    <Chip
                      size="small"
                      label={`${x.days} ngày`}
                      sx={{ fontWeight: 700, bgcolor: alpha(ACCENT, 0.1), color: ACCENT }}
                    />
                  </TableCell>
                  <TableCell sx={{ maxWidth: 260 }}>
                    <Typography
                      variant="body2"
                      color="text.secondary"
                      sx={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}
                      title={x.note ?? ''}
                    >
                      {x.note || '—'}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    <Typography variant="body2" color="text.secondary">
                      {x.createdBy || '—'}
                    </Typography>
                    {x.createdAt && (
                      <Typography variant="caption" color="text.disabled">
                        {new Date(x.createdAt).toLocaleDateString('vi-VN')}
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell align="right">
                    <Tooltip title="Xoá — hoàn lại hạn mức phép">
                      <IconButton size="small" color="error" onClick={() => setDeleting(x)}>
                        <DeleteOutlineIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      </Paper>

      <ManualAttachDialog
        open={manualOpen}
        onClose={() => setManualOpen(false)}
        onDone={(msg) => {
          setManualOpen(false);
          setSnack({ open: true, message: msg, severity: 'success' });
          void load();
        }}
      />
      <ExcelImportDialog
        open={importOpen}
        onClose={() => setImportOpen(false)}
        onApplied={(msg) => {
          setSnack({ open: true, message: msg, severity: 'success' });
          void load();
        }}
      />

      <Dialog
        open={!!deleting}
        onClose={() => !deleteBusy && setDeleting(null)}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle sx={{ fontWeight: 800 }}>Xoá phép đã gắn?</DialogTitle>
        <DialogContent>
          {deleting && (
            <Typography variant="body2">
              Xoá <b>{deleting.days} ngày</b> phép ({fmtRange(deleting.fromDate, deleting.toDate)})
              của <b>{deleting.employeeName}</b>. Hạn mức phép năm sẽ được hoàn lại; ngày nghỉ đã
              đánh dấu trên bảng công (không có giờ chấm) sẽ trở về trạng thái vắng.
            </Typography>
          )}
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={() => setDeleting(null)} disabled={deleteBusy}>
            Huỷ
          </Button>
          <Button
            variant="contained"
            color="error"
            onClick={() => void handleDelete()}
            disabled={deleteBusy}
          >
            {deleteBusy ? 'Đang xoá…' : 'Xoá'}
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={snack.open}
        autoHideDuration={5000}
        onClose={() => setSnack((s) => ({ ...s, open: false }))}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          severity={snack.severity}
          variant="filled"
          onClose={() => setSnack((s) => ({ ...s, open: false }))}
          sx={{ borderRadius: 2 }}
        >
          {snack.message}
        </Alert>
      </Snackbar>
    </Box>
  );
}

function StatCard({
  label,
  value,
  hint,
  accent,
}: {
  label: string;
  value: number;
  hint: string;
  accent?: boolean;
}) {
  const theme = useTheme();
  return (
    <Paper
      variant="outlined"
      sx={{
        p: 2,
        borderRadius: 3,
        borderColor: accent ? alpha(ACCENT, 0.35) : alpha(theme.palette.primary.main, 0.12),
        bgcolor: accent ? alpha(ACCENT, 0.05) : 'background.paper',
      }}
    >
      <Typography
        variant="overline"
        sx={{ color: 'text.secondary', fontWeight: 700, letterSpacing: 0.6 }}
      >
        {label}
      </Typography>
      <Typography
        variant="h4"
        sx={{ fontWeight: 800, color: accent ? ACCENT : 'text.primary', lineHeight: 1.2 }}
      >
        {value}
      </Typography>
      <Typography variant="caption" color="text.secondary">
        {hint}
      </Typography>
    </Paper>
  );
}

// ----------------------------------------------------------------------------- gắn tay

function ManualAttachDialog({
  open,
  onClose,
  onDone,
}: {
  open: boolean;
  onClose: () => void;
  onDone: (message: string) => void;
}) {
  const theme = useTheme();
  const [emp, setEmp] = useState<employeeService.EmployeeSummary | null>(null);
  const [options, setOptions] = useState<employeeService.EmployeeSummary[]>([]);
  const [searching, setSearching] = useState(false);
  const [input, setInput] = useState('');
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const [note, setNote] = useState('');
  const [applyAttendance, setApplyAttendance] = useState(true);
  const [balance, setBalance] = useState<svc.LeaveBalance | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const timer = useRef<number | null>(null);

  useEffect(() => {
    if (!open) {
      setEmp(null);
      setOptions([]);
      setInput('');
      setFromDate('');
      setToDate('');
      setNote('');
      setApplyAttendance(true);
      setBalance(null);
      setError('');
    }
  }, [open]);

  useEffect(() => {
    if (!open) return;
    if (timer.current) window.clearTimeout(timer.current);
    timer.current = window.setTimeout(async () => {
      setSearching(true);
      try {
        const page = await employeeService.fetchEmployees({
          q: input,
          size: 12,
          statusGroup: 'WORKING',
        });
        setOptions(page.content ?? []);
      } catch {
        setOptions([]);
      } finally {
        setSearching(false);
      }
    }, 250);
    return () => {
      if (timer.current) window.clearTimeout(timer.current);
    };
  }, [input, open]);

  const year = fromDate ? Number(fromDate.slice(0, 4)) : new Date().getFullYear();
  useEffect(() => {
    if (!emp) {
      setBalance(null);
      return;
    }
    let live = true;
    svc
      .fetchLeaveBalance(emp.id, year)
      .then((b) => live && setBalance(b))
      .catch(() => live && setBalance(null));
    return () => {
      live = false;
    };
  }, [emp, year]);

  const days = fromDate && toDate ? daysInclusive(fromDate, toDate) : 0;
  const projectedRemaining = balance ? balance.remainingDays - days : null;
  const canSubmit = !!emp && !!fromDate && !!toDate && days > 0 && !busy;

  const submit = async () => {
    if (!emp) return;
    setBusy(true);
    setError('');
    try {
      const res = await svc.attachManualLeave({
        employeeId: emp.id,
        fromDate,
        toDate,
        note: note.trim() || undefined,
        applyAttendance,
      });
      onDone(
        `Đã gắn ${res.days} ngày phép cho ${res.employeeName} — còn ${res.balance.remainingDays}/${res.balance.entitlementDays} ngày phép năm ${res.balance.year}.`,
      );
    } catch (e) {
      setError(errMsg(e, 'Không gắn được phép.'));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onClose={() => !busy && onClose()} maxWidth="sm" fullWidth>
      <DialogTitle sx={{ fontWeight: 800, pb: 1 }}>
        <Stack direction="row" spacing={1.25} alignItems="center">
          <Box
            sx={{
              width: 36,
              height: 36,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(ACCENT, 0.12),
              color: ACCENT,
            }}
          >
            <EventBusyOutlinedIcon fontSize="small" />
          </Box>
          <Box>
            <Typography variant="h6" sx={{ fontWeight: 800, lineHeight: 1.2 }}>
              Gắn tay ngày phép đã nghỉ
            </Typography>
            <Typography variant="caption" color="text.secondary">
              Ghi nhận phép năm đã nghỉ ngoài hệ thống, trừ thẳng vào hạn mức
            </Typography>
          </Box>
        </Stack>
      </DialogTitle>
      <DialogContent dividers>
        <Stack spacing={2.25} sx={{ pt: 0.5 }}>
          <Autocomplete
            options={options}
            value={emp}
            loading={searching}
            filterOptions={(x) => x}
            getOptionLabel={(o) => o.fullName}
            isOptionEqualToValue={(a, b) => a.id === b.id}
            onInputChange={(_, v) => setInput(v)}
            onChange={(_, v) => setEmp(v)}
            noOptionsText={input ? 'Không tìm thấy nhân viên' : 'Gõ tên, CCCD hoặc mã NV'}
            renderOption={(props, o) => (
              <li {...props} key={o.id}>
                <Box>
                  <Typography variant="body2" fontWeight={600}>
                    {o.fullName}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {[o.employeeCode, o.departmentName].filter(Boolean).join(' · ')}
                  </Typography>
                </Box>
              </li>
            )}
            renderInput={(params) => (
              <TextField
                {...params}
                label="Nhân viên"
                required
                placeholder="Tìm theo tên, CCCD, mã NV"
                InputProps={{
                  ...params.InputProps,
                  endAdornment: (
                    <>
                      {searching ? <CircularProgress size={16} /> : null}
                      {params.InputProps.endAdornment}
                    </>
                  ),
                }}
              />
            )}
          />

          {emp && (
            <Paper
              variant="outlined"
              sx={{
                p: 1.5,
                borderRadius: 2,
                bgcolor: alpha(theme.palette.primary.main, 0.03),
                borderColor: alpha(theme.palette.primary.main, 0.12),
              }}
            >
              <Stack direction="row" spacing={2} flexWrap="wrap" useFlexGap alignItems="center">
                <Typography variant="body2" sx={{ fontWeight: 700 }}>
                  Phép năm {year}
                </Typography>
                {balance ? (
                  <>
                    <Chip size="small" label={`Hạn mức ${balance.entitlementDays}`} />
                    <Chip size="small" label={`Đã dùng ${balance.usedDays}`} color="default" />
                    {balance.pendingDays > 0 && (
                      <Chip
                        size="small"
                        label={`Chờ duyệt ${balance.pendingDays}`}
                        color="warning"
                        variant="outlined"
                      />
                    )}
                    <Chip
                      size="small"
                      label={`Còn ${balance.remainingDays}`}
                      sx={{ fontWeight: 700, bgcolor: alpha(ACCENT, 0.12), color: ACCENT }}
                    />
                    {days > 0 && projectedRemaining != null && (
                      <Typography
                        variant="caption"
                        sx={{
                          color: projectedRemaining < 0 ? 'error.main' : 'text.secondary',
                          fontWeight: 600,
                        }}
                      >
                        → sau khi gắn còn {Math.max(0, projectedRemaining)}
                        {projectedRemaining < 0 ? ` (vượt ${-projectedRemaining} ngày)` : ''}
                      </Typography>
                    )}
                  </>
                ) : (
                  <CircularProgress size={14} />
                )}
              </Stack>
            </Paper>
          )}

          <Box
            sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' }, gap: 1.75 }}
          >
            <DatePickerField
              label="Từ ngày"
              required
              value={fromDate}
              onChange={(v) => {
                setFromDate(v);
                if (!toDate || (v && toDate < v)) setToDate(v);
              }}
            />
            <DatePickerField label="Đến ngày" required value={toDate} onChange={setToDate} />
          </Box>
          <Typography variant="caption" color={days > 0 ? 'text.secondary' : 'text.disabled'}>
            {days > 0
              ? `Số ngày phép sẽ trừ: ${days} ngày (tính cả ngày đầu và ngày cuối)`
              : fromDate && toDate
                ? 'Đến ngày phải sau hoặc bằng Từ ngày'
                : 'Chọn khoảng ngày đã nghỉ'}
          </Typography>

          <TextField
            label="Ghi chú"
            placeholder="VD: Nghỉ phép trước khi dùng phần mềm"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            multiline
            minRows={2}
          />

          <FormControlLabel
            control={
              <Checkbox
                checked={applyAttendance}
                onChange={(e) => setApplyAttendance(e.target.checked)}
              />
            }
            label={
              <Box>
                <Typography variant="body2">Đánh dấu nghỉ phép trên bảng công</Typography>
                <Typography variant="caption" color="text.secondary">
                  Chỉ áp cho ngày chưa có giờ chấm công; ngày đã có dữ liệu máy chấm công giữ
                  nguyên.
                </Typography>
              </Box>
            }
          />

          {error && (
            <Alert severity="error" sx={{ borderRadius: 2 }}>
              {error}
            </Alert>
          )}
        </Stack>
      </DialogContent>
      <DialogActions sx={{ px: 3, py: 2 }}>
        <Button onClick={onClose} disabled={busy}>
          Huỷ
        </Button>
        <Button
          variant="contained"
          onClick={() => void submit()}
          disabled={!canSubmit}
          sx={{ fontWeight: 700, bgcolor: ACCENT, '&:hover': { bgcolor: '#115e59' } }}
        >
          {busy ? 'Đang ghi nhận…' : `Gắn ${days > 0 ? `${days} ngày ` : ''}phép`}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

// ----------------------------------------------------------------------------- Excel

function ExcelImportDialog({
  open,
  onClose,
  onApplied,
}: {
  open: boolean;
  onClose: () => void;
  onApplied: (message: string) => void;
}) {
  const theme = useTheme();
  const [file, setFile] = useState<File | null>(null);
  const [result, setResult] = useState<svc.ManualLeaveImportResult | null>(null);
  const [busy, setBusy] = useState<'preview' | 'apply' | null>(null);
  const [error, setError] = useState('');
  const [applyAttendance, setApplyAttendance] = useState(true);
  const [downloading, setDownloading] = useState(false);
  const inputRef = useRef<HTMLInputElement | null>(null);

  useEffect(() => {
    if (!open) {
      setFile(null);
      setResult(null);
      setBusy(null);
      setError('');
      setApplyAttendance(true);
    }
  }, [open]);

  const pick = (f: File | null) => {
    setFile(f);
    setResult(null);
    setError('');
    if (f) void run(f, false);
  };

  const run = async (f: File, apply: boolean) => {
    setBusy(apply ? 'apply' : 'preview');
    setError('');
    try {
      const res = await svc.importManualLeaves(f, apply, applyAttendance);
      setResult(res);
      if (apply) {
        onApplied(
          `Đã ghi nhận ${res.created} dòng phép từ Excel${res.duplicate ? `, bỏ qua ${res.duplicate} dòng trùng` : ''}${res.error ? `, ${res.error} dòng lỗi` : ''}.`,
        );
      }
    } catch (e) {
      setError(errMsg(e, 'Không đọc được file.'));
      setResult(null);
    } finally {
      setBusy(null);
    }
  };

  const download = async () => {
    setDownloading(true);
    try {
      await svc.downloadManualLeaveTemplate();
    } catch (e) {
      setError(errMsg(e, 'Không tải được file mẫu.'));
    } finally {
      setDownloading(false);
    }
  };

  const applied = !!result?.applied;
  const ready = result?.ready ?? 0;
  const totalDays =
    result?.rows
      .filter((r) => r.status === 'OK' || r.status === 'CREATED')
      .reduce((s, r) => s + (r.days ?? 0), 0) ?? 0;

  return (
    <Dialog open={open} onClose={() => !busy && onClose()} maxWidth="md" fullWidth>
      <DialogTitle sx={{ fontWeight: 800, pb: 1 }}>
        <Stack direction="row" spacing={1.25} alignItems="center">
          <Box
            sx={{
              width: 36,
              height: 36,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(ACCENT, 0.12),
              color: ACCENT,
            }}
          >
            <TableChartOutlinedIcon fontSize="small" />
          </Box>
          <Box>
            <Typography variant="h6" sx={{ fontWeight: 800, lineHeight: 1.2 }}>
              Nhập phép đã nghỉ từ Excel
            </Typography>
            <Typography variant="caption" color="text.secondary">
              Cột bắt buộc: Họ tên · CCCD · Từ ngày · Đến ngày (Ghi chú tuỳ chọn)
            </Typography>
          </Box>
        </Stack>
      </DialogTitle>
      <DialogContent dividers>
        <Stack spacing={2}>
          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            spacing={1.5}
            alignItems={{ sm: 'center' }}
          >
            <StepChip n={1} label="Tải file mẫu" />
            <Button
              variant="outlined"
              size="small"
              startIcon={downloading ? <CircularProgress size={14} /> : <DownloadOutlinedIcon />}
              onClick={() => void download()}
              disabled={downloading}
              sx={{ borderRadius: 2, fontWeight: 700 }}
            >
              MAU-GAN-PHEP-NGOAI-HE-THONG.xlsx
            </Button>
            <Typography variant="caption" color="text.secondary">
              Điền dữ liệu vào sheet đầu, giữ nguyên dòng tiêu đề.
            </Typography>
          </Stack>

          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            spacing={1.5}
            alignItems={{ sm: 'center' }}
          >
            <StepChip n={2} label="Chọn file đã điền" />
            <input
              ref={inputRef}
              type="file"
              accept=".xlsx"
              hidden
              onChange={(e) => pick(e.target.files?.[0] ?? null)}
            />
            <Button
              variant="contained"
              size="small"
              startIcon={<CloudUploadOutlinedIcon />}
              onClick={() => inputRef.current?.click()}
              disabled={!!busy || applied}
              sx={{
                borderRadius: 2,
                fontWeight: 700,
                bgcolor: ACCENT,
                '&:hover': { bgcolor: '#115e59' },
              }}
            >
              Chọn file .xlsx
            </Button>
            {file && (
              <Typography variant="body2" sx={{ fontWeight: 600, wordBreak: 'break-all' }}>
                {file.name}
              </Typography>
            )}
          </Stack>

          <FormControlLabel
            control={
              <Checkbox
                checked={applyAttendance}
                onChange={(e) => setApplyAttendance(e.target.checked)}
                disabled={applied}
              />
            }
            label={
              <Typography variant="body2">
                Đánh dấu nghỉ phép trên bảng công (chỉ ngày chưa có giờ chấm công)
              </Typography>
            }
          />

          {busy === 'preview' && <LinearProgress />}
          {error && (
            <Alert severity="error" sx={{ borderRadius: 2 }}>
              {error}
            </Alert>
          )}

          {result && (
            <>
              <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap alignItems="center">
                <StepChip n={3} label={applied ? 'Kết quả' : 'Kiểm tra trước'} />
                <Chip size="small" label={`${result.total} dòng`} />
                {applied ? (
                  <Chip
                    size="small"
                    color="success"
                    icon={<CheckCircleOutlineIcon />}
                    label={`Đã ghi nhận ${result.created}`}
                  />
                ) : (
                  <Chip size="small" color="info" label={`Hợp lệ ${ready} · ${totalDays} ngày`} />
                )}
                {result.duplicate > 0 && (
                  <Chip
                    size="small"
                    color="warning"
                    icon={<WarningAmberIcon />}
                    label={`Trùng ${result.duplicate}`}
                  />
                )}
                {result.error > 0 && (
                  <Chip
                    size="small"
                    color="error"
                    icon={<ErrorOutlineIcon />}
                    label={`Lỗi ${result.error}`}
                  />
                )}
              </Stack>
              {!applied && ready > 0 && (
                <Alert severity="info" icon={<InfoOutlinedIcon />} sx={{ borderRadius: 2 }}>
                  Chỉ các dòng <b>Hợp lệ</b> được ghi nhận khi bấm “Ghi nhận”. Dòng trùng / lỗi sẽ
                  bị bỏ qua — sửa lại file và chọn lại nếu cần.
                </Alert>
              )}
              <TableContainer
                component={Paper}
                variant="outlined"
                sx={{ borderRadius: 2, maxHeight: 380, overflow: 'auto' }}
              >
                <Table size="small" stickyHeader sx={{ minWidth: 760 }}>
                  <TableHead>
                    <TableRow
                      sx={{
                        '& th': {
                          fontWeight: 700,
                          bgcolor: alpha(theme.palette.primary.main, 0.04),
                        },
                      }}
                    >
                      <TableCell align="center" sx={{ width: 56 }}>
                        Dòng
                      </TableCell>
                      <TableCell>Họ tên (file)</TableCell>
                      <TableCell>CCCD</TableCell>
                      <TableCell>Nhân viên hệ thống</TableCell>
                      <TableCell>Khoảng nghỉ</TableCell>
                      <TableCell align="center">Ngày</TableCell>
                      <TableCell>Trạng thái</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {result.rows.map((r) => {
                      const st = ROW_STATUS[r.status] ?? ROW_STATUS.ERROR;
                      return (
                        <TableRow key={r.row} hover>
                          <TableCell align="center" sx={{ color: 'text.secondary' }}>
                            {r.row}
                          </TableCell>
                          <TableCell>{r.name || '—'}</TableCell>
                          <TableCell sx={{ fontVariantNumeric: 'tabular-nums' }}>
                            {r.cccd || '—'}
                          </TableCell>
                          <TableCell>
                            {r.employeeName ? (
                              <>
                                <Typography variant="body2" fontWeight={600}>
                                  {r.employeeName}
                                </Typography>
                                <Typography variant="caption" color="text.secondary">
                                  {r.departmentName || ''}
                                </Typography>
                              </>
                            ) : (
                              '—'
                            )}
                          </TableCell>
                          <TableCell sx={{ whiteSpace: 'nowrap' }}>
                            {fmtRange(r.fromDate, r.toDate)}
                          </TableCell>
                          <TableCell align="center">{r.days ?? '—'}</TableCell>
                          <TableCell>
                            <Stack direction="row" spacing={0.75} alignItems="center">
                              <Chip
                                size="small"
                                color={st.color}
                                label={st.label}
                                sx={{ fontWeight: 700 }}
                              />
                              <Typography
                                variant="caption"
                                color={r.status === 'ERROR' ? 'error.main' : 'text.secondary'}
                              >
                                {r.message}
                              </Typography>
                            </Stack>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </TableContainer>
            </>
          )}
        </Stack>
      </DialogContent>
      <Divider />
      <DialogActions sx={{ px: 3, py: 2 }}>
        <Button onClick={onClose} disabled={!!busy}>
          {applied ? 'Đóng' : 'Huỷ'}
        </Button>
        {!applied && (
          <Button
            variant="contained"
            disabled={!file || !result || ready === 0 || !!busy}
            onClick={() => file && void run(file, true)}
            startIcon={
              busy === 'apply' ? (
                <CircularProgress size={16} color="inherit" />
              ) : (
                <CheckCircleOutlineIcon />
              )
            }
            sx={{ fontWeight: 700, bgcolor: ACCENT, '&:hover': { bgcolor: '#115e59' } }}
          >
            {busy === 'apply' ? 'Đang ghi nhận…' : `Ghi nhận ${ready > 0 ? `${ready} dòng` : ''}`}
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
}

function StepChip({ n, label }: { n: number; label: string }) {
  return (
    <Stack direction="row" spacing={0.75} alignItems="center" sx={{ minWidth: 150 }}>
      <Box
        sx={{
          width: 22,
          height: 22,
          borderRadius: '50%',
          display: 'grid',
          placeItems: 'center',
          bgcolor: ACCENT,
          color: '#fff',
          fontSize: 12,
          fontWeight: 800,
        }}
      >
        {n}
      </Box>
      <Typography variant="body2" sx={{ fontWeight: 700 }}>
        {label}
      </Typography>
    </Stack>
  );
}
