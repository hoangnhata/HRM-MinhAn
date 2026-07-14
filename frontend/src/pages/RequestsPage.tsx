import AddIcon from '@mui/icons-material/Add';
import AssignmentOutlinedIcon from '@mui/icons-material/AssignmentOutlined';
import BeachAccessOutlinedIcon from '@mui/icons-material/BeachAccessOutlined';
import BusinessCenterOutlinedIcon from '@mui/icons-material/BusinessCenterOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import EventAvailableOutlinedIcon from '@mui/icons-material/EventAvailableOutlined';
import GavelIcon from '@mui/icons-material/Gavel';
import HourglassEmptyOutlinedIcon from '@mui/icons-material/HourglassEmptyOutlined';
import InboxOutlinedIcon from '@mui/icons-material/InboxOutlined';
import WarningAmberOutlinedIcon from '@mui/icons-material/WarningAmberOutlined';
import {
  Alert,
  Box,
  Button,
  Chip,
  Grid,
  Menu,
  MenuItem,
  ListItemIcon,
  ListItemText,
  Paper,
  Stack,
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { AttendancePendingPanel } from '../components/AttendancePendingPanel';
import { BusinessTripRequestDialog } from '../components/BusinessTripRequestDialog';
import { LeaveRequestDialog } from '../components/LeaveRequestDialog';
import { PageHeader } from '../components/layout/PageHeader';
import { WorkRequestDetailDialog } from '../components/work/WorkRequestDetailDialog';
import { WorkRequestListCard } from '../components/work/WorkRequestListCard';
import { useAuth } from '../context/AuthContext';
import * as att from '../services/attendanceService';

type FilterKey = 'all' | 'leave' | 'trip' | 'pending' | 'done';

function BalanceStat({
  label,
  value,
  hint,
  accent,
  icon,
}: {
  label: string;
  value: string | number;
  hint?: string;
  accent: string;
  icon: React.ReactNode;
}) {
  return (
    <Paper
      elevation={0}
      sx={{
        p: 2,
        height: '100%',
        borderRadius: 2.5,
        border: `1px solid ${alpha(accent, 0.18)}`,
        bgcolor: alpha(accent, 0.04),
        transition: 'transform 0.18s, box-shadow 0.18s',
        '&:hover': {
          transform: 'translateY(-1px)',
          boxShadow: `0 8px 22px ${alpha(accent, 0.1)}`,
        },
      }}
    >
      <Stack direction="row" spacing={1.5} alignItems="flex-start">
        <Box
          sx={{
            width: 40,
            height: 40,
            borderRadius: 2,
            display: 'grid',
            placeItems: 'center',
            bgcolor: alpha(accent, 0.12),
            color: accent,
            flexShrink: 0,
          }}
        >
          {icon}
        </Box>
        <Box sx={{ minWidth: 0 }}>
          <Typography variant="caption" color="text.secondary" fontWeight={600} display="block">
            {label}
          </Typography>
          <Typography variant="h5" fontWeight={800} sx={{ lineHeight: 1.2, letterSpacing: '-0.02em' }}>
            {value}
          </Typography>
          {hint && (
            <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.35 }}>
              {hint}
            </Typography>
          )}
        </Box>
      </Stack>
    </Paper>
  );
}

