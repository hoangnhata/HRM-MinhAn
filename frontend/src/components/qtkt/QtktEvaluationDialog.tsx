import AccessTimeOutlinedIcon from '@mui/icons-material/AccessTimeOutlined';
import BiotechOutlinedIcon from '@mui/icons-material/BiotechOutlined';
import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import CloseIcon from '@mui/icons-material/Close';
import ExpandLessIcon from '@mui/icons-material/ExpandLess';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import GradeOutlinedIcon from '@mui/icons-material/GradeOutlined';
import SaveOutlinedIcon from '@mui/icons-material/SaveOutlined';
import SendIcon from '@mui/icons-material/Send';
import UndoOutlinedIcon from '@mui/icons-material/UndoOutlined';
import {
  Alert,
  Autocomplete,
  Box,
  Button,
  Chip,
  CircularProgress,
  Collapse,
  Dialog,
  DialogContent,
  FormControl,
  FormControlLabel,
  IconButton,
  LinearProgress,
  MenuItem,
  Radio,
  RadioGroup,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha } from '@mui/material/styles';
import { useEffect, useMemo, useState } from 'react';
import { DatePickerField } from '../ui/DateTimeFields';
import { extractApiErrorMessage } from '../../services/approvalSignatureService';
import * as qtkt from '../../services/qtktEvaluationService';

const ACCENT = '#0f766e';
const INK = '#0f172a';

type Props = {
  open: boolean;
  onClose: () => void;
  onSaved?: () => void;
  template: qtkt.QtktTemplate;
  employees: qtkt.QtktEmployee[];
  existing?: qtkt.QtktEvaluation | null;
  /** Chỉ xem (Trưởng phòng ĐD) */
  readOnly?: boolean;
  presetEmployeeId?: number;
  presetProcedureCode?: string;
  presetCheckContextCode?: string;
  presetEvalDate?: string;
};

function todayIso() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function emptyScores(proc: qtkt.QtktProcedure): Record<string, number> {
  const scores: Record<string, number> = {};
  for (const s of proc.sections) {
    for (const step of s.steps) scores[step.id] = 0;
  }
  return scores;
}

function scoreTone(pct: number) {
  if (pct >= 90) return '#15803d';
  if (pct >= 70) return ACCENT;
  if (pct >= 50) return '#b45309';
  return '#be123c';
}

