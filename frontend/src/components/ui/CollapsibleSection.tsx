import ExpandMoreRoundedIcon from '@mui/icons-material/ExpandMoreRounded';
import { Box, Button, Collapse, Stack, Typography } from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useId, useState, type KeyboardEvent, type ReactNode } from 'react';

type Props = {
  /** Khoá lưu trạng thái mở/thu gọn trên máy người dùng. */
  storageKey: string;
  defaultOpen?: boolean;
  icon: ReactNode;
  /** Màu nhấn của biểu tượng / viền khi thu gọn. */
  accent: string;
  title: string;
  subtitle?: ReactNode;
  /** Số liệu tóm tắt — luôn hiện kể cả khi thu gọn. */
  summary?: ReactNode;
  /** Điều khiển bên phải (vd chọn kỳ) — bấm vào không đóng/mở thẻ. */
  actions?: ReactNode;
  children: ReactNode;
};

function readOpen(key: string, fallback: boolean): boolean {
  try {
    const v = window.localStorage.getItem(key);
    return v == null ? fallback : v === '1';
  } catch {
    return fallback;
  }
}

function writeOpen(key: string, open: boolean) {
  try {
    window.localStorage.setItem(key, open ? '1' : '0');
  } catch {
    /* trình duyệt chặn lưu trữ — chỉ không nhớ trạng thái */
  }
}

/**
 * Thẻ mục có thể phóng to / thu gọn: tiêu đề + số liệu tóm tắt luôn hiển thị,
 * phần nội dung dài (bộ lọc, bảng) chỉ dựng khi mở lần đầu.
 */
export function CollapsibleSection({
  storageKey,
  defaultOpen = true,
  icon,
  accent,
  title,
  subtitle,
  summary,
  actions,
  children,
}: Props) {
  const theme = useTheme();
  const bodyId = useId();
  const [open, setOpen] = useState(() => readOpen(storageKey, defaultOpen));

  const toggle = () =>
    setOpen((prev) => {
      writeOpen(storageKey, !prev);
      return !prev;
    });

  const onKeyDown = (e: KeyboardEvent<HTMLDivElement>) => {
    if (e.target !== e.currentTarget) return;
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      toggle();
    }
  };

  return (
    <Box
      sx={{
        mb: 2.5,
        borderRadius: 3,
        border: `1px solid ${open ? alpha(theme.palette.primary.main, 0.12) : alpha(accent, 0.28)}`,
        bgcolor: alpha(theme.palette.background.paper, 0.98),
        boxShadow: open ? `0 6px 28px ${alpha('#0f172a', 0.05)}` : `0 2px 10px ${alpha('#0f172a', 0.035)}`,
        overflow: 'hidden',
        transition: 'border-color .2s, box-shadow .2s',
      }}
    >
      <Stack
        direction={{ xs: 'column', md: 'row' }}
        spacing={{ xs: 1.5, md: 2 }}
        alignItems={{ md: 'center' }}
        sx={{
          px: { xs: 2, sm: 2.5 },
          py: { xs: 1.75, sm: 2 },
          bgcolor: open ? 'transparent' : alpha(accent, 0.035),
          transition: 'background-color .2s',
        }}
      >
        {/* Vùng bấm để mở / thu gọn */}
        <Box
          role="button"
          tabIndex={0}
          aria-expanded={open}
          aria-controls={bodyId}
          onClick={toggle}
          onKeyDown={onKeyDown}
          sx={{
            flex: 1,
            minWidth: 0,
            display: 'flex',
            alignItems: 'center',
            gap: 1.5,
            cursor: 'pointer',
            borderRadius: 2,
            outline: 'none',
            '&:focus-visible': { boxShadow: `0 0 0 3px ${alpha(accent, 0.3)}` },
            '&:hover .collapsible-title': { color: accent },
          }}
        >
          <Box
            sx={{
              width: 42,
              height: 42,
              flexShrink: 0,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(accent, 0.12),
              color: accent,
            }}
          >
            {icon}
          </Box>
          <Box sx={{ minWidth: 0, flex: 1 }}>
            <Typography
              className="collapsible-title"
              variant="subtitle1"
              fontWeight={800}
              letterSpacing="-0.01em"
              sx={{ transition: 'color .15s', lineHeight: 1.3 }}
            >
              {title}
            </Typography>
            {subtitle && (
              <Typography variant="body2" color="text.secondary" sx={{ mt: 0.25 }}>
                {subtitle}
              </Typography>
            )}
            {summary && (
              <Stack direction="row" spacing={0.75} flexWrap="wrap" useFlexGap sx={{ mt: 1 }}>
                {summary}
              </Stack>
            )}
          </Box>
        </Box>

        <Stack
          direction="row"
          spacing={1}
          alignItems="center"
          justifyContent={{ xs: 'space-between', md: 'flex-end' }}
          sx={{ flexShrink: 0 }}
        >
          {actions}
          <Button
            onClick={toggle}
            aria-expanded={open}
            aria-controls={bodyId}
            variant={open ? 'text' : 'outlined'}
            endIcon={
              <ExpandMoreRoundedIcon
                sx={{ transform: open ? 'rotate(180deg)' : 'none', transition: 'transform .25s' }}
              />
            }
            sx={{
              textTransform: 'none',
              fontWeight: 700,
              borderRadius: 2,
              whiteSpace: 'nowrap',
              color: open ? 'text.secondary' : accent,
              borderColor: alpha(accent, 0.4),
              '&:hover': { borderColor: accent, bgcolor: alpha(accent, 0.06) },
            }}
          >
            {open ? 'Thu gọn' : 'Mở rộng'}
          </Button>
        </Stack>
      </Stack>

      <Collapse in={open} timeout="auto" mountOnEnter>
        <Box
          id={bodyId}
          sx={{
            px: { xs: 2, sm: 2.5 },
            pb: { xs: 2, sm: 2.5 },
            pt: 2,
            borderTop: `1px solid ${theme.palette.divider}`,
          }}
        >
          {children}
        </Box>
      </Collapse>
    </Box>
  );
}
