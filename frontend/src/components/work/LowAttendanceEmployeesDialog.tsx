import CloseIcon from '@mui/icons-material/Close';
import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import OpenInNewOutlinedIcon from '@mui/icons-material/OpenInNewOutlined';
import RefreshIcon from '@mui/icons-material/Refresh';
import SearchIcon from '@mui/icons-material/Search';
import TaskAltRoundedIcon from '@mui/icons-material/TaskAltRounded';
import WarningAmberRoundedIcon from '@mui/icons-material/WarningAmberRounded';
import {
  Alert,
  Avatar,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogContent,
  Divider,
  FormControl,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import * as attSvc from '../../services/attendanceService';
import type { DepartmentOption } from '../../services/employeeService';
import { EmployeeStatusChip } from '../EmployeeStatusChip';
import { formatWorkUnits } from '../../utils/shiftSchedule';

type Props = {
  open: boolean;
  onClose: () => void;
  year: number;
  month: number;
  departmentId?: number | '';
  departments: DepartmentOption[];
  deptFilterLocked?: boolean;
  onViewEmployee: (employeeId: number, departmentId?: number | null) => void;
};

const THRESHOLD_OPTIONS = [3, 4, 5, 6, 8, 10];

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return '?';
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function normalizeSearch(s: string) {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .trim();
}

export function LowAttendanceEmployeesDialog({
  open,
  onClose,
  year,
  month,
  departmentId = '',
  departments,
  deptFilterLocked,
  onViewEmployee,
}: Props) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;

  const initialScope = useMemo(() => {
    if (departmentId !== '' && departmentId != null) return departmentId;
    return '';
  }, [departmentId]);

  const [scopeDept, setScopeDept] = useState<number | ''>(initialScope);
  const [threshold, setThreshold] = useState(5);
  const [search, setSearch] = useState('');
  const [loading, setLoading] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [matrix, setMatrix] = useState<attSvc.AttendanceMonthMatrix | null>(null);

  useEffect(() => {
    if (!open) return;
    setScopeDept(initialScope);
    setSearch('');
  }, [open, initialScope]);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await attSvc.fetchAttendanceMonthMatrix(
        year,
        month,
        scopeDept === '' || scopeDept == null ? undefined : Number(scopeDept),
      );
      setMatrix(data);
    } catch (e: unknown) {
      setMatrix(null);
      const ax = e as { response?: { data?: { message?: string } }; message?: string };
      setError(ax.response?.data?.message || ax.message || 'Không tải được danh sách công tháng này');
    } finally {
      setLoading(false);
    }
  }, [year, month, scopeDept]);

  useEffect(() => {
    if (!open) return;
    void load();
  }, [open, load]);

  const handleExport = useCallback(async () => {
    setExporting(true);
    setError(null);
    try {
      await attSvc.downloadLowAttendanceReport(
        year,
        month,
        threshold,
        scopeDept === '' || scopeDept == null ? undefined : Number(scopeDept),
      );
    } catch (e: unknown) {
      const ax = e as { response?: { data?: { message?: string } }; message?: string };
      setError(ax.response?.data?.message || ax.message || 'Không xuất được file Excel');
    } finally {
      setExporting(false);
    }
  }, [year, month, threshold, scopeDept]);

  const allRows = matrix?.rows ?? [];

  const availableDepartments = useMemo(() => {
    const unique = new Map<number, DepartmentOption>();
    departments.forEach((d) => unique.set(d.id, d));
    allRows.forEach((row) => {
      if (row.departmentId != null && row.department?.trim()) {
        unique.set(row.departmentId, {
          id: row.departmentId,
          code: `DEPT-${row.departmentId}`,
          name: row.department.trim(),
        });
      }
    });
    return [...unique.values()].sort((a, b) => a.name.localeCompare(b.name, 'vi'));
  }, [departments, allRows]);

  const lowRows = useMemo(() => {
    return allRows
      .filter((r) => Number(r.totalWorkUnits ?? 0) < threshold)
      .sort((a, b) => {
        const diff = Number(a.totalWorkUnits ?? 0) - Number(b.totalWorkUnits ?? 0);
        if (diff !== 0) return diff;
        return a.fullName.localeCompare(b.fullName, 'vi');
      });
  }, [allRows, threshold]);

  const filteredRows = useMemo(() => {
    const q = normalizeSearch(search);
    if (!q) return lowRows;
    return lowRows.filter((row) => {
      const hay = normalizeSearch([row.fullName, row.employeeCode, row.position, row.department].filter(Boolean).join(' '));
      return hay.includes(q);
    });
  }, [lowRows, search]);

  const needsData = !matrix && !loading;
  const criticalCount = lowRows.filter((r) => Number(r.totalWorkUnits ?? 0) < threshold / 2).length;

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="md"
      fullWidth
      transitionDuration={220}
      PaperProps={{
        sx: {
          borderRadius: 3.5,
          maxHeight: '88vh',
          bgcolor: 'background.default',
          overflow: 'hidden',
        },
      }}
    >
      <Box
        sx={{
          px: { xs: 2.25, sm: 3 },
          py: 2.25,
          background: `linear-gradient(135deg, ${alpha(theme.palette.error.main, 0.1)}, ${alpha(primary, 0.06)})`,
          borderBottom: `1px solid ${alpha(theme.palette.divider, 0.8)}`,
        }}
      >
        <Stack direction="row" alignItems="flex-start" justifyContent="space-between" spacing={2}>
          <Stack direction="row" spacing={1.5} alignItems="center">
            <Box
              sx={{
                width: 46,
                height: 46,
                flexShrink: 0,
                borderRadius: 2.5,
                display: 'grid',
                placeItems: 'center',
                bgcolor: alpha(theme.palette.error.main, 0.12),
                color: 'error.main',
              }}
            >
              <WarningAmberRoundedIcon sx={{ fontSize: 26 }} />
            </Box>
            <Box>
              <Typography variant="h6" fontWeight={800} sx={{ lineHeight: 1.25, fontSize: '1.15rem' }}>
                Nhân viên công thấp trong tháng
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
                Tháng {month}/{year} · dưới {formatWorkUnits(threshold)} công
              </Typography>
            </Box>
          </Stack>
          <IconButton
            onClick={onClose}
            aria-label="Đóng"
            sx={{ border: 1, borderColor: 'divider', bgcolor: 'background.paper', color: 'text.secondary' }}
          >
            <CloseIcon />
          </IconButton>
        </Stack>
      </Box>

      <DialogContent sx={{ p: { xs: 1.75, sm: 2.5 }, display: 'flex', flexDirection: 'column', gap: 1.75 }}>
        <Paper
          elevation={0}
          sx={{ px: 2, py: 1.5, borderRadius: 2.5, border: 1, borderColor: 'divider', bgcolor: 'background.paper' }}
        >
          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.25} alignItems={{ sm: 'center' }} useFlexGap flexWrap="wrap">
            {!deptFilterLocked && (
              <FormControl size="small" sx={{ minWidth: { xs: '100%', sm: 200 } }}>
                <InputLabel id="low-att-dept">Khoa / phòng</InputLabel>
                <Select
                  labelId="low-att-dept"
                  label="Khoa / phòng"
                  value={scopeDept === '' ? '' : String(scopeDept)}
                  onChange={(e) => {
                    const v = e.target.value;
                    setScopeDept(v === '' ? '' : Number(v));
                  }}
                  sx={{ bgcolor: 'background.paper', fontWeight: 600 }}
                >
                  <MenuItem value="">Toàn bệnh viện</MenuItem>
                  {availableDepartments.map((d) => (
                    <MenuItem key={d.id} value={String(d.id)}>
                      {d.name}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            )}

            <FormControl size="small" sx={{ minWidth: { xs: '100%', sm: 168 } }}>
              <InputLabel id="low-att-threshold">Ngưỡng công</InputLabel>
              <Select
                labelId="low-att-threshold"
                label="Ngưỡng công"
                value={String(threshold)}
                onChange={(e) => setThreshold(Number(e.target.value))}
                sx={{ bgcolor: 'background.paper', fontWeight: 600 }}
              >
                {THRESHOLD_OPTIONS.map((t) => (
                  <MenuItem key={t} value={String(t)}>
                    Dưới {t} công
                  </MenuItem>
                ))}
              </Select>
            </FormControl>

            <TextField
              size="small"
              placeholder="Tìm theo tên hoặc mã nhân viên…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              sx={{ flex: 1, minWidth: { xs: '100%', sm: 220 } }}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <SearchIcon fontSize="small" sx={{ color: search ? 'primary.main' : 'text.disabled' }} />
                  </InputAdornment>
                ),
              }}
            />

            <Tooltip title="Tải lại dữ liệu">
              <span>
                <IconButton
                  onClick={() => void load()}
                  disabled={loading}
                  sx={{ border: 1, borderColor: 'divider', bgcolor: 'background.paper', color: 'primary.main' }}
                >
                  {loading ? <CircularProgress size={20} color="inherit" /> : <RefreshIcon />}
                </IconButton>
              </span>
            </Tooltip>

            <Tooltip title="Xuất Excel — nhóm theo khoa/phòng, sắp xếp công tăng dần trong từng khoa">
              <span>
                <Button
                  variant="contained"
                  color="error"
                  size="small"
                  startIcon={exporting ? <CircularProgress size={16} color="inherit" /> : <FileDownloadOutlinedIcon />}
                  onClick={() => void handleExport()}
                  disabled={exporting || needsData || loading}
                  sx={{ borderRadius: 1.75, textTransform: 'none', fontWeight: 700, boxShadow: 'none', whiteSpace: 'nowrap' }}
                >
                  {exporting ? 'Đang xuất…' : 'Xuất Excel'}
                </Button>
              </span>
            </Tooltip>
          </Stack>
        </Paper>

        {error && (
          <Alert severity="error" onClose={() => setError(null)} sx={{ borderRadius: 2 }}>
            {error}
          </Alert>
        )}

        {!needsData && !loading && (
          <Stack direction="row" spacing={1.25} flexWrap="wrap" useFlexGap>
            <SummaryPill
              label="Dưới ngưỡng"
              value={`${lowRows.length} / ${allRows.length}`}
              color={lowRows.length > 0 ? theme.palette.error.main : theme.palette.success.main}
            />
            {criticalCount > 0 && (
              <SummaryPill
                label={`Dưới ${formatWorkUnits(threshold / 2)} công`}
                value={String(criticalCount)}
                color={theme.palette.error.dark}
              />
            )}
          </Stack>
        )}

        <Box sx={{ flex: 1, minHeight: 0, overflowY: 'auto', pr: 0.5 }}>
          {needsData ? (
            <EmptyState text="Chọn khoa/phòng để tải dữ liệu" icon={<SearchIcon sx={{ fontSize: 26 }} />} />
          ) : loading ? (
            <EmptyState text="Đang tải dữ liệu…" loading />
          ) : filteredRows.length === 0 ? (
            <EmptyState
              text={
                search.trim()
                  ? 'Không tìm thấy nhân viên phù hợp'
                  : `Không có nhân viên nào dưới ${formatWorkUnits(threshold)} công trong tháng này`
              }
              positive={!search.trim()}
            />
          ) : (
            <Stack spacing={1.1}>
              {filteredRows.map((row, index) => {
                const units = Number(row.totalWorkUnits ?? 0);
                const critical = units < threshold / 2;
                const tone = critical ? theme.palette.error.main : theme.palette.warning.dark;
                return (
                  <Paper
                    key={row.employeeId}
                    elevation={0}
                    sx={{
                      px: 1.75,
                      py: 1.4,
                      borderRadius: 2.5,
                      border: 1,
                      borderColor: alpha(tone, 0.22),
                      bgcolor: alpha(tone, 0.035),
                      display: 'flex',
                      alignItems: 'center',
                      gap: 1.5,
                      transition: 'box-shadow 150ms ease, border-color 150ms ease',
                      '&:hover': { boxShadow: `0 4px 16px ${alpha(theme.palette.common.black, 0.06)}`, borderColor: alpha(tone, 0.4) },
                    }}
                  >
                    <Typography
                      variant="caption"
                      sx={{
                        width: 24,
                        flexShrink: 0,
                        textAlign: 'center',
                        fontWeight: 800,
                        color: 'text.disabled',
                        fontVariantNumeric: 'tabular-nums',
                      }}
                    >
                      {index + 1}
                    </Typography>
                    <Avatar sx={{ width: 42, height: 42, fontSize: 13, fontWeight: 700, flexShrink: 0, bgcolor: alpha(primary, 0.12), color: 'primary.dark' }}>
                      {initials(row.fullName)}
                    </Avatar>
                    <Box sx={{ minWidth: 0, flex: 1 }}>
                      <Stack direction="row" spacing={0.75} alignItems="center" flexWrap="wrap" useFlexGap>
                        <Typography variant="body2" fontWeight={700} noWrap title={row.fullName} sx={{ maxWidth: 260 }}>
                          {row.fullName}
                        </Typography>
                        {row.employeeStatus && <EmployeeStatusChip status={row.employeeStatus} />}
                      </Stack>
                      <Typography variant="caption" color="text.secondary" noWrap sx={{ display: 'block', mt: 0.25 }}>
                        {[row.employeeCode, row.department, row.position].filter(Boolean).join(' · ') || '—'}
                      </Typography>
                    </Box>
                    <Stack alignItems="flex-end" spacing={0.15} sx={{ flexShrink: 0 }}>
                      <Chip
                        label={`${formatWorkUnits(units)} công`}
                        size="small"
                        sx={{
                          height: 26,
                          fontWeight: 800,
                          fontSize: 13,
                          bgcolor: alpha(tone, 0.14),
                          color: tone,
                          fontVariantNumeric: 'tabular-nums',
                        }}
                      />
                    </Stack>
                    <Tooltip title="Xem chi tiết bảng công">
                      <IconButton
                        size="small"
                        onClick={() => onViewEmployee(row.employeeId, row.departmentId)}
                        sx={{ flexShrink: 0, color: 'primary.main' }}
                      >
                        <OpenInNewOutlinedIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                  </Paper>
                );
              })}
            </Stack>
          )}
        </Box>

        <Divider sx={{ mt: 0.5 }} />
        <Stack direction="row" justifyContent="space-between" alignItems="center">
          <Typography variant="caption" color="text.secondary">
            Dữ liệu tổng hợp từ bảng công đã chấm + trực trong tháng.
          </Typography>
          <Button onClick={onClose} sx={{ borderRadius: 2, textTransform: 'none', fontWeight: 700 }}>
            Đóng
          </Button>
        </Stack>
      </DialogContent>
    </Dialog>
  );
}

