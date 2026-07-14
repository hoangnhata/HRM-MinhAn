import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import DoneAllIcon from '@mui/icons-material/DoneAll';
import LockOutlinedIcon from '@mui/icons-material/LockOutlined';
import NotificationsNoneOutlinedIcon from '@mui/icons-material/NotificationsNoneOutlined';
import { Box, Chip, CircularProgress, Popover, Stack, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import * as notificationService from '../../services/notificationService';

type Props = {
  open: boolean;
  anchorEl: HTMLElement | null;
  onClose: () => void;
  onCountsUpdated?: () => void;
};

export function NotificationPopover({ open, anchorEl, onClose, onCountsUpdated }: Props) {
  const theme = useTheme();
  const navigate = useNavigate();
  const [items, setItems] = useState<notificationService.AppNotification[]>([]);
  const [loading, setLoading] = useState(false);

  const refresh = useCallback(async () => {
    setLoading(true);
    try {
      const data = await notificationService.fetchNotifications();
      setItems(data);
    } catch {
      setItems([]);
    } finally {
      setLoading(false);
    }
    onCountsUpdated?.();
  }, [onCountsUpdated]);

  useEffect(() => {
    if (!open) return;
    let cancelled = false;
    (async () => {
      setLoading(true);
      try {
        const data = await notificationService.fetchNotifications();
        if (!cancelled) setItems(data);
      } catch {
        if (!cancelled) setItems([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
      onCountsUpdated?.();
    })();
    return () => {
      cancelled = true;
    };
  }, [open, onCountsUpdated]);

  async function handleActivate(n: notificationService.AppNotification) {
    const path = notificationService.resolveNotificationPath(n);
    if (!n.read) {
      try {
        await notificationService.markRead(n.id);
      } catch {
        /* vẫn điều hướng */
      }
    }
    navigate(path);
    onClose();
    await refresh();
  }

  const unreadCount = items.filter((n) => !n.read).length;

  return (
    <Popover
      open={open}
      anchorEl={anchorEl}
      onClose={onClose}
      anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      transformOrigin={{ vertical: 'top', horizontal: 'right' }}
      PaperProps={{
        elevation: 0,
        sx: {
          width: { xs: 'min(100vw - 16px, 400px)', sm: 400 },
          maxWidth: 'calc(100vw - 16px)',
          mt: 1.25,
          borderRadius: 3,
          overflow: 'hidden',
          border: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
          boxShadow: `0 20px 50px ${alpha('#0f172a', 0.14)}`,
        },
      }}
    >
      <Box
        sx={{
          px: 2.25,
          py: 1.75,
          background: `linear-gradient(135deg, ${alpha(theme.palette.primary.main, 0.1)} 0%, ${alpha(theme.palette.primary.main, 0.02)} 100%)`,
          borderBottom: `1px solid ${alpha(theme.palette.divider, 0.8)}`,
        }}
      >
        <Stack direction="row" alignItems="center" justifyContent="space-between">
          <Box>
            <Typography variant="subtitle1" fontWeight={800} letterSpacing="-0.02em">
              Thông báo
            </Typography>
            <Typography variant="caption" color="text.secondary">
              {unreadCount > 0 ? `${unreadCount} chưa đọc` : 'Bạn đã xem hết thông báo'}
            </Typography>
          </Box>
          <NotificationsNoneOutlinedIcon sx={{ color: alpha(theme.palette.primary.main, 0.55), fontSize: 28 }} />
        </Stack>
      </Box>

      <Box sx={{ maxHeight: { xs: 'min(72vh, 440px)', sm: 440 }, overflowY: 'auto' }}>
        {loading && items.length === 0 ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 5 }}>
            <CircularProgress size={28} />
          </Box>
        ) : items.length === 0 ? (
          <Box sx={{ px: 3, py: 5, textAlign: 'center' }}>
            <NotificationsNoneOutlinedIcon sx={{ fontSize: 40, color: 'text.disabled', mb: 1 }} />
            <Typography variant="body2" color="text.secondary">
              Không có thông báo nào.
            </Typography>
          </Box>
        ) : (
          <Stack spacing={0} sx={{ py: 0.75 }}>
            {items.map((n) => {
              const meta = notificationService.notificationMeta(n.category);
              const Icon = meta.icon;
              const sensitive = Boolean(n.sensitive);
              const preview = sensitive
                ? 'Nội dung nhạy cảm — bấm để mở mục liên quan trên hệ thống.'
                : n.message;

              return (
                <Box
                  key={n.id}
                  component="button"
                  type="button"
                  onClick={() => void handleActivate(n)}
                  sx={{
                    width: '100%',
                    border: 'none',
                    cursor: 'pointer',
                    textAlign: 'left',
                    font: 'inherit',
                    display: 'block',
                    px: 1.25,
                    py: 0.5,
                    bgcolor: 'transparent',
                  }}
                >
                  <Box
                    sx={{
                      px: 1.5,
                      py: 1.35,
                      borderRadius: 2.5,
                      transition: 'background-color 0.18s ease, box-shadow 0.18s ease',
                      bgcolor: n.read ? 'transparent' : alpha(theme.palette.primary.main, 0.06),
                      border: `1px solid ${n.read ? 'transparent' : alpha(theme.palette.primary.main, 0.12)}`,
                      '&:hover': {
                        bgcolor: alpha(meta.accent, 0.08),
                        boxShadow: `0 4px 14px ${alpha(meta.accent, 0.1)}`,
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
                          bgcolor: alpha(meta.accent, 0.12),
                          color: meta.accent,
                          flexShrink: 0,
                          position: 'relative',
                        }}
                      >
                        <Icon sx={{ fontSize: 20 }} />
                        {!n.read && (
                          <Box
                            sx={{
                              position: 'absolute',
                              top: 6,
                              right: 6,
                              width: 8,
                              height: 8,
                              borderRadius: '50%',
                              bgcolor: theme.palette.primary.main,
                              border: `2px solid ${theme.palette.background.paper}`,
                            }}
                          />
                        )}
                      </Box>

                      <Box sx={{ flex: 1, minWidth: 0 }}>
                        <Stack direction="row" alignItems="flex-start" justifyContent="space-between" gap={0.5}>
                          <Typography variant="subtitle2" fontWeight={700} sx={{ lineHeight: 1.35, pr: 0.5 }}>
                            {n.title}
                          </Typography>
                          <ChevronRightIcon sx={{ fontSize: 18, color: 'text.disabled', mt: 0.15, flexShrink: 0 }} />
                        </Stack>

                        <Stack direction="row" alignItems="center" spacing={0.75} sx={{ mt: 0.35, flexWrap: 'wrap' }}>
                          <Typography variant="caption" color="text.secondary">
                            {notificationService.formatNotificationTime(n.createdAt)}
                          </Typography>
                          {sensitive && (
                            <Chip
                              size="small"
                              icon={<LockOutlinedIcon sx={{ fontSize: '14px !important' }} />}
                              label="Nhạy cảm"
                              sx={{
                                height: 20,
                                fontSize: '0.65rem',
                                fontWeight: 600,
                                bgcolor: alpha(theme.palette.warning.main, 0.12),
                                color: 'warning.dark',
                                '& .MuiChip-icon': { color: 'warning.dark', ml: 0.5 },
                              }}
                            />
                          )}
                          {n.read && (
                            <Stack direction="row" alignItems="center" spacing={0.25} sx={{ color: 'success.main' }}>
                              <DoneAllIcon sx={{ fontSize: 13 }} />
                              <Typography variant="caption" fontWeight={600}>
                                Đã đọc
                              </Typography>
                            </Stack>
                          )}
                        </Stack>

                        <Typography
                          variant="body2"
                          color="text.secondary"
                          sx={{
                            mt: 0.75,
                            lineHeight: 1.5,
                            display: '-webkit-box',
                            WebkitLineClamp: 2,
                            WebkitBoxOrient: 'vertical',
                            overflow: 'hidden',
                            wordBreak: 'break-word',
                          }}
                        >
                          {preview}
                        </Typography>
                      </Box>
                    </Stack>
                  </Box>
                </Box>
              );
            })}
          </Stack>
        )}
      </Box>
    </Popover>
  );
}