function ScoreField({
  no,
  title,
  detail,
  max,
  value,
  onChange,
  disabled,
  required,
}: {
  no: number;
  title: string;
  detail?: string;
  max: number;
  value: number;
  onChange: (v: number) => void;
  disabled?: boolean;
  required?: boolean;
}) {
  const filled = value > 0;
  const full = value >= max && max > 0;
  const hasDetail = Boolean(detail && detail.trim() && detail.trim() !== title.trim());
  const [expanded, setExpanded] = useState(false);
  const pct = max > 0 ? Math.round((value / max) * 100) : 0;

  return (
    <Box
      sx={{
        display: 'grid',
        gridTemplateColumns: { xs: '1fr', sm: '1fr 118px' },
        gap: 1.15,
        alignItems: 'start',
        px: 1.4,
        py: 1.2,
        borderRadius: 2.25,
        bgcolor: full ? alpha('#15803d', 0.05) : filled ? alpha(ACCENT, 0.045) : '#fff',
        border: `1px solid ${
          full ? alpha('#15803d', 0.22) : filled ? alpha(ACCENT, 0.22) : alpha(INK, 0.07)
        }`,
        boxShadow: filled ? `inset 3px 0 0 ${full ? '#15803d' : ACCENT}` : 'none',
        transition: 'border-color 0.12s ease, background-color 0.12s ease',
      }}
    >
      <Stack direction="row" spacing={1.1} alignItems="flex-start" sx={{ minWidth: 0 }}>
        <Box
          sx={{
            width: 28,
            height: 28,
            borderRadius: 1.25,
            flexShrink: 0,
            display: 'grid',
            placeItems: 'center',
            fontSize: 12,
            fontWeight: 850,
            bgcolor: full
              ? alpha('#15803d', 0.12)
              : filled
                ? alpha(ACCENT, 0.12)
                : alpha(INK, 0.05),
            color: full ? '#15803d' : filled ? ACCENT : alpha(INK, 0.55),
            border: `1px solid ${
              full ? alpha('#15803d', 0.2) : filled ? alpha(ACCENT, 0.2) : alpha(INK, 0.08)
            }`,
          }}
        >
          {full ? <CheckCircleOutlineIcon sx={{ fontSize: 16 }} /> : no}
        </Box>
        <Box sx={{ minWidth: 0, flex: 1 }}>
          <Typography
            variant="body2"
            sx={{ lineHeight: 1.45, color: 'text.primary', fontWeight: 650 }}
          >
            {title}
            {required && (
              <Chip
                size="small"
                label="Bắt buộc"
                sx={{
                  ml: 0.75,
                  height: 20,
                  fontSize: '0.65rem',
                  fontWeight: 800,
                  bgcolor: alpha('#b45309', 0.12),
                  color: '#b45309',
                }}
              />
            )}
          </Typography>
          {hasDetail && (
            <>
              <Button
                size="small"
                onClick={() => setExpanded((v) => !v)}
                endIcon={expanded ? <ExpandLessIcon fontSize="small" /> : <ExpandMoreIcon fontSize="small" />}
                sx={{
                  mt: 0.4,
                  px: 0.65,
                  minHeight: 0,
                  fontSize: 12,
                  fontWeight: 750,
                  color: ACCENT,
                  textTransform: 'none',
                  bgcolor: alpha(ACCENT, 0.05),
                  borderRadius: 1.25,
                  '&:hover': { bgcolor: alpha(ACCENT, 0.1) },
                }}
              >
                {expanded ? 'Thu gọn' : 'Xem đầy đủ'}
              </Button>
              <Collapse in={expanded} timeout="auto" unmountOnExit>
                <Box
                  sx={{
                    mt: 0.75,
                    px: 1.1,
                    py: 0.9,
                    borderRadius: 1.75,
                    bgcolor: alpha(INK, 0.025),
                    border: `1px solid ${alpha(INK, 0.06)}`,
                  }}
                >
                  <Typography
                    variant="body2"
                    sx={{
                      whiteSpace: 'pre-line',
                      lineHeight: 1.6,
                      color: 'text.secondary',
                      fontSize: '0.8125rem',
                    }}
                  >
                    {detail}
                  </Typography>
                </Box>
              </Collapse>
            </>
          )}
        </Box>
      </Stack>

      <Box>
        <TextField
          size="small"
          type="number"
          disabled={disabled}
          value={value}
          inputProps={{ min: 0, max, step: 0.25 }}
          onChange={(e) => {
            const n = Number(e.target.value);
            if (!Number.isFinite(n)) {
              onChange(0);
              return;
            }
            onChange(Math.max(0, Math.min(max, Math.round(n * 100) / 100)));
          }}
          sx={{
            width: '100%',
            '& .MuiOutlinedInput-root': {
              borderRadius: 1.75,
              bgcolor: '#fff',
              fontWeight: 850,
              fontSize: '1rem',
              letterSpacing: '-0.02em',
            },
            '& input': { textAlign: 'center', py: 1 },
          }}
        />
        <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mt: 0.45, px: 0.15 }}>
          <Typography variant="caption" color="text.secondary" fontWeight={650} sx={{ fontSize: '0.68rem' }}>
            / {max}
          </Typography>
          <Typography
            variant="caption"
            fontWeight={800}
            sx={{ fontSize: '0.68rem', color: filled ? scoreTone(pct) : 'text.disabled' }}
          >
            {pct}%
          </Typography>
        </Stack>
        {!disabled && (
          <Button
            size="small"
            disabled={full}
            onClick={() => onChange(max)}
            sx={{
              mt: 0.35,
              width: '100%',
              minHeight: 0,
              py: 0.25,
              fontSize: 11,
              fontWeight: 750,
              textTransform: 'none',
              color: ACCENT,
              borderRadius: 1.25,
              '&:hover': { bgcolor: alpha(ACCENT, 0.08) },
            }}
          >
            Đủ điểm
          </Button>
        )}
      </Box>
    </Box>
  );
}

function ScoreRing({
  total,
  max,
}: {
  total: number;
  max: number;
}) {
  const pct = max > 0 ? Math.min(100, Math.round((total / max) * 100)) : 0;
  const tone = scoreTone(pct);
  return (
    <Box
      sx={{
        position: 'relative',
        width: 78,
        height: 78,
        flexShrink: 0,
      }}
    >
      <CircularProgress
        variant="determinate"
        value={100}
        size={78}
        thickness={3.5}
        sx={{ color: alpha(tone, 0.12), position: 'absolute', inset: 0 }}
      />
      <CircularProgress
        variant="determinate"
        value={pct}
        size={78}
        thickness={3.5}
        sx={{
          color: tone,
          position: 'absolute',
          inset: 0,
          '& .MuiCircularProgress-circle': { strokeLinecap: 'round' },
        }}
      />
      <Box
        sx={{
          position: 'absolute',
          inset: 0,
          display: 'grid',
          placeItems: 'center',
          textAlign: 'center',
        }}
      >
        <Box>
          <Typography fontWeight={850} sx={{ fontSize: '1.05rem', lineHeight: 1, letterSpacing: '-0.04em', color: tone }}>
            {total.toFixed(1)}
          </Typography>
          <Typography variant="caption" color="text.secondary" fontWeight={700} sx={{ fontSize: '0.62rem' }}>
            / {max}
          </Typography>
        </Box>
      </Box>
    </Box>
  );
}