function SummaryPill({ label, value, color }: { label: string; value: string; color: string }) {
  return (
    <Box
      sx={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 0.75,
        pl: 1.25,
        pr: 1.5,
        py: 0.6,
        borderRadius: 999,
        bgcolor: alpha(color, 0.1),
        border: `1px solid ${alpha(color, 0.28)}`,
      }}
    >
      <Box sx={{ width: 7, height: 7, borderRadius: '50%', bgcolor: color, flexShrink: 0 }} />
      <Typography variant="caption" sx={{ color, fontWeight: 700 }}>
        {label}
      </Typography>
      <Typography variant="body2" sx={{ color, fontWeight: 800, fontVariantNumeric: 'tabular-nums' }}>
        {value}
      </Typography>
    </Box>
  );
}

function EmptyState({
  text,
  loading,
  positive,
  icon,
}: {
  text: string;
  loading?: boolean;
  positive?: boolean;
  icon?: React.ReactNode;
}) {
  const theme = useTheme();
  const primary = theme.palette.primary.main;
  const tone = positive ? theme.palette.success.main : primary;

  return (
    <Paper
      elevation={0}
      sx={{
        display: 'grid',
        placeItems: 'center',
        borderRadius: 2.5,
        border: 1,
        borderColor: 'divider',
        minHeight: 220,
        bgcolor: 'background.paper',
      }}
    >
      <Stack spacing={1.5} alignItems="center" sx={{ px: 3, textAlign: 'center' }}>
        {loading ? (
          <CircularProgress size={32} thickness={3.5} />
        ) : (
          <Box sx={{ width: 52, height: 52, borderRadius: 3, display: 'grid', placeItems: 'center', bgcolor: alpha(tone, 0.1), color: tone }}>
            {positive ? <TaskAltRoundedIcon sx={{ fontSize: 26 }} /> : icon ?? <WarningAmberRoundedIcon sx={{ fontSize: 26 }} />}
          </Box>
        )}
        <Typography color="text.secondary" fontWeight={500}>
          {text}
        </Typography>
      </Stack>
    </Paper>
  );
}
