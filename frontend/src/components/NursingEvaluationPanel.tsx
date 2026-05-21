import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Checkbox,
  Chip,
  FormControl,
  IconButton,
  InputAdornment,
  InputLabel,
  MenuItem,
  Paper,
  Select,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import RateReviewIcon from '@mui/icons-material/RateReview';
import SearchIcon from '@mui/icons-material/Search';
import { alpha } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as employeeService from '../services/employeeService';
import * as ne from '../services/nursingEvaluationService';

/** Bố cục theo mẫu Excel ảnh bạn gửi (xanh ngọc) */
const SHEET = {
  bg: '#ffffff',
  header: '#59a9a5',
  text: '#0b0f0f',
  textMuted: '#2b2b2b',
  border: 'rgba(0,0,0,0.55)',
};

type RosterStatusFilter = 'all' | 'no_sheet' | 'need_my_part' | 'done_my_part';

type RowState = {
  truongKhoa: string;
  ddt: string;
  truongKhoaNote: string;
  ddtNote: string;
  hd: string;
  hdNote: string;
};

function defaultRows(groups: ne.CriterionGroup[]): Record<string, RowState> {
  const out: Record<string, RowState> = {};
  for (const g of groups) {
    const vi = g.id.startsWith('VI_');
    out[g.id] = {
      truongKhoa: vi ? '0' : '',
      ddt: vi ? '0' : '',
      truongKhoaNote: '',
      ddtNote: '',
      hd: '',
      hdNote: '',
    };
  }
  return out;
}

function mergeRowsFromApi(
  groups: ne.CriterionGroup[],
  base: Record<string, RowState>,
  scoresUnknown: unknown
): Record<string, RowState> {
  const out = { ...base };
  if (!scoresUnknown || typeof scoresUnknown !== 'object') return out;
  const raw = scoresUnknown as Record<string, Record<string, unknown>>;
  for (const g of groups) {
    const part = raw[g.id];
    if (!part || typeof part !== 'object') continue;
    const row = { ...out[g.id] };
    for (const k of ['truongKhoa', 'ddt'] as const) {
      const v = part[k];
      if (v != null && v !== '') row[k] = String(v);
    }
    const vhd = part.hd;
    if (vhd != null && vhd !== '') row.hd = String(vhd);
    const ntk = part.truongKhoaNote;
    const ndt = part.ddtNote;
    if (ntk != null) row.truongKhoaNote = String(ntk);
    if (ndt != null) row.ddtNote = String(ndt);
    const nhd = part.hdNote;
    if (nhd != null) row.hdNote = String(nhd);
    out[g.id] = row;
  }
  return out;
}

/**
 * Phiếu chấm dạng bảng: STT — nội dung — điểm tối đa — Khoa phòng (điểm + ghi chú) — Điều dưỡng trưởng (điểm + ghi chú).
 * Không có cột tự đánh giá.
 */
export type NursingEvaluationEditFocus = {
  employeeId: number;
  periodYear: number;
  periodMonth: number;
};

type NursingEvaluationPanelProps = {
  editFocus?: NursingEvaluationEditFocus | null;
  onEditFocusConsumed?: () => void;
  /** Báo cho trang cha refetch (vd. bảng tổng hợp tháng) sau khi lưu phiếu thành công */
  onDataMutated?: () => void;
};

