import DescriptionIcon from '@mui/icons-material/Description';
import EditNoteIcon from '@mui/icons-material/EditNote';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import PlaylistAddIcon from '@mui/icons-material/PlaylistAdd';
import SwapHorizOutlinedIcon from '@mui/icons-material/SwapHorizOutlined';
import VisibilityIcon from '@mui/icons-material/Visibility';
import { IconButton, Stack, Tooltip, Typography } from '@mui/material';
import type { WorkRequest } from '../../services/attendanceService';

export type AttendanceRow = Record<string, unknown>;

const PENDING = new Set(['PENDING_HEAD', 'PENDING_HR']);

function str(v: unknown): string {
  return v != null && String(v).trim() !== '' ? String(v) : '';
}

function num(v: unknown): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

function endOfMonthIso(fromIso?: string): string {
  const base = fromIso ? new Date(`${fromIso}T12:00:00`) : new Date();
  const y = base.getFullYear();
  const m = base.getMonth();
  const last = new Date(y, m + 1, 0);
  return last.toISOString().slice(0, 10);
}

/** Cho phép mọi ngày đã qua; ngày tương lai chỉ trong tháng hiện tại. */
export function canDeployOnDate(workDate: string): boolean {
  const today = todayIso();
  if (workDate <= today) return true;
  return workDate <= endOfMonthIso(today);
}

/** Ngày chưa chấm / thiếu ca cần đơn cập nhật công. */
export function rowNeedsUpdate(row: AttendanceRow | null, workDate?: string): boolean {
  if (workDate && workDate > todayIso()) return false;
  if (!row) return true;
  const status = str(row.status);
  if (status === 'ABSENT' || status === 'PARTIAL') return true;
  if (str(row.forgotShifts)) return true;
  const total = num(row.totalWorkUnits);
  if (total > 0 && total < 0.99) return true;
  const hasPunch =
    str(row.morningCheckIn) ||
    str(row.morningCheckOut) ||
    str(row.afternoonCheckIn) ||
    str(row.afternoonCheckOut) ||
    str(row.checkIn) ||
    str(row.checkOut);
  return !hasPunch && total === 0;
}

/** Có phút muộn/về sớm tính phạt — được gửi giải trình. */
export function rowCanExplain(row: AttendanceRow | null): boolean {
  if (!row) return false;
  if (row.lateMinutesExempt) return false;
  return num(row.lateMinutes) > 0;
}

function hasPending(requests: WorkRequest[], workDate: string, type: WorkRequest['requestType']) {
  return requests.some(
    (r) => r.workDate === workDate && r.requestType === type && PENDING.has(r.status),
  );
}

type Props = {
  row: AttendanceRow | null;
  workDate: string;
  requests: WorkRequest[];
  canSubmit: boolean;
  canManageSupplement?: boolean;
  canManageDuty?: boolean;
  canCreateDeployment?: boolean;
  hasDutyShift?: boolean;
  onDetail: (date: string) => void;
  onExplain: (date: string) => void;
  onUpdate: (date: string) => void;
  onSupplement?: (date: string) => void;
  onDutyShift?: (date: string) => void;
  onDeployment?: (date: string) => void;
};

const SUBMIT_HINT =
  'Chỉ nhân viên đang xem bảng công của chính mình (tài khoản đã gắn hồ sơ) mới gửi được đơn.';

const iconBtnSx = { p: 0.5 };

