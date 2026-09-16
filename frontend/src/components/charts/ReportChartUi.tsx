import { Box, Stack, Typography, Card, CardContent } from '@mui/material';
import { alpha } from '@mui/material/styles';
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactNode,
  type PointerEvent as ReactPointerEvent,
} from 'react';
import type { TooltipProps } from 'recharts';

export const REPORT_CHART_ACCENT = '#0f766e';
export const REPORT_CHART_INK = '#0f172a';

export const REPORT_SERIES_COLORS = [
  '#0f766e',
  '#0369a1',
  '#7c3aed',
  '#b45309',
  '#be123c',
  '#0e7490',
] as const;

export const reportChartGridProps = {
  strokeDasharray: '4 6',
  stroke: alpha('#64748b', 0.16),
  vertical: false,
} as const;

export const reportChartTickStyle = {
  fontSize: 12,
  fill: alpha(REPORT_CHART_INK, 0.55),
  fontWeight: 600,
} as const;

export const reportChartLegendProps = {
  wrapperStyle: {
    paddingTop: 12,
    fontSize: 12,
    fontWeight: 650,
  },
  iconType: 'circle' as const,
  iconSize: 8,
};

/** Trục số gọn: bỏ path trục, giữ tick nhẹ. */
export const reportChartAxisLine = { stroke: alpha('#64748b', 0.18) } as const;
export const reportChartNoAxisLine = false as const;

/** Cursor hover cho BarChart. */
export const reportChartBarCursor = {
  fill: alpha(REPORT_CHART_ACCENT, 0.06),
  radius: 6,
} as const;

/** Độ rộng tối thiểu mỗi điểm (ngày) — đủ cho nhãn DD/MM. */
export function reportChartScrollWidth(pointCount: number, pxPerPoint = 72): number {
  return Math.max(pointCount, 1) * pxPerPoint;
}

/** Rút gọn nhãn trục X: 01/08/2024 → 01/08; 2024-08-01 → 01/08. */
export function reportChartTickLabel(raw: unknown): string {
  const s = String(raw ?? '');
  if (!s) return '';
  // ISO yyyy-mm-dd
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (iso) return `${iso[3]}/${iso[2]}`;
  // dd/mm/yyyy
  const dmy = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/.exec(s);
  if (dmy) return `${dmy[1].padStart(2, '0')}/${dmy[2].padStart(2, '0')}`;
  // already short or week/month label
  if (s.length <= 7) return s;
  return s.slice(0, 7);
}

export const reportChartXAxisProps = {
  tick: { ...reportChartTickStyle, fontSize: 11 },
  axisLine: { stroke: alpha('#64748b', 0.2) },
  tickLine: false,
  interval: 0 as const,
  minTickGap: 8,
  angle: 0,
  textAnchor: 'middle' as const,
  height: 28,
  tickFormatter: reportChartTickLabel,
  dy: 4,
};

/**
 * Khung cuộn ngang cho biểu đồ nhiều điểm (1 tháng / nhiều ngày).
 * Luôn ép chiều rộng theo số điểm; ResponsiveContainer nhận width số (px).
 */
