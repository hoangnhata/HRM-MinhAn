import FilterAltOffOutlinedIcon from '@mui/icons-material/FilterAltOffOutlined';
import SearchIcon from '@mui/icons-material/Search';
import {
  Box,
  Button,
  Chip,
  InputAdornment,
  MenuItem,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import * as employeeService from '../../services/employeeService';
import { DatePickerField } from '../ui/DateTimeFields';

export type RequestListFilterState = {
  q: string;
  dateFrom: string;
  dateTo: string;
  status: string;
  /** Tên phòng ban (khớp cột department trên đơn). */
  department: string;
};

export const EMPTY_REQUEST_FILTERS: RequestListFilterState = {
  q: '',
  dateFrom: '',
  dateTo: '',
  status: '',
  department: '',
};

type StatusOption = { value: string; label: string };

type Props = {
  value: RequestListFilterState;
  onChange: (next: RequestListFilterState) => void;
  statusOptions?: StatusOption[];
  /** Tên phòng ban xuất hiện trên danh sách đơn (ưu tiên hơn danh mục hệ thống). */
  departmentOptions?: string[];
  searchPlaceholder?: string;
  resultCount?: number;
  /** Nhãn caption phía trên thanh lọc. */
  title?: string;
  /** Ẩn cặp Từ/Đến ngày (dùng cho danh sách không theo ngày gửi). */
  hideDateFilters?: boolean;
  /** Nhãn chip số kết quả, mặc định "đơn". */
  resultCountLabel?: string;
};

const fieldSx = {
  minWidth: { xs: '100%', sm: 140 },
  '& .MuiOutlinedInput-root': { bgcolor: '#fff' },
} as const;

export function RequestListFilters({
  value,
  onChange,
  statusOptions,
  departmentOptions,
  searchPlaceholder = 'Tìm tên, nội dung…',
  resultCount,
  title = 'Bộ lọc đơn',
  hideDateFilters = false,
  resultCountLabel = 'đơn',
}: Props) {
  const theme = useTheme();
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);

  useEffect(() => {
    employeeService
      .fetchDepartments()
      .then(setDepartments)
      .catch(() => setDepartments([]));
  }, []);

  function patch(partial: Partial<RequestListFilterState>) {
    onChange({ ...value, ...partial });
  }

  const hasFilter = Boolean(
    value.q || value.dateFrom || value.dateTo || value.status || value.department,
  );

  const deptNames = (() => {
    if (departmentOptions && departmentOptions.length > 0) {
      return [...new Set(departmentOptions.map((n) => n.trim()).filter(Boolean))].sort((a, b) =>
        a.localeCompare(b, 'vi'),
      );
    }
    return departments.map((d) => d.name);
  })();

  return (
    <Paper
      elevation={0}
      sx={{
        p: { xs: 1.5, sm: 1.75 },
        borderRadius: 2.5,
        border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
        bgcolor: alpha(theme.palette.background.paper, 0.96),
        boxShadow: `0 4px 20px ${alpha('#0f172a', 0.04)}`,
      }}
    >
      <Stack spacing={1.25}>
        <Stack
          direction="row"
          alignItems="center"
          justifyContent="space-between"
          spacing={1}
          flexWrap="wrap"
          useFlexGap
        >
          <Typography variant="caption" fontWeight={700} color="text.secondary" letterSpacing={0.02}>
            {title}
          </Typography>
          <Stack direction="row" spacing={1} alignItems="center">
            {resultCount != null && (
              <Chip
                size="small"
                label={`${resultCount} ${resultCountLabel}`}
                variant="outlined"
                sx={{ height: 24, fontWeight: 700, borderRadius: '6px' }}
              />
            )}
            {hasFilter && (
              <Button
                size="small"
                startIcon={<FilterAltOffOutlinedIcon fontSize="small" />}
                onClick={() => onChange({ ...EMPTY_REQUEST_FILTERS })}
                sx={{ textTransform: 'none', fontWeight: 600 }}
              >
                Xóa lọc
              </Button>
            )}
          </Stack>
        </Stack>

        <Box
          sx={{
            display: 'grid',
            gap: 1.25,
            gridTemplateColumns: hideDateFilters
              ? {
                  xs: '1fr',
                  sm: '1fr 1fr',
                  md: statusOptions?.length
                    ? 'minmax(200px, 1.5fr) minmax(160px, 1fr) minmax(160px, 0.9fr)'
                    : 'minmax(200px, 1.5fr) minmax(160px, 1fr)',
                }
              : {
                  xs: '1fr',
                  sm: '1fr 1fr',
                  md: 'minmax(180px, 1.4fr) minmax(160px, 1fr) minmax(130px, 0.85fr) minmax(130px, 0.85fr) minmax(140px, 0.9fr)',
                },
            alignItems: 'center',
          }}
        >
          <TextField
            size="small"
            placeholder={searchPlaceholder}
            value={value.q}
            onChange={(e) => patch({ q: e.target.value })}
            sx={fieldSx}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon fontSize="small" color="action" />
                </InputAdornment>
              ),
            }}
          />
          <TextField
            size="small"
            select
            label="Phòng ban"
            value={value.department}
            onChange={(e) => patch({ department: e.target.value })}
            sx={fieldSx}
          >
            <MenuItem value="">Tất cả phòng ban</MenuItem>
            {deptNames.map((name) => (
              <MenuItem key={name} value={name}>
                {name}
              </MenuItem>
            ))}
          </TextField>
          {!hideDateFilters && (
            <>
              <DatePickerField
                size="small"
                fullWidth
                label="Từ ngày gửi"
                value={value.dateFrom}
                onChange={(v) => patch({ dateFrom: v })}
                sx={fieldSx}
              />
              <DatePickerField
                size="small"
                fullWidth
                label="Đến ngày gửi"
                value={value.dateTo}
                onChange={(v) => patch({ dateTo: v })}
                sx={fieldSx}
              />
            </>
          )}
          {statusOptions && statusOptions.length > 0 ? (
            <TextField
              size="small"
              select
              label="Trạng thái"
              value={value.status}
              onChange={(e) => patch({ status: e.target.value })}
              sx={fieldSx}
            >
              <MenuItem value="">Tất cả</MenuItem>
              {statusOptions.map((o) => (
                <MenuItem key={o.value} value={o.value}>
                  {o.label}
                </MenuItem>
              ))}
            </TextField>
          ) : !hideDateFilters ? (
            <Box sx={{ display: { xs: 'none', md: 'block' } }} />
          ) : null}
        </Box>
      </Stack>
    </Paper>
  );
}

