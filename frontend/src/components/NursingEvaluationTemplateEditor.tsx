import AddRoundedIcon from '@mui/icons-material/AddRounded';
import ArrowDownwardRoundedIcon from '@mui/icons-material/ArrowDownwardRounded';
import ArrowUpwardRoundedIcon from '@mui/icons-material/ArrowUpwardRounded';
import CheckCircleRoundedIcon from '@mui/icons-material/CheckCircleRounded';
import CloseRoundedIcon from '@mui/icons-material/CloseRounded';
import ContentCopyRoundedIcon from '@mui/icons-material/ContentCopyRounded';
import DeleteOutlineRoundedIcon from '@mui/icons-material/DeleteOutlineRounded';
import DriveFileMoveOutlinedIcon from '@mui/icons-material/DriveFileMoveOutlined';
import EditNoteRoundedIcon from '@mui/icons-material/EditNoteRounded';
import EmojiEventsOutlinedIcon from '@mui/icons-material/EmojiEventsOutlined';
import ErrorOutlineRoundedIcon from '@mui/icons-material/ErrorOutlineRounded';
import ExpandMoreRoundedIcon from '@mui/icons-material/ExpandMoreRounded';
import HistoryRoundedIcon from '@mui/icons-material/HistoryRounded';
import InfoOutlinedIcon from '@mui/icons-material/InfoOutlined';
import ListAltRoundedIcon from '@mui/icons-material/ListAltRounded';
import MoreVertRoundedIcon from '@mui/icons-material/MoreVertRounded';
import RestartAltRoundedIcon from '@mui/icons-material/RestartAltRounded';
import SaveRoundedIcon from '@mui/icons-material/SaveRounded';
import SortRoundedIcon from '@mui/icons-material/SortRounded';
import TuneRoundedIcon from '@mui/icons-material/TuneRounded';
import UnfoldLessRoundedIcon from '@mui/icons-material/UnfoldLessRounded';
import UnfoldMoreRoundedIcon from '@mui/icons-material/UnfoldMoreRounded';
import VisibilityOutlinedIcon from '@mui/icons-material/VisibilityOutlined';
import WarningAmberRoundedIcon from '@mui/icons-material/WarningAmberRounded';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Collapse,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  Drawer,
  IconButton,
  InputAdornment,
  LinearProgress,
  ListItemIcon,
  ListItemText,
  Menu,
  MenuItem,
  Snackbar,
  Stack,
  Tab,
  Tabs,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { Fragment, useCallback, useEffect, useMemo, useState, type ReactElement, type ReactNode } from 'react';
import * as ne from '../services/nursingEvaluationService';
import { extractApiErrorMessage } from '../services/approvalSignatureService';
import { formatDateTimeVi } from '../utils/dateFormat';

/* ============================================================================
 * Mô hình chỉnh sửa
 * ========================================================================== */

type Kind = 'normal' | 'bonus' | 'penalty';
type EdOption = { key: string; label: string; points: string };
type EdCriterion = { key: string; id: string; title: string; options: EdOption[] };
type EdSection = { key: string; name: string; kind: Kind; criteria: EdCriterion[] };
type EdGrade = { key: string; label: string; min: string; proposal: string };
type EdState = { name: string; note: string; sections: EdSection[]; grades: EdGrade[] };

type Issue = { level: 'error' | 'warning'; message: string; tab: TabKey; key?: string };
type TabKey = 'criteria' | 'grades' | 'general' | 'preview';

let seq = 0;
const uid = () => `k${(++seq).toString(36)}`;
const newCriterionId = () => `C_${Date.now().toString(36).toUpperCase()}${(++seq).toString(36).toUpperCase()}`;

const ROMAN: Array<[number, string]> = [
  [1000, 'M'], [900, 'CM'], [500, 'D'], [400, 'CD'], [100, 'C'], [90, 'XC'],
  [50, 'L'], [40, 'XL'], [10, 'X'], [9, 'IX'], [5, 'V'], [4, 'IV'], [1, 'I'],
];

function toRoman(n: number): string {
  let out = '';
  for (const [v, s] of ROMAN) {
    while (n >= v) {
      out += s;
      n -= v;
    }
  }
  return out;
}

/** "I. Tuân thủ nội quy" → "Tuân thủ nội quy" (số La Mã do hệ thống tự đánh). */
function stripRoman(name: string): string {
  return name.replace(/^\s*[IVXLCDM]+\s*[.)]\s*/, '').trim();
}

function parsePoints(s: string): number {
  const t = s.trim().replace(',', '.');
  if (!t) return NaN;
  const n = Number(t);
  return Number.isFinite(n) ? n : NaN;
}

function fmt(n: number): string {
  if (!Number.isFinite(n)) return '—';
  return Number.isInteger(n) ? String(n) : String(Math.round(n * 100) / 100);
}

function kindOf(g: ne.CriterionGroup): Kind {
  if (g.bonus || g.id.startsWith('VI_')) return 'bonus';
  if (g.penalty || g.id.startsWith('VII_')) return 'penalty';
  return 'normal';
}

/** Mã VI_ / VII_ được bản mobile hiểu là thưởng / trừ — đổi mã khi tiêu chí sang loại khác. */
function idFitsKind(id: string, kind: Kind): boolean {
  if (id.startsWith('HD_')) return false;
  if (id.startsWith('VII_')) return kind === 'penalty';
  if (id.startsWith('VI_')) return kind === 'bonus';
  return true;
}

function withKindSafeIds(criteria: EdCriterion[], kind: Kind): EdCriterion[] {
  return criteria.map((c) => (idFitsKind(c.id, kind) ? c : { ...c, id: newCriterionId() }));
}

function fromTemplate(tpl: ne.NursingTemplate): EdState {
  const sections: EdSection[] = [];
  const byName = new Map<string, EdSection>();
  for (const g of tpl.criteriaGroups ?? []) {
    const raw = g.section || 'Khác';
    let sec = byName.get(raw);
    if (!sec) {
      sec = { key: uid(), name: stripRoman(raw), kind: kindOf(g), criteria: [] };
      byName.set(raw, sec);
      sections.push(sec);
    }
    sec.criteria.push({
      key: uid(),
      id: g.id,
      title: g.title,
      options: (g.options ?? []).map((o) => ({ key: uid(), label: o.label, points: fmt(Number(o.points)) })),
    });
  }
  const grades = [...(tpl.gradingScale ?? [])]
    .sort((a, b) => Number(b.min) - Number(a.min))
    .map((g) => ({ key: uid(), label: g.label, min: fmt(Number(g.min)), proposal: g.proposal ?? '' }));
  return { name: tpl.name ?? '', note: tpl.note ?? '', sections, grades };
}

function toDraft(s: EdState): ne.NursingTemplateDraft {
  const criteriaGroups: ne.NursingTemplateDraft['criteriaGroups'] = [];
  s.sections.forEach((sec, i) => {
    const section = `${toRoman(i + 1)}. ${sec.name.trim()}`;
    for (const c of sec.criteria) {
      criteriaGroups.push({
        id: c.id,
        section,
        title: c.title.trim(),
        options: c.options.map((o) => ({ label: o.label.trim(), points: parsePoints(o.points) })),
        ...(sec.kind === 'bonus' ? { bonus: true } : {}),
        ...(sec.kind === 'penalty' ? { penalty: true } : {}),
      });
    }
  });
  return {
    name: s.name.trim(),
    note: s.note.trim() || undefined,
    criteriaGroups,
    gradingScale: s.grades.map((g) => ({
      label: g.label.trim(),
      min: parsePoints(g.min),
      proposal: g.proposal.trim(),
    })),
  };
}

/** Bản xem trước theo đúng cấu trúc form chấm. */
function draftToTemplate(s: EdState, base: ne.NursingTemplate | undefined): ne.NursingTemplate {
  const groups: ne.CriterionGroup[] = [];
  let baseMax = 0;
  s.sections.forEach((sec, i) => {
    const section = `${toRoman(i + 1)}. ${sec.name.trim() || 'Chưa đặt tên'}`;
    const secPts = sec.criteria.reduce((sum, c) => sum + criterionMax(c), 0);
    if (sec.kind === 'normal') baseMax += secPts;
    sec.criteria.forEach((c, j) => {
      groups.push({
        id: c.id,
        section,
        sectionPoints: sec.kind === 'normal' ? secPts : undefined,
        no: String(j + 1),
        title: c.title || 'Chưa đặt tên tiêu chí',
        maxPoints: criterionMax(c),
        options: c.options
          .filter((o) => Number.isFinite(parsePoints(o.points)))
          .map((o) => ({ label: o.label || '—', points: parsePoints(o.points) })),
        bonus: sec.kind === 'bonus' || undefined,
        penalty: sec.kind === 'penalty' || undefined,
      });
    });
  });
  return {
    code: base?.code ?? '',
    name: s.name,
    version: base?.version ?? 1,
    baseMaxPoints: baseMax,
    note: s.note,
    criteriaGroups: groups,
    gradingScale: s.grades
      .filter((g) => Number.isFinite(parsePoints(g.min)))
      .map((g) => ({ label: g.label, min: parsePoints(g.min), proposal: g.proposal }))
      .sort((a, b) => b.min - a.min),
  };
}

function criterionMax(c: EdCriterion): number {
  let m = 0;
  for (const o of c.options) {
    const p = parsePoints(o.points);
    if (Number.isFinite(p)) m = Math.max(m, p);
  }
  return m;
}

function newCriterion(kind: Kind): EdCriterion {
  return {
    key: uid(),
    id: newCriterionId(),
    title: '',
    options:
      kind === 'normal'
        ? [
            { key: uid(), label: '', points: '5' },
            { key: uid(), label: '', points: '0' },
          ]
        : [
            { key: uid(), label: kind === 'penalty' ? 'Có (trừ điểm)' : 'Có', points: '5' },
            { key: uid(), label: 'Không', points: '0' },
          ],
  };
}

function move<T>(list: T[], from: number, to: number): T[] {
  if (to < 0 || to >= list.length) return list;
  const next = [...list];
  const [item] = next.splice(from, 1);
  next.splice(to, 0, item);
  return next;
}

const TITLE_POINTS_RE = /\((\d+(?:[.,]\d+)?)\s*điểm\)/i;