export function QtktEvaluationDialog({
  open,
  onClose,
  onSaved,
  template,
  employees,
  existing,
  readOnly = false,
  presetEmployeeId,
  presetProcedureCode,
  presetCheckContextCode,
  presetEvalDate,
}: Props) {
  const [employee, setEmployee] = useState<qtkt.QtktEmployee | null>(null);
  const [procedureCode, setProcedureCode] = useState(template.procedures[0]?.code ?? '');
  const [checkContextCode, setCheckContextCode] = useState('');
  const [patientCode, setPatientCode] = useState('');
  const [evalDate, setEvalDate] = useState(todayIso());
  const [scores, setScores] = useState<Record<string, number>>({});
  const [note, setNote] = useState('');
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [checkContextExpanded, setCheckContextExpanded] = useState(true);

  const availableProcedures = useMemo(() => {
    if (existing) {
      return template.procedures.filter((p) => p.code === existing.procedureCode);
    }
    return template.procedures.filter((p) =>
      qtkt.isProcedureAllowedForDepartment(p, employee?.departmentName),
    );
  }, [template, employee, existing]);

  const procedure = useMemo(
    () => availableProcedures.find((p) => p.code === procedureCode) ?? availableProcedures[0],
    [availableProcedures, procedureCode],
  );

  const checkOptions = procedure?.checkOptions;
  const requiresPatientCode = Boolean(procedure?.requiresPatientCode);

  const selectedCheckContextLabel = useMemo(() => {
    if (!checkOptions || !checkContextCode) return null;
    return checkOptions.options.find((o) => o.code === checkContextCode)?.label ?? null;
  }, [checkOptions, checkContextCode]);

  useEffect(() => {
    if (!open) return;
    setErr(null);
    setCheckContextExpanded(true);
    if (existing) {
      const emp = employees.find((e) => e.id === existing.employeeId) ?? {
        id: existing.employeeId,
        fullName: existing.employeeName,
        employeeCode: existing.employeeCode,
        departmentId: existing.departmentId,
        departmentName: existing.departmentName,
      };
      setEmployee(emp);
      setProcedureCode(existing.procedureCode);
      setCheckContextCode(existing.checkContextCode ?? '');
      setPatientCode(existing.patientCode ?? '');
      setEvalDate(existing.evalDate);
      setScores({ ...existing.scores });
      setNote(existing.note ?? '');
      return;
    }
    const presetEmp =
      presetEmployeeId != null ? employees.find((e) => e.id === presetEmployeeId) ?? null : null;
    setEmployee(presetEmp);
    const allowed = template.procedures.filter((p) =>
      qtkt.isProcedureAllowedForDepartment(p, presetEmp?.departmentName),
    );
    const procCode =
      (presetProcedureCode && allowed.some((p) => p.code === presetProcedureCode)
        ? presetProcedureCode
        : null) ||
      allowed[0]?.code ||
      template.procedures[0]?.code ||
      '';
    setProcedureCode(procCode);
    const proc = template.procedures.find((p) => p.code === procCode) ?? template.procedures[0];
    setCheckContextCode(presetCheckContextCode ?? '');
    setPatientCode('');
    setEvalDate(presetEvalDate || todayIso());
    setNote('');
    setScores(proc ? emptyScores(proc) : {});
  }, [open, existing, employees, template, presetEmployeeId, presetProcedureCode, presetCheckContextCode, presetEvalDate]);

  useEffect(() => {
    if (!open || existing || !procedure) return;
    setScores(emptyScores(procedure));
    if (!presetCheckContextCode) {
      setCheckContextCode('');
    }
    setPatientCode('');
  }, [procedureCode]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    if (!open || existing || !employee) return;
    if (procedure && qtkt.isProcedureAllowedForDepartment(procedure, employee.departmentName)) return;
    const next = template.procedures.find((p) =>
      qtkt.isProcedureAllowedForDepartment(p, employee.departmentName),
    );
    if (next) setProcedureCode(next.code);
  }, [employee?.id]); // eslint-disable-line react-hooks/exhaustive-deps

  const total = useMemo(
    () => Object.values(scores).reduce((a, b) => a + (Number.isFinite(b) ? b : 0), 0),
    [scores],
  );

  const scoredSteps = useMemo(
    () => Object.values(scores).filter((v) => Number(v) > 0).length,
    [scores],
  );

  const totalSteps = useMemo(
    () => procedure?.sections.reduce((n, s) => n + s.steps.length, 0) ?? 0,
    [procedure],
  );

  const overallPct = procedure && procedure.maxTotal > 0 ? Math.round((total / procedure.maxTotal) * 100) : 0;

  async function save(submit: boolean) {
    if (!employee || !procedure) {
      setErr('Chọn nhân viên và quy trình kỹ thuật.');
      return;
    }
    if (checkOptions?.options?.length && !checkContextCode) {
      setErr(`Cần chọn ${checkOptions.label || 'nội dung kiểm tra'}.`);
      return;
    }
    if (requiresPatientCode && !patientCode.trim()) {
      setErr('Cần nhập mã bệnh nhân.');
      return;
    }
    setLoading(true);
    setErr(null);
    try {
      const body: qtkt.QtktUpsertPayload = {
        employeeId: employee.id,
        procedureCode: procedure.code,
        checkContextCode: checkContextCode || undefined,
        patientCode: requiresPatientCode ? patientCode.trim() : undefined,
        evalDate,
        scores,
        note: note.trim() || undefined,
        submit,
      };
      if (existing?.id) {
        await qtkt.updateQtktEvaluation(existing.id, body);
      } else {
        await qtkt.createQtktEvaluation(body);
      }
      onSaved?.();
      onClose();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Không lưu được phiếu đánh giá.'));
    } finally {
      setLoading(false);
    }
  }

  async function recall() {
    if (!existing?.id || !existing.canRecall) return;
    const ok = window.confirm(
      'Thu hồi phiếu đã gửi về nháp để chỉnh sửa?\nTrưởng khoa chỉ thu hồi được trong vòng 1 ngày kể từ lúc gửi.',
    );
    if (!ok) return;
    setLoading(true);
    setErr(null);
    try {
      await qtkt.recallQtktEvaluation(existing.id);
      onSaved?.();
      onClose();
    } catch (ex) {
      setErr(extractApiErrorMessage(ex, 'Không thu hồi được phiếu.'));
    } finally {
      setLoading(false);
    }
  }

  const titleText = readOnly
    ? 'Xem phiếu đánh giá'
    : existing
      ? 'Cập nhật phiếu đánh giá'
      : 'Tạo phiếu đánh giá mới';

  return (
    <Dialog
      open={open}
      onClose={loading ? undefined : onClose}
      maxWidth={false}
      fullWidth
      PaperProps={{
        sx: {
          width: { xs: '100%', sm: 'min(1480px, 98vw)' },
          maxWidth: '98vw',
          maxHeight: { xs: '100dvh', sm: '96dvh' },
          m: { xs: 0, sm: 1.5 },
          borderRadius: { xs: 0, sm: 3.5 },
          overflow: 'hidden',
          bgcolor: '#f4f7f9',
          boxShadow: `0 28px 64px ${alpha(INK, 0.18)}`,
        },
      }}
    >
      <Box
        sx={{
          px: { xs: 2, sm: 2.75 },
          pt: 2.25,
          pb: 2,
          background: `linear-gradient(135deg, ${alpha(ACCENT, 0.18)} 0%, ${alpha(ACCENT, 0.05)} 42%, #fff 100%)`,
          borderBottom: `1px solid ${alpha(ACCENT, 0.1)}`,
        }}
      >
        <Stack direction="row" spacing={2} alignItems="flex-start">
          <Box
            sx={{
              width: 50,
              height: 50,
              borderRadius: 2.5,
              display: 'grid',
              placeItems: 'center',
              bgcolor: '#fff',
              color: ACCENT,
              border: `1px solid ${alpha(ACCENT, 0.2)}`,
              boxShadow: `0 8px 18px ${alpha(ACCENT, 0.14)}`,
            }}
          >
            <BiotechOutlinedIcon />
          </Box>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography
              variant="overline"
              sx={{ color: ACCENT, fontWeight: 850, letterSpacing: '0.12em', fontSize: '0.66rem' }}
            >
              Đánh giá quy trình kỹ thuật
            </Typography>
            <Typography variant="h6" fontWeight={850} sx={{ letterSpacing: '-0.02em', lineHeight: 1.2 }}>
              {titleText}
            </Typography>
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.4 }}>
              Thang điểm 10 · Checklist chuẩn viện · Chấm từng bước
            </Typography>
          </Box>
          {procedure && <ScoreRing total={total} max={procedure.maxTotal} />}
          <IconButton
            onClick={onClose}
            disabled={loading}
            size="small"
            aria-label="Đóng"
            sx={{
              bgcolor: alpha(INK, 0.04),
              border: `1px solid ${alpha(INK, 0.08)}`,
              '&:hover': { bgcolor: alpha(INK, 0.08) },
            }}
          >
            <CloseIcon fontSize="small" />
          </IconButton>
        </Stack>
      </Box>

      <DialogContent sx={{ px: { xs: 1.75, sm: 2.75 }, py: 2.25 }}>
        <Stack spacing={2}>
          {err && (
            <Alert severity="error" variant="outlined" sx={{ borderRadius: 2.25 }}>
              {err}
            </Alert>
          )}

          <Box
            sx={{
              display: 'grid',
              gridTemplateColumns: {
                xs: '1fr',
                md: requiresPatientCode ? '1.2fr 1fr 0.85fr 0.85fr' : '1.45fr 1fr 0.95fr',
              },
              gap: 1.25,
              p: 1.65,
              borderRadius: 2.75,
              bgcolor: '#fff',
              border: `1px solid ${alpha(INK, 0.07)}`,
              boxShadow: `0 6px 18px ${alpha(INK, 0.03)}`,
            }}
          >
            <Autocomplete
              options={employees}
              value={employee}
              disabled={readOnly || !!existing || presetEmployeeId != null}
              onChange={(_, v) => setEmployee(v)}
              getOptionLabel={(o) =>
                `${o.fullName}${o.employeeCode ? ` (${o.employeeCode})` : ''}${
                  o.departmentName ? ` · ${o.departmentName}` : ''
                }`
              }
              isOptionEqualToValue={(a, b) => a.id === b.id}
              renderInput={(params) => (
                <TextField
                  {...params}
                  label="Nhân viên"
                  size="small"
                  required
                  sx={{ '& .MuiOutlinedInput-root': { borderRadius: 1.75 } }}
                />
              )}
            />
            <TextField
              select
              size="small"
              label="Quy trình kỹ thuật"
              value={procedure?.code ?? ''}
              disabled={readOnly || !!existing || !!presetProcedureCode}
              onChange={(e) => setProcedureCode(e.target.value)}
              sx={{ '& .MuiOutlinedInput-root': { borderRadius: 1.75 } }}
            >
              {availableProcedures.map((p) => (
                <MenuItem key={p.code} value={p.code}>
                  {p.name}
                </MenuItem>
              ))}
            </TextField>
            <DatePickerField
              label="Ngày đánh giá"
              value={evalDate}
              onChange={setEvalDate}
              size="small"
              disabled={readOnly || !!existing}
            />
            {requiresPatientCode && (
              <TextField
                size="small"
                label="Mã bệnh nhân"
                value={patientCode}
                onChange={(e) => setPatientCode(e.target.value)}
                required
                disabled={readOnly || !!existing}
                placeholder="Nhập mã BN"
                sx={{ '& .MuiOutlinedInput-root': { borderRadius: 1.75 } }}
              />
            )}
          </Box>

          {procedure?.note && (
            <Alert severity="info" variant="outlined" sx={{ borderRadius: 2.25 }}>
              {procedure.note}
            </Alert>
          )}

          {checkOptions && (
            <Box
              sx={{
                borderRadius: 2.75,
                bgcolor: '#fff',
                border: `1px solid ${alpha(ACCENT, 0.18)}`,
                overflow: 'hidden',
                boxShadow: `0 6px 16px ${alpha(ACCENT, 0.06)}`,
              }}
            >
              <Box
                role="button"
                tabIndex={0}
                onClick={() => setCheckContextExpanded((v) => !v)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    setCheckContextExpanded((v) => !v);
                  }
                }}
                sx={{
                  px: 1.65,
                  py: checkContextExpanded ? 1.25 : 1.1,
                  cursor: 'pointer',
                  userSelect: 'none',
                  background: checkContextExpanded
                    ? `linear-gradient(90deg, ${alpha(ACCENT, 0.12)} 0%, ${alpha(ACCENT, 0.03)} 100%)`
                    : `linear-gradient(90deg, ${alpha(ACCENT, 0.07)} 0%, #fff 72%)`,
                  borderBottom: checkContextExpanded ? `1px solid ${alpha(ACCENT, 0.12)}` : 'none',
                  borderLeft: `3px solid ${selectedCheckContextLabel ? ACCENT : alpha(ACCENT, 0.28)}`,
                  transition: 'background-color 0.15s ease, border-color 0.15s ease',
                  '&:hover': {
                    bgcolor: alpha(ACCENT, 0.045),
                    '& .check-context-toggle': {
                      bgcolor: alpha(ACCENT, 0.14),
                    },
                  },
                }}
              >
                <Stack direction="row" alignItems="center" spacing={1.25}>
                  <Box
                    sx={{
                      width: 36,
                      height: 36,
                      borderRadius: 1.75,
                      flexShrink: 0,
                      display: 'grid',
                      placeItems: 'center',
                      bgcolor: alpha(ACCENT, 0.12),
                      color: ACCENT,
                      border: `1px solid ${alpha(ACCENT, 0.16)}`,
                    }}
                  >
                    <AccessTimeOutlinedIcon sx={{ fontSize: 19 }} />
                  </Box>

                  <Box sx={{ minWidth: 0, flex: 1 }}>
                    {checkContextExpanded ? (
                      <>
                        <Typography variant="subtitle2" fontWeight={850} sx={{ letterSpacing: '-0.01em', color: ACCENT }}>
                          {checkOptions.label}
                        </Typography>
                        {checkOptions.hint && (
                          <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.35 }}>
                            {checkOptions.hint}
                          </Typography>
                        )}
                      </>
                    ) : (
                      <>
                        <Typography
                          variant="caption"
                          sx={{
                            display: 'block',
                            fontWeight: 800,
                            letterSpacing: '0.04em',
                            textTransform: 'uppercase',
                            color: alpha(ACCENT, 0.72),
                            fontSize: '0.68rem',
                          }}
                        >
                          {checkOptions.label}
                        </Typography>
                        {selectedCheckContextLabel ? (
                          <Stack direction="row" spacing={0.75} alignItems="center" sx={{ mt: 0.45, minWidth: 0 }}>
                            <CheckCircleOutlineIcon sx={{ fontSize: 17, color: ACCENT, flexShrink: 0 }} />
                            <Typography
                              variant="body2"
                              fontWeight={700}
                              sx={{ color: INK, lineHeight: 1.4 }}
                            >
                              {selectedCheckContextLabel}
                            </Typography>
                          </Stack>
                        ) : (
                          <Chip
                            size="small"
                            label="Chưa chọn thời điểm"
                            sx={{
                              mt: 0.55,
                              height: 24,
                              fontWeight: 700,
                              bgcolor: alpha(INK, 0.04),
                              color: 'text.secondary',
                              border: `1px dashed ${alpha(INK, 0.18)}`,
                            }}
                          />
                        )}
                      </>
                    )}
                  </Box>

                  <Box
                    className="check-context-toggle"
                    aria-hidden
                    sx={{
                      width: 30,
                      height: 30,
                      borderRadius: 1.35,
                      flexShrink: 0,
                      display: 'grid',
                      placeItems: 'center',
                      color: ACCENT,
                      bgcolor: alpha(ACCENT, 0.08),
                      transition: 'background-color 0.12s ease, transform 0.18s ease',
                      transform: checkContextExpanded ? 'rotate(0deg)' : 'rotate(0deg)',
                    }}
                  >
                    {checkContextExpanded ? (
                      <ExpandLessIcon sx={{ fontSize: 20 }} />
                    ) : (
                      <ExpandMoreIcon sx={{ fontSize: 20 }} />
                    )}
                  </Box>
                </Stack>
              </Box>
              <Collapse in={checkContextExpanded} timeout="auto" unmountOnExit>
                <Box sx={{ p: 1.75 }}>
                  <FormControl component="fieldset" fullWidth disabled={readOnly || !!existing} required>
                    <RadioGroup
                      value={checkContextCode}
                      onChange={(e) => setCheckContextCode(e.target.value)}
                    >
                      {checkOptions.options.map((o) => (
                        <FormControlLabel
                          key={o.code}
                          value={o.code}
                          control={
                            <Radio
                              size="small"
                              sx={{
                                p: 0.75,
                                color: alpha(ACCENT, 0.45),
                                '&.Mui-checked': { color: ACCENT },
                              }}
                            />
                          }
                          label={o.label}
                          sx={{
                            mx: 0,
                            mb: 0.15,
                            py: 0.2,
                            alignItems: 'center',
                            gap: 0.25,
                            '& .MuiFormControlLabel-label': {
                              fontSize: '0.875rem',
                              lineHeight: 1.45,
                              fontWeight: checkContextCode === o.code ? 700 : 500,
                            },
                          }}
                        />
                      ))}
                    </RadioGroup>
                  </FormControl>
                </Box>
              </Collapse>
            </Box>
          )}

          {procedure && (
            <PaperMeta
              procedure={procedure}
              scoredSteps={scoredSteps}
              totalSteps={totalSteps}
              overallPct={overallPct}
              existing={existing}
              readOnly={readOnly}
            />
          )}

          {procedure?.note && (
            <Alert severity="info" variant="outlined" sx={{ borderRadius: 2.25 }}>
              {procedure.note}
            </Alert>
          )}

          {procedure?.sections.map((section) => {
            const sectionMax = section.steps.reduce((s, st) => s + st.maxPoints, 0);
            const sectionScore = section.steps.reduce((s, st) => s + (scores[st.id] ?? 0), 0);
            const sectionPct = sectionMax > 0 ? Math.round((sectionScore / sectionMax) * 100) : 0;
            return (
              <Box
                key={section.id}
                sx={{
                  borderRadius: 2.75,
                  bgcolor: '#fff',
                  border: `1px solid ${alpha(INK, 0.07)}`,
                  overflow: 'hidden',
                  boxShadow: `0 6px 16px ${alpha(INK, 0.025)}`,
                }}
              >
                <Box
                  sx={{
                    px: 1.85,
                    py: 1.25,
                    background: `linear-gradient(90deg, ${alpha(ACCENT, 0.08)} 0%, ${alpha(ACCENT, 0.02)} 100%)`,
                    borderBottom: `1px solid ${alpha(ACCENT, 0.1)}`,
                  }}
                >
                  <Stack direction="row" justifyContent="space-between" alignItems="center" spacing={1.5}>
                    <Typography variant="subtitle2" fontWeight={850} sx={{ letterSpacing: '-0.01em' }}>
                      {section.title}
                    </Typography>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <Typography variant="caption" fontWeight={750} sx={{ color: ACCENT }}>
                        {sectionScore.toFixed(2)} / {sectionMax}
                      </Typography>
                      <Chip
                        size="small"
                        label={`${sectionPct}%`}
                        sx={{
                          height: 22,
                          fontWeight: 800,
                          bgcolor: alpha(scoreTone(sectionPct), 0.1),
                          color: scoreTone(sectionPct),
                        }}
                      />
                    </Stack>
                  </Stack>
                  <LinearProgress
                    variant="determinate"
                    value={Math.min(100, sectionPct)}
                    sx={{
                      mt: 1,
                      height: 5,
                      borderRadius: 99,
                      bgcolor: alpha(ACCENT, 0.1),
                      '& .MuiLinearProgress-bar': {
                        borderRadius: 99,
                        bgcolor: scoreTone(sectionPct),
                      },
                    }}
                  />
                </Box>
                <Stack spacing={1} sx={{ p: 1.4 }}>
                  {section.steps.map((step) => (
                    <ScoreField
                      key={step.id}
                      no={step.no}
                      title={step.title}
                      detail={step.detail}
                      max={step.maxPoints}
                      value={scores[step.id] ?? 0}
                      disabled={readOnly}
                      required={Boolean(step.required)}
                      onChange={(v) => setScores((prev) => ({ ...prev, [step.id]: v }))}
                    />
                  ))}
                </Stack>
              </Box>
            );
          })}

          <TextField
            label="Ghi chú"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            multiline
            minRows={2}
            disabled={readOnly}
            fullWidth
            placeholder="Ghi chú thêm (nếu có)…"
            sx={{
              bgcolor: '#fff',
              borderRadius: 2.25,
              '& .MuiOutlinedInput-root': { borderRadius: 2.25 },
            }}
          />
        </Stack>
      </DialogContent>

      <Box
        sx={{
          px: { xs: 1.75, sm: 2.75 },
          py: 1.65,
          bgcolor: '#fff',
          borderTop: `1px solid ${alpha(INK, 0.08)}`,
          boxShadow: `0 -8px 24px ${alpha(INK, 0.04)}`,
        }}
      >
        <Stack
          direction={{ xs: 'column', sm: 'row' }}
          spacing={1.25}
          alignItems={{ sm: 'center' }}
          justifyContent="space-between"
        >
          {procedure && (
            <Stack direction="row" spacing={1.25} alignItems="center">
              <Box
                sx={{
                  px: 1.35,
                  py: 0.7,
                  borderRadius: 2,
                  bgcolor: alpha(scoreTone(overallPct), 0.1),
                  border: `1px solid ${alpha(scoreTone(overallPct), 0.2)}`,
                }}
              >
                <Typography variant="caption" color="text.secondary" fontWeight={700} display="block" sx={{ lineHeight: 1.1 }}>
                  Tổng điểm
                </Typography>
                <Typography fontWeight={850} sx={{ color: scoreTone(overallPct), letterSpacing: '-0.03em', lineHeight: 1.15 }}>
                  {total.toFixed(2)} / {procedure.maxTotal}
                  <Typography component="span" variant="caption" fontWeight={750} sx={{ ml: 0.75, color: 'text.secondary' }}>
                    ({overallPct}%)
                  </Typography>
                </Typography>
              </Box>
              <Typography variant="caption" color="text.secondary" sx={{ display: { xs: 'none', md: 'block' } }}>
                Đã chấm {scoredSteps}/{totalSteps} bước
              </Typography>
            </Stack>
          )}
          <Stack direction="row" spacing={1.15} justifyContent="flex-end" flexWrap="wrap" useFlexGap>
            <Button
              onClick={onClose}
              disabled={loading}
              variant="outlined"
              color="inherit"
              sx={{ borderRadius: 2, fontWeight: 700 }}
            >
              {readOnly ? 'Đóng' : 'Hủy'}
            </Button>
            {readOnly && existing?.canRecall && (
              <Button
                onClick={() => void recall()}
                disabled={loading}
                variant="outlined"
                color="warning"
                startIcon={loading ? <CircularProgress size={16} /> : <UndoOutlinedIcon />}
                sx={{ borderRadius: 2, fontWeight: 750 }}
              >
                Thu hồi
              </Button>
            )}
            {!readOnly && (
              <>
                <Button
                  onClick={() => void save(false)}
                  disabled={loading}
                  variant="outlined"
                  startIcon={loading ? <CircularProgress size={16} /> : <SaveOutlinedIcon />}
                  sx={{
                    borderRadius: 2,
                    fontWeight: 750,
                    borderColor: alpha(ACCENT, 0.35),
                    color: ACCENT,
                  }}
                >
                  Lưu nháp
                </Button>
                <Button
                  onClick={() => void save(true)}
                  disabled={loading}
                  variant="contained"
                  startIcon={loading ? <CircularProgress size={16} color="inherit" /> : <SendIcon />}
                  sx={{
                    borderRadius: 2,
                    fontWeight: 800,
                    bgcolor: ACCENT,
                    px: 2,
                    boxShadow: `0 8px 18px ${alpha(ACCENT, 0.28)}`,
                    '&:hover': { bgcolor: ACCENT, filter: 'brightness(0.93)' },
                  }}
                >
                  Gửi Trưởng phòng ĐD
                </Button>
              </>
            )}
          </Stack>
        </Stack>
      </Box>
    </Dialog>
  );
}

