import ArrowForwardRoundedIcon from '@mui/icons-material/ArrowForwardRounded';
import EditNoteOutlinedIcon from '@mui/icons-material/EditNoteOutlined';
import InsightsOutlinedIcon from '@mui/icons-material/InsightsOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import EditOutlinedIcon from '@mui/icons-material/EditOutlined';
import PendingActionsOutlinedIcon from '@mui/icons-material/PendingActionsOutlined';
import RefreshOutlinedIcon from '@mui/icons-material/RefreshOutlined';
import {
  Alert,
  Box,
  Chip,
  CircularProgress,
  IconButton,
  LinearProgress,
  Paper,
  Stack,
  Tab,
  Tabs,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { PageHeader } from '../components/layout/PageHeader';
import { NursingDailyReportDialog } from '../components/nursingDaily/NursingDailyReportDialog';
import { NursingDailyReportViewDialog } from '../components/nursingDaily/NursingDailyReportViewDialog';
import { ModuleAReportsPanel } from '../components/nursingDaily/moduleA/ModuleAReportsPanel';
import { pageTabsSx, panelPaperSx } from '../components/nursingDaily/moduleA/moduleAUiStyles';
import { DatePickerField, MonthPickerField } from '../components/ui/DateTimeFields';
import { useAuth } from '../context/AuthContext';
import { extractApiErrorMessage } from '../services/approvalSignatureService';
import * as ndr from '../services/nursingDailyReportService';

const ACCENT = '#0f766e';
const WEEKDAYS = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'] as const;

function todayIso() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function currentYearMonth() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

function formatDate(iso: string) {
  const [y, m, d] = iso.split('-');
  return y && m && d ? `${d}/${m}/${y}` : iso;
}

function weekdayIndexMonFirst(iso: string) {
  const [y, m, d] = iso.split('-').map(Number);
  if (!y || !m || !d) return 0;
  const js = new Date(y, m - 1, d).getDay(); // 0=CN
  return js === 0 ? 6 : js - 1;
}

function StatPill({
  icon,
  label,
  value,
  color,
}: {
  icon: ReactNode;
  label: string;
  value: number;
  color: string;
}) {
  return (
    <Box
      sx={{
        display: 'flex',
        alignItems: 'center',
        gap: 1.1,
        px: 1.5,
        py: 0.85,
        borderRadius: 2,
        bgcolor: alpha(color, 0.07),
        border: `1px solid ${alpha(color, 0.14)}`,
        minWidth: 132,
      }}
    >
      <Box
        sx={{
          width: 28,
          height: 28,
          borderRadius: 1.25,
          display: 'grid',
          placeItems: 'center',
          bgcolor: alpha(color, 0.14),
          color,
          flexShrink: 0,
        }}
      >
        {icon}
      </Box>
      <Box sx={{ minWidth: 0 }}>
        <Typography variant="caption" color="text.secondary" sx={{ display: 'block', lineHeight: 1.15, fontSize: '0.68rem' }}>
          {label}
        </Typography>
        <Typography variant="subtitle1" fontWeight={800} sx={{ lineHeight: 1.1, letterSpacing: '-0.03em', color }}>
          {value}
        </Typography>
      </Box>
    </Box>
  );
}

/** Ô ngày trên lịch tháng — gọn, rõ trạng thái. */
function MonthDayCell({
  row,
  isToday,
  onOpen,
}: {
  row: ndr.NursingDailyReportDayRow;
  isToday: boolean;
  onOpen: () => void;
}) {
  const theme = useTheme();
  const submitted = row.submitted;
  const report = row.report;
  const tone = submitted ? theme.palette.success.main : theme.palette.warning.dark;
  const dayNum = Number(row.reportDate.split('-')[2]);

  return (
    <Box
      component="button"
      type="button"
      onClick={onOpen}
      sx={{
        all: 'unset',
        cursor: 'pointer',
        display: 'flex',
        flexDirection: 'column',
        minHeight: { xs: 96, sm: 108 },
        p: 1.15,
        borderRadius: 2,
        bgcolor: submitted ? alpha(theme.palette.success.main, 0.05) : '#fff',
        border: `1px solid ${
          isToday ? alpha(ACCENT, 0.45) : submitted ? alpha(theme.palette.success.main, 0.22) : alpha(tone, 0.28)
        }`,
        boxShadow: isToday ? `0 0 0 2px ${alpha(ACCENT, 0.12)}` : 'none',
        transition: 'transform 0.12s ease, box-shadow 0.12s ease, border-color 0.12s ease',
        '&:hover': {
          transform: 'translateY(-1px)',
          boxShadow: `0 8px 20px ${alpha('#0f172a', 0.07)}`,
          borderColor: alpha(ACCENT, 0.4),
        },
        '&:focus-visible': {
          outline: `2px solid ${alpha(ACCENT, 0.45)}`,
          outlineOffset: 2,
        },
      }}
    >
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" sx={{ mb: 0.75 }}>
        <Typography
          fontWeight={850}
          sx={{
            fontSize: '1.15rem',
            lineHeight: 1,
            letterSpacing: '-0.04em',
            color: isToday ? ACCENT : 'text.primary',
          }}
        >
          {dayNum}
        </Typography>
        <Box
          sx={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            mt: 0.35,
            bgcolor: tone,
            boxShadow: `0 0 0 3px ${alpha(tone, 0.18)}`,
          }}
        />
      </Stack>

      <Typography
        variant="caption"
        fontWeight={750}
        sx={{ color: tone, letterSpacing: '0.02em', lineHeight: 1.2 }}
      >
        {submitted ? 'Đã nộp' : 'Chưa nộp'}
      </Typography>

      {report ? (
        <Typography variant="caption" color="text.secondary" sx={{ mt: 0.55, lineHeight: 1.35 }}>
          NV {report.workingStaff}/{report.totalStaff}
          {' · '}
          NT {report.inpatients}
        </Typography>
      ) : (
        <Typography variant="caption" color="text.secondary" sx={{ mt: 0.55, lineHeight: 1.35 }}>
          Nhấn để nhập
        </Typography>
      )}

      <Stack direction="row" alignItems="center" spacing={0.35} sx={{ mt: 'auto', pt: 0.75, color: ACCENT }}>
        <Typography variant="caption" fontWeight={750} sx={{ fontSize: '0.68rem' }}>
          {submitted ? 'Xem báo cáo' : 'Nhập'}
        </Typography>
        <ArrowForwardRoundedIcon sx={{ fontSize: 14 }} />
      </Stack>
    </Box>
  );
}

