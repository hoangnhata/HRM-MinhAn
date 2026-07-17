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
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as pcs from '../services/probationConversionService';
import { ProbationConversionDetailDialog } from './ProbationConversionDetailDialog';
import { ProbationConversionListCard } from './ProbationConversionListCard';

export function ProbationConversionPendingPanel({ onChanged }: { onChanged?: () => void }) {
  const theme = useTheme();
  const { user } = useAuth();
  const isHrOrAdmin = user?.role === 'ADMIN' || user?.role === 'HR';
  const isDirectorOrAdmin = user?.role === 'ADMIN' || user?.role === 'DIRECTOR';
  const isHead =
    user?.role === 'HEAD_DEPARTMENT' || user?.role === 'HEAD_NURSING' || user?.role === 'ADMIN';

  const [pendingHr, setPendingHr] = useState<pcs.ProbationConversion[]>([]);
  const [pendingDirector, setPendingDirector] = useState<pcs.ProbationConversion[]>([]);
  const [history, setHistory] = useState<pcs.ProbationConversion[]>([]);
  const [mine, setMine] = useState<pcs.ProbationConversion[]>([]);
  const [subTab, setSubTab] = useState(0);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);
  const [detailId, setDetailId] = useState<number | null>(null);

  const reload = useCallback(() => {
    setLoading(true);
    const tasks: Promise<void>[] = [];
    if (isHrOrAdmin || isDirectorOrAdmin) {
      tasks.push(
        pcs
          .fetchPendingHrConversions()
          .then(setPendingHr)
          .catch(() => setPendingHr([])),
      );
      tasks.push(
        pcs
          .fetchPendingDirectorConversions()
          .then(setPendingDirector)
          .catch(() => setPendingDirector([])),
      );
      tasks.push(
        pcs
          .fetchConversionHistory()
          .then(setHistory)
          .catch(() => setHistory([])),
      );
    }
    if (isHead) {
      tasks.push(
        pcs
          .fetchMyConversions()
          .then(setMine)
          .catch(() => setMine([])),
      );
    }
    Promise.all(tasks)
      .then(() => setErr(null))
      .catch(() => setErr('Không tải được danh sách đơn chuyển chính thức.'))
      .finally(() => setLoading(false));
  }, [isHrOrAdmin, isDirectorOrAdmin, isHead]);

  useEffect(() => {
    reload();
  }, [reload]);

  const tabDefs = useMemo(() => {
    const tabs: { key: string; label: string; count?: number; list: pcs.ProbationConversion[] }[] = [];
    if (isHrOrAdmin) {
      tabs.push({ key: 'hr', label: 'Chờ HCNS', count: pendingHr.length, list: pendingHr });
    }
    if (isHrOrAdmin || isDirectorOrAdmin) {
      tabs.push({
        key: 'director',
        label: 'Chờ Giám đốc',
        count: pendingDirector.length,
        list: pendingDirector,
      });
      tabs.push({ key: 'history', label: 'Lịch sử', count: history.length, list: history });
    }
    if (isHead && !isHrOrAdmin) {
      tabs.push({ key: 'mine', label: 'Đơn tôi lập', count: mine.length, list: mine });
    } else if (isHead && isHrOrAdmin) {
      tabs.push({ key: 'mine', label: 'Đơn tôi lập', count: mine.length, list: mine });
    }
    return tabs;
  }, [isHrOrAdmin, isDirectorOrAdmin, isHead, pendingHr, pendingDirector, history, mine]);

  useEffect(() => {
    if (subTab >= tabDefs.length) setSubTab(0);
  }, [tabDefs.length, subTab]);

  const active = tabDefs[subTab];
  const list = active?.list ?? [];

  if (loading && tabDefs.every((t) => t.list.length === 0)) {
    return (
      <Box sx={{ py: 4, textAlign: 'center' }}>
        <CircularProgress size={28} />
      </Box>
    );
  }

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        Đơn do Trưởng khoa/phòng hoặc Điều dưỡng trưởng lập → HCNS duyệt → Giám đốc duyệt. Nhân viên chỉ lên
        chính thức đúng <strong>ngày đã chọn</strong>.
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
            maxWidth: '100%',
            overflowX: 'auto',
          }}
        >
          <Tabs
            value={Math.min(subTab, Math.max(tabDefs.length - 1, 0))}
            onChange={(_, v) => setSubTab(v)}
            variant="scrollable"
            scrollButtons="auto"
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
            {tabDefs.map((t) => (
              <Tab
                key={t.key}
                icon={
                  t.key === 'history' ? (
                    <HistoryIcon fontSize="small" />
                  ) : (
                    <Badge badgeContent={t.count ?? 0} color="warning" max={99}>
                      <PendingActionsIcon fontSize="small" />
                    </Badge>
                  )
                }
                iconPosition="start"
                label={t.key === 'history' ? `Lịch sử (${t.count ?? 0})` : t.label}
              />
            ))}
          </Tabs>
        </Box>
      </Stack>

      {list.length === 0 ? (
        <Box
          sx={{
            py: { xs: 5, sm: 6 },
            px: 2,
            textAlign: 'center',
            borderRadius: 3,
            border: `1px dashed ${alpha(theme.palette.success.main, 0.22)}`,
            bgcolor: alpha(theme.palette.success.main, 0.025),
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
              bgcolor: alpha(theme.palette.success.main, 0.08),
              color: theme.palette.success.main,
            }}
          >
            <InboxOutlinedIcon sx={{ fontSize: 28 }} />
          </Box>
          <Typography variant="subtitle1" fontWeight={800} sx={{ mb: 0.5 }}>
            Không có đơn
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 420, mx: 'auto' }}>
            Khi có đề nghị chuyển chính thức, đơn sẽ xuất hiện tại đây.
          </Typography>
        </Box>
      ) : (
        <Grid container spacing={1.75}>
          {list.map((r) => (
            <Grid item xs={12} md={6} key={r.id}>
              <ProbationConversionListCard conversion={r} onClick={() => setDetailId(r.id)} />
            </Grid>
          ))}
        </Grid>
      )}

      <ProbationConversionDetailDialog
        open={detailId != null}
        conversionId={detailId}
        onClose={() => setDetailId(null)}
        canHrReview={isHrOrAdmin}
        canDirectorReview={isDirectorOrAdmin}
        onChanged={() => {
          reload();
          onChanged?.();
        }}
      />
    </Stack>
  );
}
