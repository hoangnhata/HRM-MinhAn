import HistoryIcon from '@mui/icons-material/History';
import InboxOutlinedIcon from '@mui/icons-material/InboxOutlined';
import PendingActionsIcon from '@mui/icons-material/PendingActions';
import {
  Alert,
  Badge,
  Box,
  Grid,
  Stack,
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as att from '../services/attendanceService';
import { WorkRequestDetailDialog } from './work/WorkRequestDetailDialog';
import { WorkRequestListCard } from './work/WorkRequestListCard';

type Props = {
  onChanged?: () => void;
  /** Chỉ hiện các loại đơn này (mặc định: tất cả). */
  types?: att.WorkRequest['requestType'][];
  description?: string;
};

export function AttendancePendingPanel({ onChanged, types, description }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const [pendingAll, setPendingAll] = useState<att.WorkRequest[]>([]);
  const [historyAll, setHistoryAll] = useState<att.WorkRequest[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [selected, setSelected] = useState<att.WorkRequest | null>(null);
  const [comment, setComment] = useState('');
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  const isHead = user?.role === 'ADMIN' || user?.role === 'HEAD_DEPARTMENT' || user?.role === 'HEAD_NURSING';
  const isHr = user?.role === 'ADMIN' || user?.role === 'HR';

  const typeSet = useMemo(() => (types && types.length > 0 ? new Set(types) : null), [types]);

  const pending = useMemo(
    () => (typeSet ? pendingAll.filter((r) => typeSet.has(r.requestType)) : pendingAll),
    [pendingAll, typeSet],
  );
  const history = useMemo(
    () => (typeSet ? historyAll.filter((r) => typeSet.has(r.requestType)) : historyAll),
    [historyAll, typeSet],
  );

  const reload = useCallback(() => {
    if (!isHead && !isHr) return;
    Promise.all([
      att.fetchPendingWorkRequests().catch(() => [] as att.WorkRequest[]),
      att.fetchReviewHistoryWorkRequests().catch(() => [] as att.WorkRequest[]),
    ]).then(([p, h]) => {
      setPendingAll(p);
      setHistoryAll(h);
    });
  }, [isHead, isHr]);

  useEffect(() => {
    reload();
  }, [reload]);

  if (!isHead && !isHr) return null;

  function openDetail(r: att.WorkRequest) {
    setSelected(r);
    setComment('');
    setMsg(null);
  }

  function closeDetail() {
    if (loading) return;
    setSelected(null);
    setComment('');
  }

  async function headAct(approved: boolean) {
    if (!selected) return;
    setLoading(true);
    setMsg(null);
    try {
      await att.headReviewRequest(selected.id, approved, comment);
      reload();
      onChanged?.();
      setMsg(approved ? 'Đã chuyển HCNS duyệt.' : 'Đã từ chối đơn.');
      closeDetail();
    } catch {
      setMsg('Thao tác thất bại.');
    } finally {
      setLoading(false);
    }
  }

  async function hrAct(approved: boolean, waiveFine?: boolean) {
    if (!selected) return;
    setLoading(true);
    setMsg(null);
    try {
      await att.hrReviewRequest(selected.id, approved, { comment, waiveForgotFine: waiveFine });
      reload();
      onChanged?.();
      setMsg('Đã xử lý đơn.');
      closeDetail();
    } catch {
      setMsg('Thao tác thất bại.');
    } finally {
      setLoading(false);
    }
  }

  const list = subTab === 0 ? pending : history;

  return (
    <Stack spacing={2}>
      {description && (
        <Typography variant="body2" color="text.secondary">
          {description}
        </Typography>
      )}

      {msg && (
        <Alert severity="info" sx={{ borderRadius: 2 }} onClose={() => setMsg(null)}>
          {msg}
        </Alert>
      )}

      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={1.5}
        alignItems={{ xs: 'stretch', sm: 'center' }}
        justifyContent="space-between"
      >
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
            value={subTab}
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
            <Tab
              icon={
                <Badge badgeContent={pending.length} color="warning" max={99}>
                  <PendingActionsIcon fontSize="small" />
                </Badge>
              }
              iconPosition="start"
              label="Chờ duyệt"
            />
            <Tab
              icon={<HistoryIcon fontSize="small" />}
              iconPosition="start"
              label={`Lịch sử (${history.length})`}
            />
          </Tabs>
        </Box>
        {list.length > 0 && (
          <Typography variant="caption" color="text.secondary" fontWeight={600}>
            {subTab === 0
              ? `${pending.length} đơn chờ — bấm thẻ để xem chi tiết và duyệt`
              : `${history.length} đơn đã xử lý — bấm «Xem chi tiết» để xem nội dung`}
          </Typography>
        )}
      </Stack>

      {list.length === 0 ? (
        <Box
          sx={{
            py: { xs: 5, sm: 6 },
            px: 2,
            textAlign: 'center',
            borderRadius: 3,
            border: `1px dashed ${alpha(theme.palette.primary.main, 0.22)}`,
            bgcolor: alpha(theme.palette.primary.main, 0.025),
          }}
        >
          <Box
            sx={{
              width: 56,
              height: 56,
              mx: 'auto',
              mb: 1.75,
              borderRadius: 2.5,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(theme.palette.primary.main, 0.08),
              color: theme.palette.primary.main,
            }}
          >
            <InboxOutlinedIcon sx={{ fontSize: 28 }} />
          </Box>
          <Typography variant="subtitle1" fontWeight={800} sx={{ mb: 0.5 }}>
            {subTab === 0 ? 'Không có đơn chờ duyệt' : 'Chưa có lịch sử duyệt'}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 400, mx: 'auto', lineHeight: 1.65 }}>
            {subTab === 0
              ? 'Các đơn mới sẽ xuất hiện tại đây để bạn xem chi tiết và duyệt.'
              : 'Các đơn đã duyệt hoặc từ chối sẽ được lưu tại đây.'}
          </Typography>
        </Box>
      ) : (
        <Grid container spacing={1.75}>
          {list.map((r) => (
            <Grid item xs={12} md={6} key={r.id}>
              <WorkRequestListCard request={r} showEmployee onClick={() => openDetail(r)} />
            </Grid>
          ))}
        </Grid>
      )}

      <WorkRequestDetailDialog
        open={selected != null}
        onClose={closeDetail}
        request={selected}
        mode="review"
        review={{
          isHead,
          isHr,
          comment,
          onCommentChange: setComment,
          loading,
          onHeadReview: headAct,
          onHrReview: hrAct,
        }}
      />
    </Stack>
  );
}