function DeptCard({ row, onOpen }: { row: ndr.NursingDailyReportDayRow; onOpen: () => void }) {
  const theme = useTheme();
  const submitted = row.submitted;
  const report = row.report;
  const tone = submitted ? theme.palette.success.main : theme.palette.warning.dark;

  return (
    <Box
      component="button"
      type="button"
      onClick={onOpen}
      sx={{
        all: 'unset',
        cursor: 'pointer',
        display: 'flex',
        flexDirection: 'column',
        minHeight: 148,
        p: 1.5,
        borderRadius: 2.25,
        bgcolor: submitted ? alpha(theme.palette.success.main, 0.04) : '#fff',
        border: `1px solid ${submitted ? alpha(theme.palette.success.main, 0.2) : alpha(tone, 0.26)}`,
        boxShadow: `inset 3px 0 0 ${tone}`,
        transition: 'transform 0.12s ease, box-shadow 0.12s ease, border-color 0.12s ease',
        '&:hover': {
          transform: 'translateY(-2px)',
          boxShadow: `inset 3px 0 0 ${tone}, 0 10px 24px ${alpha('#0f172a', 0.08)}`,
          borderColor: alpha(ACCENT, 0.35),
        },
        '&:focus-visible': {
          outline: `2px solid ${alpha(ACCENT, 0.45)}`,
          outlineOffset: 2,
        },
      }}
    >
      <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
        <Box sx={{ minWidth: 0, flex: 1 }}>
          <Typography
            variant="subtitle2"
            fontWeight={800}
            sx={{
              lineHeight: 1.3,
              letterSpacing: '-0.01em',
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
              overflow: 'hidden',
            }}
          >
            {row.departmentName}
          </Typography>
        </Box>
        <Box
          sx={{
            flexShrink: 0,
            px: 0.85,
            py: 0.35,
            borderRadius: 1.25,
            bgcolor: alpha(tone, 0.12),
            border: `1px solid ${alpha(tone, 0.16)}`,
          }}
        >
          <Typography variant="caption" fontWeight={800} sx={{ color: tone, lineHeight: 1.2, fontSize: '0.68rem' }}>
            {submitted ? 'Đã nộp' : 'Chưa nộp'}
          </Typography>
        </Box>
      </Stack>

      {report ? (
        <Box
          sx={{
            mt: 1.15,
            display: 'grid',
            gridTemplateColumns: 'repeat(3, 1fr)',
            gap: 0.65,
            flex: 1,
          }}
        >
          {[
            { k: 'NV', v: `${report.workingStaff}/${report.totalStaff}` },
            { k: 'Nội trú', v: String(report.inpatients) },
            { k: 'Giường', v: `${report.actualBeds}/${report.plannedBeds}` },
          ].map((m) => (
            <Box
              key={m.k}
              sx={{
                px: 0.75,
                py: 0.65,
                borderRadius: 1.5,
                bgcolor: alpha('#0f172a', 0.03),
                border: `1px solid ${alpha('#0f172a', 0.05)}`,
                textAlign: 'center',
              }}
            >
              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', fontSize: '0.62rem', lineHeight: 1.2 }}>
                {m.k}
              </Typography>
              <Typography variant="body2" fontWeight={800} sx={{ letterSpacing: '-0.02em', lineHeight: 1.25, color: ACCENT }}>
                {m.v}
              </Typography>
            </Box>
          ))}
        </Box>
      ) : (
        <Typography variant="caption" color="text.secondary" sx={{ mt: 1.15, flex: 1, lineHeight: 1.45 }}>
          Chưa có số liệu — nhấn để nhập (mặc định 0).
        </Typography>
      )}

      <Stack direction="row" alignItems="center" justifyContent="space-between" sx={{ mt: 'auto', pt: 1.15 }}>
        <Box
          sx={{
            display: 'inline-flex',
            alignItems: 'center',
            gap: 0.5,
            px: 1.15,
            py: 0.55,
            borderRadius: 1.5,
            bgcolor: submitted ? 'transparent' : ACCENT,
            color: submitted ? ACCENT : '#fff',
            border: submitted ? `1px solid ${alpha(ACCENT, 0.3)}` : 'none',
            fontWeight: 750,
            fontSize: '0.72rem',
          }}
        >
          {submitted ? <EditOutlinedIcon sx={{ fontSize: 14 }} /> : null}
          {submitted ? 'Xem báo cáo' : row.hasDraft ? 'Tiếp tục nhập' : 'Nhập báo cáo'}
        </Box>
        <ArrowForwardRoundedIcon sx={{ fontSize: 16, color: ACCENT, opacity: 0.7 }} />
      </Stack>
    </Box>
  );
}