function validate(s: EdState): Issue[] {
  const issues: Issue[] = [];
  const err = (message: string, tab: TabKey, key?: string) => issues.push({ level: 'error', message, tab, key });
  const warn = (message: string, tab: TabKey, key?: string) => issues.push({ level: 'warning', message, tab, key });

  if (!s.name.trim()) err('Chưa nhập tên mẫu đánh giá', 'general');
  if (!s.sections.length) err('Mẫu chưa có mục tiêu chí nào', 'criteria');

  let base = 0;
  s.sections.forEach((sec, i) => {
    const r = toRoman(i + 1);
    if (!sec.name.trim()) err(`Mục ${r}: chưa có tên mục`, 'criteria', sec.key);
    if (!sec.criteria.length) err(`Mục ${r}: chưa có tiêu chí`, 'criteria', sec.key);
    sec.criteria.forEach((c, j) => {
      const where = `Mục ${r} · tiêu chí ${j + 1}`;
      if (!c.title.trim()) err(`${where}: chưa có tên tiêu chí`, 'criteria', c.key);
      if (!c.options.length) err(`${where}: cần ít nhất 1 mức điểm`, 'criteria', c.key);
      const seen = new Set<number>();
      c.options.forEach((o, k) => {
        const p = parsePoints(o.points);
        if (!o.label.trim()) err(`${where} · mức ${k + 1}: chưa có mô tả`, 'criteria', c.key);
        if (!Number.isFinite(p) || p < 0) err(`${where} · mức ${k + 1}: điểm không hợp lệ`, 'criteria', c.key);
        else if (seen.has(p)) err(`${where}: có 2 mức cùng ${fmt(p)} điểm`, 'criteria', c.key);
        else seen.add(p);
      });
      const max = criterionMax(c);
      const m = TITLE_POINTS_RE.exec(c.title);
      if (m && c.options.length && Math.abs(parsePoints(m[1]) - max) > 0.001) {
        warn(`${where}: tên ghi "${m[1]} điểm" nhưng mức cao nhất là ${fmt(max)} điểm`, 'criteria', c.key);
      }
      if (c.options.length === 1) warn(`${where}: chỉ có 1 mức điểm`, 'criteria', c.key);
      if (sec.kind === 'normal') base += max;
    });
  });
  if (s.sections.length && base <= 0) err('Cần ít nhất 1 tiêu chí tính điểm có điểm tối đa lớn hơn 0', 'criteria');
  else if (base > 0 && Math.abs(base - 100) > 0.001) {
    warn(`Tổng điểm chuẩn là ${fmt(base)} (không phải 100) — xếp loại quy đổi theo tỷ lệ %`, 'criteria');
  }

  if (!s.grades.length) err('Chưa có mức xếp loại nào', 'grades');
  const mins = new Set<number>();
  const labels = new Set<string>();
  let hasZero = false;
  s.grades.forEach((g, i) => {
    const where = `Xếp loại ${i + 1}`;
    const min = parsePoints(g.min);
    if (!g.label.trim()) err(`${where}: chưa có tên`, 'grades', g.key);
    else if (labels.has(g.label.trim().toLowerCase())) err(`Tên xếp loại bị trùng: ${g.label.trim()}`, 'grades', g.key);
    else labels.add(g.label.trim().toLowerCase());
    if (!Number.isFinite(min) || min < 0 || min > 100) err(`${where}: ngưỡng phải từ 0 đến 100`, 'grades', g.key);
    else if (mins.has(min)) err(`Hai xếp loại cùng ngưỡng ${fmt(min)}%`, 'grades', g.key);
    else {
      mins.add(min);
      if (min === 0) hasZero = true;
    }
  });
  if (s.grades.length && !hasZero) err('Cần một mức xếp loại có ngưỡng 0 (mức thấp nhất)', 'grades');
  return issues;
}

type Diff = { added: number; removed: number; changed: number; sectionsChanged: boolean; gradesChanged: boolean; infoChanged: boolean };

function diffDrafts(before: ne.NursingTemplateDraft, after: ne.NursingTemplateDraft): Diff {
  const sig = (c: ne.NursingTemplateDraft['criteriaGroups'][number]) =>
    JSON.stringify([c.title, c.options, c.bonus ?? false, c.penalty ?? false, stripRoman(c.section)]);
  const a = new Map(before.criteriaGroups.map((c) => [c.id, sig(c)]));
  const b = new Map(after.criteriaGroups.map((c) => [c.id, sig(c)]));
  let added = 0;
  let removed = 0;
  let changed = 0;
  for (const [id, s] of b) {
    if (!a.has(id)) added += 1;
    else if (a.get(id) !== s) changed += 1;
  }
  for (const id of a.keys()) if (!b.has(id)) removed += 1;
  const sectionNames = (d: ne.NursingTemplateDraft) => JSON.stringify([...new Set(d.criteriaGroups.map((c) => c.section))]);
  return {
    added,
    removed,
    changed,
    sectionsChanged: sectionNames(before) !== sectionNames(after),
    gradesChanged: JSON.stringify(before.gradingScale) !== JSON.stringify(after.gradingScale),
    infoChanged: before.name !== after.name || (before.note ?? '') !== (after.note ?? ''),
  };
}

const GRADE_COLORS = ['#15803d', '#0e7490', '#ca8a04', '#ea580c', '#9333ea', '#475569'];
/** Màu xếp loại theo thứ hạng (cao → thấp); mức thấp nhất luôn đỏ. */
const gradeColor = (rank: number, count: number) =>
  rank === count - 1 && count > 1 ? '#dc2626' : GRADE_COLORS[rank % GRADE_COLORS.length];

/* ============================================================================
 * Component
 * ========================================================================== */

type Props = {
  open: boolean;
  templateCode: string;
  onClose: () => void;
  /** Gọi sau khi mẫu được lưu / khôi phục — để form chấm tải lại mẫu. */
  onSaved?: () => void;
};

type ConfirmState = {
  title: string;
  message: ReactNode;
  confirmLabel: string;
  danger?: boolean;
  onConfirm: () => void | Promise<void>;
};

type CriterionMenuState = { anchor: HTMLElement; sectionKey: string; criterionKey: string } | null;