export default function RequestsPage() {
  const theme = useTheme();
  const { user } = useAuth();
  const isHead =
    user?.role === 'ADMIN' || user?.role === 'HEAD_DEPARTMENT' || user?.role === 'HEAD_NURSING';
  const isHrOrAdmin = user?.role === 'ADMIN' || user?.role === 'HR';
  const canApprove = isHead || isHrOrAdmin;

  const [searchParams, setSearchParams] = useSearchParams();
  const [tab, setTab] = useState(0);
  const [myRequests, setMyRequests] = useState<att.WorkRequest[]>([]);
  const [filter, setFilter] = useState<FilterKey>('all');
  const [detail, setDetail] = useState<att.WorkRequest | null>(null);
  const [leaveOpen, setLeaveOpen] = useState(false);
  const [tripOpen, setTripOpen] = useState(false);
  const [createMenuEl, setCreateMenuEl] = useState<null | HTMLElement>(null);
  const [balance, setBalance] = useState<att.LeaveBalance | null>(null);
  const [msg, setMsg] = useState<string | null>(null);
  const [msgSeverity, setMsgSeverity] = useState<'success' | 'error'>('success');
  const [withdrawLoading, setWithdrawLoading] = useState(false);

  const paperSx = {
    borderRadius: 3,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
    bgcolor: alpha(theme.palette.background.paper, 0.96),
    boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
    overflow: 'hidden' as const,
  };

  const reload = useCallback(() => {
    if (user?.employeeId) {
      att.fetchMyWorkRequests().then(setMyRequests).catch(() => setMyRequests([]));
      att.fetchMyLeaveBalance().then(setBalance).catch(() => setBalance(null));
    } else {
      setMyRequests([]);
      setBalance(null);
    }
  }, [user?.employeeId]);

  useEffect(() => {
    reload();
  }, [reload]);

  useEffect(() => {
    const raw = searchParams.get('tab');
    if (raw === 'approve' || raw === 'pending') {
      setTab(canApprove ? 1 : 0);
    } else if (raw === 'mine' || raw === '0') {
      setTab(0);
    }
  }, [searchParams, canApprove]);

  const counts = useMemo(() => {
    const leave = myRequests.filter((r) => r.requestType === 'LEAVE').length;
    const trip = myRequests.filter((r) => r.requestType === 'BUSINESS_TRIP').length;
    const pending = myRequests.filter((r) => att.isRequestPending(r.status)).length;
    const done = myRequests.filter((r) => !att.isRequestPending(r.status)).length;
    return { all: myRequests.length, leave, trip, pending, done };
  }, [myRequests]);

  const filtered = useMemo(() => {
    if (filter === 'leave') return myRequests.filter((r) => r.requestType === 'LEAVE');
    if (filter === 'trip') return myRequests.filter((r) => r.requestType === 'BUSINESS_TRIP');
    if (filter === 'pending') return myRequests.filter((r) => att.isRequestPending(r.status));
    if (filter === 'done') return myRequests.filter((r) => !att.isRequestPending(r.status));
    return myRequests;
  }, [myRequests, filter]);

  function changeTab(next: number) {
    setTab(next);
    const params = new URLSearchParams(searchParams);
    params.set('tab', next === 1 ? 'approve' : 'mine');
    setSearchParams(params, { replace: true });
  }

  async function handleWithdraw() {
    if (!detail) return;
    setWithdrawLoading(true);
    try {
      await att.withdrawWorkRequest(detail.id);
      setMsg('Đã thu hồi đơn thành công.');
      setMsgSeverity('success');
      setDetail(null);
      reload();
    } catch {
      setMsg('Không thể thu hồi đơn. Đơn có thể đã được duyệt.');
      setMsgSeverity('error');
    } finally {
      setWithdrawLoading(false);
    }
  }

  const filters: { key: FilterKey; label: string; count: number }[] = [
    { key: 'all', label: 'Tất cả', count: counts.all },
    { key: 'leave', label: 'Nghỉ phép', count: counts.leave },
    { key: 'trip', label: 'Công tác', count: counts.trip },
    { key: 'pending', label: 'Chờ duyệt', count: counts.pending },
    { key: 'done', label: 'Đã xử lý', count: counts.done },
  ];

  const remainingAccent =
    balance && balance.remainingDays <= 2 ? theme.palette.warning.main : theme.palette.success.main;

  return (
    <Box>
      <PageHeader
        overline="Đơn từ"
        title="Đơn nghỉ phép & công tác"
        description="Gửi đơn nghỉ phép hoặc công tác, theo dõi trạng thái duyệt và hạn mức phép năm. Lãnh đạo / HCNS duyệt theo quy trình hiện hành."
        actions={
          <>
            <Button
              variant="contained"
              size="large"
              startIcon={<AddIcon />}
              onClick={(e) => setCreateMenuEl(e.currentTarget)}
              sx={{
                borderRadius: 2.5,
                px: 2.5,
                py: 1.1,
                fontWeight: 700,
                boxShadow: `0 8px 20px ${alpha(theme.palette.primary.main, 0.28)}`,
              }}
            >
              Tạo đơn
            </Button>
            <Menu
              anchorEl={createMenuEl}
              open={Boolean(createMenuEl)}
              onClose={() => setCreateMenuEl(null)}
              anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
              transformOrigin={{ vertical: 'top', horizontal: 'right' }}
              PaperProps={{
                sx: {
                  mt: 1,
                  minWidth: 220,
                  borderRadius: 2.5,
                  border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                  boxShadow: `0 12px 32px ${alpha('#0f172a', 0.12)}`,
                },
              }}
            >
              <MenuItem
                onClick={() => {
                  setCreateMenuEl(null);
                  setLeaveOpen(true);
                }}
                sx={{ py: 1.25, borderRadius: 1.5, mx: 0.5 }}
              >
                <ListItemIcon>
                  <BeachAccessOutlinedIcon fontSize="small" color="secondary" />
                </ListItemIcon>
                <ListItemText
                  primary="Xin nghỉ phép"
                  secondary="Khoảng ngày · hạn mức năm"
                  primaryTypographyProps={{ fontWeight: 700, fontSize: '0.9rem' }}
                  secondaryTypographyProps={{ fontSize: '0.72rem' }}
                />
              </MenuItem>
              <MenuItem
                onClick={() => {
                  setCreateMenuEl(null);
                  setTripOpen(true);
                }}
                sx={{ py: 1.25, borderRadius: 1.5, mx: 0.5 }}
              >
                <ListItemIcon>
                  <BusinessCenterOutlinedIcon fontSize="small" sx={{ color: 'warning.dark' }} />
                </ListItemIcon>
                <ListItemText
                  primary="Xin công tác"
                  secondary="Ngày · địa điểm · lý do"
                  primaryTypographyProps={{ fontWeight: 700, fontSize: '0.9rem' }}
                  secondaryTypographyProps={{ fontSize: '0.72rem' }}
                />
              </MenuItem>
            </Menu>
          </>
        }
      />

      {msg && (
        <Alert severity={msgSeverity} sx={{ mb: 2.5, borderRadius: 2 }} onClose={() => setMsg(null)}>
          {msg}
        </Alert>
      )}

      {balance && (
        <Box sx={{ mb: 2.5 }}>
          <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mb: 1.5 }}>
            <Typography variant="subtitle2" fontWeight={800} color="text.secondary">
              Hạn mức phép năm {balance.year}
            </Typography>
            {balance.yearsOfService > 0 && (
              <Chip
                size="small"
                label={`Thâm niên ${balance.yearsOfService} năm`}
                variant="outlined"
                sx={{ height: 24, fontWeight: 600 }}
              />
            )}
          </Stack>
          <Grid container spacing={1.75}>
            <Grid item xs={6} md={3}>
              <BalanceStat
                icon={<EventAvailableOutlinedIcon fontSize="small" />}
                label="Hạn mức năm"
                value={balance.entitlementDays}
                hint="12 ngày + 1 mỗi 5 năm"
                accent={theme.palette.primary.main}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <BalanceStat
                icon={<CheckCircleOutlineIcon fontSize="small" />}
                label="Đã dùng"
                value={balance.usedDays}
                hint="Đơn nghỉ phép đã duyệt"
                accent={theme.palette.info.main}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <BalanceStat
                icon={<HourglassEmptyOutlinedIcon fontSize="small" />}
                label="Chờ duyệt"
                value={balance.pendingDays}
                hint="Đang chờ lãnh đạo / HCNS"
                accent={theme.palette.warning.main}
              />
            </Grid>
            <Grid item xs={6} md={3}>
              <BalanceStat
                icon={
                  balance.remainingDays <= 2 ? (
                    <WarningAmberOutlinedIcon fontSize="small" />
                  ) : (
                    <BeachAccessOutlinedIcon fontSize="small" />
                  )
                }
                label="Còn lại"
                value={balance.remainingDays}
                hint={`Tối đa ${balance.entitlementDays} ngày/năm`}
                accent={remainingAccent}
              />
            </Grid>
          </Grid>
          {balance.warning && (
            <Alert severity="warning" variant="outlined" sx={{ mt: 1.75, borderRadius: 2 }}>
              {balance.warning}
            </Alert>
          )}
        </Box>
      )}

      <Paper elevation={0} sx={paperSx}>
        <Box
          sx={{
            px: 2,
            pt: 1,
            borderBottom: 1,
            borderColor: 'divider',
            bgcolor: alpha(theme.palette.primary.main, 0.03),
          }}
        >
          <Tabs
            value={tab}
            onChange={(_, v) => changeTab(v)}
            sx={{
              minHeight: 52,
              '& .MuiTab-root': { fontWeight: 600, minHeight: 52, textTransform: 'none' },
            }}
          >
            <Tab icon={<AssignmentOutlinedIcon />} iconPosition="start" label="Đơn của tôi" />
            {canApprove && <Tab icon={<GavelIcon />} iconPosition="start" label="Duyệt đơn" />}
          </Tabs>
        </Box>

        <Box sx={{ p: { xs: 2, sm: 2.5 } }}>
          {tab === 0 && (
            <Stack spacing={2.25}>
              <Stack
                direction={{ xs: 'column', sm: 'row' }}
                spacing={1.5}
                alignItems={{ sm: 'center' }}
                justifyContent="space-between"
              >
                <Box
                  sx={{
                    display: 'inline-flex',
                    p: 0.5,
                    borderRadius: 2.5,
                    bgcolor: alpha(theme.palette.grey[500], 0.06),
                    border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                    flexWrap: 'wrap',
                    gap: 0.5,
                  }}
                >
                  {filters.map((f) => {
                    const selected = filter === f.key;
                    return (
                      <Button
                        key={f.key}
                        size="small"
                        onClick={() => setFilter(f.key)}
                        sx={{
                          borderRadius: 2,
                          px: 1.5,
                          py: 0.75,
                          minWidth: 0,
                          textTransform: 'none',
                          fontWeight: selected ? 700 : 500,
                          color: selected ? theme.palette.primary.contrastText : 'text.secondary',
                          bgcolor: selected ? theme.palette.primary.main : 'transparent',
                          boxShadow: selected
                            ? `0 4px 12px ${alpha(theme.palette.primary.main, 0.25)}`
                            : 'none',
                          '&:hover': {
                            bgcolor: selected
                              ? theme.palette.primary.main
                              : alpha(theme.palette.primary.main, 0.06),
                          },
                        }}
                      >
                        {f.label}
                        <Box
                          component="span"
                          sx={{
                            ml: 0.75,
                            px: 0.75,
                            py: 0.1,
                            borderRadius: 1,
                            fontSize: '0.7rem',
                            fontWeight: 700,
                            bgcolor: selected
                              ? alpha('#fff', 0.22)
                              : alpha(theme.palette.text.primary, 0.06),
                          }}
                        >
                          {f.count}
                        </Box>
                      </Button>
                    );
                  })}
                </Box>

                <Typography variant="caption" color="text.secondary" fontWeight={600}>
                  {filtered.length} đơn hiển thị
                </Typography>
              </Stack>

              {filtered.length === 0 ? (
                <Box
                  sx={{
                    py: { xs: 5, sm: 7 },
                    px: 2,
                    textAlign: 'center',
                    borderRadius: 3,
                    border: `1px dashed ${alpha(theme.palette.primary.main, 0.22)}`,
                    bgcolor: alpha(theme.palette.primary.main, 0.025),
                  }}
                >
                  <Box
                    sx={{
                      width: 64,
                      height: 64,
                      mx: 'auto',
                      mb: 2,
                      borderRadius: 3,
                      display: 'grid',
                      placeItems: 'center',
                      bgcolor: alpha(theme.palette.primary.main, 0.08),
                      color: theme.palette.primary.main,
                    }}
                  >
                    <InboxOutlinedIcon sx={{ fontSize: 32 }} />
                  </Box>
                  <Typography variant="h6" fontWeight={800} sx={{ mb: 0.75 }}>
                    {filter === 'all' ? 'Chưa có đơn nào' : 'Không có đơn phù hợp bộ lọc'}
                  </Typography>
                  <Typography
                    variant="body2"
                    color="text.secondary"
                    sx={{ maxWidth: 420, mx: 'auto', mb: 2.5, lineHeight: 1.65 }}
                  >
                    {filter === 'all'
                      ? 'Bắt đầu bằng đơn nghỉ phép hoặc công tác — chọn khoảng ngày và lý do, rồi gửi lãnh đạo duyệt.'
                      : filter === 'trip'
                        ? 'Chưa có đơn công tác. Tạo đơn với khoảng ngày, địa điểm và lý do.'
                        : 'Thử đổi bộ lọc hoặc tạo đơn mới.'}
                  </Typography>
                  {(filter === 'all' || filter === 'leave') && (
                    <Button
                      variant="contained"
                      startIcon={<BeachAccessOutlinedIcon />}
                      onClick={() => setLeaveOpen(true)}
                      sx={{ borderRadius: 2.5, px: 2.5, fontWeight: 700, mr: 1 }}
                    >
                      Tạo đơn nghỉ phép
                    </Button>
                  )}
                  {(filter === 'all' || filter === 'trip') && (
                    <Button
                      variant={filter === 'trip' ? 'contained' : 'outlined'}
                      startIcon={<BusinessCenterOutlinedIcon />}
                      onClick={() => setTripOpen(true)}
                      sx={{
                        borderRadius: 2.5,
                        px: 2.5,
                        fontWeight: 700,
                        ...(filter === 'trip'
                          ? {
                              bgcolor: theme.palette.warning.dark,
                              '&:hover': { bgcolor: theme.palette.warning.dark, filter: 'brightness(0.92)' },
                            }
                          : {}),
                      }}
                    >
                      Tạo đơn công tác
                    </Button>
                  )}
                </Box>
              ) : (
                <Grid container spacing={1.75}>
                  {filtered.map((r) => (
                    <Grid item xs={12} md={6} key={r.id}>
                      <WorkRequestListCard request={r} onClick={() => setDetail(r)} />
                    </Grid>
                  ))}
                </Grid>
              )}
            </Stack>
          )}

          {tab === 1 && canApprove && <AttendancePendingPanel onChanged={reload} />}
        </Box>
      </Paper>

      <LeaveRequestDialog
        open={leaveOpen}
        onClose={() => setLeaveOpen(false)}
        onSubmitted={() => {
          setMsg('Đã gửi đơn nghỉ phép thành công.');
          setMsgSeverity('success');
          reload();
        }}
      />

      <BusinessTripRequestDialog
        open={tripOpen}
        onClose={() => setTripOpen(false)}
        onSubmitted={() => {
          setMsg('Đã gửi đơn công tác thành công.');
          setMsgSeverity('success');
          reload();
        }}
      />

      <WorkRequestDetailDialog
        open={Boolean(detail)}
        onClose={() => setDetail(null)}
        request={detail}
        mode="mine"
        onWithdraw={handleWithdraw}
        withdrawLoading={withdrawLoading}
      />
    </Box>
  );
}