export function ReportChartScrollFrame({
  pointCount,
  height,
  children,
  pxPerPoint = 72,
}: {
  pointCount: number;
  height: number;
  children: (chartWidth: number) => ReactNode;
  pxPerPoint?: number;
}) {
  const scrollerRef = useRef<HTMLDivElement>(null);
  const [viewportW, setViewportW] = useState(0);
  const [scrollState, setScrollState] = useState({ left: true, right: true });
  const dragRef = useRef<{
    pending: boolean;
    active: boolean;
    startX: number;
    startScroll: number;
    pointerId: number | null;
  }>({
    pending: false,
    active: false,
    startX: 0,
    startScroll: 0,
    pointerId: null,
  });

  const intrinsicW = reportChartScrollWidth(pointCount, pxPerPoint);
  // Khi ít điểm: full viewport; khi nhiều: rộng hơn để cuộn
  const chartW = Math.max(intrinsicW, viewportW || intrinsicW);
  const needsScroll = viewportW > 0 && intrinsicW > viewportW + 8;

  const syncScrollEdges = useCallback(() => {
    const el = scrollerRef.current;
    if (!el) return;
    const max = el.scrollWidth - el.clientWidth;
    setScrollState({
      left: el.scrollLeft <= 2,
      right: max <= 2 || el.scrollLeft >= max - 2,
    });
  }, []);

  useEffect(() => {
    const el = scrollerRef.current;
    if (!el) return;
    const measure = () => {
      setViewportW(el.clientWidth);
      // defer edge sync after width paint
      requestAnimationFrame(() => syncScrollEdges());
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [syncScrollEdges, pointCount, intrinsicW]);

  const resetDrag = (el: HTMLDivElement | null) => {
    dragRef.current = {
      pending: false,
      active: false,
      startX: 0,
      startScroll: 0,
      pointerId: null,
    };
    if (el) el.style.cursor = needsScroll ? 'grab' : 'default';
  };

  const onPointerDown = (e: ReactPointerEvent<HTMLDivElement>) => {
    if (!needsScroll || e.button !== 0) return;
    // Không chặn tương tác với legend/tooltip nếu click vào vùng chart — chỉ drag khi giữ và kéo
    const el = scrollerRef.current;
    if (!el) return;
    dragRef.current = {
      pending: true,
      active: false,
      startX: e.clientX,
      startScroll: el.scrollLeft,
      pointerId: e.pointerId,
    };
  };

  const onPointerMove = (e: ReactPointerEvent<HTMLDivElement>) => {
    const drag = dragRef.current;
    if (!drag.pending && !drag.active) return;
    const el = scrollerRef.current;
    if (!el) return;
    const dx = e.clientX - drag.startX;
    if (!drag.active) {
      if (Math.abs(dx) < 10) return;
      drag.active = true;
      drag.pending = false;
      el.setPointerCapture(e.pointerId);
      el.style.cursor = 'grabbing';
    }
    el.scrollLeft = drag.startScroll - dx;
    syncScrollEdges();
  };

  const endDrag = () => {
    const el = scrollerRef.current;
    if (dragRef.current.active && el && dragRef.current.pointerId != null) {
      try {
        el.releasePointerCapture(dragRef.current.pointerId);
      } catch {
        /* ignore */
      }
    }
    resetDrag(el);
  };

  return (
    <Box sx={{ position: 'relative', width: '100%' }}>
      {needsScroll && (
        <Stack
          direction="row"
          alignItems="center"
          justifyContent="space-between"
          sx={{ mb: 0.85, px: 0.25 }}
        >
          <Typography
            variant="caption"
            fontWeight={650}
            sx={{ color: alpha(REPORT_CHART_INK, 0.48), letterSpacing: '0.01em' }}
          >
            Kéo thanh ngang hoặc vuốt để xem từng ngày
          </Typography>
          <Box
            sx={{
              display: 'inline-flex',
              alignItems: 'center',
              gap: 0.5,
              px: 0.85,
              py: 0.3,
              borderRadius: 999,
              bgcolor: alpha(REPORT_CHART_ACCENT, 0.08),
              border: `1px solid ${alpha(REPORT_CHART_ACCENT, 0.14)}`,
            }}
          >
            <Typography
              variant="caption"
              fontWeight={750}
              sx={{ color: REPORT_CHART_ACCENT, fontSize: '0.68rem', lineHeight: 1.2 }}
            >
              {pointCount} ngày
            </Typography>
          </Box>
        </Stack>
      )}

      <Box sx={{ position: 'relative' }}>
        {needsScroll && !scrollState.left && (
          <Box
            sx={{
              pointerEvents: 'none',
              position: 'absolute',
              left: 0,
              top: 0,
              bottom: 14,
              width: 40,
              zIndex: 2,
              background: `linear-gradient(90deg, #fff 18%, ${alpha('#fff', 0)})`,
            }}
          />
        )}
        {needsScroll && !scrollState.right && (
          <Box
            sx={{
              pointerEvents: 'none',
              position: 'absolute',
              right: 0,
              top: 0,
              bottom: 14,
              width: 40,
              zIndex: 2,
              background: `linear-gradient(270deg, #fff 18%, ${alpha('#fff', 0)})`,
            }}
          />
        )}

        <Box
          ref={scrollerRef}
          onScroll={syncScrollEdges}
          onPointerDown={onPointerDown}
          onPointerMove={onPointerMove}
          onPointerUp={endDrag}
          onPointerCancel={endDrag}
          sx={{
            width: '100%',
            overflowX: needsScroll ? 'auto' : 'hidden',
            overflowY: 'hidden',
            cursor: needsScroll ? 'grab' : 'default',
            WebkitOverflowScrolling: 'touch',
            touchAction: needsScroll ? 'pan-x' : 'auto',
            pb: needsScroll ? 1 : 0,
            '&::-webkit-scrollbar': { height: 9 },
            '&::-webkit-scrollbar-track': {
              marginInline: 6,
              borderRadius: 999,
              bgcolor: alpha(REPORT_CHART_ACCENT, 0.07),
            },
            '&::-webkit-scrollbar-thumb': {
              borderRadius: 999,
              bgcolor: alpha(REPORT_CHART_ACCENT, 0.38),
              border: `2px solid ${alpha('#fff', 0.95)}`,
              backgroundClip: 'padding-box',
              '&:hover': { bgcolor: alpha(REPORT_CHART_ACCENT, 0.55) },
            },
            scrollbarWidth: 'thin',
            scrollbarColor: `${alpha(REPORT_CHART_ACCENT, 0.45)} ${alpha(REPORT_CHART_ACCENT, 0.08)}`,
          }}
        >
          <Box
            sx={{
              width: chartW,
              minWidth: chartW,
              height,
              // Tránh ResponsiveContainer đo 0 khi chưa mount
              position: 'relative',
            }}
          >
            {children(chartW)}
          </Box>
        </Box>
      </Box>
    </Box>
  );
}

type TooltipRow = {
  label: string;
  value: string;
  color?: string;
};

/** Recharts có thể truyền fill dạng url(#gradient) — MUI alpha() không hỗ trợ. */
function resolveTooltipColor(raw: unknown): string {
  if (typeof raw !== 'string' || !raw.trim()) return REPORT_CHART_ACCENT;
  const c = raw.trim();
  if (c.startsWith('url(') || c.startsWith('var(')) return REPORT_CHART_ACCENT;
  try {
    alpha(c, 0.15);
    return c;
  } catch {
    return REPORT_CHART_ACCENT;
  }
}

/** Tooltip chuyên nghiệp cho biểu đồ báo cáo (Recharts). */
export function ReportChartTooltip({
  active,
  payload,
  label,
  valueFormatter,
}: TooltipProps<number, string> & {
  valueFormatter?: (value: number, name: string) => string;
}) {
  if (!active || !payload?.length) return null;

  const rows: TooltipRow[] = payload
    .filter((p) => p.value != null && p.dataKey != null)
    .map((p) => {
      const num = Number(p.value);
      const name = String(p.name ?? p.dataKey);
      return {
        label: name,
        value: valueFormatter
          ? valueFormatter(num, name)
          : Number.isFinite(num)
            ? String(num)
            : String(p.value),
        color: resolveTooltipColor(p.color),
      };
    });

  if (rows.length === 0) return null;

  return (
    <Box
      sx={{
        minWidth: 180,
        maxWidth: 280,
        px: 1.75,
        py: 1.35,
        borderRadius: 2.25,
        bgcolor: '#fff',
        border: `1px solid ${alpha(REPORT_CHART_ACCENT, 0.18)}`,
        boxShadow: `0 14px 36px ${alpha(REPORT_CHART_INK, 0.12)}`,
      }}
    >
      {label != null && label !== '' && (
        <Typography
          variant="caption"
          fontWeight={800}
          sx={{
            display: 'block',
            mb: 1,
            color: alpha(REPORT_CHART_INK, 0.7),
            letterSpacing: '0.02em',
          }}
        >
          {String(label)}
        </Typography>
      )}
      <Stack spacing={0.75}>
        {rows.map((row) => {
          const color = row.color ?? REPORT_CHART_ACCENT;
          return (
          <Stack
            key={row.label}
            direction="row"
            alignItems="center"
            justifyContent="space-between"
            spacing={1.5}
          >
            <Stack direction="row" alignItems="center" spacing={0.85} sx={{ minWidth: 0 }}>
              <Box
                sx={{
                  width: 8,
                  height: 8,
                  borderRadius: '50%',
                  flexShrink: 0,
                  bgcolor: color,
                  boxShadow: `0 0 0 3px ${alpha(color, 0.15)}`,
                }}
              />
              <Typography
                variant="caption"
                fontWeight={650}
                color="text.secondary"
                sx={{ lineHeight: 1.2 }}
                noWrap
              >
                {row.label}
              </Typography>
            </Stack>
            <Typography
              variant="body2"
              fontWeight={850}
              sx={{
                color,
                letterSpacing: '-0.02em',
                lineHeight: 1.2,
                whiteSpace: 'nowrap',
              }}
            >
              {row.value}
            </Typography>
          </Stack>
          );
        })}
      </Stack>
    </Box>
  );
}

/** Card bọc biểu đồ: header gradient + nội dung. */
export function ReportChartCard({
  title,
  subtitle,
  action,
  children,
  height = 300,
}: {
  title: string;
  subtitle?: string;
  action?: ReactNode;
  children: ReactNode;
  height?: number;
}) {
  return (
    <Box
      sx={{
        borderRadius: 3,
        border: `1px solid ${alpha('#64748b', 0.12)}`,
        overflow: 'hidden',
        bgcolor: '#fff',
        boxShadow: `0 1px 3px ${alpha(REPORT_CHART_INK, 0.04)}`,
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={1}
        alignItems={{ sm: 'center' }}
        sx={{
          px: { xs: 1.5, sm: 1.75 },
          py: 1.35,
          borderBottom: `1px solid ${alpha('#64748b', 0.1)}`,
          background: `linear-gradient(135deg, ${alpha(REPORT_CHART_ACCENT, 0.07)} 0%, ${alpha('#fff', 0.96)} 55%, ${alpha('#f0fdfa', 0.4)} 100%)`,
        }}
      >
        <Box sx={{ flex: 1, minWidth: 0 }}>
          <Typography variant="subtitle2" fontWeight={850} sx={{ letterSpacing: '-0.015em', lineHeight: 1.25 }}>
            {title}
          </Typography>
          {subtitle && (
            <Typography variant="caption" color="text.secondary" fontWeight={600}>
              {subtitle}
            </Typography>
          )}
        </Box>
        {action}
      </Stack>
      <Box sx={{ px: { xs: 0.75, sm: 1.25 }, pt: 1.5, pb: 1.5, flex: 1, minHeight: height }}>
        {children}
      </Box>
    </Box>
  );
}

export function ReportChartEmpty({ message }: { message: string }) {
  return (
    <Box
      sx={{
        height: '100%',
        minHeight: 220,
        display: 'grid',
        placeItems: 'center',
        textAlign: 'center',
        color: 'text.secondary',
        borderRadius: 2.5,
        border: `1px dashed ${alpha(REPORT_CHART_ACCENT, 0.22)}`,
        bgcolor: alpha('#f8fafc', 0.7),
        px: 2,
      }}
    >
      <Typography variant="body2" fontWeight={650}>
        {message}
      </Typography>
    </Box>
  );
}

/** Thẻ KPI giống báo cáo tuân thủ QTKT — icon bên phải, nền gradient. */
export function ReportKpiCard({
  label,
  value,
  hint,
  color = REPORT_CHART_ACCENT,
  icon,
}: {
  label: string;
  value: ReactNode;
  hint?: ReactNode;
  color?: string;
  icon: ReactNode;
}) {
  return (
    <Card
      elevation={0}
      sx={{
        height: '100%',
        borderRadius: 2.5,
        border: `1px solid ${alpha(color, 0.16)}`,
        background: `linear-gradient(145deg, ${alpha(color, 0.07)}, #fff 72%)`,
      }}
    >
      <CardContent sx={{ py: 1.35, px: 1.5, '&:last-child': { pb: 1.35 } }}>
        <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
          <Box sx={{ minWidth: 0, flex: 1 }}>
            <Typography
              variant="caption"
              color="text.secondary"
              fontWeight={700}
              sx={{ textTransform: 'uppercase', letterSpacing: '.04em', fontSize: '0.65rem' }}
            >
              {label}
            </Typography>
            <Typography
              variant="h6"
              fontWeight={850}
              sx={{
                color,
                lineHeight: 1.25,
                mt: 0.2,
                letterSpacing: '-0.02em',
                wordBreak: 'break-word',
              }}
            >
              {value ?? '—'}
            </Typography>
            {hint != null && hint !== '' && (
              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.35, lineHeight: 1.35 }}>
                {hint}
              </Typography>
            )}
          </Box>
          <Box
            sx={{
              width: 34,
              height: 34,
              borderRadius: 1.5,
              flexShrink: 0,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(color, 0.12),
              color,
            }}
          >
            {icon}
          </Box>
        </Stack>
      </CardContent>
    </Card>
  );
}