/** Lọc theo ngày gửi đơn và luôn xếp đơn gửi mới nhất lên trước. */
export function applyRequestListFilters<T>(
  items: T[],
  filters: RequestListFilterState,
  opts: {
    searchText: (item: T) => string;
    dateValue: (item: T) => string | null | undefined;
    statusValue?: (item: T) => string;
    departmentValue?: (item: T) => string | null | undefined;
  },
): T[] {
  const q = filters.q.trim().toLowerCase();
  const from = filters.dateFrom.slice(0, 10);
  const to = filters.dateTo.slice(0, 10);
  const dept = filters.department.trim().toLowerCase();
  return items.filter((item) => {
    if (q) {
      const hay = opts.searchText(item).toLowerCase();
      if (!hay.includes(q)) return false;
    }
    if (dept && opts.departmentValue) {
      const d = (opts.departmentValue(item) || '').trim().toLowerCase();
      if (d !== dept && !d.includes(dept)) return false;
    }
    if (filters.status && opts.statusValue) {
      if (opts.statusValue(item) !== filters.status) return false;
    }
    const raw = opts.dateValue(item);
    const d = raw ? String(raw).slice(0, 10) : '';
    if (from && (!d || d < from)) return false;
    if (to && (!d || d > to)) return false;
    return true;
  }).sort((a, b) => {
    const aDate = opts.dateValue(a);
    const bDate = opts.dateValue(b);
    return String(bDate || '').localeCompare(String(aDate || ''));
  });
}