export function NursingEvaluationTemplateEditor({ open, templateCode, onClose, onSaved }: Props) {
  const theme = useTheme();
  const accent = theme.palette.primary.main;
  const kindMeta: Record<Kind, { label: string; short: string; color: string }> = {
    normal: { label: 'Tính điểm', short: 'Tính điểm', color: accent },
    bonus: { label: 'Điểm thưởng (cộng)', short: 'Thưởng', color: theme.palette.success.main },
    penalty: { label: 'Điểm trừ', short: 'Trừ', color: theme.palette.error.main },
  };

  const [server, setServer] = useState<ne.NursingTemplateEditorState | null>(null);
  const [draft, setDraft] = useState<EdState | null>(null);
  const [baseline, setBaseline] = useState('');
  const [loading, setLoading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [conflict, setConflict] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [tab, setTab] = useState<TabKey>('criteria');
  const [expanded, setExpanded] = useState<Set<string>>(new Set());
  const [focusKey, setFocusKey] = useState<string | null>(null);
  const [attempted, setAttempted] = useState(false);
  const [confirm, setConfirm] = useState<ConfirmState | null>(null);
  const [critMenu, setCritMenu] = useState<CriterionMenuState>(null);
  const [moveMenu, setMoveMenu] = useState<CriterionMenuState>(null);
  const [saveOpen, setSaveOpen] = useState(false);
  const [changeNote, setChangeNote] = useState('');
  const [historyOpen, setHistoryOpen] = useState(false);
  const [revisions, setRevisions] = useState<ne.NursingTemplateRevision[] | null>(null);
  const [revisionsLoading, setRevisionsLoading] = useState(false);

  const applyServer = useCallback((state: ne.NursingTemplateEditorState) => {
    const ed = fromTemplate(state.template);
    setServer(state);
    setDraft(ed);
    setBaseline(JSON.stringify(toDraft(ed)));
    setExpanded(new Set());
    setAttempted(false);
    setConflict(false);
    setErr(null);
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    setErr(null);
    try {
      applyServer(await ne.fetchNursingTemplateEditor(templateCode));
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Không tải được mẫu đánh giá.'));
    } finally {
      setLoading(false);
    }
  }, [templateCode, applyServer]);

  useEffect(() => {
    if (open) {
      setTab('criteria');
      setRevisions(null);
      void load();
    }
  }, [open, load]);

  const currentDraft = useMemo(() => (draft ? toDraft(draft) : null), [draft]);
  const dirty = currentDraft != null && JSON.stringify(currentDraft) !== baseline;
  const issues = useMemo(() => (draft ? validate(draft) : []), [draft]);
  const errors = issues.filter((i) => i.level === 'error');
  const warnings = issues.filter((i) => i.level === 'warning');
  const errorKeys = useMemo(
    () => new Set(errors.map((i) => i.key).filter((k): k is string => Boolean(k))),
    [errors],
  );

  const stats = useMemo(() => {
    if (!draft) return null;
    let base = 0;
    let bonus = 0;
    let penalty = 0;
    let criteria = 0;
    let options = 0;
    const perSection = draft.sections.map((sec, i) => {
      const pts = sec.criteria.reduce((sum, c) => sum + criterionMax(c), 0);
      criteria += sec.criteria.length;
      options += sec.criteria.reduce((sum, c) => sum + c.options.length, 0);
      if (sec.kind === 'normal') base += pts;
      else if (sec.kind === 'bonus') bonus += pts;
      else penalty += pts;
      return { key: sec.key, roman: toRoman(i + 1), name: sec.name, kind: sec.kind, pts };
    });
    return { base, bonus, penalty, criteria, options, perSection };
  }, [draft]);

  const diff = useMemo(() => {
    if (!currentDraft || !baseline) return null;
    return diffDrafts(JSON.parse(baseline) as ne.NursingTemplateDraft, currentDraft);
  }, [currentDraft, baseline]);

  /* ---------------- cập nhật bản nháp ---------------- */

  const patch = (fn: (s: EdState) => EdState) => setDraft((prev) => (prev ? fn(prev) : prev));

  const patchSection = (key: string, fn: (s: EdSection) => EdSection) =>
    patch((s) => ({ ...s, sections: s.sections.map((sec) => (sec.key === key ? fn(sec) : sec)) }));

  const patchCriterion = (sKey: string, cKey: string, fn: (c: EdCriterion) => EdCriterion) =>
    patchSection(sKey, (sec) => ({ ...sec, criteria: sec.criteria.map((c) => (c.key === cKey ? fn(c) : c)) }));

  function addSection(kind: Kind = 'normal') {
    const sec: EdSection = { key: uid(), name: '', kind, criteria: [newCriterion(kind)] };
    patch((s) => {
      const next = [...s.sections];
      // Mục tính điểm mới đặt trước các mục thưởng / trừ.
      const firstExtra = kind === 'normal' ? next.findIndex((x) => x.kind !== 'normal') : -1;
      next.splice(firstExtra >= 0 ? firstExtra : next.length, 0, sec);
      return { ...s, sections: next };
    });
    setExpanded((prev) => new Set(prev).add(sec.criteria[0].key));
    setFocusKey(sec.key);
  }

  function addCriterion(sec: EdSection) {
    const c = newCriterion(sec.kind);
    patchSection(sec.key, (x) => ({ ...x, criteria: [...x.criteria, c] }));
    setExpanded((prev) => new Set(prev).add(c.key));
    setFocusKey(c.key);
  }

  function setSectionKind(sec: EdSection, kind: Kind) {
    patchSection(sec.key, (x) => ({ ...x, kind, criteria: withKindSafeIds(x.criteria, kind) }));
  }

  function removeSection(sec: EdSection, index: number) {
    const doIt = () => patch((s) => ({ ...s, sections: s.sections.filter((x) => x.key !== sec.key) }));
    if (!sec.criteria.length) {
      doIt();
      return;
    }
    setConfirm({
      title: `Xóa mục ${toRoman(index + 1)}?`,
      message: (
        <>
          Mục <b>{sec.name || 'chưa đặt tên'}</b> cùng <b>{sec.criteria.length} tiêu chí</b> bên trong sẽ bị xóa khỏi
          mẫu. Phiếu đã gửi duyệt không bị ảnh hưởng.
        </>
      ),
      confirmLabel: 'Xóa mục',
      danger: true,
      onConfirm: doIt,
    });
  }

  function removeCriterion(sKey: string, c: EdCriterion) {
    setConfirm({
      title: 'Xóa tiêu chí?',
      message: (
        <>
          Tiêu chí <b>{c.title || 'chưa đặt tên'}</b> sẽ bị xóa khỏi mẫu. Phiếu nháp đang chấm sẽ bỏ điểm của tiêu chí
          này khi lưu lại; phiếu đã gửi duyệt giữ nguyên.
        </>
      ),
      confirmLabel: 'Xóa tiêu chí',
      danger: true,
      onConfirm: () => patchSection(sKey, (sec) => ({ ...sec, criteria: sec.criteria.filter((x) => x.key !== c.key) })),
    });
  }

  function duplicateCriterion(sKey: string, c: EdCriterion) {
    const copy: EdCriterion = {
      key: uid(),
      id: newCriterionId(),
      title: c.title ? `${c.title} (bản sao)` : '',
      options: c.options.map((o) => ({ ...o, key: uid() })),
    };
    patchSection(sKey, (sec) => {
      const i = sec.criteria.findIndex((x) => x.key === c.key);
      const next = [...sec.criteria];
      next.splice(i + 1, 0, copy);
      return { ...sec, criteria: next };
    });
    setExpanded((prev) => new Set(prev).add(copy.key));
  }

  function moveCriterionToSection(fromKey: string, cKey: string, toKey: string) {
    patch((s) => {
      const from = s.sections.find((x) => x.key === fromKey);
      const to = s.sections.find((x) => x.key === toKey);
      const c = from?.criteria.find((x) => x.key === cKey);
      if (!from || !to || !c) return s;
      const moved = withKindSafeIds([c], to.kind)[0];
      return {
        ...s,
        sections: s.sections.map((sec) => {
          if (sec.key === fromKey) return { ...sec, criteria: sec.criteria.filter((x) => x.key !== cKey) };
          if (sec.key === toKey) return { ...sec, criteria: [...sec.criteria, moved] };
          return sec;
        }),
      };
    });
  }

  function toggleExpanded(key: string) {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(key)) next.delete(key);
      else next.add(key);
      return next;
    });
  }

  const allCriterionKeys = draft?.sections.flatMap((s) => s.criteria.map((c) => c.key)) ?? [];
  const allExpanded = allCriterionKeys.length > 0 && allCriterionKeys.every((k) => expanded.has(k));

  /* ---------------- lưu / khôi phục ---------------- */

  function requestSave() {
    setAttempted(true);
    if (errors.length) {
      setTab(errors[0].tab);
      setExpanded((prev) => {
        const next = new Set(prev);
        for (const e of errors) if (e.key) next.add(e.key);
        return next;
      });
      return;
    }
    setChangeNote('');
    setSaveOpen(true);
  }

  async function runServerAction(action: () => Promise<ne.NursingTemplateEditorState>, success: string) {
    setBusy(true);
    setErr(null);
    try {
      applyServer(await action());
      setRevisions(null);
      setToast(success);
      onSaved?.();
      return true;
    } catch (e) {
      const status = (e as { response?: { status?: number } })?.response?.status;
      setConflict(status === 409);
      setErr(extractApiErrorMessage(e, 'Thao tác thất bại.'));
      return false;
    } finally {
      setBusy(false);
    }
  }

  async function doSave() {
    if (!server || !currentDraft) return;
    const ok = await runServerAction(
      () =>
        ne.saveNursingTemplate(templateCode, {
          baseVersion: server.version,
          template: currentDraft,
          changeNote: changeNote.trim() || undefined,
        }),
      `Đã lưu mẫu — phiên bản v${server.version + 1} đang được áp dụng.`,
    );
    setSaveOpen(false);
    if (!ok) setAttempted(true);
  }

  function requestReset() {
    if (!server) return;
    setConfirm({
      title: 'Khôi phục mẫu gốc?',
      message: (
        <>
          Mẫu sẽ trở về nội dung gốc của hệ thống (v{server.defaultVersion}) và được lưu thành phiên bản mới v
          {server.version + 1}. Các phiên bản hiện tại vẫn còn trong lịch sử để khôi phục lại khi cần.
          {dirty && (
            <Box component="span" sx={{ display: 'block', mt: 1, color: 'warning.dark', fontWeight: 700 }}>
              Các thay đổi chưa lưu sẽ bị bỏ.
            </Box>
          )}
        </>
      ),
      confirmLabel: 'Khôi phục mẫu gốc',
      danger: true,
      onConfirm: async () => {
        await runServerAction(
          () => ne.resetNursingTemplate(templateCode, { baseVersion: server.version }),
          'Đã khôi phục mẫu gốc.',
        );
      },
    });
  }

  function requestRestore(rev: ne.NursingTemplateRevision) {
    if (!server) return;
    setConfirm({
      title: `Khôi phục phiên bản v${rev.version}?`,
      message: (
        <>
          Nội dung v{rev.version} ({rev.criteriaCount} tiêu chí, {fmt(Number(rev.baseMaxPoints))} điểm chuẩn) sẽ được
          lưu thành phiên bản mới v{server.version + 1} và áp dụng ngay.
          {dirty && (
            <Box component="span" sx={{ display: 'block', mt: 1, color: 'warning.dark', fontWeight: 700 }}>
              Các thay đổi chưa lưu sẽ bị bỏ.
            </Box>
          )}
        </>
      ),
      confirmLabel: 'Khôi phục',
      onConfirm: async () => {
        const ok = await runServerAction(
          () => ne.restoreNursingTemplateRevision(templateCode, rev.id, { baseVersion: server.version }),
          `Đã khôi phục nội dung phiên bản v${rev.version}.`,
        );
        if (ok) setHistoryOpen(false);
      },
    });
  }

  async function openRevisionInEditor(rev: ne.NursingTemplateRevision) {
    setBusy(true);
    try {
      const tpl = await ne.fetchNursingTemplateRevision(templateCode, rev.id);
      setDraft(fromTemplate(tpl));
      setExpanded(new Set());
      setHistoryOpen(false);
      setTab('criteria');
      setToast(`Đã nạp nội dung v${rev.version} vào bản đang sửa — kiểm tra rồi bấm "Lưu thay đổi" để áp dụng.`);
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Không tải được phiên bản.'));
    } finally {
      setBusy(false);
    }
  }

  const loadRevisions = useCallback(async () => {
    setRevisionsLoading(true);
    try {
      setRevisions(await ne.fetchNursingTemplateRevisions(templateCode));
    } catch (e) {
      setErr(extractApiErrorMessage(e, 'Không tải được lịch sử phiên bản.'));
    } finally {
      setRevisionsLoading(false);
    }
  }, [templateCode]);

  useEffect(() => {
    if (historyOpen && revisions == null) void loadRevisions();
  }, [historyOpen, revisions, loadRevisions]);

  function requestClose() {
    if (!dirty) {
      onClose();
      return;
    }
    setConfirm({
      title: 'Bỏ thay đổi chưa lưu?',
      message: 'Bạn có thay đổi chưa lưu trong mẫu đánh giá. Đóng lúc này sẽ mất các thay đổi đó.',
      confirmLabel: 'Bỏ thay đổi',
      danger: true,
      onConfirm: onClose,
    });
  }

  // Ctrl/Cmd + S để lưu.
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') {
        e.preventDefault();
        if (dirty && !busy && !saveOpen) requestSave();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  /* ---------------- render helpers ---------------- */

  const cardBorder = theme.palette.divider;
  const cardSx = {
    borderRadius: '12px',
    border: `1px solid ${cardBorder}`,
    bgcolor: 'background.paper',
    boxShadow: `0 1px 2px ${alpha('#0f172a', 0.04)}, 0 6px 24px ${alpha('#0f172a', 0.04)}`,
  } as const;

  const inputSx = { '& .MuiOutlinedInput-root': { bgcolor: 'background.paper', borderRadius: '8px' } } as const;

  function renderCriterion(sec: EdSection, c: EdCriterion, j: number) {
    const open = expanded.has(c.key);
    const max = criterionMax(c);
    const hasError = attempted && errorKeys.has(c.key);
    const color = kindMeta[sec.kind].color;
    return (
      <Box
        key={c.key}
        sx={{
          borderTop: `1px solid ${theme.palette.divider}`,
          bgcolor: open ? alpha(color, 0.025) : 'transparent',
          boxShadow: hasError ? `inset 3px 0 0 ${theme.palette.error.main}` : 'none',
          transition: 'background-color .15s',
        }}
      >
        <Stack direction="row" spacing={1.25} alignItems="flex-start" sx={{ px: { xs: 1.5, sm: 2 }, py: 1.25 }}>
          <Box
            sx={{
              mt: 0.5,
              flexShrink: 0,
              width: 26,
              height: 26,
              borderRadius: '50%',
              display: 'grid',
              placeItems: 'center',
              fontSize: 12,
              fontWeight: 800,
              color,
              bgcolor: alpha(color, 0.1),
            }}
          >
            {j + 1}
          </Box>
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <TextField
              fullWidth
              multiline
              variant="standard"
              placeholder="Tên tiêu chí, ví dụ: Tuân thủ thời gian làm việc (5 điểm)"
              value={c.title}
              autoFocus={focusKey === c.key}
              error={attempted && !c.title.trim()}
              onChange={(e) => patchCriterion(sec.key, c.key, (x) => ({ ...x, title: e.target.value }))}
              InputProps={{ disableUnderline: !(attempted && !c.title.trim()), sx: { fontWeight: 650, fontSize: 14.5 } }}
            />
            <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.25 }}>
              {c.options.length} mức điểm
              {c.options.length > 0 && ' · '}
              {c.options.map((o, k) => (
                <Fragment key={o.key}>
                  {k > 0 && <Box component="span" sx={{ mx: 0.5, color: 'text.disabled' }}>/</Box>}
                  <Tooltip title={o.label || 'Chưa có mô tả'} placement="top">
                    <Box component="span" sx={{ fontWeight: 700, cursor: 'help' }}>
                      {o.points || '?'}
                    </Box>
                  </Tooltip>
                </Fragment>
              ))}
            </Typography>
          </Box>
          <Box
            sx={{
              flexShrink: 0,
              alignSelf: 'center',
              minWidth: 76,
              px: 1,
              py: 0.375,
              borderRadius: '6px',
              textAlign: 'center',
              fontSize: 12.5,
              fontWeight: 800,
              color,
              bgcolor: alpha(color, 0.08),
              border: `1px solid ${alpha(color, 0.16)}`,
              whiteSpace: 'nowrap',
            }}
          >
            {sec.kind === 'penalty' ? '−' : sec.kind === 'bonus' ? '+' : ''}
            {fmt(max)} điểm
          </Box>
          <Stack direction="row" spacing={0.25} sx={{ flexShrink: 0, alignSelf: 'center' }}>
            <Tooltip title={open ? 'Thu gọn mức điểm' : 'Sửa mức điểm'}>
              <IconButton size="small" onClick={() => toggleExpanded(c.key)}>
                <ExpandMoreRoundedIcon
                  fontSize="small"
                  sx={{ transform: open ? 'rotate(180deg)' : 'none', transition: 'transform .2s' }}
                />
              </IconButton>
            </Tooltip>
            <IconButton
              size="small"
              aria-label="Thao tác tiêu chí"
              onClick={(e) => setCritMenu({ anchor: e.currentTarget, sectionKey: sec.key, criterionKey: c.key })}
            >
              <MoreVertRoundedIcon fontSize="small" />
            </IconButton>
          </Stack>
        </Stack>

        <Collapse in={open} unmountOnExit>
          <Box sx={{ pl: { xs: 1.5, sm: 6.25 }, pr: { xs: 1.5, sm: 2 }, pb: 1.75 }}>
            <Box
              sx={{
                borderRadius: '8px',
                border: `1px solid ${alpha(color, 0.18)}`,
                bgcolor: 'background.paper',
                overflow: 'hidden',
              }}
            >
              <Stack
                direction="row"
                sx={{
                  px: 1.5,
                  py: 0.75,
                  bgcolor: alpha(color, 0.06),
                  color: 'text.secondary',
                  fontSize: 12,
                  fontWeight: 800,
                  textTransform: 'uppercase',
                  letterSpacing: '.03em',
                }}
              >
                <Box sx={{ flex: 1 }}>Mức đánh giá</Box>
                <Box sx={{ width: { xs: 84, sm: 104 }, textAlign: 'left' }}>Điểm</Box>
                <Box sx={{ width: { xs: 34, sm: 100 } }} />
              </Stack>
              {c.options.map((o, k) => {
                const p = parsePoints(o.points);
                const badPts = attempted && (!Number.isFinite(p) || p < 0);
                return (
                  <Stack
                    key={o.key}
                    direction="row"
                    spacing={1}
                    alignItems="flex-start"
                    sx={{ px: 1.5, py: 1, borderTop: k ? `1px dashed ${theme.palette.divider}` : 'none' }}
                  >
                    <TextField
                      fullWidth
                      multiline
                      size="small"
                      placeholder={
                        k === 0 ? 'Mô tả mức đạt cao nhất' : k === c.options.length - 1 ? 'Mô tả mức thấp nhất' : 'Mô tả mức đánh giá'
                      }
                      value={o.label}
                      error={attempted && !o.label.trim()}
                      onChange={(e) =>
                        patchCriterion(sec.key, c.key, (x) => ({
                          ...x,
                          options: x.options.map((y) => (y.key === o.key ? { ...y, label: e.target.value } : y)),
                        }))
                      }
                      sx={{ flex: 1, ...inputSx }}
                    />
                    <TextField
                      size="small"
                      value={o.points}
                      error={badPts}
                      inputProps={{ inputMode: 'decimal', style: { fontWeight: 800, textAlign: 'right' } }}
                      InputProps={{ endAdornment: <InputAdornment position="end">đ</InputAdornment> }}
                      onChange={(e) =>
                        patchCriterion(sec.key, c.key, (x) => ({
                          ...x,
                          options: x.options.map((y) =>
                            y.key === o.key ? { ...y, points: e.target.value.replace(/[^\d.,]/g, '') } : y,
                          ),
                        }))
                      }
                      sx={{ width: { xs: 84, sm: 104 }, flexShrink: 0, ...inputSx }}
                    />
                    <Stack direction="row" sx={{ width: { xs: 34, sm: 100 }, flexShrink: 0, pt: 0.25, '& .opt-move': { display: { xs: 'none', sm: 'inline-flex' } } }} justifyContent="flex-end">
                      <IconButton
                        size="small"
                        disabled={k === 0}
                        className="opt-move"
                        aria-label="Lên"
                        onClick={() => patchCriterion(sec.key, c.key, (x) => ({ ...x, options: move(x.options, k, k - 1) }))}
                      >
                        <ArrowUpwardRoundedIcon sx={{ fontSize: 17 }} />
                      </IconButton>
                      <IconButton
                        size="small"
                        disabled={k === c.options.length - 1}
                        className="opt-move"
                        aria-label="Xuống"
                        onClick={() => patchCriterion(sec.key, c.key, (x) => ({ ...x, options: move(x.options, k, k + 1) }))}
                      >
                        <ArrowDownwardRoundedIcon sx={{ fontSize: 17 }} />
                      </IconButton>
                      <Tooltip title="Xóa mức">
                        <span>
                          <IconButton
                            size="small"
                            color="error"
                            disabled={c.options.length <= 1}
                            onClick={() =>
                              patchCriterion(sec.key, c.key, (x) => ({
                                ...x,
                                options: x.options.filter((y) => y.key !== o.key),
                              }))
                            }
                          >
                            <DeleteOutlineRoundedIcon sx={{ fontSize: 18 }} />
                          </IconButton>
                        </span>
                      </Tooltip>
                    </Stack>
                  </Stack>
                );
              })}
              <Stack
                direction="row"
                spacing={1}
                sx={{ px: 1, py: 0.75, borderTop: `1px solid ${theme.palette.divider}` }}
              >
                <Button
                  size="small"
                  startIcon={<AddRoundedIcon />}
                  disabled={c.options.length >= 20}
                  onClick={() =>
                    patchCriterion(sec.key, c.key, (x) => ({
                      ...x,
                      options: [...x.options, { key: uid(), label: '', points: '' }],
                    }))
                  }
                  sx={{ textTransform: 'none', fontWeight: 700 }}
                >
                  Thêm mức điểm
                </Button>
                <Button
                  size="small"
                  color="inherit"
                  startIcon={<SortRoundedIcon />}
                  disabled={c.options.length < 2}
                  onClick={() =>
                    patchCriterion(sec.key, c.key, (x) => ({
                      ...x,
                      options: [...x.options].sort(
                        (a, b) => (parsePoints(b.points) || 0) - (parsePoints(a.points) || 0),
                      ),
                    }))
                  }
                  sx={{ textTransform: 'none', fontWeight: 650, color: 'text.secondary' }}
                >
                  Sắp xếp điểm giảm dần
                </Button>
              </Stack>
            </Box>
          </Box>
        </Collapse>
      </Box>
    );
  }

  function renderSection(sec: EdSection, i: number) {
    const meta = kindMeta[sec.kind];
    const pts = stats?.perSection[i]?.pts ?? 0;
    const hasError = attempted && errorKeys.has(sec.key);
    return (
      <Box key={sec.key} sx={{ ...cardSx, overflow: 'hidden', borderColor: hasError ? theme.palette.error.main : cardBorder }}>
        <Stack
          direction={{ xs: 'column', md: 'row' }}
          spacing={{ xs: 1, md: 1.5 }}
          alignItems={{ md: 'center' }}
          sx={{
            px: { xs: 1.5, sm: 2 },
            py: 1.25,
            bgcolor: alpha(meta.color, 0.07),
            borderLeft: `4px solid ${meta.color}`,
          }}
        >
          <Stack direction="row" spacing={1.25} alignItems="center" sx={{ flex: 1, minWidth: 0 }}>
            <Box
              sx={{
                flexShrink: 0,
                minWidth: 34,
                height: 30,
                px: 0.75,
                borderRadius: '6px',
                display: 'grid',
                placeItems: 'center',
                fontWeight: 900,
                fontSize: 13,
                color: '#fff',
                bgcolor: meta.color,
                fontFamily: 'Georgia, "Times New Roman", serif',
              }}
            >
              {toRoman(i + 1)}
            </Box>
            <TextField
              fullWidth
              variant="standard"
              placeholder="Tên mục, ví dụ: Tuân thủ nội quy"
              value={sec.name}
              autoFocus={focusKey === sec.key}
              error={attempted && !sec.name.trim()}
              onChange={(e) => patchSection(sec.key, (x) => ({ ...x, name: e.target.value }))}
              InputProps={{
                disableUnderline: !(attempted && !sec.name.trim()),
                sx: { fontWeight: 800, fontSize: 15.5, color: theme.palette.text.primary },
              }}
            />
          </Stack>
          <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap sx={{ flexShrink: 0 }}>
            <TextField
              select
              size="small"
              value={sec.kind}
              onChange={(e) => setSectionKind(sec, e.target.value as Kind)}
              sx={{ width: { xs: 140, sm: 168 }, ...inputSx }}
              SelectProps={{
                renderValue: (v) => (
                  <Stack direction="row" spacing={0.75} alignItems="center">
                    <Box sx={{ width: 8, height: 8, borderRadius: '50%', bgcolor: kindMeta[v as Kind].color }} />
                    <Typography variant="body2" fontWeight={700} noWrap>
                      {kindMeta[v as Kind].short}
                    </Typography>
                  </Stack>
                ),
              }}
            >
              {(Object.keys(kindMeta) as Kind[]).map((k) => (
                <MenuItem key={k} value={k}>
                  <Stack direction="row" spacing={1} alignItems="center">
                    <Box sx={{ width: 9, height: 9, borderRadius: '50%', bgcolor: kindMeta[k].color }} />
                    <span>{kindMeta[k].label}</span>
                  </Stack>
                </MenuItem>
              ))}
            </TextField>
            <Chip
              label={sec.kind === 'normal' ? `${fmt(pts)} điểm` : sec.kind === 'bonus' ? `+${fmt(pts)} tối đa` : `−${fmt(pts)} tối đa`}
              sx={{ fontWeight: 800, bgcolor: alpha(meta.color, 0.14), color: meta.color, minWidth: 82 }}
            />
            <Divider orientation="vertical" flexItem sx={{ mx: 0.25, display: { xs: 'none', sm: 'block' } }} />
            <Tooltip title="Chuyển mục lên">
              <span>
                <IconButton size="small" disabled={i === 0} onClick={() => patch((s) => ({ ...s, sections: move(s.sections, i, i - 1) }))}>
                  <ArrowUpwardRoundedIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>
            <Tooltip title="Chuyển mục xuống">
              <span>
                <IconButton
                  size="small"
                  disabled={i === (draft?.sections.length ?? 0) - 1}
                  onClick={() => patch((s) => ({ ...s, sections: move(s.sections, i, i + 1) }))}
                >
                  <ArrowDownwardRoundedIcon fontSize="small" />
                </IconButton>
              </span>
            </Tooltip>
            <Tooltip title="Xóa mục">
              <IconButton size="small" color="error" onClick={() => removeSection(sec, i)}>
                <DeleteOutlineRoundedIcon fontSize="small" />
              </IconButton>
            </Tooltip>
          </Stack>
        </Stack>

        {sec.criteria.length === 0 && (
          <Typography variant="body2" color="text.secondary" sx={{ px: 2, py: 2, borderTop: `1px solid ${theme.palette.divider}` }}>
            Mục chưa có tiêu chí nào.
          </Typography>
        )}
        {sec.criteria.map((c, j) => renderCriterion(sec, c, j))}

        <Box sx={{ px: 1.25, py: 0.75, borderTop: `1px solid ${theme.palette.divider}` }}>
          <Button
            size="small"
            startIcon={<AddRoundedIcon />}
            onClick={() => addCriterion(sec)}
            sx={{ textTransform: 'none', fontWeight: 700, color: meta.color }}
          >
            Thêm tiêu chí vào mục {toRoman(i + 1)}
          </Button>
        </Box>
      </Box>
    );
  }

  function renderCriteriaTab() {
    if (!draft) return null;
    return (
      <Stack spacing={2}>
        <Stack direction="row" spacing={1} alignItems="center" justifyContent="space-between" flexWrap="wrap" useFlexGap>
          <Typography variant="body2" color="text.secondary" sx={{ maxWidth: 640 }}>
            Số La Mã của mục, STT tiêu chí, điểm mục và tổng điểm chuẩn được tính tự động. Điểm tối đa của mỗi tiêu chí là mức
            điểm cao nhất của tiêu chí đó.
          </Typography>
          <Button
            size="small"
            color="inherit"
            startIcon={allExpanded ? <UnfoldLessRoundedIcon /> : <UnfoldMoreRoundedIcon />}
            onClick={() => setExpanded(allExpanded ? new Set() : new Set(allCriterionKeys))}
            sx={{ textTransform: 'none', fontWeight: 700, color: 'text.secondary' }}
          >
            {allExpanded ? 'Thu gọn tất cả' : 'Mở tất cả mức điểm'}
          </Button>
        </Stack>

        {draft.sections.map((sec, i) => renderSection(sec, i))}

        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.25}>
          <Button
            fullWidth
            variant="outlined"
            startIcon={<AddRoundedIcon />}
            onClick={() => addSection('normal')}
            sx={{
              py: 1.5,
              borderRadius: '12px',
              borderStyle: 'dashed',
              borderWidth: 2,
              textTransform: 'none',
              fontWeight: 800,
              '&:hover': { borderStyle: 'dashed', borderWidth: 2, bgcolor: alpha(accent, 0.04) },
            }}
          >
            Thêm mục tiêu chí tính điểm
          </Button>
          <Button
            variant="outlined"
            color="success"
            startIcon={<AddRoundedIcon />}
            onClick={() => addSection('bonus')}
            sx={{ py: 1.5, px: 2.5, borderRadius: '12px', borderStyle: 'dashed', borderWidth: 2, textTransform: 'none', fontWeight: 700, whiteSpace: 'nowrap', '&:hover': { borderStyle: 'dashed', borderWidth: 2 } }}
          >
            Mục điểm thưởng
          </Button>
          <Button
            variant="outlined"
            color="error"
            startIcon={<AddRoundedIcon />}
            onClick={() => addSection('penalty')}
            sx={{ py: 1.5, px: 2.5, borderRadius: '12px', borderStyle: 'dashed', borderWidth: 2, textTransform: 'none', fontWeight: 700, whiteSpace: 'nowrap', '&:hover': { borderStyle: 'dashed', borderWidth: 2 } }}
          >
            Mục điểm trừ
          </Button>
        </Stack>
      </Stack>
    );
  }

  function renderGradesTab() {
    if (!draft || !stats) return null;
    const sorted = draft.grades
      .map((g) => ({ ...g, n: parsePoints(g.min) }))
      .filter((g) => Number.isFinite(g.n) && g.n >= 0 && g.n <= 100)
      .sort((a, b) => b.n - a.n);
    const colorOf = (key: string) => {
      const idx = sorted.findIndex((g) => g.key === key);
      return idx >= 0 ? gradeColor(idx, sorted.length) : theme.palette.grey[400];
    };
    // Dải thang 0 → 100 (thấp → cao).
    const bands = [...sorted].reverse().map((g, i, arr) => ({
      ...g,
      from: g.n,
      to: i < arr.length - 1 ? arr[i + 1].n : 100,
    }));
    return (
      <Stack spacing={2}>
        <Box sx={{ ...cardSx, p: { xs: 2, sm: 2.5 } }}>
          <Stack direction="row" spacing={1.25} alignItems="center" sx={{ mb: 0.5 }}>
            <EmojiEventsOutlinedIcon sx={{ color: accent }} />
            <Typography variant="subtitle1" fontWeight={800}>
              Thang xếp loại
            </Typography>
          </Stack>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Xếp loại theo tỷ lệ <b>tổng điểm</b> (gồm điểm thưởng, điểm trừ) trên <b>tổng điểm chuẩn {fmt(stats.base)}</b>.
            Nhân viên đạt từ ngưỡng nào trở lên thì nhận xếp loại đó.
          </Typography>

          {bands.length > 0 && (
            <Box sx={{ mb: 2.5 }}>
              <Stack direction="row" sx={{ height: 34, borderRadius: '8px', overflow: 'hidden' }}>
                {bands.map((b) => (
                  <Tooltip key={b.key} title={`${b.label || '—'}: ${fmt(b.from)}% – ${fmt(b.to)}%`}>
                    <Box
                      sx={{
                        flex: Math.max(b.to - b.from, 0.0001),
                        bgcolor: colorOf(b.key),
                        color: '#fff',
                        display: 'grid',
                        placeItems: 'center',
                        fontSize: 12,
                        fontWeight: 800,
                        overflow: 'hidden',
                        whiteSpace: 'nowrap',
                        px: 0.5,
                        borderRight: '2px solid #fff',
                      }}
                    >
                      {b.to - b.from >= 8 ? b.label : ''}
                    </Box>
                  </Tooltip>
                ))}
              </Stack>
              <Box sx={{ position: 'relative', height: 18, mt: 0.5 }}>
                {[0, ...bands.slice(1).map((b) => b.from), 100].map((v, i) => (
                  <Typography
                    key={`${v}-${i}`}
                    variant="caption"
                    color="text.secondary"
                    sx={{ position: 'absolute', left: `${v}%`, transform: v === 0 ? 'none' : v === 100 ? 'translateX(-100%)' : 'translateX(-50%)', fontWeight: 700 }}
                  >
                    {fmt(v)}
                  </Typography>
                ))}
              </Box>
            </Box>
          )}

          <Box sx={{ borderRadius: '8px', border: `1px solid ${theme.palette.divider}`, overflow: 'hidden' }}>
            <Box
              sx={{
                display: { xs: 'none', md: 'grid' },
                gridTemplateColumns: '28px 1.1fr 150px 1.6fr 40px',
                gap: 1.5,
                px: 1.5,
                py: 1,
                bgcolor: alpha(accent, 0.06),
                fontSize: 12,
                fontWeight: 800,
                color: 'text.secondary',
                textTransform: 'uppercase',
                letterSpacing: '.03em',
              }}
            >
              <span />
              <span>Xếp loại</span>
              <span>Từ ngưỡng</span>
              <span>Đề xuất / hướng xử lý</span>
              <span />
            </Box>
            {draft.grades.map((g) => {
              const min = parsePoints(g.min);
              const hasError = attempted && errorKeys.has(g.key);
              return (
                <Box
                  key={g.key}
                  sx={{
                    display: 'grid',
                    gridTemplateColumns: { xs: '28px 1fr 40px', md: '28px 1.1fr 150px 1.6fr 40px' },
                    gap: 1.5,
                    alignItems: 'center',
                    px: 1.5,
                    py: 1.25,
                    borderTop: `1px solid ${theme.palette.divider}`,
                    boxShadow: hasError ? `inset 3px 0 0 ${theme.palette.error.main}` : 'none',
                  }}
                >
                  <Box sx={{ width: 14, height: 14, borderRadius: '4px', bgcolor: colorOf(g.key), justifySelf: 'center' }} />
                  <TextField
                    size="small"
                    placeholder="Ví dụ: Xuất sắc"
                    value={g.label}
                    error={attempted && !g.label.trim()}
                    onChange={(e) =>
                      patch((s) => ({ ...s, grades: s.grades.map((x) => (x.key === g.key ? { ...x, label: e.target.value } : x)) }))
                    }
                    inputProps={{ style: { fontWeight: 750 } }}
                    sx={inputSx}
                  />
                  <Box sx={{ gridColumn: { xs: '2 / 3', md: 'auto' } }}>
                    <TextField
                      size="small"
                      value={g.min}
                      error={attempted && (!Number.isFinite(min) || min < 0 || min > 100)}
                      helperText={
                        Number.isFinite(min) && stats.base > 0 && Math.abs(stats.base - 100) > 0.001
                          ? `≈ ${fmt((min * stats.base) / 100)} điểm`
                          : undefined
                      }
                      onChange={(e) =>
                        patch((s) => ({
                          ...s,
                          grades: s.grades.map((x) => (x.key === g.key ? { ...x, min: e.target.value.replace(/[^\d.,]/g, '') } : x)),
                        }))
                      }
                      inputProps={{ inputMode: 'decimal', style: { fontWeight: 800 } }}
                      InputProps={{
                        startAdornment: <InputAdornment position="start">≥</InputAdornment>,
                        endAdornment: <InputAdornment position="end">%</InputAdornment>,
                      }}
                      sx={{ width: '100%', ...inputSx }}
                    />
                  </Box>
                  <TextField
                    size="small"
                    placeholder="Ví dụ: Xét tăng lương sớm"
                    value={g.proposal}
                    onChange={(e) =>
                      patch((s) => ({ ...s, grades: s.grades.map((x) => (x.key === g.key ? { ...x, proposal: e.target.value } : x)) }))
                    }
                    sx={{ gridColumn: { xs: '2 / 3', md: 'auto' }, ...inputSx }}
                  />
                  <Box sx={{ gridRow: { xs: 1, md: 'auto' }, gridColumn: { xs: 3, md: 'auto' }, justifySelf: 'end' }}>
                    <Tooltip title="Xóa xếp loại">
                      <span>
                        <IconButton
                          size="small"
                          color="error"
                          disabled={draft.grades.length <= 1}
                          onClick={() => patch((s) => ({ ...s, grades: s.grades.filter((x) => x.key !== g.key) }))}
                        >
                          <DeleteOutlineRoundedIcon fontSize="small" />
                        </IconButton>
                      </span>
                    </Tooltip>
                  </Box>
                </Box>
              );
            })}
          </Box>
          <Stack direction="row" spacing={1} sx={{ mt: 1.25 }}>
            <Button
              size="small"
              startIcon={<AddRoundedIcon />}
              disabled={draft.grades.length >= 10}
              onClick={() => patch((s) => ({ ...s, grades: [...s.grades, { key: uid(), label: '', min: '', proposal: '' }] }))}
              sx={{ textTransform: 'none', fontWeight: 700 }}
            >
              Thêm mức xếp loại
            </Button>
            <Button
              size="small"
              color="inherit"
              startIcon={<SortRoundedIcon />}
              onClick={() =>
                patch((s) => ({
                  ...s,
                  grades: [...s.grades].sort((a, b) => (parsePoints(b.min) || 0) - (parsePoints(a.min) || 0)),
                }))
              }
              sx={{ textTransform: 'none', fontWeight: 650, color: 'text.secondary' }}
            >
              Sắp xếp theo ngưỡng
            </Button>
          </Stack>
        </Box>
        <Alert severity="info" icon={<InfoOutlinedIcon />} sx={{ borderRadius: '10px' }}>
          Thay đổi thang xếp loại chỉ áp dụng cho phiếu chấm hoặc lưu lại sau khi lưu mẫu. Xếp loại của phiếu đã gửi duyệt
          được giữ nguyên.
        </Alert>
      </Stack>
    );
  }

  function renderGeneralTab() {
    if (!draft || !server) return null;
    return (
      <Box sx={{ ...cardSx, p: { xs: 2, sm: 2.5 } }}>
        <Stack spacing={2.25}>
          <TextField
            label="Tên mẫu đánh giá"
            value={draft.name}
            error={attempted && !draft.name.trim()}
            helperText={attempted && !draft.name.trim() ? 'Bắt buộc' : 'Hiển thị trên phiếu đánh giá và bản in.'}
            onChange={(e) => patch((s) => ({ ...s, name: e.target.value }))}
            sx={inputSx}
          />
          <TextField
            label="Mã mẫu"
            value={server.template.code || templateCode}
            disabled
            helperText="Mã cố định dùng để liên kết phiếu đánh giá, không đổi được."
            sx={inputSx}
          />
          <TextField
            label="Ghi chú cho người chấm"
            value={draft.note}
            multiline
            minRows={4}
            helperText="Hiện ở đầu form chấm điểm, ví dụ quy định không xét thi đua, cách xử lý điểm bằng nhau."
            onChange={(e) => patch((s) => ({ ...s, note: e.target.value }))}
            sx={inputSx}
          />
        </Stack>
      </Box>
    );
  }

  function renderPreviewTab() {
    if (!draft) return null;
    return <TemplatePreview template={draftToTemplate(draft, server?.template)} />;
  }

  function renderSidebar() {
    if (!stats || !draft) return null;
    const ok = stats.base > 0 && Math.abs(stats.base - 100) < 0.001;
    const normals = stats.perSection.filter((s) => s.kind === 'normal');
    return (
      <Stack spacing={2} sx={{ position: { lg: 'sticky' }, top: { lg: 16 } }}>
        <Box sx={{ ...cardSx, p: 2.25 }}>
          <Typography variant="overline" sx={{ fontWeight: 800, color: 'text.secondary', lineHeight: 1.4 }}>
            Tổng điểm chuẩn
          </Typography>
          <Stack direction="row" alignItems="baseline" spacing={1} sx={{ mb: 1.5 }}>
            <Typography sx={{ fontSize: 40, fontWeight: 900, lineHeight: 1.05, color: ok ? accent : 'warning.dark', letterSpacing: '-0.02em' }}>
              {fmt(stats.base)}
            </Typography>
            <Typography variant="body2" color="text.secondary" fontWeight={700}>
              điểm
            </Typography>
            <Box sx={{ flex: 1 }} />
            <Chip
              size="small"
              color={ok ? 'success' : 'warning'}
              variant="outlined"
              label={ok ? 'Đúng thang 100' : 'Khác 100'}
              sx={{ fontWeight: 750 }}
            />
          </Stack>
          {stats.base > 0 && (
            <Stack direction="row" sx={{ height: 10, borderRadius: 99, overflow: 'hidden', mb: 1.5, bgcolor: alpha(accent, 0.08) }}>
              {normals.map((s, i) => (
                <Tooltip key={s.key} title={`${s.roman}. ${s.name || '—'}: ${fmt(s.pts)} điểm`}>
                  <Box sx={{ flex: s.pts || 0.0001, bgcolor: alpha(accent, 1 - (i % 5) * 0.16), borderRight: '2px solid #fff' }} />
                </Tooltip>
              ))}
            </Stack>
          )}
          <Stack spacing={0.75}>
            {stats.perSection.map((s) => (
              <Stack key={s.key} direction="row" spacing={1} alignItems="center">
                <Typography variant="caption" fontWeight={900} sx={{ width: 26, color: kindMeta[s.kind].color }}>
                  {s.roman}
                </Typography>
                <Typography variant="body2" noWrap sx={{ flex: 1, minWidth: 0 }} title={s.name}>
                  {s.name || <i style={{ opacity: 0.6 }}>Chưa đặt tên</i>}
                </Typography>
                <Typography variant="body2" fontWeight={800} sx={{ color: kindMeta[s.kind].color, whiteSpace: 'nowrap' }}>
                  {s.kind === 'normal' ? fmt(s.pts) : s.kind === 'bonus' ? `+${fmt(s.pts)}` : `−${fmt(s.pts)}`}
                </Typography>
              </Stack>
            ))}
          </Stack>
          <Divider sx={{ my: 1.5 }} />
          <Stack direction="row" spacing={1} justifyContent="space-between">
            {[
              { v: draft.sections.length, l: 'Mục' },
              { v: stats.criteria, l: 'Tiêu chí' },
              { v: stats.options, l: 'Mức điểm' },
              { v: draft.grades.length, l: 'Xếp loại' },
            ].map((x) => (
              <Box key={x.l} sx={{ textAlign: 'center', flex: 1 }}>
                <Typography fontWeight={900} fontSize={18}>
                  {x.v}
                </Typography>
                <Typography variant="caption" color="text.secondary" fontWeight={700}>
                  {x.l}
                </Typography>
              </Box>
            ))}
          </Stack>
        </Box>

        <Box sx={{ ...cardSx, p: 2.25 }}>
          <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1.25 }}>
            <Typography variant="subtitle2" fontWeight={800} sx={{ flex: 1 }}>
              Kiểm tra mẫu
            </Typography>
            {errors.length > 0 && <Chip size="small" color="error" label={`${errors.length} lỗi`} sx={{ fontWeight: 750 }} />}
            {warnings.length > 0 && (
              <Chip size="small" color="warning" variant="outlined" label={`${warnings.length} lưu ý`} sx={{ fontWeight: 750 }} />
            )}
          </Stack>
          {issues.length === 0 ? (
            <Stack direction="row" spacing={1} alignItems="center" sx={{ color: 'success.main' }}>
              <CheckCircleRoundedIcon fontSize="small" />
              <Typography variant="body2" fontWeight={700}>
                Mẫu hợp lệ, sẵn sàng lưu.
              </Typography>
            </Stack>
          ) : (
            <Stack spacing={0.5} sx={{ maxHeight: 260, overflowY: 'auto', mr: -1, pr: 1 }}>
              {[...errors, ...warnings].map((it, i) => (
                <Stack
                  key={i}
                  direction="row"
                  spacing={1}
                  alignItems="flex-start"
                  onClick={() => {
                    setTab(it.tab);
                    if (it.key) setExpanded((prev) => new Set(prev).add(it.key!));
                  }}
                  sx={{ cursor: 'pointer', borderRadius: '6px', p: 0.5, '&:hover': { bgcolor: alpha(theme.palette.text.primary, 0.04) } }}
                >
                  {it.level === 'error' ? (
                    <ErrorOutlineRoundedIcon sx={{ fontSize: 17, mt: 0.2, color: 'error.main' }} />
                  ) : (
                    <WarningAmberRoundedIcon sx={{ fontSize: 17, mt: 0.2, color: 'warning.main' }} />
                  )}
                  <Typography variant="body2" sx={{ fontSize: 13, lineHeight: 1.45 }}>
                    {it.message}
                  </Typography>
                </Stack>
              ))}
            </Stack>
          )}
        </Box>

        <Alert severity="info" icon={<InfoOutlinedIcon fontSize="small" />} sx={{ borderRadius: '10px', fontSize: 13 }}>
          Phiếu đã gửi duyệt giữ nguyên mẫu tại thời điểm chấm. Phiếu mới và phiếu nháp lưu lại sẽ dùng mẫu mới.
        </Alert>
      </Stack>
    );
  }

  /* ---------------- tiêu chí đang mở menu ---------------- */

  const menuSection = critMenu ? draft?.sections.find((s) => s.key === critMenu.sectionKey) : undefined;
  const menuIndex = menuSection && critMenu ? menuSection.criteria.findIndex((c) => c.key === critMenu.criterionKey) : -1;
  const menuCriterion = menuSection && menuIndex >= 0 ? menuSection.criteria[menuIndex] : undefined;

  /* ---------------- layout ---------------- */

  const tabs: Array<{ value: TabKey; label: string; icon: ReactElement; count?: number }> = [
    { value: 'criteria', label: 'Tiêu chí chấm điểm', icon: <ListAltRoundedIcon fontSize="small" />, count: stats?.criteria },
    { value: 'grades', label: 'Thang xếp loại', icon: <EmojiEventsOutlinedIcon fontSize="small" />, count: draft?.grades.length },
    { value: 'general', label: 'Thông tin chung', icon: <EditNoteRoundedIcon fontSize="small" /> },
    { value: 'preview', label: 'Xem trước', icon: <VisibilityOutlinedIcon fontSize="small" /> },
  ];
  const tabErrors = (t: TabKey) => attempted && errors.some((e) => e.tab === t);

  const onBarBtn = {
    textTransform: 'none',
    fontWeight: 700,
    borderRadius: '8px',
    color: alpha('#fff', 0.9),
    '&:hover': { bgcolor: alpha('#fff', 0.1) },
    '&.Mui-disabled': { color: alpha('#fff', 0.4) },
  } as const;

  return (
    <Dialog
      fullScreen
      open={open}
      onClose={requestClose}
      PaperProps={{
        sx: { bgcolor: '#F3F6F7', backgroundImage: 'none', borderRadius: 0, border: 'none', boxShadow: 'none' },
      }}
    >
      {/* Header */}
      <Box sx={{ position: 'relative', flexShrink: 0, zIndex: 5 }}>
        {/* Thanh tiêu đề — cùng nhận diện với thanh điều hướng chính */}
        <Box
          sx={{
            color: '#fff',
            backgroundImage: 'linear-gradient(180deg, #0C7A75 0%, #045E5A 58%, #033F3D 100%)',
            boxShadow: `inset 0 -2px 0 ${alpha('#E6C76E', 0.85)}`,
          }}
        >
          <Stack
            direction={{ xs: 'column', md: 'row' }}
            spacing={{ xs: 1.5, md: 2 }}
            alignItems={{ md: 'center' }}
            sx={{ px: { xs: 2, md: 3 }, py: 1.5, maxWidth: 1440, mx: 'auto' }}
          >
            <Stack direction="row" spacing={1.5} alignItems="center" sx={{ flex: 1, minWidth: 0 }}>
              <Box
                sx={{
                  width: 40,
                  height: 40,
                  borderRadius: '10px',
                  flexShrink: 0,
                  display: 'grid',
                  placeItems: 'center',
                  bgcolor: alpha('#fff', 0.14),
                  border: `1px solid ${alpha('#fff', 0.24)}`,
                }}
              >
                <TuneRoundedIcon sx={{ fontSize: 22 }} />
              </Box>
              <Box sx={{ minWidth: 0 }}>
                <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap>
                  <Typography sx={{ fontSize: 17, fontWeight: 800, letterSpacing: '-0.015em', lineHeight: 1.3, color: '#fff' }}>
                    Cấu hình mẫu đánh giá & xếp loại
                  </Typography>
                  {server && (
                    <Box
                      component="span"
                      sx={{
                        px: 0.875,
                        py: 0.125,
                        borderRadius: '6px',
                        fontSize: 12,
                        fontWeight: 800,
                        bgcolor: alpha('#fff', 0.16),
                        border: `1px solid ${alpha('#fff', 0.22)}`,
                      }}
                    >
                      v{server.version}
                      {server.isDefault ? ' · mẫu gốc' : ''}
                    </Box>
                  )}
                  {dirty && (
                    <Box
                      component="span"
                      sx={{ px: 0.875, py: 0.125, borderRadius: '6px', fontSize: 12, fontWeight: 800, bgcolor: '#E6C76E', color: '#251B05' }}
                    >
                      Chưa lưu
                    </Box>
                  )}
                </Stack>
                <Typography variant="body2" noWrap sx={{ color: alpha('#fff', 0.72), mt: 0.25 }}>
                  {server?.template.name || 'Đang tải…'}
                  {server?.updatedAt &&
                    ` · Cập nhật ${formatDateTimeVi(server.updatedAt)}${server.updatedBy ? ` bởi ${server.updatedBy}` : ''}`}
                </Typography>
              </Box>
            </Stack>
            <Stack direction="row" spacing={0.75} alignItems="center" flexWrap="wrap" useFlexGap>
              <Button startIcon={<HistoryRoundedIcon />} onClick={() => setHistoryOpen(true)} disabled={!server} sx={onBarBtn}>
                Lịch sử
              </Button>
              <Button startIcon={<RestartAltRoundedIcon />} onClick={requestReset} disabled={!server || busy} sx={onBarBtn}>
                Mẫu gốc
              </Button>
              <Box sx={{ width: '1px', height: 24, bgcolor: alpha('#fff', 0.22), mx: 0.5, display: { xs: 'none', sm: 'block' } }} />
              <Button
                variant="outlined"
                startIcon={<CloseRoundedIcon />}
                onClick={requestClose}
                sx={{
                  ...onBarBtn,
                  color: '#fff',
                  borderColor: alpha('#fff', 0.4),
                  '&:hover': { borderColor: '#fff', bgcolor: alpha('#fff', 0.08) },
                }}
              >
                Đóng
              </Button>
              <Button
                variant="contained"
                startIcon={busy ? <CircularProgress size={16} color="inherit" /> : <SaveRoundedIcon />}
                onClick={requestSave}
                disabled={!dirty || busy || !server}
                sx={{
                  textTransform: 'none',
                  fontWeight: 800,
                  borderRadius: '8px',
                  px: 2.25,
                  bgcolor: '#fff',
                  color: theme.palette.primary.dark,
                  boxShadow: '0 4px 14px rgba(0, 0, 0, 0.18)',
                  '&:hover': { bgcolor: '#F1FAF9', boxShadow: '0 6px 18px rgba(0, 0, 0, 0.22)' },
                  '&.Mui-disabled': { bgcolor: alpha('#fff', 0.14), color: alpha('#fff', 0.5), boxShadow: 'none' },
                }}
              >
                Lưu thay đổi
              </Button>
            </Stack>
          </Stack>
        </Box>

        {/* Thanh tab */}
        <Box sx={{ bgcolor: '#fff', borderBottom: `1px solid ${theme.palette.divider}`, boxShadow: '0 2px 10px rgba(23, 32, 51, 0.04)' }}>
          <Box sx={{ px: { xs: 1, md: 2 }, maxWidth: 1440, mx: 'auto' }}>
            <Tabs
              value={tab}
              onChange={(_, v: TabKey) => setTab(v)}
              variant="scrollable"
              allowScrollButtonsMobile
              sx={{ minHeight: 46, '& .MuiTab-root': { minHeight: 46, px: 2, fontWeight: 700 } }}
            >
              {tabs.map((t) => (
                <Tab
                  key={t.value}
                  value={t.value}
                  iconPosition="start"
                  icon={t.icon}
                  label={
                    <Stack direction="row" spacing={0.75} alignItems="center">
                      <span>{t.label}</span>
                      {t.count != null && (
                        <Box
                          component="span"
                          sx={{
                            minWidth: 20,
                            px: 0.625,
                            borderRadius: '6px',
                            fontSize: 11.5,
                            lineHeight: '18px',
                            fontWeight: 800,
                            textAlign: 'center',
                            bgcolor: tabErrors(t.value)
                              ? alpha(theme.palette.error.main, 0.12)
                              : tab === t.value
                                ? alpha(accent, 0.12)
                                : alpha(theme.palette.text.primary, 0.06),
                            color: tabErrors(t.value) ? 'error.main' : tab === t.value ? accent : 'text.secondary',
                          }}
                        >
                          {t.count}
                        </Box>
                      )}
                      {t.count == null && tabErrors(t.value) && (
                        <Box component="span" sx={{ width: 7, height: 7, borderRadius: '50%', bgcolor: 'error.main' }} />
                      )}
                    </Stack>
                  }
                />
              ))}
            </Tabs>
          </Box>
        </Box>
        {(loading || busy) && <LinearProgress sx={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 2 }} />}
      </Box>

      {/* Body */}
      <DialogContent sx={{ p: 0 }}>
        <Box sx={{ maxWidth: 1440, mx: 'auto', px: { xs: 1.5, md: 3 }, py: { xs: 2, md: 3 } }}>
          {err && (
            <Alert
              severity="error"
              sx={{ mb: 2, borderRadius: '10px' }}
              onClose={() => setErr(null)}
              action={
                conflict ? (
                  <Button color="inherit" size="small" onClick={() => void load()} sx={{ fontWeight: 800 }}>
                    Tải lại mẫu
                  </Button>
                ) : undefined
              }
            >
              {err}
            </Alert>
          )}
          {!draft && loading && (
            <Stack alignItems="center" spacing={1.5} sx={{ py: 10 }}>
              <CircularProgress />
              <Typography color="text.secondary">Đang tải mẫu đánh giá…</Typography>
            </Stack>
          )}
          {draft && (
            <Box
              sx={{
                display: 'grid',
                gap: 2.5,
                gridTemplateColumns: { xs: 'minmax(0, 1fr)', lg: tab === 'preview' ? 'minmax(0, 1fr)' : 'minmax(0, 1fr) 340px' },
                alignItems: 'start',
              }}
            >
              <Box sx={{ minWidth: 0 }}>
                {tab === 'criteria' && renderCriteriaTab()}
                {tab === 'grades' && renderGradesTab()}
                {tab === 'general' && renderGeneralTab()}
                {tab === 'preview' && renderPreviewTab()}
              </Box>
              {tab !== 'preview' && renderSidebar()}
            </Box>
          )}
        </Box>
      </DialogContent>

      {/* Menu thao tác tiêu chí */}
      <Menu
        anchorEl={critMenu?.anchor}
        open={Boolean(critMenu && menuCriterion)}
        onClose={() => setCritMenu(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
        transformOrigin={{ vertical: 'top', horizontal: 'right' }}
        PaperProps={{ sx: { borderRadius: '8px', minWidth: 220 } }}
      >
        <MenuItem
          disabled={menuIndex <= 0}
          onClick={() => {
            if (menuSection) patchSection(menuSection.key, (s) => ({ ...s, criteria: move(s.criteria, menuIndex, menuIndex - 1) }));
            setCritMenu(null);
          }}
        >
          <ListItemIcon>
            <ArrowUpwardRoundedIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText>Di chuyển lên</ListItemText>
        </MenuItem>
        <MenuItem
          disabled={!menuSection || menuIndex >= menuSection.criteria.length - 1}
          onClick={() => {
            if (menuSection) patchSection(menuSection.key, (s) => ({ ...s, criteria: move(s.criteria, menuIndex, menuIndex + 1) }));
            setCritMenu(null);
          }}
        >
          <ListItemIcon>
            <ArrowDownwardRoundedIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText>Di chuyển xuống</ListItemText>
        </MenuItem>
        <MenuItem
          disabled={(draft?.sections.length ?? 0) < 2}
          onClick={() => {
            setMoveMenu(critMenu);
            setCritMenu(null);
          }}
        >
          <ListItemIcon>
            <DriveFileMoveOutlinedIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText>Chuyển sang mục khác…</ListItemText>
        </MenuItem>
        <MenuItem
          onClick={() => {
            if (menuSection && menuCriterion) duplicateCriterion(menuSection.key, menuCriterion);
            setCritMenu(null);
          }}
        >
          <ListItemIcon>
            <ContentCopyRoundedIcon fontSize="small" />
          </ListItemIcon>
          <ListItemText>Nhân bản</ListItemText>
        </MenuItem>
        <Divider />
        <MenuItem
          sx={{ color: 'error.main' }}
          onClick={() => {
            if (menuSection && menuCriterion) removeCriterion(menuSection.key, menuCriterion);
            setCritMenu(null);
          }}
        >
          <ListItemIcon>
            <DeleteOutlineRoundedIcon fontSize="small" color="error" />
          </ListItemIcon>
          <ListItemText>Xóa tiêu chí</ListItemText>
        </MenuItem>
      </Menu>

      {/* Menu chọn mục đích */}
      <Menu
        anchorEl={moveMenu?.anchor}
        open={Boolean(moveMenu)}
        onClose={() => setMoveMenu(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
        transformOrigin={{ vertical: 'top', horizontal: 'right' }}
        PaperProps={{ sx: { borderRadius: '8px', maxWidth: 360 } }}
      >
        <Typography variant="caption" color="text.secondary" fontWeight={800} sx={{ px: 2, py: 0.75, display: 'block' }}>
          CHUYỂN TIÊU CHÍ SANG MỤC
        </Typography>
        {draft?.sections.map((s, i) => (
          <MenuItem
            key={s.key}
            disabled={s.key === moveMenu?.sectionKey}
            onClick={() => {
              if (moveMenu) moveCriterionToSection(moveMenu.sectionKey, moveMenu.criterionKey, s.key);
              setMoveMenu(null);
            }}
          >
            <Typography component="span" fontWeight={900} sx={{ width: 32, color: kindMeta[s.kind].color }}>
              {toRoman(i + 1)}
            </Typography>
            <Typography noWrap>{s.name || 'Chưa đặt tên'}</Typography>
          </MenuItem>
        ))}
      </Menu>

      {/* Xác nhận lưu */}
      <Dialog open={saveOpen} onClose={() => !busy && setSaveOpen(false)} maxWidth="sm" fullWidth PaperProps={{ sx: { borderRadius: '12px' } }}>
        <DialogTitle sx={{ fontWeight: 850, pb: 1 }}>Lưu phiên bản mới v{(server?.version ?? 0) + 1}</DialogTitle>
        <DialogContent>
          {diff && (
            <Stack direction="row" spacing={0.75} flexWrap="wrap" useFlexGap sx={{ mb: 2 }}>
              {diff.added > 0 && <Chip size="small" color="success" label={`+${diff.added} tiêu chí mới`} sx={{ fontWeight: 750 }} />}
              {diff.removed > 0 && <Chip size="small" color="error" label={`−${diff.removed} tiêu chí bị xóa`} sx={{ fontWeight: 750 }} />}
              {diff.changed > 0 && <Chip size="small" color="info" label={`${diff.changed} tiêu chí sửa`} sx={{ fontWeight: 750 }} />}
              {diff.sectionsChanged && <Chip size="small" variant="outlined" label="Đổi cấu trúc mục" sx={{ fontWeight: 700 }} />}
              {diff.gradesChanged && <Chip size="small" variant="outlined" label="Đổi thang xếp loại" sx={{ fontWeight: 700 }} />}
              {diff.infoChanged && <Chip size="small" variant="outlined" label="Đổi thông tin chung" sx={{ fontWeight: 700 }} />}
            </Stack>
          )}
          <Box
            sx={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: 1,
              mb: 2,
              p: 1.5,
              borderRadius: '8px',
              bgcolor: alpha(accent, 0.05),
              border: `1px solid ${alpha(accent, 0.12)}`,
            }}
          >
            {[
              { l: 'Tổng điểm chuẩn', v: fmt(stats?.base ?? 0) },
              { l: 'Tiêu chí', v: stats?.criteria ?? 0 },
              { l: 'Mức xếp loại', v: draft?.grades.length ?? 0 },
            ].map((x) => (
              <Box key={x.l} sx={{ textAlign: 'center' }}>
                <Typography fontWeight={900} fontSize={20} color="primary.main">
                  {x.v}
                </Typography>
                <Typography variant="caption" color="text.secondary" fontWeight={700}>
                  {x.l}
                </Typography>
              </Box>
            ))}
          </Box>
          {warnings.length > 0 && (
            <Alert severity="warning" sx={{ mb: 2, borderRadius: '8px' }}>
              Mẫu còn {warnings.length} lưu ý (không bắt buộc sửa). Xem mục “Kiểm tra mẫu” để biết chi tiết.
            </Alert>
          )}
          <TextField
            fullWidth
            multiline
            minRows={2}
            label="Ghi chú thay đổi (không bắt buộc)"
            placeholder="Ví dụ: Bổ sung tiêu chí truyền thông theo quyết định tháng 10/2026"
            value={changeNote}
            onChange={(e) => setChangeNote(e.target.value.slice(0, 500))}
            sx={inputSx}
          />
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1.5 }}>
            Mẫu mới áp dụng ngay cho web và ứng dụng di động. Phiếu đã gửi duyệt giữ nguyên mẫu cũ.
          </Typography>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5 }}>
          <Button onClick={() => setSaveOpen(false)} disabled={busy} sx={{ textTransform: 'none', fontWeight: 700 }}>
            Hủy
          </Button>
          <Button
            variant="contained"
            onClick={() => void doSave()}
            disabled={busy}
            startIcon={busy ? <CircularProgress size={16} color="inherit" /> : <SaveRoundedIcon />}
            sx={{ textTransform: 'none', fontWeight: 800, borderRadius: '8px' }}
          >
            Lưu & áp dụng
          </Button>
        </DialogActions>
      </Dialog>

      {/* Xác nhận chung */}
      <Dialog open={Boolean(confirm)} onClose={() => !busy && setConfirm(null)} maxWidth="xs" fullWidth PaperProps={{ sx: { borderRadius: '12px' } }}>
        <DialogTitle sx={{ fontWeight: 850, pb: 1 }}>{confirm?.title}</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary" component="div" sx={{ lineHeight: 1.6 }}>
            {confirm?.message}
          </Typography>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2.5 }}>
          <Button onClick={() => setConfirm(null)} disabled={busy} sx={{ textTransform: 'none', fontWeight: 700 }}>
            Hủy
          </Button>
          <Button
            variant="contained"
            color={confirm?.danger ? 'error' : 'primary'}
            disabled={busy}
            onClick={async () => {
              const c = confirm;
              if (!c) return;
              await c.onConfirm();
              setConfirm(null);
            }}
            sx={{ textTransform: 'none', fontWeight: 800, borderRadius: '8px' }}
          >
            {confirm?.confirmLabel}
          </Button>
        </DialogActions>
      </Dialog>

      {/* Lịch sử phiên bản */}
      <Drawer
        anchor="right"
        open={historyOpen}
        onClose={() => setHistoryOpen(false)}
        PaperProps={{ sx: { width: { xs: '100%', sm: 440 }, bgcolor: 'background.default' } }}
      >
        <Stack direction="row" alignItems="center" spacing={1} sx={{ px: 2.5, py: 2, bgcolor: 'background.paper', borderBottom: `1px solid ${theme.palette.divider}` }}>
          <HistoryRoundedIcon sx={{ color: accent }} />
          <Typography variant="subtitle1" fontWeight={850} sx={{ flex: 1 }}>
            Lịch sử phiên bản
          </Typography>
          <IconButton onClick={() => setHistoryOpen(false)} size="small">
            <CloseRoundedIcon />
          </IconButton>
        </Stack>
        {revisionsLoading && <LinearProgress />}
        <Stack spacing={1.25} sx={{ p: 2, overflowY: 'auto' }}>
          {revisions?.length === 0 && (
            <Box sx={{ ...cardSx, p: 2.5, textAlign: 'center' }}>
              <Typography fontWeight={750}>Chưa có chỉnh sửa nào</Typography>
              <Typography variant="body2" color="text.secondary">
                Hệ thống đang dùng mẫu gốc v{server?.defaultVersion}.
              </Typography>
            </Box>
          )}
          {revisions?.map((r) => (
            <Box
              key={r.id}
              sx={{
                ...cardSx,
                p: 1.75,
                borderColor: r.current ? alpha(accent, 0.5) : cardBorder,
                boxShadow: r.current ? `0 0 0 3px ${alpha(accent, 0.08)}` : cardSx.boxShadow,
              }}
            >
              <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 0.5 }}>
                <Chip size="small" label={`v${r.version}`} sx={{ fontWeight: 900, bgcolor: alpha(accent, 0.1), color: accent }} />
                {r.current && <Chip size="small" color="success" label="Đang dùng" sx={{ fontWeight: 750 }} />}
                <Box sx={{ flex: 1 }} />
                <Typography variant="caption" color="text.secondary" fontWeight={650}>
                  {formatDateTimeVi(r.createdAt)}
                </Typography>
              </Stack>
              <Typography variant="body2" fontWeight={700}>
                {r.changeNote || <span style={{ opacity: 0.6, fontWeight: 500 }}>Không có ghi chú</span>}
              </Typography>
              <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.25 }}>
                {r.createdBy ? `${r.createdBy} · ` : ''}
                {r.criteriaCount} tiêu chí · {fmt(Number(r.baseMaxPoints))} điểm chuẩn
              </Typography>
              {!r.current && (
                <Stack direction="row" spacing={1} sx={{ mt: 1.25 }}>
                  <Button
                    size="small"
                    variant="outlined"
                    disabled={busy}
                    startIcon={<VisibilityOutlinedIcon />}
                    onClick={() => void openRevisionInEditor(r)}
                    sx={{ textTransform: 'none', fontWeight: 700, borderRadius: '8px' }}
                  >
                    Mở để xem / sửa
                  </Button>
                  <Button
                    size="small"
                    disabled={busy}
                    startIcon={<RestartAltRoundedIcon />}
                    onClick={() => requestRestore(r)}
                    sx={{ textTransform: 'none', fontWeight: 700 }}
                  >
                    Khôi phục
                  </Button>
                </Stack>
              )}
            </Box>
          ))}
          {server && (
            <Box sx={{ ...cardSx, p: 1.75, bgcolor: alpha(theme.palette.text.primary, 0.02), borderStyle: 'dashed' }}>
              <Stack direction="row" spacing={1} alignItems="center">
                <Chip size="small" variant="outlined" label={`Mẫu gốc v${server.defaultVersion}`} sx={{ fontWeight: 800 }} />
                {server.isDefault && <Chip size="small" color="success" label="Đang dùng" sx={{ fontWeight: 750 }} />}
              </Stack>
              <Typography variant="caption" color="text.secondary" display="block" sx={{ mt: 0.75 }}>
                Nội dung chuẩn đi kèm hệ thống (Excel MA 2026).
              </Typography>
              {!server.isDefault && (
                <Button
                  size="small"
                  disabled={busy}
                  startIcon={<RestartAltRoundedIcon />}
                  onClick={requestReset}
                  sx={{ mt: 1, textTransform: 'none', fontWeight: 700 }}
                >
                  Khôi phục mẫu gốc
                </Button>
              )}
            </Box>
          )}
        </Stack>
      </Drawer>

      <Snackbar
        open={Boolean(toast)}
        autoHideDuration={5000}
        onClose={() => setToast(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert severity="success" variant="filled" onClose={() => setToast(null)} sx={{ borderRadius: '10px', fontWeight: 650 }}>
          {toast}
        </Alert>
      </Snackbar>
    </Dialog>
  );
}

