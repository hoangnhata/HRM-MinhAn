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
  FormControlLabel,
  LinearProgress,
  Stack,
  Switch,
  Typography,
} from '@mui/material';
import axios from 'axios';
import { useEffect, useState } from 'react';
import * as importService from '../services/importService';
import { DatePickerField, TimePickerField } from './ui/DateTimeFields';

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
  const range = r.fromDate ? ` (từ ${r.fromDate})` : ' (7 ngày gần nhất)';
  return `${r.rawPunches} lượt quẹt → ${r.upserted} ngày công${range}${unmapped}`;
}

function formatDateTime(iso?: string | null) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString('vi-VN', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit', year: 'numeric' });
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
  const [scheduleLoading, setScheduleLoading] = useState(false);
  const [scheduleSaving, setScheduleSaving] = useState(false);
  const [autoSyncEnabled, setAutoSyncEnabled] = useState(true);
  const [syncTime, setSyncTime] = useState('01:30');
  const [lastAutoSyncAt, setLastAutoSyncAt] = useState<string | null>(null);
  const [scheduleMsg, setScheduleMsg] = useState<string | null>(null);
  const [result, setResult] = useState<importService.ImportCheckInOutResult | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!open) {
      setResult(null);
      setErr(null);
      setScheduleMsg(null);
      setLoading(false);
      return;
    }
    setFromDate(defaultFromDate ?? '');
    setScheduleLoading(true);
    importService
      .fetchCheckInOutSyncStatus()
      .then((s) => {
        setAutoSyncEnabled(s.autoSyncEnabled ?? true);
        setSyncTime(s.autoSyncTime ?? '01:30');
        setLastAutoSyncAt(s.lastAutoSyncAt ?? null);
      })
      .catch(() => {
        setScheduleMsg('Không tải được cấu hình hẹn giờ.');
      })
      .finally(() => setScheduleLoading(false));
  }, [open, defaultFromDate]);

  async function runSync(fromDateParam?: string) {
    setErr(null);
    setResult(null);
    setLoading(true);
    try {
      const r = await importService.syncCheckInOut(fromDateParam);
      setResult(r);
      onSynced?.(`Đồng bộ máy chấm công: ${formatResult(r)}`);
    } catch (e) {
      setErr(syncErrorMessage(e));
    } finally {
      setLoading(false);
    }
  }

  async function onSyncRecent() {
    await runSync();
  }

  async function onSyncFromDate(e: React.FormEvent) {
    e.preventDefault();
    if (!fromDate) {
      setErr('Chọn ngày bắt đầu đồng bộ.');
      return;
    }
    await runSync(fromDate);
  }

  async function saveSchedule() {
    if (!syncTime) {
      setScheduleMsg('Chọn giờ tự động đồng bộ.');
      return;
    }
    setScheduleSaving(true);
    setScheduleMsg(null);
    try {
      const s = await importService.updateCheckInOutSyncSchedule({
        autoSyncEnabled,
        syncTime,
      });
      setAutoSyncEnabled(s.autoSyncEnabled ?? autoSyncEnabled);
      setSyncTime(s.autoSyncTime ?? syncTime);
      setLastAutoSyncAt(s.lastAutoSyncAt ?? null);
      setScheduleMsg(
        autoSyncEnabled
          ? `Đã lưu — tự động đồng bộ lúc ${s.autoSyncTime ?? syncTime} hàng ngày.`
          : 'Đã tắt tự động đồng bộ.',
      );
    } catch (e) {
      setScheduleMsg(syncErrorMessage(e));
    } finally {
      setScheduleSaving(false);
    }
  }

  return (
    <Dialog open={open} onClose={loading ? undefined : onClose} maxWidth="sm" fullWidth>
      <DialogTitle>Đồng bộ máy chấm công</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Lấy dữ liệu trực tiếp từ SQL Server <strong>chamcong.dbo.CheckInOut</strong>. Mã quẹt thẻ (
          <em>UserEnrollNumber</em>) phải trùng <strong>mã chấm công</strong> của nhân viên.
        </Typography>

        {loading && <LinearProgress sx={{ mb: 2 }} />}

        {err && (
          <Alert severity="error" sx={{ mb: 2 }}>
            {err}
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

        <Stack spacing={2}>
          <Box>
            <Typography variant="subtitle2" fontWeight={700} gutterBottom>
              Hẹn giờ tự động
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
              Đến giờ đã chọn, hệ thống tự đồng bộ <strong>7 ngày gần nhất</strong> (backend phải đang chạy).
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
                      disabled={scheduleSaving || loading}
                    />
                  }
                  label="Bật tự động đồng bộ hàng ngày"
                />
                <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} alignItems={{ sm: 'flex-start' }}>
                  <TimePickerField
                    label="Giờ đồng bộ"
                    value={syncTime}
                    onChange={setSyncTime}
                    disabled={!autoSyncEnabled || scheduleSaving || loading}
                    minuteStep={1}
                    sx={{ minWidth: 160 }}
                  />
                  <Button
                    variant="outlined"
                    startIcon={<ScheduleIcon />}
                    onClick={saveSchedule}
                    disabled={scheduleSaving || loading}
                    sx={{ mt: { xs: 0, sm: 0.5 }, whiteSpace: 'nowrap' }}
                  >
                    {scheduleSaving ? 'Đang lưu…' : 'Lưu hẹn giờ'}
                  </Button>
                </Stack>
                <Typography variant="caption" color="text.secondary">
                  Lần tự động gần nhất: {formatDateTime(lastAutoSyncAt)}
                </Typography>
                {scheduleMsg && (
                  <Alert severity={scheduleMsg.startsWith('Đã') ? 'success' : 'info'} sx={{ py: 0.5 }}>
                    {scheduleMsg}
                  </Alert>
                )}
              </Stack>
            )}
          </Box>

          <Divider />

          <Box>
            <Typography variant="subtitle2" fontWeight={700} gutterBottom>
              Nhanh — 7 ngày gần nhất
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
              Dùng hàng ngày; đủ cho cập nhật mới và chỉnh sửa trễ gần đây.
            </Typography>
            <Button
              variant="contained"
              startIcon={<CloudSyncIcon />}
              disabled={loading}
              onClick={onSyncRecent}
            >
              Đồng bộ 7 ngày
            </Button>
          </Box>

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
                disabled={loading}
                sx={{ minWidth: 200, flex: 1 }}
              />
              <Button
                type="submit"
                variant="outlined"
                startIcon={<CloudSyncIcon />}
                disabled={loading || !fromDate}
                sx={{ mt: { xs: 0, sm: 0.5 }, whiteSpace: 'nowrap' }}
              >
                Đồng bộ từ ngày
              </Button>
            </Stack>
          </Box>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={loading}>
          Đóng
        </Button>
      </DialogActions>
    </Dialog>
  );
}