export function AttendanceRowActions({
  row,
  workDate,
  requests,
  canSubmit,
  canManageSupplement = false,
  canManageDuty = false,
  canCreateDeployment = false,
  hasDutyShift = false,
  onDetail,
  onExplain,
  onUpdate,
  onSupplement,
  onDutyShift,
  onDeployment,
}: Props) {
  const needsUpdate = rowNeedsUpdate(row, workDate);
  const canExplain = rowCanExplain(row);
  const pendingUpdate = hasPending(requests, workDate, 'UPDATE');
  const pendingExplain = hasPending(requests, workDate, 'EXPLANATION');
  const showDeployment = canCreateDeployment && onDeployment && canDeployOnDate(workDate);

  return (
    <Stack
      direction="row"
      spacing={0}
      alignItems="center"
      justifyContent="flex-end"
      sx={{ flexWrap: 'nowrap', minWidth: 'max-content' }}
    >
      <Tooltip title="Chi tiết chấm công">
        <IconButton size="small" onClick={() => onDetail(workDate)} sx={iconBtnSx} aria-label="Chi tiết">
          <VisibilityIcon sx={{ fontSize: 18 }} />
        </IconButton>
      </Tooltip>

      {needsUpdate &&
        (pendingUpdate ? (
          <Tooltip title="Đã gửi đơn cập nhật">
            <Typography variant="caption" color="text.secondary" sx={{ px: 0.5, whiteSpace: 'nowrap' }}>
              Đã gửi
            </Typography>
          </Tooltip>
        ) : (
          <Tooltip title={!canSubmit ? SUBMIT_HINT : 'Cập nhật / quên chấm công'}>
            <span>
              <IconButton
                size="small"
                onClick={() => onUpdate(workDate)}
                disabled={!canSubmit}
                sx={iconBtnSx}
                aria-label="Cập nhật"
                color="warning"
              >
                <EditNoteIcon sx={{ fontSize: 18 }} />
              </IconButton>
            </span>
          </Tooltip>
        ))}

      {canManageSupplement && onSupplement && (
        <Tooltip
          title={
            hasDutyShift
              ? 'Sửa / bổ sung công trực & Quang Trung'
              : 'Bổ sung hoặc sửa công trực / Quang Trung'
          }
        >
          <IconButton
            size="small"
            onClick={() => onSupplement(workDate)}
            sx={iconBtnSx}
            aria-label="Bổ sung công"
            color={hasDutyShift ? 'secondary' : 'primary'}
          >
            <PlaylistAddIcon sx={{ fontSize: 18 }} />
          </IconButton>
        </Tooltip>
      )}

      {canManageDuty && !canManageSupplement && onDutyShift && (
        <Tooltip title={hasDutyShift ? 'Sửa ca trực' : 'Bổ sung ca trực'}>
          <IconButton
            size="small"
            onClick={() => onDutyShift(workDate)}
            sx={iconBtnSx}
            aria-label="Ca trực"
            color={hasDutyShift ? 'secondary' : 'primary'}
          >
            <NightsStayIcon sx={{ fontSize: 18 }} />
          </IconButton>
        </Tooltip>
      )}

      {showDeployment && (
        <Tooltip title="Điều động nhân sự (trong ca ×1,5 hoặc ngoài ca)">
          <IconButton
            size="small"
            onClick={() => onDeployment(workDate)}
            sx={iconBtnSx}
            aria-label="Điều động"
            color="info"
          >
            <SwapHorizOutlinedIcon sx={{ fontSize: 18 }} />
          </IconButton>
        </Tooltip>
      )}

      {canExplain &&
        (pendingExplain ? (
          <Tooltip title="Chờ duyệt giải trình">
            <Typography variant="caption" color="text.secondary" sx={{ px: 0.5, whiteSpace: 'nowrap' }}>
              GT
            </Typography>
          </Tooltip>
        ) : (
          <Tooltip title={!canSubmit ? SUBMIT_HINT : 'Giải trình muộn / về sớm'}>
            <span>
              <IconButton
                size="small"
                onClick={() => onExplain(workDate)}
                disabled={!canSubmit}
                sx={iconBtnSx}
                aria-label="Giải trình"
              >
                <DescriptionIcon sx={{ fontSize: 18 }} />
              </IconButton>
            </span>
          </Tooltip>
        ))}
    </Stack>
  );
}