/* ============================================================================
 * Xem trước form chấm (giống giao diện Trưởng khoa / ĐDT nhìn thấy)
 * ========================================================================== */

function TemplatePreview({ template }: { template: ne.NursingTemplate }) {
  const theme = useTheme();
  const accent = theme.palette.primary.main;
  const [picked, setPicked] = useState<Record<string, string>>({});

  const sections = useMemo(() => {
    const map = new Map<string, ne.CriterionGroup[]>();
    for (const g of template.criteriaGroups) {
      if (!map.has(g.section || 'Khác')) map.set(g.section || 'Khác', []);
      map.get(g.section || 'Khác')!.push(g);
    }
    return [...map.entries()];
  }, [template]);

  const total = useMemo(() => {
    let sum = 0;
    for (const g of template.criteriaGroups) {
      const v = Number(picked[g.id]);
      if (!Number.isFinite(v) || picked[g.id] == null || picked[g.id] === '') continue;
      sum += g.penalty ? -v : v;
    }
    return Math.max(0, sum);
  }, [picked, template]);

  const base = template.baseMaxPoints || 0;
  const pct = base > 0 ? (Math.min(total, base) * 100) / base : 0;
  const grade = template.gradingScale.find((g) => pct >= g.min) ?? template.gradingScale[template.gradingScale.length - 1];
  const filled = template.criteriaGroups.filter((g) => !g.bonus && !g.penalty && picked[g.id]).length;
  const required = template.criteriaGroups.filter((g) => !g.bonus && !g.penalty).length;

  return (
    <Box
      sx={{
        p: { xs: 2, sm: 2.5 },
        borderRadius: '12px',
        border: `1px solid ${alpha(accent, 0.14)}`,
        bgcolor: 'background.paper',
        boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
      }}
    >
      <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5} justifyContent="space-between" sx={{ mb: 2 }}>
        <Box>
          <Typography variant="overline" color="text.secondary" fontWeight={800}>
            Xem trước — form chấm điểm
          </Typography>
          <Typography variant="subtitle1" fontWeight={850}>
            {template.name || 'Chưa đặt tên mẫu'}
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Chọn thử điểm để kiểm tra cách tính tổng và xếp loại. Không lưu dữ liệu.
          </Typography>
        </Box>
        <Stack direction="row" spacing={1} alignItems="flex-start" flexWrap="wrap" useFlexGap>
          <Chip label={`${filled}/${required} tiêu chí`} sx={{ fontWeight: 750 }} />
          <Chip color="primary" label={`Tạm tính: ${fmt(total)} / ${fmt(base)} điểm`} sx={{ fontWeight: 850 }} />
          {grade && filled > 0 && <Chip color="success" variant="outlined" label={`Xếp loại: ${grade.label}`} sx={{ fontWeight: 850 }} />}
          {Object.keys(picked).length > 0 && (
            <Button size="small" onClick={() => setPicked({})} sx={{ textTransform: 'none', fontWeight: 700 }}>
              Xóa lựa chọn
            </Button>
          )}
        </Stack>
      </Stack>

      {template.note && (
        <Alert severity="info" sx={{ mb: 2, borderRadius: '8px' }}>
          {template.note}
        </Alert>
      )}

      <Box sx={{ border: `1px solid ${theme.palette.divider}`, borderRadius: '10px', overflow: 'hidden' }}>
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: { xs: '36px 1fr', md: '44px 1fr 300px' },
            bgcolor: accent,
            color: '#fff',
            fontWeight: 800,
            fontSize: 14,
            px: 1,
            py: 1.25,
            gap: 1,
          }}
        >
          <span>STT</span>
          <span>Tiêu chí</span>
          <Box sx={{ display: { xs: 'none', md: 'block' } }}>Điểm đạt</Box>
        </Box>
        {sections.map(([section, items]) => (
          <Fragment key={section}>
            <Box
              sx={{
                px: 1.5,
                py: 1.1,
                bgcolor: alpha(accent, 0.1),
                fontWeight: 800,
                color: theme.palette.primary.dark,
                fontSize: 14,
                borderTop: `1px solid ${theme.palette.divider}`,
              }}
            >
              {section}
              {items[0]?.sectionPoints != null ? ` (${fmt(Number(items[0].sectionPoints))} điểm)` : ''}
            </Box>
            {items.map((g, idx) => (
              <Box
                key={g.id}
                sx={{
                  display: 'grid',
                  gridTemplateColumns: { xs: '36px 1fr', md: '44px 1fr 300px' },
                  gap: 1,
                  alignItems: 'center',
                  px: 1,
                  py: 1,
                  borderTop: `1px solid ${theme.palette.divider}`,
                  bgcolor: idx % 2 ? alpha(accent, 0.02) : 'transparent',
                }}
              >
                <Typography variant="body2" fontWeight={700} color="text.secondary">
                  {g.no}
                </Typography>
                <Typography variant="body2" fontWeight={650}>
                  {g.title}
                </Typography>
                <TextField
                  select
                  size="small"
                  value={picked[g.id] ?? ''}
                  onChange={(e) => setPicked((p) => ({ ...p, [g.id]: e.target.value }))}
                  SelectProps={{
                    displayEmpty: true,
                    renderValue: (v) => {
                      const o = g.options.find((x) => String(x.points) === String(v));
                      return (
                        <Typography variant="body2" noWrap color={o ? 'text.primary' : 'text.secondary'}>
                          {o ? `${fmt(o.points)} — ${o.label}` : '— Chọn điểm —'}
                        </Typography>
                      );
                    },
                    MenuProps: { PaperProps: { sx: { maxWidth: 440, maxHeight: 360 } } },
                  }}
                  sx={{ gridColumn: { xs: '2 / 3', md: 'auto' }, '& .MuiOutlinedInput-root': { borderRadius: '8px' } }}
                >
                  <MenuItem value="">— Chọn điểm —</MenuItem>
                  {g.options.map((o) => (
                    <MenuItem key={`${o.points}-${o.label}`} value={String(o.points)} sx={{ whiteSpace: 'normal', py: 1.1 }}>
                      <Typography variant="body2" sx={{ lineHeight: 1.45 }}>
                        <b>{fmt(o.points)}</b> — {o.label}
                      </Typography>
                    </MenuItem>
                  ))}
                </TextField>
              </Box>
            ))}
          </Fragment>
        ))}
      </Box>

      {template.gradingScale.length > 0 && (
        <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap sx={{ mt: 2 }}>
          <Typography variant="body2" fontWeight={800} color="text.secondary" sx={{ mr: 0.5, alignSelf: 'center' }}>
            Thang xếp loại:
          </Typography>
          {template.gradingScale.map((g, i) => (
            <Chip
              key={`${g.label}-${g.min}`}
              size="small"
              label={`${g.label} ≥ ${fmt(g.min)}%${g.proposal ? ` · ${g.proposal}` : ''}`}
              sx={{
                fontWeight: 700,
                bgcolor: alpha(gradeColor(i, template.gradingScale.length), 0.12),
                color: gradeColor(i, template.gradingScale.length),
                outline: grade?.label === g.label && filled > 0 ? `2px solid ${gradeColor(i, template.gradingScale.length)}` : 'none',
              }}
            />
          ))}
        </Stack>
      )}
    </Box>
  );
}