function PaperMeta({
  procedure,
  scoredSteps,
  totalSteps,
  overallPct,
  existing,
  readOnly,
}: {
  procedure: qtkt.QtktProcedure;
  scoredSteps: number;
  totalSteps: number;
  overallPct: number;
  existing?: qtkt.QtktEvaluation | null;
  readOnly: boolean;
}) {
  return (
    <Box
      sx={{
        display: 'flex',
        flexWrap: 'wrap',
        gap: 1,
        alignItems: 'center',
        justifyContent: 'space-between',
        px: 1.5,
        py: 1.15,
        borderRadius: 2.5,
        bgcolor: '#fff',
        border: `1px solid ${alpha(INK, 0.07)}`,
      }}
    >
      <Stack direction="row" spacing={0.85} flexWrap="wrap" useFlexGap alignItems="center">
        <Chip
          size="small"
          icon={<BiotechOutlinedIcon sx={{ fontSize: '15px !important' }} />}
          label={procedure.name}
          sx={{
            fontWeight: 800,
            bgcolor: alpha(ACCENT, 0.1),
            color: ACCENT,
            '& .MuiChip-icon': { color: ACCENT },
          }}
        />
        <Chip
          size="small"
          icon={<AccessTimeOutlinedIcon sx={{ fontSize: '15px !important' }} />}
          label={`${procedure.durationMinutes} phút`}
          variant="outlined"
          sx={{ fontWeight: 700 }}
        />
        <Chip
          size="small"
          icon={<GradeOutlinedIcon sx={{ fontSize: '15px !important' }} />}
          label={`Tối đa ${procedure.maxTotal} điểm`}
          variant="outlined"
          sx={{ fontWeight: 700 }}
        />
        {existing?.status && (
          <Chip
            size="small"
            label={
              existing.status === 'SUBMITTED'
                ? 'Đã gửi'
                : existing.status === 'DRAFT'
                  ? 'Nháp'
                  : 'Đã hủy'
            }
            sx={{
              fontWeight: 750,
              bgcolor:
                existing.status === 'SUBMITTED'
                  ? alpha('#15803d', 0.1)
                  : existing.status === 'DRAFT'
                    ? alpha('#b45309', 0.1)
                    : alpha('#64748b', 0.1),
              color:
                existing.status === 'SUBMITTED'
                  ? '#15803d'
                  : existing.status === 'DRAFT'
                    ? '#b45309'
                    : '#64748b',
            }}
          />
        )}
        {readOnly && (
          <Chip size="small" label="Chỉ xem" variant="outlined" sx={{ fontWeight: 700 }} />
        )}
      </Stack>
      <Typography variant="caption" color="text.secondary" fontWeight={700}>
        Tiến độ chấm · {scoredSteps}/{totalSteps} bước · {overallPct}%
      </Typography>
    </Box>
  );
}
