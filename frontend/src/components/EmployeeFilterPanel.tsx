import FilterListIcon from '@mui/icons-material/FilterList';
import SearchIcon from '@mui/icons-material/Search';
import {
  Box,
  Button,
  Chip,
  Collapse,
  Grid,
  InputAdornment,
  MenuItem,
  Paper,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useState } from 'react';
import type { DepartmentOption, EmployeeSummary } from '../services/employeeService';

export const EMPLOYEE_STATUS_OPTIONS = [
  { value: '', label: 'Tất cả trạng thái' },
  { value: 'ACTIVE', label: 'Đang làm việc' },
  { value: 'ON_LEAVE', label: 'Nghỉ phép' },
  { value: 'TERMINATED', label: 'Đã nghỉ việc' },
] as const;

export function formatEmployeeLabel(e: EmployeeSummary): string {
  return `${e.employeeCode ? `[${e.employeeCode}] ` : ''}${e.fullName}`;
}

type Props = {
  qInput: string;
  onQInputChange: (value: string) => void;
  filterDept: number | '';
  onFilterDeptChange: (value: number | '') => void;
  filterStatus: string;
  onFilterStatusChange: (value: string) => void;
  departments: DepartmentOption[];
  employees: EmployeeSummary[];
  selected: number | '';
  onSelectedChange: (id: number) => void;
  defaultOpen?: boolean;
};

export function EmployeeFilterPanel({
  qInput,
  onQInputChange,
  filterDept,
  onFilterDeptChange,
  filterStatus,
  onFilterStatusChange,
  departments,
  employees,
  selected,
  onSelectedChange,
  defaultOpen = true,
}: Props) {
  const theme = useTheme();
  const [open, setOpen] = useState(defaultOpen);
  const selectedEmployee = employees.find((e) => e.id === selected);

  const paperSx = {
    borderRadius: 3,
    border: `1px solid ${alpha(theme.palette.primary.main, 0.1)}`,
    bgcolor: alpha(theme.palette.background.paper, 0.96),
    boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
    overflow: 'hidden' as const,
    mb: 2.5,
  };

  return (
    <Paper elevation={0} sx={paperSx}>
      <Stack
        direction="row"
        alignItems="center"
        justifyContent="space-between"
        sx={{
          px: 2.5,
          py: 1.75,
          bgcolor: alpha(theme.palette.primary.main, 0.03),
          borderBottom: open ? 1 : 0,
          borderColor: 'divider',
        }}
      >
        <Stack direction="row" spacing={1} alignItems="center" flexWrap="wrap" useFlexGap sx={{ flex: 1, minWidth: 0 }}>
          <FilterListIcon color="primary" fontSize="small" />
          <Typography variant="subtitle1" fontWeight={700} sx={{ flexShrink: 0 }}>
            Chọn nhân viên
          </Typography>
          {!open && selectedEmployee && (
            <Chip
              size="small"
              label={formatEmployeeLabel(selectedEmployee)}
              color="primary"
              variant="outlined"
              sx={{
                fontWeight: 600,
                height: 'auto',
                maxWidth: 'none',
                '& .MuiChip-label': {
                  whiteSpace: 'normal',
                  overflow: 'visible',
                  textOverflow: 'clip',
                  display: 'block',
                  py: 0.25,
                },
              }}
            />
          )}
        </Stack>
        <Button size="small" startIcon={<FilterListIcon />} onClick={() => setOpen((v) => !v)} sx={{ flexShrink: 0 }}>
          {open ? 'Thu gọn' : 'Bộ lọc'}
        </Button>
      </Stack>

      <Collapse in={open}>
        <Box sx={{ p: 2.5 }}>
          <Grid container spacing={2}>
            <Grid item xs={12} md={4}>
              <TextField
                size="small"
                fullWidth
                label="Tìm theo tên, mã NV"
                value={qInput}
                onChange={(e) => onQInputChange(e.target.value)}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <SearchIcon fontSize="small" color="action" />
                    </InputAdornment>
                  ),
                }}
              />
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
              <TextField
                size="small"
                fullWidth
                select
                label="Phòng ban"
                value={filterDept}
                onChange={(e) => onFilterDeptChange(e.target.value === '' ? '' : Number(e.target.value))}
              >
                <MenuItem value="">Tất cả</MenuItem>
                {departments.map((d) => (
                  <MenuItem key={d.id} value={d.id}>
                    {d.name}
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
              <TextField
                size="small"
                fullWidth
                select
                label="Trạng thái"
                value={filterStatus}
                onChange={(e) => onFilterStatusChange(e.target.value)}
              >
                {EMPLOYEE_STATUS_OPTIONS.map((o) => (
                  <MenuItem key={o.value || 'all'} value={o.value}>
                    {o.label}
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
            <Grid item xs={12}>
              <TextField
                size="small"
                select
                fullWidth
                label="Nhân viên"
                value={selected}
                onChange={(e) => onSelectedChange(Number(e.target.value))}
                disabled={employees.length === 0}
              >
                {employees.map((e) => (
                  <MenuItem key={e.id} value={e.id}>
                    {formatEmployeeLabel(e)}
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
          </Grid>
        </Box>
      </Collapse>
    </Paper>
  );
}
