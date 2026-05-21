import {
  Alert,
  Box,
  Button,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { useEffect, useMemo, useState } from 'react';
import * as ne from '../services/nursingEvaluationService';

export type NursingDetailEditRequest = {
  employeeId: number;
  periodYear: number;
  periodMonth: number;
};

type ChannelEvalSlot = { username?: string; displayName?: string; savedAt?: string };

type Props = {
  open: boolean;
  onClose: () => void;
  evaluationId: number | null;
  templateCode: string;
  onRequestEdit?: (p: NursingDetailEditRequest) => void;
  /** Tăng khi dữ liệu phiếu thay đổi ngoài dialog để tải lại nội dung khi đang mở */
  dataVersion?: number;
};

function cell(v: unknown): string {
  if (v == null) return '—';
  return String(v);
}

function cellNumLoose(v: unknown): string {
  if (v == null || v === '') return '—';
  const n = Number(v);
  if (Number.isNaN(n)) return '—';
  return String(n);
}

/** Chi tiết phiếu: một cột «Điểm» (gộp các kênh theo từng dòng). */
export function NursingEvaluationDetailDialog({
  open,
  onClose,
  evaluationId,
  templateCode,
  onRequestEdit,
  dataVersion = 0,
}: Props) {
  const [loading, setLoading] = useState(false);
  const [rec, setRec] = useState<Record<string, unknown> | null>(null);
  const [template, setTemplate] = useState<ne.NursingTemplate | null>(null);

  useEffect(() => {
    if (!open || evaluationId == null) {
      setRec(null);
      setTemplate(null);
      return;
    }
    let cancelled = false;
    setLoading(true);
    Promise.all([ne.fetchNursingEvaluationRecord(evaluationId), ne.fetchNursingTemplate(templateCode)])
      .then(([r, t]) => {
        if (!cancelled) {
          setRec(r as Record<string, unknown>);
          setTemplate(t);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [open, evaluationId, templateCode, dataVersion]);

  const scores = rec?.scores as Record<string, Record<string, unknown>> | undefined;
  const groups = template?.criteriaGroups ?? [];
  const channelEvaluators = rec?.channelEvaluators as Record<string, ChannelEvalSlot> | undefined;

  function toNum(v: unknown): number | undefined {
    if (v == null || v === '') return undefined;
    const n = Number(v);
    return Number.isNaN(n) ? undefined : n;
  }

  function labelFor(g: ne.CriterionGroup, p: number | undefined): string {
    if (p == null || Number.isNaN(p)) return '—';
    const o = g.options.find((x) => Number(x.points) === Number(p));
    if (o) return `${o.points} — ${o.label}`;
    return String(p);
  }

  const councilSum = useMemo(() => {
    if (!scores || !groups.length) return null;
    let sum = 0;
    for (const g of groups) {
      if (!g.id.startsWith('HD_')) continue;
      const p = toNum(scores[g.id]?.hd);
      if (p == null) return null;
      sum += p;
    }
    return Number(sum.toFixed(2));
  }, [scores, groups]);

  /** Một dòng: khoa phòng và ĐDT coi như cùng vai trò thực tế. */
  const deptMergedSummary = useMemo(() => {
    if (!rec) return '— (—)';
    const tkN = toNum(rec.totalTruongKhoa);
    const ddtN = toNum(rec.totalDdt);
    const tkS = cellNumLoose(rec.totalTruongKhoa);
    const ddtS = cellNumLoose(rec.totalDdt);
    const gTk = cell(rec.gradeTruongKhoa);
    const gDdt = cell(rec.gradeDdt);

    const fmt = (score: string, grade: string) =>
      grade !== '—' ? `${score} (${grade})` : score === '—' ? '—' : `${score} (—)`;

    if (tkN == null && ddtN == null) return '— (—)';
    if (tkN != null && ddtN == null) return fmt(tkS, gTk);
    if (tkN == null && ddtN != null) return fmt(ddtS, gDdt);
    if (tkN === ddtN) {
      const g = gTk !== '—' ? gTk : gDdt;
      return fmt(tkS, g);
    }
    return `${fmt(tkS, gTk)} · ${fmt(ddtS, gDdt)}`;
  }, [rec]);

  const statusLines = useMemo(() => {
    const lines: string[] = [];
    const tkSlot = channelEvaluators?.truongKhoa;
    const ddtSlot = channelEvaluators?.ddt;
    const tkName = tkSlot ? ne.formatChannelEvaluatorName(tkSlot) : '';
    const ddtName = ddtSlot ? ne.formatChannelEvaluatorName(ddtSlot) : '';
    const fmtWhen = (savedAt?: string) => (savedAt ? ne.formatChannelEvalSavedAt(savedAt) : '');
    const deptMergedLabel = 'Khoa phòng / Điều dưỡng trưởng';

    if (tkName || ddtName) {
      if (tkName && ddtName && tkName !== ddtName) {
        const whenTk = fmtWhen(tkSlot?.savedAt);
        const whenDdt = fmtWhen(ddtSlot?.savedAt);
        lines.push(`${deptMergedLabel} (khoa): đã chấm bởi «${tkName}»${whenTk ? ` — ${whenTk}` : ''}.`);
        lines.push(`${deptMergedLabel} (ĐĐT): đã chấm bởi «${ddtName}»${whenDdt ? ` — ${whenDdt}` : ''}.`);
      } else {
        const name = tkName || ddtName;
        const when = fmtWhen(tkSlot?.savedAt) || fmtWhen(ddtSlot?.savedAt);
        lines.push(`${deptMergedLabel}: đã chấm bởi «${name}»${when ? ` — ${when}` : ''}.`);
      }
    }

    const hdSlot = channelEvaluators?.hd;
    const hdName = hdSlot ? ne.formatChannelEvaluatorName(hdSlot) : '';
    if (hdName) {
      const when = fmtWhen(hdSlot?.savedAt);
      lines.push(`Hội đồng (30 điểm): đã chấm bởi «${hdName}»${when ? ` — ${when}` : ''}.`);
    }

    if (lines.length === 0 && rec?.evaluatorUsername) {
      lines.push(`Cập nhật gần nhất trên hệ thống: «${cell(rec.evaluatorUsername)}».`);
    }
    return lines;
  }, [channelEvaluators, rec]);

  function onEditClick() {
    if (!rec || !onRequestEdit) return;
    const employeeId = Number(rec.employeeId);
    const periodYear = Number(rec.periodYear);
    const periodMonth = Number(rec.periodMonth);
    if (!Number.isFinite(employeeId) || !Number.isFinite(periodYear) || !Number.isFinite(periodMonth)) return;
    onRequestEdit({ employeeId, periodYear, periodMonth });
    onClose();
  }

  return (
    <Dialog open={open} onClose={onClose} maxWidth="lg" fullWidth scroll="paper">
      <DialogTitle>Chi tiết đánh giá theo tiêu chí</DialogTitle>
      <DialogContent dividers>
        {loading && (
          <Box sx={{ py: 4, display: 'flex', justifyContent: 'center' }}>
            <CircularProgress size={36} />
          </Box>
        )}
        {!loading && rec && (
          <Stack spacing={2}>
            <Typography variant="body1" fontWeight={600}>
              {cell(rec.fullName)}
            </Typography>
            <Typography variant="body2" color="text.secondary">
              {cell(rec.departmentName)}
              {rec.employeeCode != null && rec.employeeCode !== '' ? ` · Mã ${cell(rec.employeeCode)}` : ''}
            </Typography>
            <Typography variant="body2">
              Kỳ <strong>{cell(rec.periodMonth)}/{cell(rec.periodYear)}</strong>
            </Typography>
            <Typography variant="body2" sx={{ lineHeight: 1.7 }}>
              <strong>Khoa phòng & Điều dưỡng trưởng (70):</strong> {deptMergedSummary} ·{' '}
              <strong>Hội đồng (30):</strong> {councilSum != null ? `${councilSum} / 30` : '—'}
            </Typography>

            {statusLines.length > 0 && (
              <Alert severity="info" sx={{ '& .MuiAlert-message': { width: '100%' } }}>
                <Typography variant="subtitle2" fontWeight={700} gutterBottom>
                  Trạng thái chấm điểm
                </Typography>
                <Stack component="ul" sx={{ m: 0, pl: 2.5 }} spacing={0.5}>
                  {statusLines.map((t) => (
                    <Typography key={t} component="li" variant="body2">
                      {t}
                    </Typography>
                  ))}
                </Stack>
              </Alert>
            )}

            <TableContainer sx={{ overflowX: 'auto', border: 1, borderColor: 'divider', borderRadius: 1 }}>
              <Table size="small" sx={{ minWidth: 520 }}>
                <TableHead>
                  <TableRow>
                    <TableCell sx={{ fontWeight: 700 }}>Tiêu chí</TableCell>
                    <TableCell sx={{ fontWeight: 700 }}>Điểm</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {groups.map((g) => {
                    const row = scores?.[g.id];
                    const isHd = g.id.startsWith('HD_');
                    const pTk = toNum(row?.truongKhoa);
                    const pDdt = toNum(row?.ddt);
                    const pHd = toNum(row?.hd);
                    const showTk = pTk !== undefined;
                    const showDdt = pDdt !== undefined;
                    return (
                      <TableRow key={g.id}>
                        <TableCell sx={{ maxWidth: 320, verticalAlign: 'top' }}>
                          <Typography variant="body2" sx={{ lineHeight: 1.5 }}>
                            {g.title}
                            {g.maxPoints != null ? (
                              <Typography component="span" variant="caption" color="text.secondary" sx={{ ml: 0.5 }}>
                                ({g.maxPoints} điểm)
                              </Typography>
                            ) : null}
                          </Typography>
                        </TableCell>
                        <TableCell sx={{ verticalAlign: 'top' }}>
                          {isHd ? (
                            <Typography variant="body2" sx={{ lineHeight: 1.5 }}>
                              <Box component="span" sx={{ fontWeight: 600, color: 'text.secondary' }}>
                                Hội đồng:{' '}
                              </Box>
                              {labelFor(g, pHd)}
                            </Typography>
                          ) : !showTk && !showDdt ? (
                            <Typography variant="body2" color="text.secondary">
                              —
                            </Typography>
                          ) : (showTk && !showDdt) || (!showTk && showDdt) ? (
                            <Typography variant="body2" sx={{ lineHeight: 1.5 }}>
                              {labelFor(g, showTk ? pTk : pDdt)}
                            </Typography>
                          ) : showTk && showDdt && pTk === pDdt ? (
                            <Typography variant="body2" sx={{ lineHeight: 1.5 }}>
                              {labelFor(g, pTk)}
                            </Typography>
                          ) : (
                            <Stack spacing={0.75}>
                              {showTk && (
                                <Typography variant="body2" sx={{ lineHeight: 1.5 }}>
                                  <Box component="span" sx={{ fontWeight: 600, color: 'text.secondary' }}>
                                    Khoa phòng:{' '}
                                  </Box>
                                  {labelFor(g, pTk)}
                                </Typography>
                              )}
                              {showDdt && (
                                <Typography variant="body2" sx={{ lineHeight: 1.5 }}>
                                  <Box component="span" sx={{ fontWeight: 600, color: 'text.secondary' }}>
                                    Điều dưỡng trưởng:{' '}
                                  </Box>
                                  {labelFor(g, pDdt)}
                                </Typography>
                              )}
                            </Stack>
                          )}
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </TableContainer>

            {rec.comments != null && String(rec.comments).trim() !== '' && (
              <Box>
                <Typography variant="subtitle2" fontWeight={600} gutterBottom>
                  Ghi chú chung
                </Typography>
                <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                  {String(rec.comments)}
                </Typography>
              </Box>
            )}
          </Stack>
        )}
      </DialogContent>
      <DialogActions sx={{ px: 3, py: 2 }}>
        <Button onClick={onClose}>Đóng</Button>
        {onRequestEdit && (
          <Button variant="contained" onClick={onEditClick}>
            Sửa đánh giá
          </Button>
        )}
      </DialogActions>
    </Dialog>
  );
}