export default function NursingDailyReportsPage() {
  const theme = useTheme();
  const { user } = useAuth();
  const monthTracking = user?.role === 'HEAD_DEPARTMENT';

  const [date, setDate] = useState(todayIso());
  const [yearMonth, setYearMonth] = useState(currentYearMonth());
  const [rows, setRows] = useState<ndr.NursingDailyReportDayRow[]>([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [viewRow, setViewRow] = useState<ndr.NursingDailyReportDayRow | null>(null);
  const [editRow, setEditRow] = useState<ndr.NursingDailyReportDayRow | null>(null);
  const [pageTab, setPageTab] = useState<'entry' | 'module-a'>('entry');

  function openRow(row: ndr.NursingDailyReportDayRow) {
    if (row.submitted && row.report) {
      setViewRow(row);
      setEditRow(null);
      return;
    }
    // Nháp hoặc chưa có → mở form nhập/sửa
    setViewRow(null);
    setEditRow(row);
  }

  const reload = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      const data = monthTracking
        ? await ndr.fetchNursingDailyMonthRows(yearMonth)
        : await ndr.fetchNursingDailyDayRows(date);
      setRows(data);
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Không tải được danh sách báo cáo.'));
      setRows([]);
    } finally {
      setLoading(false);
    }
  }, [date, yearMonth, monthTracking]);

  useEffect(() => {
    void reload();
  }, [reload]);

  const submittedCount = useMemo(() => rows.filter((r) => r.submitted).length, [rows]);
  const pendingCount = rows.length - submittedCount;
  const progressPct = rows.length === 0 ? 0 : Math.round((submittedCount / rows.length) * 100);
  const today = todayIso();
  const deptName = rows[0]?.departmentName;

  const calendarCells = useMemo(() => {
    if (!monthTracking || rows.length === 0) return [];
    const first = rows[0].reportDate;
    const pad = weekdayIndexMonFirst(first);
    const cells: Array<ndr.NursingDailyReportDayRow | null> = Array.from({ length: pad }, () => null);
    for (const r of rows) cells.push(r);
    while (cells.length % 7 !== 0) cells.push(null);
    return cells;
  }, [monthTracking, rows]);

  const officeRows = useMemo(() => {
    if (monthTracking) return rows;
    return [...rows].sort((a, b) => {
      if (a.submitted !== b.submitted) return a.submitted ? 1 : -1;
      return a.departmentName.localeCompare(b.departmentName, 'vi');
    });
  }, [monthTracking, rows]);

  return (
    <Box>
      <PageHeader
        overline="Điều dưỡng"
        title="Báo cáo điều dưỡng hằng ngày"
        description={
          monthTracking
            ? 'Chọn tháng để theo dõi từng ngày đến hôm nay — ngày chưa nộp sẽ nổi bật để nhập kịp.'
            : 'Điều dưỡng trưởng khoa nhập 01 phiếu / khoa / ngày. Trưởng phòng Điều dưỡng xem và chỉnh sửa toàn bộ phiếu khối ĐD.'
        }
      />

      <Box sx={{ mb: 2.5 }}>
        <Tabs
          value={pageTab}
          onChange={(_, v) => setPageTab(v)}
          variant="scrollable"
          scrollButtons="auto"
          allowScrollButtonsMobile
          sx={pageTabsSx()}
        >
          <Tab
            value="entry"
            icon={<EditNoteOutlinedIcon />}
            iconPosition="start"
            label="Nhập báo cáo hằng ngày"
          />
          <Tab
            value="module-a"
            icon={<InsightsOutlinedIcon />}
            iconPosition="start"
            label="Báo cáo hoạt động điều dưỡng"
          />
        </Tabs>
      </Box>

      {pageTab === 'module-a' ? (
        <ModuleAReportsPanel />
      ) : (
        <>
      <Paper
        elevation={0}
        sx={{
          mb: 2.25,
          borderRadius: 3,
          border: `1px solid ${alpha('#0f172a', 0.08)}`,
          bgcolor: '#fff',
          overflow: 'hidden',
        }}
      >
        <Stack
          direction={{ xs: 'column', md: 'row' }}
          spacing={1.5}
          alignItems={{ md: 'center' }}
          justifyContent="space-between"
          sx={{ px: { xs: 1.5, sm: 2 }, py: 1.5 }}
        >
          <Stack direction="row" spacing={1.15} alignItems="center" flexWrap="wrap" useFlexGap>
            {monthTracking ? (
              <MonthPickerField
                label="Tháng báo cáo"
                value={yearMonth}
                onChange={setYearMonth}
                size="small"
                sx={{ minWidth: 190 }}
              />
            ) : (
              <DatePickerField
                label="Ngày báo cáo"
                value={date}
                onChange={setDate}
                size="small"
                sx={{ minWidth: 190 }}
              />
            )}
            <Tooltip title="Tải lại">
              <span>
                <IconButton
                  onClick={() => void reload()}
                  disabled={loading}
                  size="small"
                  sx={{
                    border: `1px solid ${alpha(ACCENT, 0.25)}`,
                    color: ACCENT,
                    borderRadius: 1.75,
                  }}
                >
                  <RefreshOutlinedIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>
            {monthTracking && deptName ? (
              <Chip
                size="small"
                label={deptName}
                sx={{
                  fontWeight: 700,
                  bgcolor: alpha(ACCENT, 0.08),
                  color: ACCENT,
                  border: `1px solid ${alpha(ACCENT, 0.16)}`,
                  maxWidth: 280,
                }}
              />
            ) : !monthTracking ? (
              <Chip
                size="small"
                label={formatDate(date)}
                sx={{
                  fontWeight: 700,
                  bgcolor: alpha(ACCENT, 0.08),
                  color: ACCENT,
                  border: `1px solid ${alpha(ACCENT, 0.16)}`,
                }}
              />
            ) : null}
          </Stack>
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <StatPill
              icon={<CheckCircleOutlineIcon sx={{ fontSize: 16 }} />}
              label="Đã nộp"
              value={submittedCount}
              color={theme.palette.success.main}
            />
            <StatPill
              icon={<PendingActionsOutlinedIcon sx={{ fontSize: 16 }} />}
              label="Chưa nộp"
              value={pendingCount}
              color={theme.palette.warning.main}
            />
          </Stack>
        </Stack>

        {rows.length > 0 && (
          <Box sx={{ px: { xs: 1.5, sm: 2 }, pb: 1.5 }}>
            <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 0.65 }}>
              <Typography variant="caption" color="text.secondary" fontWeight={650}>
                {monthTracking ? 'Tiến độ tháng' : 'Tiến độ trong ngày'}
              </Typography>
              <Typography variant="caption" fontWeight={800} sx={{ color: ACCENT }}>
                {submittedCount}/{rows.length} · {progressPct}%
              </Typography>
            </Stack>
            <LinearProgress
              variant="determinate"
              value={progressPct}
              sx={{
                height: 7,
                borderRadius: 99,
                bgcolor: alpha(theme.palette.warning.main, 0.15),
                '& .MuiLinearProgress-bar': {
                  borderRadius: 99,
                  bgcolor: ACCENT,
                },
              }}
            />
          </Box>
        )}
      </Paper>

      {err && (
        <Alert severity="error" sx={{ mb: 2, borderRadius: 2 }}>
          {err}
        </Alert>
      )}

      {loading && rows.length === 0 ? (
        <Box sx={{ py: 8, textAlign: 'center' }}>
          <CircularProgress size={32} sx={{ color: ACCENT }} />
        </Box>
      ) : rows.length === 0 ? (
        <Alert severity="info" sx={{ borderRadius: 2 }}>
          {monthTracking
            ? 'Không có ngày nào trong tháng này (hoặc tháng chưa tới).'
            : 'Không có khoa nào trong khối Điều dưỡng để lập báo cáo.'}
        </Alert>
      ) : monthTracking ? (
        <Paper
          elevation={0}
          sx={{
            p: { xs: 1.25, sm: 1.75 },
            borderRadius: 3,
            border: `1px solid ${alpha('#0f172a', 0.07)}`,
            bgcolor: alpha('#f8fafc', 0.9),
          }}
        >
          <Box
            sx={{
              display: 'grid',
              gridTemplateColumns: 'repeat(7, minmax(0, 1fr))',
              gap: { xs: 0.65, sm: 0.9 },
              mb: 0.9,
            }}
          >
            {WEEKDAYS.map((w) => (
              <Typography
                key={w}
                variant="caption"
                fontWeight={800}
                color="text.secondary"
                sx={{ textAlign: 'center', letterSpacing: '0.06em', fontSize: '0.68rem' }}
              >
                {w}
              </Typography>
            ))}
          </Box>
          <Box
            sx={{
              display: 'grid',
              gridTemplateColumns: 'repeat(7, minmax(0, 1fr))',
              gap: { xs: 0.65, sm: 0.9 },
            }}
          >
            {calendarCells.map((cell, idx) =>
              cell ? (
                <MonthDayCell
                  key={`${cell.departmentId}-${cell.reportDate}`}
                  row={cell}
                  isToday={cell.reportDate === today}
                  onOpen={() => openRow(cell)}
                />
              ) : (
                <Box
                  key={`pad-${idx}`}
                  sx={{
                    minHeight: { xs: 96, sm: 108 },
                    borderRadius: 2,
                    bgcolor: alpha('#0f172a', 0.015),
                    border: `1px dashed ${alpha('#0f172a', 0.05)}`,
                  }}
                />
              ),
            )}
          </Box>
          <Stack direction="row" spacing={2} sx={{ mt: 1.5, px: 0.25 }} flexWrap="wrap" useFlexGap>
            <Stack direction="row" spacing={0.75} alignItems="center">
              <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: theme.palette.warning.dark }} />
              <Typography variant="caption" color="text.secondary">
                Chưa nộp
              </Typography>
            </Stack>
            <Stack direction="row" spacing={0.75} alignItems="center">
              <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: theme.palette.success.main }} />
              <Typography variant="caption" color="text.secondary">
                Đã nộp
              </Typography>
            </Stack>
            <Stack direction="row" spacing={0.75} alignItems="center">
              <Box
                sx={{
                  width: 14,
                  height: 10,
                  borderRadius: 0.75,
                  border: `1.5px solid ${alpha(ACCENT, 0.45)}`,
                }}
              />
              <Typography variant="caption" color="text.secondary">
                Hôm nay
              </Typography>
            </Stack>
          </Stack>
        </Paper>
      ) : (
        <Paper
          elevation={0}
          sx={{
            p: { xs: 1.25, sm: 1.75 },
            borderRadius: 3,
            border: `1px solid ${alpha('#0f172a', 0.07)}`,
            bgcolor: alpha('#f8fafc', 0.9),
          }}
        >
          <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mb: 1.25 }} flexWrap="wrap" useFlexGap spacing={1}>
            <Typography variant="subtitle2" fontWeight={800} sx={{ letterSpacing: '-0.01em' }}>
              Khoa khối Điều dưỡng
            </Typography>
            <Stack direction="row" spacing={1.75} flexWrap="wrap" useFlexGap>
              <Stack direction="row" spacing={0.65} alignItems="center">
                <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: theme.palette.warning.dark }} />
                <Typography variant="caption" color="text.secondary">
                  Chưa nộp trước
                </Typography>
              </Stack>
              <Stack direction="row" spacing={0.65} alignItems="center">
                <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: theme.palette.success.main }} />
                <Typography variant="caption" color="text.secondary">
                  Đã nộp
                </Typography>
              </Stack>
            </Stack>
          </Stack>
          <Box
            sx={{
              display: 'grid',
              gridTemplateColumns: {
                xs: '1fr',
                sm: '1fr 1fr',
                md: 'repeat(3, 1fr)',
                lg: 'repeat(4, 1fr)',
              },
              gap: 1.15,
            }}
          >
            {officeRows.map((row) => (
              <DeptCard
                key={`${row.departmentId}-${row.reportDate}`}
                row={row}
                onOpen={() => openRow(row)}
              />
            ))}
          </Box>
        </Paper>
      )}
        </>
      )}

      {viewRow?.report && !editRow && (
        <NursingDailyReportViewDialog
          open
          report={viewRow.report}
          onClose={() => setViewRow(null)}
          onEdit={
            viewRow.report.canEdit
              ? () => {
                  setEditRow(viewRow);
                }
              : undefined
          }
          onRecalled={() => {
            void reload();
            setViewRow(null);
          }}
        />
      )}

      {editRow && (
        <NursingDailyReportDialog
          open
          onClose={() => {
            setEditRow(null);
            // Giữ trang xem nếu đang sửa phiếu đã nộp
          }}
          onSaved={() => {
            void reload();
            setEditRow(null);
            setViewRow(null);
          }}
          departmentId={editRow.departmentId}
          departmentName={editRow.departmentName}
          reportDate={editRow.reportDate}
          existing={editRow.report}
        />
      )}
    </Box>
  );
}
