import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import ChecklistRtlIcon from '@mui/icons-material/ChecklistRtl';
import CloseIcon from '@mui/icons-material/Close';
import HighlightOffIcon from '@mui/icons-material/HighlightOff';
import InboxOutlinedIcon from '@mui/icons-material/InboxOutlined';
import SelectAllIcon from '@mui/icons-material/SelectAll';
import DeselectIcon from '@mui/icons-material/Deselect';
import VisibilityIcon from '@mui/icons-material/Visibility';
import {
  Box,
  Button,
  Checkbox,
  Chip,
  CircularProgress,
  IconButton,
  Paper,
  Stack,
  Tab,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Tabs,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useState, type ReactNode } from 'react';

const PAGE_SIZE = 100;

export type RequestListStatusColor =
  | 'default'
  | 'primary'
  | 'secondary'
  | 'error'
  | 'info'
  | 'success'
  | 'warning';

export type RequestListRow = {
  id: number | string;
  /** Loại đơn */
  typeLabel: string;
  /** Người liên quan / tiêu đề chính — nên gồm chức vụ: "Họ tên - Chức vụ" */
  subject: string;
  /** Phòng ban */
  department?: string | null;
  /** Thông tin ngắn: ngày, số ngày, nội dung… */
  summary?: string | null;
  /** Người lập / mã NV… */
  meta?: string | null;
  statusLabel: string;
  statusColor?: RequestListStatusColor;
  /** Ngày yêu cầu (ngày hiệu lực / ngày công / ngày diễn ra…) */
  dateLabel?: string | null;
  /** Ngày gửi đơn (createdAt) */
  submittedAtLabel?: string | null;
  /** Tô hàng chờ duyệt */
  pending?: boolean;
  canApprove?: boolean;
  canReject?: boolean;
};

/** Hiển thị "Họ tên - Chức vụ" trên danh sách đơn. */
export function formatRequestSubject(
  name?: string | null,
  positionTitle?: string | null,
  fallback = '—',
): string {
  const n = (name || '').trim() || fallback;
  const p = (positionTitle || '').trim();
  return p ? `${n} - ${p}` : n;
}

type Props = {
  rows: RequestListRow[];
  loading?: boolean;
  emptyTitle?: string;
  emptyHint?: string;
  toolbar?: ReactNode;
  onView: (row: RequestListRow) => void;
  onApprove?: (row: RequestListRow) => void;
  onReject?: (row: RequestListRow) => void;
  /** Bật chọn nhiều + duyệt / từ chối hàng loạt */
  onBulkApprove?: (rows: RequestListRow[]) => void | Promise<void>;
  onBulkReject?: (rows: RequestListRow[]) => void | Promise<void>;
  actionBusyId?: number | string | null;
  bulkBusy?: boolean;
};

const chipSx = {
  height: 22,
  fontSize: '0.68rem',
  fontWeight: 600,
  borderRadius: '5px',
  '& .MuiChip-label': { px: 0.75 },
} as const;

function rowKey(id: number | string) {
  return String(id);
}