export function NursingEvaluationPanel({
  editFocus = null,
  onEditFocusConsumed,
  onDataMutated,
}: NursingEvaluationPanelProps = {}) {
  const templateCode = ne.MA2026_EVAL_TEMPLATE_CODE;
  const { user } = useAuth();

  /** Chuẩn hóa để tránh lệch chữ hoa/thường từ API hoặc dữ liệu cũ trong storage. */
  const role = (user?.role ?? '').toUpperCase();
  const isAdmin = role === 'ADMIN';
  const isHr = role === 'HR';
  const isDeptHead = role === 'HEAD_DEPARTMENT';
  const isNursingHead = role === 'HEAD_NURSING';
  const isEmployee = role === 'EMPLOYEE';

  const canPickEmployee = isAdmin || isDeptHead || isNursingHead || isHr;
  const canEdit = isAdmin || isDeptHead || isNursingHead || isHr;
  const showTkCol = isAdmin || isDeptHead; // chỉ trưởng khoa thấy cột trưởng khoa
  const showDdtCol = isAdmin || isNursingHead; // chỉ ĐDT thấy cột ĐDT
  const showHdCol = isAdmin || isHr; // chỉ hội đồng (HR) thấy phần HD_*

  const editTk = isAdmin || isDeptHead;
  const editDdt = isAdmin || isNursingHead;
  const editHd = isAdmin || isHr;

  const [template, setTemplate] = useState<ne.NursingTemplate | null>(null);
  const [roster, setRoster] = useState<employeeService.EmployeeSummary[]>([]);
  const [employeeId, setEmployeeId] = useState<number | ''>('');
  const [year, setYear] = useState(new Date().getFullYear());
  const [month, setMonth] = useState(new Date().getMonth() + 1);
  const [rows, setRows] = useState<Record<string, RowState>>({});
  // Ghi chú chung đã bỏ theo yêu cầu
  const [history, setHistory] = useState<ne.NursingEvalRow[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [ok, setOk] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const panelRef = useRef<HTMLDivElement | null>(null);
  const formSheetRef = useRef<HTMLDivElement | null>(null);
  const [periodStatusRows, setPeriodStatusRows] = useState<ne.NursingPeriodStatusRow[]>([]);
  const [periodStatusLoading, setPeriodStatusLoading] = useState(false);
  const [rosterStatusFilter, setRosterStatusFilter] = useState<RosterStatusFilter>('all');
  const [departmentFilter, setDepartmentFilter] = useState<string>('all');
  const [rosterSearchText, setRosterSearchText] = useState('');

  const loadPeriodStatus = useCallback(async () => {
    if (!canPickEmployee) return;
    setPeriodStatusLoading(true);
    try {
      const rows = await ne.fetchNursingPeriodStatus(year, month, templateCode);
      setPeriodStatusRows(rows);
    } catch {
      setPeriodStatusRows([]);
    } finally {
      setPeriodStatusLoading(false);
    }
  }, [canPickEmployee, year, month, templateCode]);

  useEffect(() => {
    void loadPeriodStatus();
  }, [loadPeriodStatus]);

  const groups = template?.criteriaGroups ?? [];

  /** Chỉ render đúng phần việc của từng vai trò (HCNS: 30 điểm HD; khoa/ĐDT/NV: I–VI, không HD). */
  const groupsForTable = useMemo(() => {
    if (!template?.criteriaGroups?.length) return [];
    const all = template.criteriaGroups;
    if (isAdmin) return all;
    if (isHr) return all.filter((g) => g.id.startsWith('HD_'));
    return all.filter((g) => !g.id.startsWith('HD_'));
  }, [template, isAdmin, isHr]);

  const activeRow = useMemo(() => {
    return history.find(
      (x) => Number(x.periodYear) === year && Number(x.periodMonth) === month && String(x.templateCode) === templateCode
    );
  }, [history, month, templateCode, year]);

  const channelEvalStatus = useMemo(() => {
    const scores = activeRow?.scores as Record<string, unknown> | undefined;
    if (!scores || typeof scores !== 'object') return null;
    const raw = scores['__channelEvaluators__'];
    if (!raw || typeof raw !== 'object') return null;
    return raw as Record<string, { username?: string; displayName?: string; savedAt?: string }>;
  }, [activeRow]);

  const channelStatusLines = useMemo(() => {
    if (!channelEvalStatus) return [];
    const labels: Record<string, string> = {
      truongKhoa: 'Trưởng khoa phòng',
      ddt: 'Điều dưỡng trưởng',
      hd: 'Hội đồng (30 điểm)',
    };
    const out: string[] = [];
    for (const key of Object.keys(labels)) {
      const slot = channelEvalStatus[key];
      const name = ne.formatChannelEvaluatorName(slot);
      if (!name) continue;
      const when = ne.formatChannelEvalSavedAt(slot?.savedAt);
      out.push(`${labels[key]}: đã lưu bởi «${name}»${when ? ` — ${when}` : ''}.`);
    }
    return out;
  }, [channelEvalStatus]);

  /** Đã có điểm lưu trên server đúng kênh / vai trò hiện tại → mặc định hiện nút Sửa. */
  const hasMyChannelData = useMemo(() => {
    const scores = activeRow?.scores as Record<string, Record<string, unknown>> | undefined;
    if (!scores) return false;
    const skipMeta = (id: string) => id === '__channelEvaluators__';

    if (isAdmin) {
      for (const g of groups) {
        if (skipMeta(g.id)) continue;
        const row = scores[g.id];
        if (!row) continue;
        if (g.id.startsWith('HD_')) {
          if (row.hd != null && String(row.hd).trim() !== '') return true;
        } else {
          const tk = row.truongKhoa != null && String(row.truongKhoa).trim() !== '';
          const ddt = row.ddt != null && String(row.ddt).trim() !== '';
          if (tk && ddt) return true;
        }
      }
      return false;
    }
    if (isDeptHead) {
      return Object.entries(scores).some(
        ([id, row]) =>
          !skipMeta(id) &&
          !id.startsWith('HD_') &&
          row?.truongKhoa != null &&
          String(row.truongKhoa).trim() !== ''
      );
    }
    if (isNursingHead) {
      return Object.entries(scores).some(
        ([id, row]) =>
          !skipMeta(id) && !id.startsWith('HD_') && row?.ddt != null && String(row.ddt).trim() !== ''
      );
    }
    if (isHr) {
      return Object.entries(scores).some(
        ([id, row]) => id.startsWith('HD_') && row?.hd != null && String(row.hd).trim() !== ''
      );
    }
    return false;
  }, [activeRow, groups, isAdmin, isDeptHead, isHr, isNursingHead]);

  const [saveUiPhase, setSaveUiPhase] = useState<'save' | 'sua'>('save');

  useEffect(() => {
    setSaveUiPhase(hasMyChannelData ? 'sua' : 'save');
  }, [employeeId, year, month, hasMyChannelData]);

  const formLocked = canEdit && saveUiPhase === 'sua';

  const statusByEmployeeId = useMemo(() => {
    const m = new Map<number, ne.NursingPeriodStatusRow>();
    for (const r of periodStatusRows) {
      m.set(r.employeeId, r);
    }
    return m;
  }, [periodStatusRows]);

  const departmentOptions = useMemo(() => {
    const s = new Set<string>();
    for (const em of roster) {
      if (em.departmentName) s.add(em.departmentName);
    }
    return Array.from(s).sort((a, b) => a.localeCompare(b, 'vi'));
  }, [roster]);

  const channelComplete = useCallback((st: ne.NursingPeriodStatusRow | undefined) => {
    if (!st) return false;
    if (isAdmin) return st.hasTruongKhoa && st.hasDdt && st.hasHd;
    if (isHr) return st.hasHd;
    if (isDeptHead) return st.hasTruongKhoa;
    if (isNursingHead) return st.hasDdt;
    return false;
  }, [isAdmin, isHr, isDeptHead, isNursingHead]);

  const filteredRoster = useMemo(() => {
    return roster.filter((em) => {
      if (departmentFilter !== 'all' && em.departmentName !== departmentFilter) return false;
      const st = statusByEmployeeId.get(em.id);
      const hasSheet = statusByEmployeeId.has(em.id);
      switch (rosterStatusFilter) {
        case 'all':
          return true;
        case 'no_sheet':
          return !hasSheet;
        case 'need_my_part':
          return !channelComplete(st);
        case 'done_my_part':
          return channelComplete(st);
        default:
          return true;
      }
    });
  }, [roster, rosterStatusFilter, departmentFilter, statusByEmployeeId, channelComplete]);

  const displayRoster = useMemo(() => {
    const q = rosterSearchText.trim().toLowerCase();
    if (!q) return filteredRoster;
    return filteredRoster.filter((em) => {
      const hay = `${em.employeeCode ?? ''} ${em.fullName} ${em.departmentName} ${em.username ?? ''}`.toLowerCase();
      return hay.includes(q);
    });
  }, [filteredRoster, rosterSearchText]);

  const openEmployeeSheet = useCallback((em: employeeService.EmployeeSummary) => {
    setEmployeeId(em.id);
    setErr(null);
    setOk(null);
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        formSheetRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    });
  }, []);

  const showEvalSheet = !canPickEmployee || employeeId !== '';

  useEffect(() => {
    if (departmentFilter !== 'all' && !departmentOptions.includes(departmentFilter)) {
      setDepartmentFilter('all');
    }
  }, [departmentFilter, departmentOptions]);

  const totals = useMemo(() => {
    if (!template) {
      return {
        total70: null as number | null,
        bonusVI: 0,
        total30: null as number | null,
        totalWithBonus: null as number | null,
        maxBase70: 70,
        maxBonus12: 12,
      };
    }

    const isVi = (id: string) => id.startsWith('VI_');
    const isHdCrit = (id: string) => id.startsWith('HD_');

    const maxBase70 = groups
      .filter((g) => !isHdCrit(g.id) && !isVi(g.id))
      .reduce((s, g) => s + (g.maxPoints ?? 0), 0);
    const maxBonus12 = groups.filter((g) => isVi(g.id)).reduce((s, g) => s + (g.maxPoints ?? 0), 0);

    const parse = (v: string | undefined) => {
      if (!v || v === '') return null;
      const n = Number(v);
      return Number.isFinite(n) ? n : null;
    };

    if (isHr) {
      const requiredHdIds = groups.filter((g) => isHdCrit(g.id)).map((g) => g.id);
      let sum = 0;
      for (const cid of requiredHdIds) {
        const v = parse(rows[cid]?.hd);
        if (v == null) {
          return {
            total70: null,
            bonusVI: 0,
            total30: null,
            totalWithBonus: null,
            maxBase70,
            maxBonus12,
          };
        }
        sum += v;
      }
      return {
        total70: null,
        bonusVI: 0,
        total30: Number(sum.toFixed(2)),
        totalWithBonus: null,
        maxBase70,
        maxBonus12,
      };
    }

    const deptChannelKey: keyof RowState = isDeptHead ? 'truongKhoa' : isNursingHead ? 'ddt' : 'truongKhoa';
    const requiredDeptIds = groups
      .filter((g) => !isHdCrit(g.id) && !isVi(g.id))
      .map((g) => g.id);
    let sum70 = 0;
    for (const cid of requiredDeptIds) {
      const v = parse(rows[cid]?.[deptChannelKey]);
      if (v == null) {
        return {
          total70: null,
          bonusVI: 0,
          total30: null,
          totalWithBonus: null,
          maxBase70,
          maxBonus12,
        };
      }
      sum70 += v;
    }

    const bonusIds = groups.filter((g) => isVi(g.id)).map((g) => g.id);
    let bonusSum = 0;
    for (const cid of bonusIds) {
      const v = parse(rows[cid]?.[deptChannelKey]);
      bonusSum += v ?? 0;
    }

    const baseN = Number(sum70.toFixed(2));
    const bonusN = Number(bonusSum.toFixed(2));

    return {
      total70: baseN,
      bonusVI: bonusN,
      total30: null,
      totalWithBonus: Number((baseN + bonusN).toFixed(2)),
      maxBase70,
      maxBonus12,
    };
  }, [groups, isDeptHead, isHr, isNursingHead, rows, template]);

  useEffect(() => {
    let c = false;
    ne.fetchNursingTemplate(templateCode).then((t) => {
      if (!c) {
        setTemplate(t);
        setRows(defaultRows(t.criteriaGroups));
      }
    });
    return () => {
      c = true;
    };
  }, [templateCode]);

  useEffect(() => {
    if (!canPickEmployee) {
      if (user?.employeeId) setEmployeeId(user.employeeId);
      return;
    }
    employeeService.fetchEvaluationRoster().then(setRoster).catch(() => setRoster([]));
  }, [canPickEmployee, user?.employeeId]);

  useEffect(() => {
    if (employeeId === '') return;
    let c = false;
    ne.fetchNursingHistory(Number(employeeId)).then((h) => {
      if (c) return;
      setHistory(h);
      const row = h.find(
        (x) =>
          Number(x.periodYear) === year &&
          Number(x.periodMonth) === month &&
          String(x.templateCode) === templateCode
      );
      if (template) {
        const base = defaultRows(template.criteriaGroups);
        setRows(mergeRowsFromApi(template.criteriaGroups, base, row?.scores));
      }
    });
    return () => {
      c = true;
    };
  }, [employeeId, year, month, template, templateCode]);

  useEffect(() => {
    if (!editFocus) return;
    setEmployeeId(editFocus.employeeId);
    setYear(editFocus.periodYear);
    setMonth(editFocus.periodMonth);
    onEditFocusConsumed?.();
    const id = requestAnimationFrame(() => {
      panelRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      requestAnimationFrame(() => {
        formSheetRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      });
    });
    return () => cancelAnimationFrame(id);
  }, [editFocus, onEditFocusConsumed]);

  function setRowField(id: string, field: keyof RowState, value: string) {
    setRows((prev) => ({
      ...prev,
      [id]: {
        ...(prev[id] || { truongKhoa: '', ddt: '', truongKhoaNote: '', ddtNote: '', hd: '', hdNote: '' }),
        [field]: value,
      },
    }));
  }

  const titleBlock = useMemo(
    () => (
      <Box sx={{ mb: 2 }}>
        <Typography variant="h6" fontWeight={800} sx={{ color: SHEET.text, letterSpacing: '0.01em' }}>
          {isHr
            ? 'Đánh giá ĐD-KTV-HS (MA 2026) — Hội đồng (30 điểm)'
            : 'Đánh giá ĐD-KTV-HS (MA 2026) — khoa phòng (I–V + điểm thưởng)'}
        </Typography>
      </Box>
    ),
    [isHr]
  );

  async function onSave() {
    setErr(null);
    setOk(null);
    if (employeeId === '') {
      setErr('Chọn nhân viên.');
      return;
    }
    if (!template) return;

    if (isAdmin) {
      const bodyScores: Record<string, ne.CriterionScorePayload> = {};
      for (const g of groups) {
        const r = rows[g.id];
        if (!r) continue;
        const payload: ne.CriterionScorePayload = {
          truongKhoa: Number(r.truongKhoa),
          ddt: Number(r.ddt),
        };
        if (g.id.startsWith('HD_')) {
          payload.hd = Number(r.hd);
          if (r.hdNote.trim()) payload.hdNote = r.hdNote.trim();
        } else {
          if (r.truongKhoaNote.trim()) payload.truongKhoaNote = r.truongKhoaNote.trim();
          if (r.ddtNote.trim()) payload.ddtNote = r.ddtNote.trim();
        }
        bodyScores[g.id] = payload;
      }
      setLoading(true);
      try {
        await ne.submitNursingEvaluation({
          employeeId: Number(employeeId),
          periodYear: year,
          periodMonth: month,
          templateCode,
          scores: bodyScores,
        });
        setOk('Đã lưu phiếu (hai cột đánh giá + ghi chú).');
        setSaveUiPhase('sua');
        setHistory(await ne.fetchNursingHistory(Number(employeeId)));
        void loadPeriodStatus();
        onDataMutated?.();
      } catch {
        setErr('Không lưu được — kiểm tra mỗi ô điểm phải chọn đúng một mức trong thang.');
      } finally {
        setLoading(false);
      }
      return;
    }

    const channel =
      isDeptHead ? ('truongKhoa' as const) : isNursingHead ? ('ddt' as const) : isHr ? ('hd' as const) : null;
    if (!channel) {
      setErr('Tài khoản không được phép lưu điểm.');
      return;
    }

    const part: Record<string, number> = {};
    const notes: Record<string, string> = {};
    for (const g of groups) {
      const r = rows[g.id];
      if (!r) continue;
      if (channel === 'hd' && !g.id.startsWith('HD_')) continue;
      if (channel !== 'hd' && g.id.startsWith('HD_')) continue;

      const raw = (r as any)[channel] as string | undefined;

      if (g.id.startsWith('VI_')) {
        const n = raw === '' || raw == null ? 0 : Number(raw);
        if (!Number.isFinite(n) || (n !== 0 && n !== 3)) {
          setErr('Điểm thưởng: mỗi tiêu chí chỉ 0 hoặc 3 điểm.');
          return;
        }
        part[g.id] = n;
      } else {
        if (raw === '' || raw == null || Number.isNaN(Number(raw))) {
          setErr('Chọn đủ điểm cho từng dòng tiêu chí.');
          return;
        }
        part[g.id] = Number(raw);
      }

      const noteKey = channel === 'truongKhoa' ? 'truongKhoaNote' : channel === 'ddt' ? 'ddtNote' : 'hdNote';
      const noteText = (r as any)[noteKey].trim();
      if (noteText) notes[g.id] = noteText;
    }

    setLoading(true);
    try {
      await ne.submitNursingEvaluationChannel({
        employeeId: Number(employeeId),
        periodYear: year,
        periodMonth: month,
        templateCode,
        channel,
        scores: part,
        ...(Object.keys(notes).length ? { notes } : {}),
      });
      setOk(
        channel === 'truongKhoa'
          ? 'Đã lưu cột khoa phòng.'
          : channel === 'ddt'
            ? 'Đã lưu cột Điều dưỡng trưởng.'
            : 'Đã lưu phần Hội đồng (30 điểm).'
      );
      setSaveUiPhase('sua');
      setHistory(await ne.fetchNursingHistory(Number(employeeId)));
      void loadPeriodStatus();
      onDataMutated?.();
    } catch {
      setErr('Không lưu được. Kiểm tra quyền và mức điểm hợp lệ.');
    } finally {
      setLoading(false);
    }
  }

  // HCNS chấm phần 30 điểm ngay trên phiếu, nên không return sớm.

  return (
    <Box ref={panelRef}>
      {!template && <Typography color="text.secondary">Đang tải mẫu…</Typography>}

      {template && (
        <Card
          elevation={0}
          sx={{
            bgcolor: SHEET.bg,
            border: `1px solid ${SHEET.border}`,
            borderRadius: 2,
            overflow: 'hidden',
          }}
        >
          <CardContent sx={{ p: { xs: 1.5, sm: 2.5 } }}>
            {titleBlock}

            {isEmployee && (
              <Alert
                severity="info"
                sx={{
                  mb: 2,
                  bgcolor: alpha(SHEET.header, 0.1),
                  color: SHEET.textMuted,
                  border: `1px solid ${SHEET.border}`,
                }}
              >
                Bạn chỉ <strong style={{ color: SHEET.text }}>xem</strong> phiếu đánh giá.
              </Alert>
            )}

            {!canPickEmployee && (
              <Stack direction="row" spacing={2} sx={{ mb: 2 }} flexWrap="wrap" useFlexGap>
                <TextField
                  size="small"
                  type="number"
                  label="Năm"
                  value={year}
                  onChange={(e) => setYear(Number(e.target.value))}
                  sx={{
                    width: 110,
                    input: { color: SHEET.text },
                    label: { color: SHEET.textMuted },
                    '& .MuiOutlinedInput-notchedOutline': { borderColor: SHEET.border },
                  }}
                />
                <TextField
                  size="small"
                  type="number"
                  label="Tháng"
                  value={month}
                  onChange={(e) => setMonth(Number(e.target.value))}
                  inputProps={{ min: 1, max: 12 }}
                  sx={{
                    width: 100,
                    input: { color: SHEET.text },
                    label: { color: SHEET.textMuted },
                    '& .MuiOutlinedInput-notchedOutline': { borderColor: SHEET.border },
                  }}
                />
              </Stack>
            )}

            {canPickEmployee && (
              <Paper
                elevation={0}
                sx={{
                  mb: 2,
                  p: 2,
                  border: `1px solid ${SHEET.border}`,
                  borderRadius: 1,
                  bgcolor: '#fafcfc',
                }}
              >
                <Stack spacing={2}>
                  <Typography variant="subtitle1" fontWeight={800} sx={{ color: SHEET.text }}>
                    Chọn nhân viên đánh giá
                  </Typography>
                  <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} flexWrap="wrap" useFlexGap>
                    <TextField
                      size="small"
                      type="number"
                      label="Năm"
                      value={year}
                      onChange={(e) => setYear(Number(e.target.value))}
                      sx={{
                        width: 110,
                        input: { color: SHEET.text },
                        label: { color: SHEET.textMuted },
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: SHEET.border },
                      }}
                    />
                    <TextField
                      size="small"
                      type="number"
                      label="Tháng"
                      value={month}
                      onChange={(e) => setMonth(Number(e.target.value))}
                      inputProps={{ min: 1, max: 12 }}
                      sx={{
                        width: 100,
                        input: { color: SHEET.text },
                        label: { color: SHEET.textMuted },
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: SHEET.border },
                      }}
                    />
                    <FormControl size="small" sx={{ minWidth: { xs: '100%', sm: 200 } }}>
                      <InputLabel sx={{ color: SHEET.textMuted }}>Khoa / phòng</InputLabel>
                      <Select
                        label="Khoa / phòng"
                        value={departmentFilter}
                        onChange={(e) => setDepartmentFilter(String(e.target.value))}
                        sx={{
                          color: SHEET.text,
                          '.MuiOutlinedInput-notchedOutline': { borderColor: SHEET.border },
                          '&:hover .MuiOutlinedInput-notchedOutline': { borderColor: SHEET.header },
                        }}
                      >
                        <MenuItem value="all">Tất cả</MenuItem>
                        {departmentOptions.map((d) => (
                          <MenuItem key={d} value={d}>
                            {d}
                          </MenuItem>
                        ))}
                      </Select>
                    </FormControl>
                    <FormControl size="small" sx={{ minWidth: { xs: '100%', sm: 280 } }}>
                      <InputLabel sx={{ color: SHEET.textMuted }}>Trạng thái đánh giá</InputLabel>
                      <Select
                        label="Trạng thái đánh giá"
                        value={rosterStatusFilter}
                        onChange={(e) => setRosterStatusFilter(e.target.value as RosterStatusFilter)}
                        sx={{
                          color: SHEET.text,
                          '.MuiOutlinedInput-notchedOutline': { borderColor: SHEET.border },
                          '&:hover .MuiOutlinedInput-notchedOutline': { borderColor: SHEET.header },
                        }}
                      >
                        <MenuItem value="all">Tất cả ({roster.length})</MenuItem>
                        <MenuItem value="no_sheet">Chưa có phiếu tháng này</MenuItem>
                        <MenuItem value="need_my_part">
                          {isAdmin
                            ? 'Chưa đủ 3 kênh (khoa + ĐDT + HĐ)'
                            : isHr
                              ? 'Chưa chấm / chưa xong hội đồng'
                              : isDeptHead
                                ? 'Chưa chấm / chưa xong khoa phòng'
                                : isNursingHead
                                  ? 'Chưa chấm / chưa xong ĐDT'
                                  : 'Chưa xong phần của tôi'}
                        </MenuItem>
                        <MenuItem value="done_my_part">
                          {isAdmin
                            ? 'Đã đủ 3 kênh'
                            : isHr
                              ? 'Đã chấm hội đồng'
                              : isDeptHead
                                ? 'Đã chấm khoa phòng'
                                : isNursingHead
                                  ? 'Đã chấm ĐDT'
                                  : 'Đã xong phần của tôi'}
                        </MenuItem>
                      </Select>
                    </FormControl>
                    <TextField
                      size="small"
                      value={rosterSearchText}
                      onChange={(e) => setRosterSearchText(e.target.value)}
                      placeholder="Tìm mã NV, họ tên, khoa…"
                      InputProps={{
                        startAdornment: (
                          <InputAdornment position="start">
                            <SearchIcon sx={{ color: SHEET.textMuted, fontSize: 20 }} />
                          </InputAdornment>
                        ),
                      }}
                      sx={{
                        flex: { md: 1 },
                        minWidth: { xs: '100%', md: 240 },
                        '& .MuiOutlinedInput-root': { color: SHEET.text },
                        '& .MuiOutlinedInput-notchedOutline': { borderColor: SHEET.border },
                      }}
                    />
                  </Stack>
                  <Typography variant="caption" sx={{ color: SHEET.textMuted }}>
                    Hiển thị {displayRoster.length}/{roster.length} nhân viên sau lọc.
                    {periodStatusLoading ? ' Đang đồng bộ trạng thái kỳ…' : ''}
                    {displayRoster.length === 0 && roster.length > 0 && !periodStatusLoading
                      ? ' Không có dòng khớp — đổi bộ lọc hoặc từ khóa tìm kiếm.'
                      : ''}
                  </Typography>
                  <TableContainer
                    component={Paper}
                    elevation={0}
                    sx={{
                      maxHeight: 380,
                      border: `1px solid ${SHEET.border}`,
                      borderRadius: 0,
                      bgcolor: '#fff',
                    }}
                  >
                    <Table size="small" stickyHeader>
                      <TableHead>
                        <TableRow>
                          <TableCell sx={{ fontWeight: 800, bgcolor: SHEET.header, color: '#fff', borderColor: SHEET.border }}>
                            STT
                          </TableCell>
                          <TableCell sx={{ fontWeight: 800, bgcolor: SHEET.header, color: '#fff', borderColor: SHEET.border }}>
                            Mã NV
                          </TableCell>
                          <TableCell sx={{ fontWeight: 800, bgcolor: SHEET.header, color: '#fff', borderColor: SHEET.border }}>
                            Họ và tên
                          </TableCell>
                          <TableCell sx={{ fontWeight: 800, bgcolor: SHEET.header, color: '#fff', borderColor: SHEET.border }}>
                            Khoa / phòng
                          </TableCell>
                          <TableCell sx={{ fontWeight: 800, bgcolor: SHEET.header, color: '#fff', borderColor: SHEET.border }}>
                            Trạng thái kỳ
                          </TableCell>
                          <TableCell
                            align="center"
                            sx={{
                              fontWeight: 800,
                              bgcolor: SHEET.header,
                              color: '#fff',
                              borderColor: SHEET.border,
                              width: 88,
                            }}
                          >
                            Phiếu
                          </TableCell>
                        </TableRow>
                      </TableHead>
                      <TableBody>
                        {roster.length === 0 && (
                          <TableRow>
                            <TableCell colSpan={6} sx={{ borderColor: SHEET.border }}>
                              <Typography color="text.secondary">Đang tải danh sách nhân viên…</Typography>
                            </TableCell>
                          </TableRow>
                        )}
                        {roster.length > 0 && displayRoster.length === 0 && (
                          <TableRow>
                            <TableCell colSpan={6} sx={{ borderColor: SHEET.border }}>
                              <Typography color="text.secondary">Không có nhân viên khớp bộ lọc hoặc từ khóa.</Typography>
                            </TableCell>
                          </TableRow>
                        )}
                        {displayRoster.map((em, idx) => {
                          const st = statusByEmployeeId.get(em.id);
                          const hasSheet = statusByEmployeeId.has(em.id);
                          const done = channelComplete(st);
                          const statusChip = !hasSheet ? (
                            <Chip size="small" variant="outlined" label="Chưa có phiếu" sx={{ borderColor: SHEET.border }} />
                          ) : done ? (
                            <Chip size="small" color="success" label="Hoàn thành (theo vai trò)" />
                          ) : (
                            <Chip size="small" color="warning" label="Đang chấm / thiếu kênh" />
                          );
                          return (
                            <TableRow
                              key={em.id}
                              hover
                              selected={employeeId === em.id}
                              sx={{
                                '&.MuiTableRow-root': {
                                  ...(employeeId === em.id ? { bgcolor: alpha(SHEET.header, 0.14) } : {}),
                                },
                                '&.Mui-selected': { bgcolor: `${alpha(SHEET.header, 0.2)} !important` },
                              }}
                            >
                              <TableCell sx={{ borderColor: SHEET.border }}>{idx + 1}</TableCell>
                              <TableCell sx={{ fontWeight: 700, borderColor: SHEET.border }}>{em.employeeCode ?? '—'}</TableCell>
                              <TableCell sx={{ borderColor: SHEET.border }}>{em.fullName}</TableCell>
                              <TableCell sx={{ borderColor: SHEET.border }}>{em.departmentName}</TableCell>
                              <TableCell sx={{ borderColor: SHEET.border }}>{statusChip}</TableCell>
                              <TableCell align="center" sx={{ borderColor: SHEET.border }}>
                                <Tooltip title="Mở phiếu đánh giá">
                                  <IconButton
                                    size="small"
                                    sx={{ color: SHEET.header }}
                                    onClick={() => openEmployeeSheet(em)}
                                    aria-label={`Đánh giá ${em.fullName}`}
                                  >
                                    <RateReviewIcon fontSize="small" />
                                  </IconButton>
                                </Tooltip>
                              </TableCell>
                            </TableRow>
                          );
                        })}
                      </TableBody>
                    </Table>
                  </TableContainer>
                </Stack>
              </Paper>
            )}

            {err && (
              <Alert severity="error" sx={{ mb: 2 }}>
                {err}
              </Alert>
            )}
            {ok && (
              <Alert severity="success" sx={{ mb: 2 }}>
                {ok}
              </Alert>
            )}

            <Box ref={formSheetRef}>
            {showEvalSheet ? (
              <>
            {channelStatusLines.length > 0 && (
              <Alert severity="info" sx={{ mb: 2 }}>
                <Typography variant="subtitle2" fontWeight={700} gutterBottom>
                  Phiếu kỳ này
                </Typography>
                {channelStatusLines.map((line) => (
                  <Typography key={line} variant="body2" display="block">
                    {line}
                  </Typography>
                ))}
              </Alert>
            )}

            <TableContainer
              component={Paper}
              elevation={0}
              sx={{
                bgcolor: '#fff',
                border: `1px solid ${SHEET.border}`,
                borderRadius: 0,
                maxHeight: { xs: '70vh', md: 'none' },
              }}
            >
              <Table size="small" stickyHeader sx={{ minWidth: 960 }}>
                <TableHead>
                  <TableRow>
                    <TableCell
                      rowSpan={2}
                      sx={{
                        bgcolor: SHEET.header,
                        color: '#ffffff',
                        fontWeight: 900,
                        borderColor: SHEET.border,
                        verticalAlign: 'middle',
                        width: 48,
                      }}
                    >
                      STT
                    </TableCell>
                    <TableCell
                      rowSpan={2}
                      sx={{
                        bgcolor: SHEET.header,
                        color: '#ffffff',
                        fontWeight: 900,
                        borderColor: SHEET.border,
                        minWidth: 260,
                      }}
                    >
                      TIÊU CHÍ
                    </TableCell>
                    <TableCell
                      rowSpan={2}
                      align="center"
                      sx={{
                        bgcolor: SHEET.header,
                        color: '#ffffff',
                        fontWeight: 900,
                        borderColor: SHEET.border,
                        width: 88,
                      }}
                    >
                      THANG ĐIỂM
                    </TableCell>
                    <TableCell
                      colSpan={showTkCol && showDdtCol ? 2 : 1}
                      align="center"
                      sx={{
                        bgcolor: SHEET.header,
                        color: '#ffffff',
                        fontWeight: 900,
                        borderColor: SHEET.border,
                      }}
                    >
                      {showHdCol && !showTkCol && !showDdtCol ? 'HỘI ĐỒNG' : 'KHOA PHÒNG'}
                    </TableCell>
                  </TableRow>
                  <TableRow>
                    {showTkCol && (
                      <TableCell
                        align="center"
                        sx={{ bgcolor: SHEET.header, color: '#ffffff', fontWeight: 800, borderColor: SHEET.border }}
                      >
                        Trưởng khoa
                      </TableCell>
                    )}
                    {showDdtCol && (
                      <TableCell
                        align="center"
                        sx={{ bgcolor: SHEET.header, color: '#ffffff', fontWeight: 800, borderColor: SHEET.border }}
                      >
                        ĐDT
                      </TableCell>
                    )}
                    {showHdCol && !showTkCol && !showDdtCol && (
                      <TableCell
                        align="center"
                        sx={{ bgcolor: SHEET.header, color: '#ffffff', fontWeight: 800, borderColor: SHEET.border }}
                      >
                        Điểm
                      </TableCell>
                    )}
                  </TableRow>
                </TableHead>
                <TableBody>
                  {(() => {
                    const bySection = new Map<string, ne.CriterionGroup[]>();
                    for (const g of groupsForTable) {
                      const s = g.section || '—';
                      bySection.set(s, [...(bySection.get(s) || []), g]);
                    }
                    return Array.from(bySection.entries()).flatMap(([sec, items]) => {
                      const out: React.ReactNode[] = [];
                      const secStt = (() => {
                        // Excel style: I., II., III... when section begins with roman numerals
                        const m = /^([IVXLCDM]+)\./.exec(sec.trim());
                        return m ? `${m[1]}.` : '';
                      })();
                      const secLabel = sec.replace(/^([IVXLCDM]+)\.\s*/, '');
                      out.push(
                        <TableRow key={`sec-${sec}`}>
                          <TableCell
                            align="center"
                            sx={{ fontWeight: 900, fontStyle: 'italic', borderColor: SHEET.border, width: 48 }}
                          >
                            {secStt}
                          </TableCell>
                          <TableCell
                            colSpan={
                              2 +
                              (showTkCol ? 1 : 0) +
                              (showDdtCol ? 1 : 0) +
                              (showHdCol && !showTkCol && !showDdtCol ? 1 : 0)
                            }
                            sx={{ fontWeight: 900, fontStyle: 'italic', borderColor: SHEET.border }}
                          >
                            {secLabel}
                          </TableCell>
                        </TableRow>
                      );
                      for (const g of items) {
                        const r =
                          rows[g.id] ||
                          ({ truongKhoa: '', ddt: '', truongKhoaNote: '', ddtNote: '', hd: '', hdNote: '' } satisfies RowState);
                        const isHd = g.id.startsWith('HD_');
                        const isVi = g.id.startsWith('VI_');

                        const maxThang =
                          g.maxPoints != null
                            ? g.maxPoints
                            : g.options.length
                              ? Math.max(...g.options.map((o) => o.points))
                              : 0;

                        if (isVi) {
                          const deptEvalCols = (showTkCol ? 1 : 0) + (showDdtCol ? 1 : 0);
                          out.push(
                            <TableRow key={`vi-${g.id}`}>
                              <TableCell align="center" sx={{ borderColor: SHEET.border }}>
                                -
                              </TableCell>
                              <TableCell sx={{ borderColor: SHEET.border }}>{g.title}</TableCell>
                              <TableCell align="center" sx={{ borderColor: SHEET.border, fontWeight: 700 }}>
                                {maxThang}
                              </TableCell>
                              {deptEvalCols === 0 ? (
                                <TableCell align="center" sx={{ borderColor: SHEET.border, color: 'text.secondary' }}>
                                  —
                                </TableCell>
                              ) : (
                                <>
                                  {showTkCol && (
                                    <TableCell align="center" sx={{ borderColor: SHEET.border }}>
                                      <Checkbox
                                        size="small"
                                        checked={r.truongKhoa === '3'}
                                        disabled={!editTk || formLocked}
                                        onChange={(_, c) => setRowField(g.id, 'truongKhoa', c ? '3' : '0')}
                                      />
                                    </TableCell>
                                  )}
                                  {showDdtCol && (
                                    <TableCell align="center" sx={{ borderColor: SHEET.border }}>
                                      <Checkbox
                                        size="small"
                                        checked={r.ddt === '3'}
                                        disabled={!editDdt || formLocked}
                                        onChange={(_, c) => setRowField(g.id, 'ddt', c ? '3' : '0')}
                                      />
                                    </TableCell>
                                  )}
                                </>
                              )}
                            </TableRow>
                          );
                          continue;
                        }

                        out.push(
                          <TableRow key={`crit-${g.id}`}>
                            <TableCell align="center" sx={{ fontWeight: 800, borderColor: SHEET.border }}>
                              {g.no || ''}
                            </TableCell>
                            <TableCell sx={{ fontWeight: 800, fontStyle: 'italic', borderColor: SHEET.border }}>
                              {g.title}
                            </TableCell>
                            <TableCell align="center" sx={{ borderColor: SHEET.border }} />
                            {!isHd ? (
                              <>
                                {showTkCol && (
                                  <TableCell sx={{ borderColor: SHEET.border, minWidth: 110 }}>
                                    <FormControl size="small" fullWidth disabled={!editTk || formLocked}>
                                      <Select
                                        value={r.truongKhoa}
                                        displayEmpty
                                        renderValue={(selected) => (selected ? String(selected) : ' ')}
                                        onChange={(e) => setRowField(g.id, 'truongKhoa', e.target.value as string)}
                                      >
                                        {g.options.map((o, i) => (
                                          <MenuItem key={i} value={String(o.points)}>
                                            {o.points}
                                          </MenuItem>
                                        ))}
                                      </Select>
                                    </FormControl>
                                  </TableCell>
                                )}
                                {showDdtCol && (
                                  <TableCell sx={{ borderColor: SHEET.border, minWidth: 110 }}>
                                    <FormControl size="small" fullWidth disabled={!editDdt || formLocked}>
                                      <Select
                                        value={r.ddt}
                                        displayEmpty
                                        renderValue={(selected) => (selected ? String(selected) : ' ')}
                                        onChange={(e) => setRowField(g.id, 'ddt', e.target.value as string)}
                                      >
                                        {g.options.map((o, i) => (
                                          <MenuItem key={i} value={String(o.points)}>
                                            {o.points}
                                          </MenuItem>
                                        ))}
                                      </Select>
                                    </FormControl>
                                  </TableCell>
                                )}
                              </>
                            ) : (
                              <>
                                <TableCell colSpan={showHdCol ? 1 : 0} sx={{ borderColor: SHEET.border }}>
                                  <FormControl size="small" fullWidth disabled={!editHd || formLocked}>
                                    <Select
                                      value={r.hd}
                                      displayEmpty
                                      renderValue={(selected) => (selected ? String(selected) : ' ')}
                                      onChange={(e) => setRowField(g.id, 'hd', e.target.value as string)}
                                    >
                                      {g.options.map((o, i) => (
                                        <MenuItem key={i} value={String(o.points)}>
                                          {o.points}
                                        </MenuItem>
                                      ))}
                                    </Select>
                                  </FormControl>
                                </TableCell>
                              </>
                            )}
                          </TableRow>
                        );

                        for (const o of g.options) {
                          const trailingCount = isHd ? (showHdCol ? 1 : 0) : (showTkCol ? 1 : 0) + (showDdtCol ? 1 : 0);
                          out.push(
                            <TableRow key={`opt-${g.id}-${o.points}-${o.label.slice(0, 10)}`}>
                              <TableCell align="center" sx={{ borderColor: SHEET.border }}>
                                -
                              </TableCell>
                              <TableCell sx={{ borderColor: SHEET.border }}>{o.label}</TableCell>
                              <TableCell align="center" sx={{ borderColor: SHEET.border, fontWeight: 700 }}>
                                {o.points}
                              </TableCell>
                              {Array.from({ length: trailingCount }).map((_, idx) => (
                                <TableCell key={`opt-empty-${g.id}-${idx}`} sx={{ borderColor: SHEET.border }} />
                              ))}
                            </TableRow>
                          );
                        }
                      }
                      return out;
                    });
                  })()}
                </TableBody>
              </Table>
            </TableContainer>

              {isHr && (
                <Typography variant="subtitle2" sx={{ display: 'block', mt: 1, fontWeight: 800 }}>
                  Tổng điểm Hội đồng (30): {totals.total30 ?? 'Chưa đủ'} / 30
                </Typography>
              )}
              {!isHr && (isDeptHead || isNursingHead) && (
                <Box sx={{ mt: 1 }}>
                  <Typography variant="subtitle2" sx={{ display: 'block', fontWeight: 800 }}>
                    Tổng điểm (I–V + thưởng): {totals.totalWithBonus ?? 'Chưa đủ'} /{' '}
                    {totals.maxBase70 + totals.maxBonus12}
                  </Typography>
                  <Typography variant="caption" sx={{ display: 'block', mt: 0.25, color: SHEET.textMuted }}>
                    Trong đó phần I–V: {totals.total70 ?? '—'} / {totals.maxBase70} · Điểm thưởng: {totals.bonusVI} /{' '}
                    {totals.maxBonus12}
                  </Typography>
                </Box>
              )}

            {canEdit && (
              <Button
                variant={saveUiPhase === 'sua' ? 'outlined' : 'contained'}
                size="large"
                sx={{
                  mt: 2,
                  bgcolor: saveUiPhase === 'sua' ? 'transparent' : SHEET.header,
                  color: saveUiPhase === 'sua' ? SHEET.header : '#fff',
                  borderColor: saveUiPhase === 'sua' ? SHEET.header : undefined,
                  fontWeight: 800,
                  '&:hover': {
                    bgcolor: saveUiPhase === 'sua' ? alpha(SHEET.header, 0.08) : '#4f9c98',
                    borderColor: saveUiPhase === 'sua' ? SHEET.header : undefined,
                  },
                }}
                onClick={() => {
                  if (saveUiPhase === 'sua') {
                    setSaveUiPhase('save');
                    return;
                  }
                  void onSave();
                }}
                disabled={loading}
              >
                {saveUiPhase === 'sua'
                  ? `Sửa đánh giá — ${month}/${year}`
                  : isAdmin
                    ? `Lưu phiếu — ${month}/${year}`
                    : `Lưu phần được phân quyền — ${month}/${year}`}
              </Button>
            )}
              </>
            ) : (
              <Paper
                elevation={0}
                sx={{
                  py: 5,
                  px: 3,
                  textAlign: 'center',
                  border: `1px dashed ${SHEET.border}`,
                  bgcolor: alpha(SHEET.header, 0.06),
                  borderRadius: 1,
                }}
              >
                <RateReviewIcon sx={{ fontSize: 40, color: SHEET.header, opacity: 0.85, mb: 1 }} />
                <Typography variant="subtitle1" fontWeight={800} sx={{ color: SHEET.text }}>
                  Chưa chọn nhân viên
                </Typography>
              </Paper>
            )}
            </Box>
          </CardContent>
        </Card>
      )}

      {employeeId !== '' && (
        <Card sx={{ mt: 2.5 }} variant="outlined">
          <CardContent>
            <Typography variant="h6" gutterBottom fontWeight={600}>
              Lịch sử (MA 2026)
            </Typography>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Kỳ</TableCell>
                  <TableCell align="right">Điểm KP</TableCell>
                  <TableCell>Loại KP</TableCell>
                  <TableCell align="right">Điểm ĐDT</TableCell>
                  <TableCell>Loại ĐDT</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {history.filter((h) => String(h.templateCode) === templateCode).length === 0 && (
                  <TableRow>
                    <TableCell colSpan={5}>
                      <Typography color="text.secondary">Chưa có bản đánh giá.</Typography>
                    </TableCell>
                  </TableRow>
                )}
                {history
                  .filter((h) => String(h.templateCode) === templateCode)
                  .map((r) => (
                    <TableRow key={String(r.id)}>
                      <TableCell>
                        {String(r.periodMonth)}/{String(r.periodYear)}
                      </TableCell>
                      <TableCell align="right">{String(r.totalTruongKhoa ?? '—')}</TableCell>
                      <TableCell>{String(r.gradeTruongKhoa ?? '—')}</TableCell>
                      <TableCell align="right">{String(r.totalDdt ?? '—')}</TableCell>
                      <TableCell>{String(r.gradeDdt ?? '—')}</TableCell>
                    </TableRow>
                  ))}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      )}
    </Box>
  );
}
