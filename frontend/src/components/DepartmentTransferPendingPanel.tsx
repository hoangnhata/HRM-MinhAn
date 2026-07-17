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
  CircularProgress,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as departmentTransferService from '../services/departmentTransferService';
import { DepartmentTransferDetailDialog } from './DepartmentTransferDetailDialog';
import { DepartmentTransferListCard } from './DepartmentTransferListCard';

export function DepartmentTransferPendingPanel({ onChanged }: { onChanged?: () => void }) {
  const theme = useTheme();
  const { user } = useAuth();
  const canReview = user?.role === 'ADMIN' || user?.role === 'DIRECTOR';

  const [pending, setPending] = useState<departmentTransferService.DepartmentTransfer[]>([]);
  const [history, setHistory] = useState<departmentTransferService.DepartmentTransfer[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [detailId, setDetailId] = useState<number | null>(null);

  const reload = useCallback(() => {
    setLoading(true);
    Promise.all([
      departmentTransferService.fetchPendingTransfers().catch(() => [] as departmentTransferService.DepartmentTransfer[]),
      departmentTransferService.fetchTransferHistory().catch(() => [] as departmentTransferService.DepartmentTransfer[]),
    ])
      .then(([p, h]) => {
        setPending(p);
        setHistory(h);
        setErr(null);
      })
      .catch(() => setErr('Không tải được danh sách luân chuyển.'))
      .finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    reload();
  }, [reload]);

  const list = subTab === 0 ? pending : history;

  if (loading && pending.length === 0 && history.length === 0) {
    return (
      <Box sx={{ py: 4, textAlign: 'center' }}>
        <CircularProgress size={28} />
      </Box>
    );
  }

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Đề nghị luân chuyển do HCNS gửi. Sau khi Giám đốc duyệt, hệ thống chỉ chuyển nhân viên đúng{' '}
        <strong>ngày hiệu lực</strong>. Bấm thẻ để xem chi tiết đơn.
      </Typography>

      {err && (
        <Alert severity="error" onClose={() => setErr(null)}>
          {err}
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
              ? `${pending.length} đơn chờ — bấm thẻ để xem chi tiết${canReview ? ' và duyệt' : ''}`
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
            {subTab === 0 ? 'Không có đơn chờ duyệt' : 'Chưa có lịch sử luân chuyển'}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 420, mx: 'auto' }}>
            {subTab === 0
              ? 'Khi HCNS gửi đề nghị luân chuyển, đơn sẽ xuất hiện tại đây.'
              : 'Các đơn đã duyệt, từ chối, đã chuyển hoặc hủy sẽ lưu tại đây.'}
          </Typography>
        </Box>
      ) : (
        <Grid container spacing={1.75}>
          {list.map((r) => (
            <Grid item xs={12} md={6} key={r.id}>
              <DepartmentTransferListCard transfer={r} onClick={() => setDetailId(r.id)} />
            </Grid>
          ))}
        </Grid>
      )}

      <DepartmentTransferDetailDialog
        open={detailId != null}
        transferId={detailId}
        onClose={() => setDetailId(null)}
        canReview={canReview}
        onChanged={() => {
          reload();
          onChanged?.();
        }}
      />
    </Stack>
  );
}
