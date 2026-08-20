import BadgeIcon from '@mui/icons-material/Badge';
import CloudSyncIcon from '@mui/icons-material/CloudSync';
import ScheduleIcon from '@mui/icons-material/Schedule';
import {
  Alert,
  Box,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  FormControl,
  FormControlLabel,
  InputLabel,
  LinearProgress,
  MenuItem,
  Select,
  Stack,
  Switch,
  Typography,
} from '@mui/material';
import axios from 'axios';
import { useEffect, useState } from 'react';
import * as importService from '../services/importService';
import * as attendanceService from '../services/attendanceService';
import { formatDateTimeVi, formatDateVi } from '../utils/dateFormat';
import { DatePickerField } from './ui/DateTimeFields';

const INTERVAL_OPTIONS = [
  { value: 1, label: 'Mỗi 1 phút' },
  { value: 2, label: 'Mỗi 2 phút' },
  { value: 5, label: 'Mỗi 5 phút' },
];

function syncErrorMessage(err: unknown): string {
  if (axios.isAxiosError(err)) {
    const msg = (err.response?.data as { message?: string } | undefined)?.message;
    if (msg) return msg;
    if (err.code === 'ECONNABORTED') {
      return 'Đồng bộ quá thời gian chờ — dữ liệu nhiều có thể cần vài phút, thử lại.';
    }
  }
  return 'Đồng bộ thất bại. Kiểm tra kết nối SQL Server máy chấm công.';
}

function formatResult(r: importService.ImportCheckInOutResult) {
  const unmapped =
    r.unmappedEnrollCount > 0 ? ` · ${r.unmappedEnrollCount} mã chưa khớp NV` : '';
  const range = r.fromDate ? ` (từ ${formatDateVi(r.fromDate)})` : ' (7 ngày gần nhất)';
  const reapplied =
    r.reappliedApprovedRequests != null && r.reappliedApprovedRequests > 0
      ? ` · đã áp lại ${r.reappliedApprovedRequests} đơn công`
      : '';
  const protectedDays =
    r.skippedProtectedDays != null && r.skippedProtectedDays > 0
      ? ` · giữ ${r.skippedProtectedDays} ngày nghỉ/công tác`
      : '';
  return `${r.rawPunches} lượt quẹt → ${r.upserted} ngày công${range}${reapplied}${protectedDays}${unmapped}`;
}

function formatDateTime(iso?: string | null) {
  return formatDateTimeVi(iso);
}

type Props = {
  open: boolean;
  onClose: () => void;
  onSynced?: (message: string) => void;
  defaultFromDate?: string;
};

