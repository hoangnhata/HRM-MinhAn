import ChildCareIcon from '@mui/icons-material/ChildCare';
import HistoryIcon from '@mui/icons-material/History';
import InboxOutlinedIcon from '@mui/icons-material/InboxOutlined';
import PendingActionsIcon from '@mui/icons-material/PendingActions';
import CheckIcon from '@mui/icons-material/Check';
import CloseIcon from '@mui/icons-material/Close';
import {
  Alert,
  Badge,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Grid,
  Paper,
  Stack,
  Tab,
  Tabs,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as ycs from '../services/youngChildRequestService';

export function YoungChildRequestPendingPanel({ onChanged }: { onChanged?: () => void }) {
  const theme = useTheme();
  const { user } = useAuth();
  const canReview = user?.role === 'ADMIN' || user?.role === 'HR';
  const isHead =
    user?.role === 'HEAD_DEPARTMENT' || user?.role === 'HEAD_NURSING' || user?.role === 'ADMIN';

  const [pending, setPending] = useState<ycs.YoungChildRequest[]>([]);
  const [history, setHistory] = useState<ycs.YoungChildRequest[]>([]);
  const [mine, setMine] = useState<ycs.YoungChildRequest[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [detail, setDetail] = useState<ycs.YoungChildRequest | null>(null);
  const [comment, setComment] = useState('');
  const [acting, setActing] = useState(false);

  const reload = useCallback(() => {
    setLoading(true);
    const tasks: Promise<unknown>[] = [];
    if (canReview) {
      tasks.push(ycs.fetchPendingYoungChildRequests().then(setPending).catch(() => setPending([])));
      tasks.push(ycs.fetchYoungChildRequestHistory().then(setHistory).catch(() => setHistory([])));
    }
    if (isHead) {
      tasks.push(ycs.fetchMyYoungChildRequests().then(setMine).catch(() => setMine([])));
    }
    Promise.all(tasks)
      .then(() => setErr(null))
      .catch(() => setErr('Không tải được đề xuất nuôi con nhỏ.'))
      .finally(() => setLoading(false));
  }, [canReview, isHead]);

  useEffect(() => {
    reload();
  }, [reload]);

  const tabs: { key: string; label: string; list: ycs.YoungChildRequest[] }[] = [];
  if (canReview) {
    tabs.push({ key: 'pending', label: 'Chờ duyệt', list: pending });
    tabs.push({ key: 'history', label: 'Lịch sử', list: history });
  }
  if (isHead) {
    tabs.push({ key: 'mine', label: 'Đề xuất của tôi', list: mine });
  }
  const active = tabs[Math.min(subTab, Math.max(tabs.length - 1, 0))];
  const list = active?.list ?? [];

  async function review(approved: boolean) {
    if (!detail) return;
    setActing(true);
    try {
      await ycs.hrReviewYoungChildRequest(detail.id, approved, comment);
      setDetail(null);
      setComment('');
      reload();
      onChanged?.();
    } catch {
      setErr(approved ? 'Duyệt thất bại.' : 'Từ chối thất bại.');
    } finally {
      setActing(false);
    }
  }

  if (loading && list.length === 0) {
    return (
      <Box sx={{ py: 4, textAlign: 'center' }}>
        <CircularProgress size={28} />
      </Box>
    );
  }

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Trưởng khoa / Điều dưỡng trưởng đề xuất bật hoặc tắt chế độ nuôi con nhỏ theo tháng; HCNS duyệt thì hệ
        thống áp dụng (−1 giờ/ngày, tối thiểu 7h = 1 công).
      </Typography>
      {err && (
        <Alert severity="error" onClose={() => setErr(null)}>
          {err}
        </Alert>
      )}

      <Box
        sx={{
          display: 'inline-flex',
          p: 0.5,
          borderRadius: 2.5,
          bgcolor: alpha(theme.palette.grey[500], 0.06),
          border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
          width: 'fit-content',
        }}
      >
        <Tabs
          value={Math.min(subTab, Math.max(tabs.length - 1, 0))}
          onChange={(_, v) => setSubTab(v)}
          sx={{
            minHeight: 40,
            '& .MuiTabs-indicator': { display: 'none' },
            '& .MuiTab-root': {
              minHeight: 40,
              textTransform: 'none',
              fontWeight: 600,
              borderRadius: 2,
              px: 1.75,
              mr: 0.5,
              '&.Mui-selected': {
                bgcolor: theme.palette.primary.main,
                color: theme.palette.primary.contrastText,
              },
            },
          }}
        >
          {tabs.map((t) => (
            <Tab
              key={t.key}
              icon={
                t.key === 'history' ? (
                  <HistoryIcon fontSize="small" />
                ) : (
                  <Badge badgeContent={t.list.length} color="warning" max={99}>
                    <PendingActionsIcon fontSize="small" />
                  </Badge>
                )
              }
              iconPosition="start"
              label={t.key === 'history' ? `Lịch sử (${t.list.length})` : t.label}
            />
          ))}
        </Tabs>
      </Box>

      {list.length === 0 ? (
        <Box
          sx={{
            py: 5,
            textAlign: 'center',
            borderRadius: 3,
            border: `1px dashed ${alpha(theme.palette.secondary.main, 0.25)}`,
            bgcolor: alpha(theme.palette.secondary.main, 0.03),
          }}
        >
          <InboxOutlinedIcon sx={{ fontSize: 32, color: 'secondary.main', mb: 1 }} />
          <Typography fontWeight={800}>Không có đề xuất</Typography>
        </Box>
      ) : (
        <Grid container spacing={1.75}>
          {list.map((r) => (
            <Grid item xs={12} md={6} key={r.id}>
              <Paper
                variant="outlined"
                onClick={() => setDetail(r)}
                sx={{
                  p: 1.75,
                  borderRadius: 2.5,
                  cursor: 'pointer',
                  '&:hover': { borderColor: alpha(theme.palette.secondary.main, 0.5) },
                }}
              >
                <Stack direction="row" spacing={1.5} alignItems="flex-start">
                  <ChildCareIcon color="secondary" />
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Stack direction="row" justifyContent="space-between" spacing={1}>
                      <Typography fontWeight={800} noWrap>
                        {r.employeeName}
                      </Typography>
                      <Chip
                        size="small"
                        label={ycs.YOUNG_CHILD_STATUS_LABEL[r.status] || r.status}
                        color={r.status === 'PENDING_HR' ? 'warning' : r.status === 'APPROVED' ? 'success' : 'default'}
                      />
                    </Stack>
                    <Typography variant="caption" color="text.secondary" display="block">
                      {r.enabled ? 'Đề xuất bật' : 'Đề xuất tắt'} · tháng {r.month}/{r.year} ·{' '}
                      {r.departmentName || '—'}
                    </Typography>
                    <Typography variant="body2" noWrap sx={{ mt: 0.75 }}>
                      {r.reason || 'Không có lý do ghi kèm'}
                    </Typography>
                  </Box>
                </Stack>
              </Paper>
            </Grid>
          ))}
        </Grid>
      )}

      <Dialog open={Boolean(detail)} onClose={() => !acting && setDetail(null)} maxWidth="sm" fullWidth>
        <DialogTitle>Đề xuất nuôi con nhỏ</DialogTitle>
        <DialogContent>
          {detail && (
            <Stack spacing={1.5} sx={{ mt: 1 }}>
              <Typography>
                <strong>{detail.employeeName}</strong> · tháng {detail.month}/{detail.year}
              </Typography>
              <Typography variant="body2">
                Nội dung: <strong>{detail.enabled ? 'Bật' : 'Tắt'}</strong> chế độ nuôi con nhỏ
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Người đề xuất: {detail.requestedByUsername || '—'}
              </Typography>
              {detail.reason && (
                <Typography variant="body2">Lý do: {detail.reason}</Typography>
              )}
              {canReview && detail.status === 'PENDING_HR' && (
                <TextField
                  label="Ghi chú duyệt (tuỳ chọn)"
                  fullWidth
                  size="small"
                  multiline
                  minRows={2}
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                />
              )}
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDetail(null)} disabled={acting}>
            Đóng
          </Button>
          {canReview && detail?.status === 'PENDING_HR' && (
            <>
              <Button color="error" startIcon={<CloseIcon />} disabled={acting} onClick={() => review(false)}>
                Từ chối
              </Button>
              <Button
                variant="contained"
                color="secondary"
                startIcon={<CheckIcon />}
                disabled={acting}
                onClick={() => review(true)}
              >
                Duyệt
              </Button>
            </>
          )}
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
