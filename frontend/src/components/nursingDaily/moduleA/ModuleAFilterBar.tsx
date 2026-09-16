import RefreshOutlinedIcon from '@mui/icons-material/RefreshOutlined';
import {
  Box,
  IconButton,
  MenuItem,
  Paper,
  Stack,
  TextField,
} from '@mui/material';
import { filterBarSx } from './moduleAUiStyles';
import { DatePickerField, MonthPickerField } from '../../ui/DateTimeFields';
import type { ActivityReportQuery, FilterDepartment, PeriodType } from '../../../services/nursingActivityReportService';
import { currentYear, currentYearMonth } from '../../../services/nursingActivityReportService';

type Props = {
  query: ActivityReportQuery;
  onChange: (q: ActivityReportQuery) => void;
  departments: FilterDepartment[];
  canPickDept: boolean;
  onRefresh: () => void;
};

const PERIOD_OPTIONS: { value: PeriodType; label: string }[] = [
  { value: 'MONTH', label: 'Tháng' },
  { value: 'QUARTER', label: 'Quý' },
  { value: 'HALF_YEAR', label: '6 tháng' },
  { value: 'YEAR', label: 'Năm' },
  { value: 'DAY', label: 'Ngày' },
  { value: 'CUSTOM', label: 'Khoảng thời gian' },
];

export function ModuleAFilterBar({ query, onChange, departments, canPickDept, onRefresh }: Props) {
  const periodType = query.periodType ?? 'MONTH';

  function setPeriodType(v: PeriodType) {
    const next: ActivityReportQuery = { ...query, periodType: v };
    if (v === 'MONTH') next.yearMonth = query.yearMonth ?? currentYearMonth();
    if (v === 'YEAR') next.year = query.year ?? currentYear();
    if (v === 'QUARTER') {
      next.year = query.year ?? currentYear();
      next.quarter = query.quarter ?? Math.ceil((new Date().getMonth() + 1) / 3);
    }
    if (v === 'HALF_YEAR') {
      next.year = query.year ?? currentYear();
      next.half = query.half ?? (new Date().getMonth() < 6 ? 1 : 2);
    }
    onChange(next);
  }

  return (
    <Paper elevation={0} sx={filterBarSx()}>
      <Stack direction="row" spacing={1.15} alignItems="center" sx={{ flexWrap: { xs: 'wrap', lg: 'nowrap' } }}>
        <TextField
          select
          size="small"
          label="Kỳ báo cáo"
          value={periodType}
          sx={{ minWidth: 140, flex: { lg: '0 0 140px' } }}
          onChange={(e) => setPeriodType(e.target.value as PeriodType)}
        >
          {PERIOD_OPTIONS.map((o) => (
            <MenuItem key={o.value} value={o.value}>{o.label}</MenuItem>
          ))}
        </TextField>

        {periodType === 'MONTH' && (
          <MonthPickerField
            label="Tháng"
            value={query.yearMonth ?? currentYearMonth()}
            onChange={(v: string) => onChange({ ...query, yearMonth: v })}
            size="small"
            sx={{ minWidth: 178, flex: { lg: '0 0 178px' } }}
          />
        )}

        {(periodType === 'YEAR' || periodType === 'QUARTER' || periodType === 'HALF_YEAR') && (
          <TextField
            size="small"
            label="Năm"
            type="number"
            value={query.year ?? currentYear()}
            sx={{ width: 100 }}
            onChange={(e) => onChange({ ...query, year: Number(e.target.value) })}
          />
        )}

        {periodType === 'QUARTER' && (
          <TextField
            select
            size="small"
            label="Quý"
            value={query.quarter ?? 1}
            sx={{ minWidth: 90 }}
            onChange={(e) => onChange({ ...query, quarter: Number(e.target.value) })}
          >
            {[1, 2, 3, 4].map((q) => <MenuItem key={q} value={q}>Q{q}</MenuItem>)}
          </TextField>
        )}

        {periodType === 'HALF_YEAR' && (
          <TextField
            select
            size="small"
            label="Kỳ"
            value={query.half ?? 1}
            sx={{ minWidth: 120 }}
            onChange={(e) => onChange({ ...query, half: Number(e.target.value) })}
          >
            <MenuItem value={1}>6 tháng đầu</MenuItem>
            <MenuItem value={2}>6 tháng cuối</MenuItem>
          </TextField>
        )}

        {periodType === 'DAY' && (
          <DatePickerField
            label="Ngày"
            value={query.from ?? ''}
            onChange={(v: string) => onChange({ ...query, from: v, to: v })}
            size="small"
            sx={{ minWidth: 160 }}
          />
        )}

        {periodType === 'CUSTOM' && (
          <>
            <DatePickerField label="Từ ngày" value={query.from ?? ''} onChange={(v: string) => onChange({ ...query, from: v })} size="small" sx={{ minWidth: 160 }} />
            <DatePickerField label="Đến ngày" value={query.to ?? ''} onChange={(v: string) => onChange({ ...query, to: v })} size="small" sx={{ minWidth: 160 }} />
          </>
        )}

        {canPickDept && (
          <TextField
            select
            size="small"
            label="Khoa"
            value={query.departmentId ?? ''}
            sx={{ minWidth: 170, flex: { lg: '0 0 190px' } }}
            onChange={(e) => onChange({ ...query, departmentId: e.target.value ? Number(e.target.value) : undefined })}
          >
            <MenuItem value="">Tất cả</MenuItem>
            {departments.map((d) => <MenuItem key={d.id} value={d.id}>{d.name}</MenuItem>)}
          </TextField>
        )}

        <Box sx={{ flex: 1 }} />
        <IconButton onClick={onRefresh} aria-label="Làm mới"><RefreshOutlinedIcon /></IconButton>
      </Stack>
    </Paper>
  );
}