export function CheckInOutSyncDialog({ open, onClose, onSynced, defaultFromDate }: Props) {
  const [fromDate, setFromDate] = useState('');
  const [loading, setLoading] = useState(false);
  const [codeSyncLoading, setCodeSyncLoading] = useState(false);
  const [scheduleLoading, setScheduleLoading] = useState(false);
  const [scheduleSaving, setScheduleSaving] = useState(false);
  const [autoSyncEnabled, setAutoSyncEnabled] = useState(true);
  const [intervalMinutes, setIntervalMinutes] = useState(1);
  const [lastAutoSyncAt, setLastAutoSyncAt] = useState<string | null>(null);
  const [scheduleMsg, setScheduleMsg] = useState<string | null>(null);
  const [result, setResult] = useState<importService.ImportCheckInOutResult | null>(null);
  const [codeResult, setCodeResult] = useState<importService.AttendanceCodeSyncResult | null>(null);
  const [restoreMsg, setRestoreMsg] = useState<string | null>(null);
  const [restoreLoading, setRestoreLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) {
      setResult(null);
      setCodeResult(null);
      setErr(null);
      setScheduleMsg(null);
      setRestoreMsg(null);
      setLoading(false);
      setCodeSyncLoading(false);
      setRestoreLoading(false);
      return;
    }
    setFromDate(defaultFromDate ?? '');
    setScheduleLoading(true);
    importService
      .fetchCheckInOutSyncStatus()
      .then((s) => {
        setAutoSyncEnabled(s.autoSyncEnabled ?? true);
        setIntervalMinutes(s.autoSyncIntervalMinutes ?? 1);
        setLastAutoSyncAt(s.lastAutoSyncAt ?? null);
      })
      .catch(() => {
        setScheduleMsg('Không tải được cấu hình đồng bộ.');
      })
      .finally(() => setScheduleLoading(false));
  }, [open, defaultFromDate]);

  async function runSync(fromDateParam?: string) {
    setErr(null);
    setResult(null);
    setCodeResult(null);
    setLoading(true);
    try {
      const r = await importService.syncCheckInOut(fromDateParam);
      setResult(r);
      onSynced?.(formatResult(r));
    } catch (e) {
      setErr(syncErrorMessage(e));
    } finally {
      setLoading(false);
    }
  }

  async function onSyncFromDate(e: React.FormEvent) {
    e.preventDefault();
    if (!fromDate) {
      setErr('Chọn ngày bắt đầu đồng bộ.');
      return;
    }
    await runSync(fromDate);
  }

  async function syncAttendanceCodes() {
    setErr(null);
    setResult(null);
    setCodeResult(null);
    setCodeSyncLoading(true);
    try {
      const r = await importService.syncAttendanceCodesFromDevice();
      setCodeResult(r);
      onSynced?.(
        `Đã gán mã chấm công cho ${r.updated}/${r.missingBefore} NV còn thiếu (từ ${r.deviceUsers} người trên máy).`,
      );
    } catch (e) {
      setErr(syncErrorMessage(e));
    } finally {
      setCodeSyncLoading(false);
    }
  }

  async function restoreApprovedEffects() {
    setErr(null);
    setRestoreMsg(null);
    setRestoreLoading(true);
    try {
      const from = fromDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
      const r = await attendanceService.reapplyApprovedAttendanceEffects(from);
      const msg = `Đã khôi phục hiệu lực ${r.reapplied} đơn công đã duyệt (từ ${formatDateVi(r.from)} đến ${formatDateVi(r.to)}).`;
      setRestoreMsg(msg);
      onSynced?.(msg);
    } catch (e) {
      setErr(syncErrorMessage(e));
    } finally {
      setRestoreLoading(false);
    }
  }

  async function saveSchedule() {
    setScheduleMsg(null);
    setScheduleSaving(true);
    try {
      const s = await importService.updateCheckInOutSyncSchedule({
        autoSyncEnabled,
        intervalMinutes,
      });
      setLastAutoSyncAt(s.lastAutoSyncAt ?? null);
      setScheduleMsg(
        autoSyncEnabled
          ? `Đã bật tự động đồng bộ (${intervalMinutes} phút/lần).`
          : 'Đã tắt tự động đồng bộ.',
      );
    } catch (e) {
      setScheduleMsg(syncErrorMessage(e));
    } finally {
      setScheduleSaving(false);
    }
  }

  const busy = loading || codeSyncLoading || restoreLoading;

  return (
    <Dialog open={open} onClose={busy ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Đồng bộ máy chấm công</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Kết nối SQL Server <strong>chamcong</strong> (192.168.31.101). Mã quẹt thẻ (
          <em>UserEnrollNumber</em>) phải trùng <strong>mã chấm công</strong> của nhân viên.
        </Typography>

        {(loading || codeSyncLoading || scheduleLoading || restoreLoading) && <LinearProgress sx={{ mb: 2 }} />}

        {err && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {err}
          </Alert>
        )}

        {restoreMsg && (
          <Alert severity="success" sx={{ mb: 2 }}>
            {restoreMsg}
          </Alert>
        )}

        {result && (
          <Alert severity="success" sx={{ mb: 2 }}>
            {formatResult(result)}
            {result.unmappedEnrollNumbers.length > 0 && (
              <Typography variant="caption" display="block" sx={{ mt: 0.5 }}>
                Mã chưa khớp (tối đa 50): {result.unmappedEnrollNumbers.join(', ')}
              </Typography>
            )}
          </Alert>
        )}

        {codeResult && (
          <Alert severity={codeResult.updated > 0 ? 'success' : 'info'} sx={{ mb: 2 }}>
            <Typography variant="body2" fontWeight={700}>
              Mã chấm công: đã gán {codeResult.updated}/{codeResult.missingBefore} NV còn thiếu
            </Typography>
            <Typography variant="caption" display="block">
              Máy có {codeResult.deviceUsers} người · không khớp tên {codeResult.skippedNoMatch} · trùng tên{' '}
              {codeResult.skippedAmbiguous} · mã đã dùng {codeResult.skippedConflict}
            </Typography>
            {codeResult.samples.length > 0 && (
              <Typography variant="caption" display="block" sx={{ mt: 0.75 }}>
                Ví dụ: {codeResult.samples.slice(0, 5).map((s) => `${s.fullName}=${s.attendanceCode}`).join('; ')}
              </Typography>
            )}
            {codeResult.unmatched.length > 0 && (
              <Typography variant="caption" display="block" sx={{ mt: 0.5 }} color="text.secondary">
                Chưa khớp (một phần): {codeResult.unmatched.slice(0, 8).map((u) => u.fullName).join(', ')}
                {codeResult.unmatched.length > 8 ? '…' : ''}
              </Typography>
            )}
          </Alert>
        )}

        <Stack spacing={2}>
          <Box>
            <Typography variant="subtitle2" fontWeight={700} gutterBottom>
              Đồng bộ mã chấm công (UserInfo)
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
              Lấy <em>UserEnrollNumber</em> từ <strong>dbo.UserInfo</strong>, khớp theo họ tên (và ngày sinh nếu trùng
              tên) rồi gán cho NV HRM <strong>chưa có mã</strong>. Không ghi đè mã đã có.
            </Typography>
            <Button
              variant="contained"
              color="secondary"
              startIcon={<BadgeIcon />}
              onClick={() => void syncAttendanceCodes()}
              disabled={busy || scheduleSaving}
            >
              {codeSyncLoading ? 'Đang gán mã…' : 'Đồng bộ mã chấm công còn thiếu'}
            </Button>
          </Box>

          <Divider />

          <Box>
            <Typography variant="subtitle2" fontWeight={700} gutterBottom>
              Tự động đồng bộ liên tục
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
              Khi bật, hệ thống tự kéo dữ liệu mới từ máy chấm theo chu kỳ (không cần chờ giờ cố định trong ngày).
              Màn bảng công cũng tự làm mới khi đang mở.
            </Typography>
            {scheduleLoading ? (
              <LinearProgress sx={{ mb: 1 }} />
            ) : (
              <Stack spacing={1.5}>
                <FormControlLabel
                  control={
                    <Switch
                      checked={autoSyncEnabled}
                      onChange={(e) => setAutoSyncEnabled(e.target.checked)}
                      disabled={scheduleSaving || busy}
                    />
                  }
                  label="Bật tự động đồng bộ"
                />
                <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ sm: 'flex-start' }}>
                  <FormControl size="small" sx={{ minWidth: 180 }} disabled={!autoSyncEnabled || scheduleSaving || busy}>
                    <InputLabel id="chamcong-interval-label">Chu kỳ</InputLabel>
                    <Select
                      labelId="chamcong-interval-label"
                      label="Chu kỳ"
                      value={intervalMinutes}
                      onChange={(e) => setIntervalMinutes(Number(e.target.value))}
                    >
                      {INTERVAL_OPTIONS.map((o) => (
                        <MenuItem key={o.value} value={o.value}>
                          {o.label}
                        </MenuItem>
                      ))}
                    </Select>
                  </FormControl>
                  <Button
                    variant="outlined"
                    startIcon={<ScheduleIcon />}
                    onClick={() => void saveSchedule()}
                    disabled={scheduleSaving || busy}
                  >
                    Lưu lịch
                  </Button>
                </Stack>
                {scheduleMsg && (
                  <Typography variant="body2" color="text.secondary">
                    {scheduleMsg}
                    {lastAutoSyncAt ? ` · Lần gần nhất: ${formatDateTime(lastAutoSyncAt)}` : ''}
                  </Typography>
                )}
              </Stack>
            )}
          </Box>

          <Divider />

          <Box>
            <Typography variant="subtitle2" fontWeight={700} gutterBottom>
              Đồng bộ dữ liệu quẹt thẻ
            </Typography>
            <Button
              variant="contained"
              startIcon={<CloudSyncIcon />}
              onClick={() => void runSync()}
              disabled={busy || scheduleSaving}
              sx={{ mb: 2 }}
            >
              Đồng bộ 7 ngày
            </Button>

            <Box component="form" onSubmit={onSyncFromDate}>
              <Typography variant="subtitle2" fontWeight={700} gutterBottom>
                Đồng bộ từ ngày
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
                Kéo dữ liệu lịch sử từ ngày chọn đến hôm nay (lần đầu hoặc bù tháng cũ).
              </Typography>
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ sm: 'flex-start' }}>
                <DatePickerField
                  label="Từ ngày"
                  required
                  value={fromDate}
                  onChange={setFromDate}
                  disabled={busy}
                  sx={{ minWidth: 200, flex: 1 }}
                />
                <Button
                  type="submit"
                  variant="outlined"
                  startIcon={<CloudSyncIcon />}
                  disabled={busy || !fromDate}
                  sx={{ mt: { xs: 0, sm: 0.5 }, whiteSpace: 'nowrap' }}
                >
                  Đồng bộ từ ngày
                </Button>
              </Stack>
            </Box>
          </Box>

          <Divider />

          <Box>
            <Typography variant="subtitle2" fontWeight={700} gutterBottom>
              Khôi phục đơn công đã duyệt
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
              Nếu đồng bộ trước đó làm mất hiệu lực giải trình / cập nhật công / nghỉ trên bảng công, bấm
              khôi phục (đơn vẫn còn trong hệ thống — chỉ áp lại lên bảng công). Dùng &quot;Từ ngày&quot; ở
              trên nếu có chọn; không thì lấy 30 ngày gần nhất.
            </Typography>
            <Button
              variant="outlined"
              color="warning"
              onClick={() => void restoreApprovedEffects()}
              disabled={busy || scheduleSaving}
            >
              {restoreLoading ? 'Đang khôi phục…' : 'Khôi phục hiệu lực đơn đã duyệt'}
            </Button>
          </Box>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={busy}>
          Đóng
        </Button>
      </DialogActions>
    </Dialog>
  );
}
