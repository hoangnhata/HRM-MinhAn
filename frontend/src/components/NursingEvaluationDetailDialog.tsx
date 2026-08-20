import AssessmentIcon from '@mui/icons-material/Assessment';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { Fragment, useEffect, useMemo, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { isHeadDepartmentRole } from '../utils/roleAccess';
import * as ne from '../services/nursingEvaluationService';
import { ensureHasSignature, extractApiErrorMessage } from '../services/approvalSignatureService';
import {
  FormSection,
  InfoBanner,
  WorkRequestViewShell,
  detailHeaderChipSx,
} from './work/WorkRequestFormUi';
import { ApprovalReviewNoteCard } from './ApprovalReviewNoteCard';

type Props = {
  open: boolean;
  evaluationId: number | null;
  onClose: () => void;
  onChanged?: () => void;
  canNursingHeadReview?: boolean;
  canHrReview?: boolean;
  canDirectorReview?: boolean;
  canCancel?: boolean;
};

export type NursingDetailEditRequest = {
  employeeId: number;
  periodYear: number;
  periodMonth: number;
};

function formatTs(iso?: string | null) {
  if (!iso) return '';
  try {
    return new Intl.DateTimeFormat('vi-VN', {
      dateStyle: 'short',
      timeStyle: 'short',
      timeZone: 'Asia/Ho_Chi_Minh',
    }).format(new Date(iso));
  } catch {
    return iso;
  }
}

function scorePoints(
  scores: Record<string, Record<string, unknown>>,
  criterionId: string,
): string {
  const part = scores[criterionId];
  if (!part) return '—';
  const pts = part.points ?? part.truongKhoa ?? part.ddt;
  return pts != null && pts !== '' ? String(pts) : '—';
}

function scoreNote(
  scores: Record<string, Record<string, unknown>>,
  criterionId: string,
): string {
  const part = scores[criterionId];
  if (!part) return '';
  const note = part.note ?? part.truongKhoaNote;
  return note != null ? String(note) : '';
}

export function NursingEvaluationDetailDialog({
  open,
  evaluationId,
  onClose,
  onChanged,
  canNursingHeadReview = false,
  canHrReview = false,
  canDirectorReview = false,
  canCancel = false,
}: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const [row, setRow] = useState<ne.NursingEvalRow | null>(null);
  const [template, setTemplate] = useState<ne.NursingTemplate | null>(null);
  const [loading, setLoading] = useState(false);
  const [acting, setActing] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [comment, setComment] = useState('');

  useEffect(() => {
    if (!open || evaluationId == null) return;
    let active = true;
    setLoading(true);
    setErr(null);
    Promise.all([
      ne.fetchNursingEvaluationRecord(evaluationId),
      ne.fetchNursingTemplate(ne.MA2026_EVAL_TEMPLATE_CODE),
    ])
      .then(([d, tpl]) => {
        if (!active) return;
        setRow(d);
        setTemplate(tpl);
        setComment('');
      })
      .catch((e) => setErr(extractApiErrorMessage(e, 'Không tải được phiếu.')))
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [open, evaluationId]);

  const status = row?.status != null ? String(row.status) : '';
  const reviewLocked = status === 'APPROVED' || status === 'CANCELLED';
  const nursingHeadPending = status === 'PENDING_NURSING_HEAD';
  const hrPending = status === 'PENDING_HR';
  const directorPending = status === 'PENDING_DIRECTOR';
  const showNursingHead =
    canNursingHeadReview && !reviewLocked && (nursingHeadPending || Boolean(row?.headReviewedAt));
  const showHr =
    canHrReview && !reviewLocked && (hrPending || Boolean(row?.hrReviewedAt));
  const showDirector =
    canDirectorReview && !reviewLocked && (directorPending || Boolean(row?.directorReviewedAt));
  const showCancel =
    (canCancel || user?.role === 'ADMIN' || isHeadDepartmentRole(user?.role)) &&
    row != null &&
    status !== 'CANCELLED';

  const accent = theme.palette.primary.main;
  const groups = template?.criteriaGroups ?? [];
  const scores = (row?.scores && typeof row.scores === 'object' ? row.scores : {}) as Record<
    string,
    Record<string, unknown>
  >;

  const sections = useMemo(() => {
    const map = new Map<string, ne.CriterionGroup[]>();
    for (const g of groups) {
      const key = g.section || 'Khác';
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(g);
    }
    return [...map.entries()];
  }, [groups]);

  async function review(step: 'nursing-head' | 'hr' | 'director', approved: boolean) {
    if (!row?.id) return;
    setActing(true);
    setErr(null);
    try {
      await ensureHasSignature();
      if (step === 'nursing-head') {
        await ne.nursingHeadReviewNursingEvaluation(Number(row.id), approved, comment || undefined);
      } else if (step === 'hr') {
        await ne.hrReviewNursingEvaluation(Number(row.id), approved, comment || undefined);
      } else {
        await ne.directorReviewNursingEvaluation(Number(row.id), approved, comment || undefined);
      }
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Duyệt thất bại.'));
    } finally {
      setActing(false);
    }
  }

  async function handleCancel() {
    if (!row?.id || !window.confirm('Thu hồi phiếu đánh giá này?')) return;
    setActing(true);
    try {
      await ne.cancelNursingEvaluation(Number(row.id));
      onChanged?.();
      onClose();
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Thu hồi thất bại.'));
    } finally {
      setActing(false);
    }
  }

  const footer = (
    <Box sx={{ px: 2.5, py: 2, borderTop: `1px solid ${theme.palette.divider}` }}>
      <Stack direction="row" spacing={1.25} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
        {showCancel && (
          <Button color="error" variant="outlined" disabled={acting} onClick={() => void handleCancel()} sx={{ mr: 'auto' }}>
            Thu hồi
          </Button>
        )}
        <Button onClick={onClose} disabled={acting} variant="outlined">
          Đóng
        </Button>
        {showNursingHead && nursingHeadPending && (
          <>
            <Button color="error" variant="outlined" disabled={acting} onClick={() => void review('nursing-head', false)}>
              Từ chối
            </Button>
            <Button
              variant="contained"
              disabled={acting}
              onClick={() => void review('nursing-head', true)}
              sx={{ bgcolor: accent, fontWeight: 800 }}
            >
              Duyệt — chuyển HCNS
            </Button>
          </>
        )}
        {showHr && hrPending && (
          <>
            <Button color="error" variant="outlined" disabled={acting} onClick={() => void review('hr', false)}>
              Từ chối
            </Button>
            <Button
              variant="contained"
              disabled={acting}
              onClick={() => void review('hr', true)}
              sx={{ bgcolor: accent, fontWeight: 800 }}
            >
              Duyệt — chuyển Giám đốc
            </Button>
          </>
        )}
        {showDirector && directorPending && (
          <>
            <Button color="error" variant="outlined" disabled={acting} onClick={() => void review('director', false)}>
              Từ chối
            </Button>
            <Button
              variant="contained"
              disabled={acting}
              onClick={() => void review('director', true)}
              sx={{ bgcolor: accent, fontWeight: 800 }}
            >
              Duyệt cuối
            </Button>
          </>
        )}
      </Stack>
    </Box>
  );

  return (
    <WorkRequestViewShell
      open={open}
      onClose={onClose}
      accent={accent}
      icon={<AssessmentIcon />}
      overline="Phiếu đánh giá khối ĐD"
      title={row ? String(row.employeeName || row.fullName || 'Phiếu đánh giá') : 'Phiếu đánh giá'}
      description={
        row
          ? `Tháng ${row.periodMonth}/${row.periodYear} · ${row.departmentName || ''}`
          : undefined
      }
      headerExtra={
        row ? (
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Chip
              size="small"
              color={ne.nursingEvalStatusColor(status)}
              label={ne.NURSING_EVAL_STATUS_LABEL[status] || status || '—'}
              sx={detailHeaderChipSx.outlined}
            />
            {row.totalScore != null && (
              <Chip
                size="small"
                color="primary"
                label={`${row.totalScore} điểm · ${row.overallGrade || ''}`}
                sx={{ fontWeight: 800 }}
              />
            )}
          </Stack>
        ) : undefined
      }
      footer={footer}
    >
      {loading && !row ? (
        <Box sx={{ py: 4, textAlign: 'center' }}>
          <CircularProgress size={28} />
        </Box>
      ) : err && !row ? (
        <Typography color="error">{err}</Typography>
      ) : row ? (
        <>
          {err && (
            <Alert severity="error" sx={{ mb: 1.5, borderRadius: 2 }} onClose={() => setErr(null)}>
              {err}
            </Alert>
          )}
          {(showNursingHead || showHr || showDirector) && (nursingHeadPending || hrPending || directorPending) && (
            <InfoBanner>
              {nursingHeadPending
                ? 'Trưởng phòng Điều dưỡng xem phiếu và chọn Duyệt hoặc Từ chối (có chữ ký).'
                : hrPending
                  ? 'HCNS kiểm tra phiếu và chọn Duyệt hoặc Từ chối (có chữ ký).'
                  : 'Giám đốc kết luận cuối: duyệt hoặc từ chối (có chữ ký).'}
            </InfoBanner>
          )}

          {/* Tiêu đề mẫu đánh giá */}
          <Box
            sx={{
              mb: 2,
              p: 2,
              borderRadius: 2.5,
              border: `1px solid ${alpha(accent, 0.2)}`,
              background: `linear-gradient(180deg, ${alpha(accent, 0.08)} 0%, ${alpha('#fff', 0.9)} 100%)`,
              textAlign: 'center',
            }}
          >
            <Typography
              variant="overline"
              sx={{ fontWeight: 800, letterSpacing: '0.08em', color: accent, display: 'block' }}
            >
              Bệnh viện Minh An
            </Typography>
            <Typography variant="h6" fontWeight={900} sx={{ letterSpacing: '-0.02em', lineHeight: 1.3 }}>
              Bảng đánh giá kết quả làm việc tháng
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
              Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa · Kỳ {String(row.periodMonth).padStart(2, '0')}/
              {String(row.periodYear ?? '')}
            </Typography>
          </Box>

          {/* Thông tin NV dạng phiếu */}
          <FormSection title="Thông tin người được đánh giá">
            <Box
              sx={{
                display: 'grid',
                gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
                gap: 1.25,
              }}
            >
              {[
                { label: 'Họ và tên', value: String(row.employeeName || row.fullName || '—') },
                { label: 'Khoa / phòng', value: String(row.departmentName || '—') },
                { label: 'Chức danh', value: String(row.positionTitle || '—') },
                { label: 'Mã NV', value: String(row.employeeCode || '—') },
                { label: 'Người lập phiếu', value: String(row.evaluatorUsername || '—') },
                {
                  label: 'Tổng điểm / Xếp loại',
                  value:
                    row.totalScore != null
                      ? `${row.totalScore} điểm · ${row.overallGrade || '—'}`
                      : '—',
                },
              ].map((f) => (
                <Box
                  key={f.label}
                  sx={{
                    px: 1.5,
                    py: 1.15,
                    borderRadius: 2,
                    border: `1px solid ${alpha(theme.palette.divider, 0.95)}`,
                    bgcolor: alpha(theme.palette.background.paper, 0.9),
                  }}
                >
                  <Typography
                    variant="caption"
                    color="text.secondary"
                    fontWeight={750}
                    sx={{ textTransform: 'uppercase', letterSpacing: 0.04, display: 'block' }}
                  >
                    {f.label}
                  </Typography>
                  <Typography variant="body2" fontWeight={750} sx={{ mt: 0.25 }}>
                    {f.value}
                  </Typography>
                </Box>
              ))}
            </Box>
          </FormSection>

          {/* Bảng điểm theo mẫu */}
          <FormSection title="Nội dung đánh giá theo tiêu chí">
            <Box
              sx={{
                borderRadius: 2.5,
                border: `1px solid ${alpha(theme.palette.divider, 0.95)}`,
                overflow: 'hidden',
              }}
            >
              <Box
                sx={{
                  display: 'grid',
                  gridTemplateColumns: '48px 1fr 72px',
                  bgcolor: accent,
                  color: '#fff',
                  px: 1.25,
                  py: 1,
                }}
              >
                <Typography variant="caption" fontWeight={800}>
                  STT
                </Typography>
                <Typography variant="caption" fontWeight={800}>
                  Tiêu chí
                </Typography>
                <Typography variant="caption" fontWeight={800} textAlign="right">
                  Điểm
                </Typography>
              </Box>

              {sections.map(([section, items]) => (
                <Fragment key={section}>
                  <Box
                    sx={{
                      px: 1.25,
                      py: 0.85,
                      bgcolor: alpha(accent, 0.1),
                      borderTop: `1px solid ${alpha(theme.palette.divider, 0.7)}`,
                    }}
                  >
                    <Typography variant="body2" fontWeight={850} color="primary.dark">
                      {section}
                      {items[0]?.sectionPoints != null ? ` (${items[0].sectionPoints} điểm)` : ''}
                    </Typography>
                  </Box>
                  {items.map((g) => {
                    const note = scoreNote(scores, g.id);
                    return (
                      <Box
                        key={g.id}
                        sx={{
                          display: 'grid',
                          gridTemplateColumns: '48px 1fr 72px',
                          gap: 1,
                          px: 1.25,
                          py: 1,
                          borderTop: `1px solid ${alpha(theme.palette.divider, 0.55)}`,
                          alignItems: 'start',
                          '&:nth-of-type(even)': { bgcolor: alpha(accent, 0.02) },
                        }}
                      >
                        <Typography variant="body2" fontWeight={700} color="text.secondary">
                          {g.no || ''}
                        </Typography>
                        <Box sx={{ minWidth: 0 }}>
                          <Typography variant="body2" fontWeight={650}>
                            {g.title}
                          </Typography>
                          {note && (
                            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.35 }}>
                              Ghi chú: {note}
                            </Typography>
                          )}
                        </Box>
                        <Typography variant="body2" fontWeight={900} color="primary.main" textAlign="right">
                          {scorePoints(scores, g.id)}
                        </Typography>
                      </Box>
                    );
                  })}
                </Fragment>
              ))}

              <Box
                sx={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  px: 1.5,
                  py: 1.25,
                  bgcolor: alpha(accent, 0.08),
                  borderTop: `1px solid ${alpha(accent, 0.2)}`,
                }}
              >
                <Typography variant="body2" fontWeight={800}>
                  Tổng điểm / Xếp loại
                </Typography>
                <Typography variant="subtitle1" fontWeight={900} color="primary.main">
                  {row.totalScore != null ? `${row.totalScore}` : '—'}
                  {row.overallGrade ? ` · ${row.overallGrade}` : ''}
                </Typography>
              </Box>
            </Box>
          </FormSection>

          {Boolean(row.comments) && (
            <FormSection title="Nhận xét chung">
              <Box
                sx={{
                  p: 1.5,
                  borderRadius: 2,
                  border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
                  bgcolor: alpha(theme.palette.grey[500], 0.04),
                  whiteSpace: 'pre-wrap',
                }}
              >
                <Typography variant="body2">{String(row.comments)}</Typography>
              </Box>
            </FormSection>
          )}

          {/* Khối chữ ký — đúng mẫu phiếu */}
          <FormSection title="Chữ ký xác nhận">
            <Box
              sx={{
                display: 'grid',
                gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
                gap: 1.25,
              }}
            >
              <ApprovalReviewNoteCard
                role={`Người lập (Trưởng khoa / ĐDT) · ${row.evaluatorUsername || '—'}`}
                timestamp={
                  row.evaluatorSignedAt != null
                    ? String(row.evaluatorSignedAt)
                    : row.createdAt != null
                      ? String(row.createdAt)
                      : ''
                }
                comment={
                  row.evaluatorSignatureUrl
                    ? 'Đã ký khi gửi phiếu đánh giá'
                    : status === 'DRAFT'
                      ? 'Chưa gửi — chưa có chữ ký'
                      : 'Chưa có chữ ký kèm theo'
                }
                signatureUrl={
                  row.evaluatorSignatureUrl != null ? String(row.evaluatorSignatureUrl) : null
                }
                formatTimestamp={formatTs}
              />
              {(Boolean(row.headReviewedAt) || nursingHeadPending) && (
                <ApprovalReviewNoteCard
                  role={`Trưởng phòng ĐD · ${row.headReviewerUsername || (nursingHeadPending ? 'Chờ duyệt' : '—')}`}
                  timestamp={String(row.headReviewedAt || '')}
                  comment={
                    row.headComment != null
                      ? String(row.headComment)
                      : nursingHeadPending
                        ? 'Đang chờ duyệt ký'
                        : ''
                  }
                  signatureUrl={row.headSignatureUrl != null ? String(row.headSignatureUrl) : null}
                  formatTimestamp={formatTs}
                />
              )}
              {(Boolean(row.hrReviewedAt) || hrPending || Boolean(row.headReviewedAt)) && (
                <ApprovalReviewNoteCard
                  role={`HCNS · ${row.hrReviewerUsername || (hrPending ? 'Chờ duyệt' : '—')}`}
                  timestamp={String(row.hrReviewedAt || '')}
                  comment={
                    row.hrComment != null
                      ? String(row.hrComment)
                      : hrPending
                        ? 'Đang chờ duyệt ký'
                        : ''
                  }
                  signatureUrl={row.hrSignatureUrl != null ? String(row.hrSignatureUrl) : null}
                  formatTimestamp={formatTs}
                />
              )}
              {(Boolean(row.directorReviewedAt) ||
                directorPending ||
                Boolean(row.hrReviewedAt)) && (
                <ApprovalReviewNoteCard
                  role={`Giám đốc · ${row.directorReviewerUsername || (directorPending ? 'Chờ duyệt' : '—')}`}
                  timestamp={String(row.directorReviewedAt || '')}
                  comment={
                    row.directorComment != null
                      ? String(row.directorComment)
                      : directorPending
                        ? 'Đang chờ duyệt ký'
                        : ''
                  }
                  signatureUrl={
                    row.directorSignatureUrl != null ? String(row.directorSignatureUrl) : null
                  }
                  formatTimestamp={formatTs}
                />
              )}
            </Box>
          </FormSection>

          {(showNursingHead || showHr || showDirector) && (nursingHeadPending || hrPending || directorPending) && (
            <FormSection title="Ý kiến duyệt">
              <TextField
                fullWidth
                size="small"
                multiline
                minRows={2}
                label="Ghi chú (tuỳ chọn)"
                value={comment}
                onChange={(e) => setComment(e.target.value)}
                sx={{ '& .MuiOutlinedInput-root': { bgcolor: '#fff', borderRadius: 2 } }}
              />
            </FormSection>
          )}
        </>
      ) : null}
    </WorkRequestViewShell>
  );
}
