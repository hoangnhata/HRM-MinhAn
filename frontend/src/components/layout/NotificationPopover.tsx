import LockOutlinedIcon from '@mui/icons-material/LockOutlined';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import { Box, Button, CircularProgress, Divider, Popover, Typography } from '@mui/material';
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
  const [revealed, setRevealed] = useState<Record<number, boolean>>({});
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

  async function handleMarkRead(id: number) {
    await notificationService.markRead(id);
    await refresh();
  }

  async function handleRowActivate(n: notificationService.AppNotification) {
    const annId = n.relatedAnnouncementId;
    if (annId != null && annId > 0) {
      if (!n.read) {
        await notificationService.markRead(n.id);
      }
      navigate(`/announcements?announcement=${annId}`);
      onClose();
      await refresh();
      return;
    }
  }

  return (
    <Popover
      open={open}
      anchorEl={anchorEl}
      onClose={onClose}
      anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      transformOrigin={{ vertical: 'top', horizontal: 'right' }}
      PaperProps={{
        elevation: 8,
        sx: {
          width: 380,
          maxWidth: 'calc(100vw - 16px)',
          mt: 1,
          borderRadius: 2,
          overflow: 'hidden',
          border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
          boxShadow: `0 12px 40px ${alpha('#0f172a', 0.12)}`,
        },
      }}
    >
      <Box
        sx={{
          px: 2,
          py: 1.25,
          borderBottom: `1px solid ${alpha(theme.palette.divider, 0.85)}`,
          bgcolor: alpha(theme.palette.primary.main, 0.04),
        }}
      >
        <Typography variant="subtitle2" fontWeight={700} letterSpacing="-0.02em">
          Thông báo
        </Typography>
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.25 }}>
          Bấm chuông để xem nhanh — dữ liệu nhạy cảm cần xác nhận trước khi hiện.
        </Typography>
      </Box>

      <Box sx={{ maxHeight: { xs: 'min(70vh, 420px)', sm: 420 }, overflowY: 'auto' }}>
        {loading && items.length === 0 ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
            <CircularProgress size={28} />
          </Box>
        ) : items.length === 0 ? (
          <Typography variant="body2" color="text.secondary" sx={{ px: 2, py: 3, textAlign: 'center' }}>
            Không có thông báo.
          </Typography>
        ) : (
          items.map((n, index) => {
            const sensitive = Boolean(n.sensitive);
            const showBody = !sensitive || revealed[n.id];
            const goAnnounce = n.relatedAnnouncementId != null && n.relatedAnnouncementId > 0;
            return (
              <Box key={n.id}>
                {index > 0 ? <Divider /> : null}
                <Box
                  role={goAnnounce ? 'button' : undefined}
                  tabIndex={goAnnounce ? 0 : undefined}
                  onClick={goAnnounce ? () => void handleRowActivate(n) : undefined}
                  onKeyDown={
                    goAnnounce
                      ? (e) => {
                          if (e.key === 'Enter' || e.key === ' ') {
                            e.preventDefault();
                            void handleRowActivate(n);
                          }
                        }
                      : undefined
                  }
                  sx={{
                    px: 2,
                    py: 1.5,
                    bgcolor: n.read ? 'transparent' : alpha(theme.palette.primary.main, 0.04),
                    borderLeft: n.read ? 'none' : `3px solid ${theme.palette.primary.main}`,
                    cursor: goAnnounce ? 'pointer' : 'default',
                    '&:hover': goAnnounce ? { bgcolor: alpha(theme.palette.primary.main, 0.07) } : undefined,
                  }}
                >
                  <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', gap: 1 }}>
                    <Box sx={{ minWidth: 0, flex: 1 }}>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5, mb: 0.25 }}>
                        {sensitive ? (
                          <LockOutlinedIcon sx={{ fontSize: 16, color: 'warning.dark', flexShrink: 0 }} />
                        ) : null}
                        <Typography variant="subtitle2" fontWeight={600} sx={{ lineHeight: 1.35 }}>
                          {n.title}
                        </Typography>
                        {goAnnounce ? (
                          <OpenInNewIcon sx={{ fontSize: 14, color: 'text.secondary', flexShrink: 0, ml: 0.5, mt: 0.2 }} />
                        ) : null}
                      </Box>
                      <Typography variant="caption" color="text.secondary" sx={{ display: 'block' }}>
                        {n.category} · {new Date(n.createdAt).toLocaleString('vi-VN')}
                      </Typography>
                      {showBody ? (
                        <Typography variant="body2" sx={{ mt: 0.75, lineHeight: 1.5, wordBreak: 'break-word' }}>
                          {n.message}
                        </Typography>
                      ) : (
                        <Button
                          size="small"
                          sx={{ mt: 0.75, textTransform: 'none' }}
                          onClick={(e) => {
                            e.stopPropagation();
                            setRevealed((r) => ({ ...r, [n.id]: true }));
                          }}
                        >
                          Hiển thị nội dung
                        </Button>
                      )}
                    </Box>
                    {!n.read && (
                      <Button
                        size="small"
                        variant="text"
                        aria-label="Đánh dấu đã đọc"
                        onClick={(e) => {
                          e.stopPropagation();
                          void handleMarkRead(n.id);
                        }}
                        sx={{ flexShrink: 0, minWidth: 72, alignSelf: 'flex-start', fontWeight: 600 }}
                      >
                        Đã đọc
                      </Button>
                    )}
                  </Box>
                </Box>
              </Box>
            );
          })
        )}
      </Box>
    </Popover>
  );
}