export function RequestListTable({
  rows,
  loading = false,
  emptyTitle = 'Không có đơn',
  emptyHint = 'Thử đổi bộ lọc hoặc tạo đơn mới.',
  toolbar,
  onView,
  onApprove,
  onReject,
  onBulkApprove,
  onBulkReject,
  actionBusyId = null,
  bulkBusy = false,
}: Props) {
  const theme = useTheme();
  const showReview = Boolean(onApprove || onReject);
  const enableBulk = Boolean(onBulkApprove || onBulkReject);
  const [selectMode, setSelectMode] = useState(false);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [page, setPage] = useState(0);

  const rowsSignature = `${rows.length}:${rows[0]?.id ?? ''}:${rows[rows.length - 1]?.id ?? ''}`;
  useEffect(() => {
    setPage(0);
  }, [rowsSignature]);

  const pageCount = Math.max(1, Math.ceil(rows.length / PAGE_SIZE));
  const safePage = Math.min(page, pageCount - 1);
  const displayedRows = useMemo(() => {
    if (rows.length <= PAGE_SIZE) return rows;
    const start = safePage * PAGE_SIZE;
    return rows.slice(start, start + PAGE_SIZE);
  }, [rows, safePage]);

  useEffect(() => {
    if (page !== safePage) setPage(safePage);
  }, [page, safePage]);

  const showSelectColumn = enableBulk && selectMode;

  const selectableRows = useMemo(
    () => displayedRows.filter((r) => Boolean(r.canApprove || r.canReject)),
    [displayedRows],
  );
  const selectableKeys = useMemo(
    () => new Set(selectableRows.map((r) => rowKey(r.id))),
    [selectableRows],
  );

  useEffect(() => {
    setSelected((prev) => {
      const next = new Set<string>();
      prev.forEach((id) => {
        if (selectableKeys.has(id)) next.add(id);
      });
      return next.size === prev.size && [...next].every((id) => prev.has(id)) ? prev : next;
    });
  }, [selectableKeys]);

  useEffect(() => {
    if (!enableBulk) {
      setSelectMode(false);
      setSelected(new Set());
    }
  }, [enableBulk]);

  const selectedRows = useMemo(
    () => displayedRows.filter((r) => selected.has(rowKey(r.id))),
    [displayedRows, selected],
  );
  const allSelected =
    selectableRows.length > 0 && selectableRows.every((r) => selected.has(rowKey(r.id)));
  const someSelected = selected.size > 0 && !allSelected;
  const busy = bulkBusy || actionBusyId != null;

  function exitSelectMode() {
    setSelectMode(false);
    setSelected(new Set());
  }

  function enterSelectMode() {
    setSelectMode(true);
  }

  function toggleOne(id: number | string) {
    const key = rowKey(id);
    if (!selectableKeys.has(key)) return;
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  function selectAll() {
    setSelected(new Set(selectableRows.map((r) => rowKey(r.id))));
  }

  function clearSelection() {
    setSelected(new Set());
  }

  function toggleAll() {
    if (allSelected) clearSelection();
    else selectAll();
  }

  async function runBulk(approved: boolean) {
    const targets = selectedRows.filter((r) => (approved ? r.canApprove : r.canReject));
    if (targets.length === 0) return;
    if (approved) await onBulkApprove?.(targets);
    else await onBulkReject?.(targets);
    clearSelection();
  }

  return (
    <Stack spacing={1.75}>
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={1.25}
        alignItems={{ xs: 'stretch', sm: 'flex-start' }}
        justifyContent="space-between"
      >
        {enableBulk ? (
          <Button
            size="small"
            variant={selectMode ? 'contained' : 'outlined'}
            color={selectMode ? 'primary' : 'inherit'}
            startIcon={selectMode ? <CloseIcon /> : <ChecklistRtlIcon />}
            disabled={busy || (!selectMode && selectableRows.length === 0)}
            onClick={() => (selectMode ? exitSelectMode() : enterSelectMode())}
            sx={{
              alignSelf: { xs: 'flex-start', sm: 'center' },
              borderRadius: 2,
              fontWeight: 700,
              textTransform: 'none',
              px: 1.75,
              whiteSpace: 'nowrap',
              flexShrink: 0,
              ...(selectMode
                ? {}
                : {
                    borderColor: alpha(theme.palette.text.primary, 0.22),
                    bgcolor: alpha(theme.palette.background.paper, 0.9),
                    '&:hover': {
                      borderColor: theme.palette.primary.main,
                      bgcolor: alpha(theme.palette.primary.main, 0.06),
                    },
                  }),
            }}
          >
            {selectMode ? 'Huỷ chọn đơn' : 'Chọn đơn'}
          </Button>
        ) : null}
        {toolbar ? <Box sx={{ flex: 1, minWidth: 0, width: '100%' }}>{toolbar}</Box> : null}
      </Stack>

      {rows.length > PAGE_SIZE ? (
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          spacing={1}
          alignItems={{ xs: 'stretch', sm: 'center' }}
          justifyContent="space-between"
        >
          <Typography variant="caption" color="text.secondary" sx={{ fontWeight: 600 }}>
            Tổng {rows.length} đơn · mỗi tab {PAGE_SIZE} đơn
          </Typography>
          <Tabs
            value={safePage}
            onChange={(_, value: number) => {
              setPage(value);
              setSelected(new Set());
            }}
            variant="scrollable"
            scrollButtons="auto"
            allowScrollButtonsMobile
            sx={{
              minHeight: 36,
              '& .MuiTab-root': {
                minHeight: 36,
                py: 0.5,
                px: 1.5,
                fontSize: '0.8rem',
                fontWeight: 700,
                textTransform: 'none',
              },
            }}
          >
            {Array.from({ length: pageCount }, (_, i) => {
              const from = i * PAGE_SIZE + 1;
              const to = Math.min((i + 1) * PAGE_SIZE, rows.length);
              return <Tab key={i} value={i} label={`${from}–${to}`} />;
            })}
          </Tabs>
        </Stack>
      ) : null}

      {showSelectColumn && selected.size > 0 && (
        <Paper
          elevation={0}
          sx={{
            px: { xs: 1.5, sm: 2 },
            py: 1.25,
            borderRadius: 2.5,
            border: `1px solid ${alpha(theme.palette.primary.main, 0.22)}`,
            bgcolor: alpha(theme.palette.primary.main, 0.05),
            boxShadow: `0 8px 28px ${alpha(theme.palette.primary.main, 0.08)}`,
          }}
        >
          <Stack
            direction={{ xs: 'column', sm: 'row' }}
            spacing={1.25}
            alignItems={{ xs: 'stretch', sm: 'center' }}
            justifyContent="space-between"
          >
            <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
              <Chip
                size="small"
                color="primary"
                label={`Đã chọn ${selected.size} đơn`}
                sx={{ fontWeight: 700, height: 28 }}
              />
              <Button
                size="small"
                variant="text"
                startIcon={<SelectAllIcon />}
                onClick={selectAll}
                disabled={busy || allSelected}
                sx={{ textTransform: 'none', fontWeight: 600 }}
              >
                Chọn tất cả ({selectableRows.length})
              </Button>
              <Button
                size="small"
                variant="text"
                color="inherit"
                startIcon={<DeselectIcon />}
                onClick={clearSelection}
                disabled={busy}
                sx={{ textTransform: 'none', fontWeight: 600 }}
              >
                Bỏ chọn
              </Button>
            </Stack>
            <Stack direction="row" spacing={1} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
              {onBulkReject && (
                <Button
                  size="small"
                  variant="outlined"
                  color="error"
                  startIcon={
                    bulkBusy ? <CircularProgress size={14} color="inherit" /> : <HighlightOffIcon />
                  }
                  disabled={busy || !selectedRows.some((r) => r.canReject)}
                  onClick={() => void runBulk(false)}
                  sx={{ borderRadius: 2, fontWeight: 700, textTransform: 'none' }}
                >
                  Từ chối đã chọn
                </Button>
              )}
              {onBulkApprove && (
                <Button
                  size="small"
                  variant="contained"
                  color="success"
                  startIcon={
                    bulkBusy ? (
                      <CircularProgress size={14} color="inherit" />
                    ) : (
                      <CheckCircleOutlineIcon />
                    )
                  }
                  disabled={busy || !selectedRows.some((r) => r.canApprove)}
                  onClick={() => void runBulk(true)}
                  sx={{ borderRadius: 2, fontWeight: 700, textTransform: 'none', px: 2 }}
                >
                  Duyệt đã chọn
                </Button>
              )}
            </Stack>
          </Stack>
        </Paper>
      )}

      <TableContainer
        component={Paper}
        elevation={0}
        sx={{
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.divider, 1)}`,
          overflow: 'hidden',
          boxShadow: `0 4px 24px ${alpha('#0f172a', 0.05)}`,
        }}
      >
        {loading ? (
          <Box sx={{ py: 6, textAlign: 'center' }}>
            <CircularProgress size={32} />
          </Box>
        ) : rows.length === 0 ? (
          <Box
            sx={{
              py: { xs: 5, sm: 6 },
              px: 2,
              textAlign: 'center',
              bgcolor: alpha(theme.palette.primary.main, 0.02),
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
              {emptyTitle}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 420, mx: 'auto' }}>
              {emptyHint}
            </Typography>
          </Box>
        ) : (
          <Table size="small">
            <TableHead>
              <TableRow
                sx={{
                  bgcolor: alpha(theme.palette.grey[500], 0.07),
                  '& .MuiTableCell-head': {
                    fontWeight: 700,
                    color: 'text.secondary',
                    fontSize: '0.78rem',
                    letterSpacing: '0.02em',
                    borderBottomColor: alpha(theme.palette.divider, 0.9),
                    py: 1.1,
                  },
                }}
              >
                {showSelectColumn && (
                  <TableCell padding="checkbox" sx={{ width: 48 }}>
                    <Tooltip title={allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả đơn có thể duyệt'}>
                      <span>
                        <Checkbox
                          size="small"
                          indeterminate={someSelected}
                          checked={allSelected}
                          disabled={busy || selectableRows.length === 0}
                          onChange={toggleAll}
                          inputProps={{ 'aria-label': 'Chọn tất cả' }}
                        />
                      </span>
                    </Tooltip>
                  </TableCell>
                )}
                <TableCell>Loại đơn</TableCell>
                <TableCell>Người / nội dung</TableCell>
                <TableCell>Phòng ban</TableCell>
                <TableCell>Thông tin</TableCell>
                <TableCell>Ngày yêu cầu</TableCell>
                <TableCell>Ngày gửi đơn</TableCell>
                <TableCell>Trạng thái</TableCell>
                <TableCell align="right" sx={{ width: showReview ? 160 : 88, whiteSpace: 'nowrap' }}>
                  Thao tác
                </TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {displayedRows.map((r) => {
                const rowBusy = actionBusyId != null && actionBusyId === r.id;
                const key = rowKey(r.id);
                const canSelect = showSelectColumn && selectableKeys.has(key);
                const isChecked = selected.has(key);
                return (
                  <TableRow
                    key={key}
                    hover
                    selected={isChecked}
                    sx={{
                      ...(r.pending ? { bgcolor: alpha(theme.palette.warning.main, 0.05) } : null),
                      ...(isChecked
                        ? { bgcolor: `${alpha(theme.palette.primary.main, 0.07)} !important` }
                        : null),
                      '& .MuiTableCell-root': {
                        py: 1.15,
                        borderBottomColor: alpha(theme.palette.divider, 0.7),
                      },
                      '&:last-of-type .MuiTableCell-root': { borderBottom: 0 },
                    }}
                  >
                    {showSelectColumn && (
                      <TableCell padding="checkbox">
                        <Checkbox
                          size="small"
                          checked={isChecked}
                          disabled={busy || !canSelect}
                          onChange={() => toggleOne(r.id)}
                          inputProps={{ 'aria-label': `Chọn đơn ${r.id}` }}
                        />
                      </TableCell>
                    )}
                    <TableCell>
                      <Typography variant="body2" fontWeight={700} noWrap>
                        {r.typeLabel}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" fontWeight={600}>
                        {r.subject}
                      </Typography>
                      {r.meta ? (
                        <Typography variant="caption" color="text.secondary" display="block">
                          {r.meta}
                        </Typography>
                      ) : null}
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary">
                        {r.department?.trim() || '—'}
                      </Typography>
                    </TableCell>
                    <TableCell sx={{ maxWidth: 280 }}>
                      <Typography
                        variant="body2"
                        color="text.secondary"
                        noWrap
                        title={r.summary || undefined}
                      >
                        {r.summary?.trim() || '—'}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" whiteSpace="nowrap">
                        {r.dateLabel || '—'}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Typography variant="body2" color="text.secondary" whiteSpace="nowrap">
                        {r.submittedAtLabel || '—'}
                      </Typography>
                    </TableCell>
                    <TableCell>
                      <Chip
                        size="small"
                        label={r.statusLabel}
                        color={r.statusColor ?? 'default'}
                        variant="outlined"
                        sx={chipSx}
                      />
                    </TableCell>
                    <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                      <Stack
                        direction="row"
                        spacing={0.25}
                        justifyContent="flex-end"
                        alignItems="center"
                        sx={{ width: 'max-content', ml: 'auto' }}
                      >
                        <Tooltip title="Xem chi tiết">
                          <span>
                            <IconButton
                              size="small"
                              color="primary"
                              disabled={rowBusy || bulkBusy}
                              onClick={() => onView(r)}
                              aria-label="Xem chi tiết"
                            >
                              <VisibilityIcon fontSize="small" />
                            </IconButton>
                          </span>
                        </Tooltip>
                        {r.canApprove && onApprove && (
                          <Tooltip title="Duyệt">
                            <span>
                              <IconButton
                                size="small"
                                color="success"
                                disabled={rowBusy || bulkBusy}
                                onClick={() => onApprove(r)}
                                aria-label="Duyệt"
                              >
                                <CheckCircleOutlineIcon fontSize="small" />
                              </IconButton>
                            </span>
                          </Tooltip>
                        )}
                        {r.canReject && onReject && (
                          <Tooltip title="Không duyệt">
                            <span>
                              <IconButton
                                size="small"
                                color="error"
                                disabled={rowBusy || bulkBusy}
                                onClick={() => onReject(r)}
                                aria-label="Không duyệt"
                              >
                                <HighlightOffIcon fontSize="small" />
                              </IconButton>
                            </span>
                          </Tooltip>
                        )}
                      </Stack>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        )}
      </TableContainer>
    </Stack>
  );
}
