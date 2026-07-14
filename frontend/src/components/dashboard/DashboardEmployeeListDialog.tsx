import {
  Box,
  CircularProgress,
  Dialog,
  DialogContent,
  DialogTitle,
  IconButton,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import CloseIcon from '@mui/icons-material/Close';
import { Link } from 'react-router-dom';
import { EmployeeStatusChip } from '../EmployeeStatusChip';
import { MaternityLeaveChip } from '../MaternityLeaveChip';
import type { EmployeeSummary } from '../../services/employeeService';

type Props = {
  open: boolean;
  title: string;
  subtitle?: string;
  employees: EmployeeSummary[];
  loading?: boolean;
  showHireDate?: boolean;
  onClose: () => void;
};

function formatDate(iso?: string | null) {
  if (!iso) return '—';
  const [y, m, d] = iso.split('-');
  return d && m && y ? `${d}/${m}/${y}` : iso;
}

function isTrialEmployee(row: EmployeeSummary) {
  const code = row.employeeCode?.toUpperCase() ?? '';
  if (code.startsWith('TV-')) return true;
  return row.status === 'PROBATION' || row.status === 'INTERN';
}

export function DashboardEmployeeListDialog({
  open,
  title,
  subtitle,
  employees,
  loading = false,
  showHireDate = false,
  onClose,
}: Props) {
  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle sx={{ pr: 6 }}>
        {title}
        {subtitle && (
          <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5, fontWeight: 400 }}>
            {subtitle}
          </Typography>
        )}
        <IconButton
          aria-label="Đóng"
          onClick={onClose}
          sx={{ position: 'absolute', right: 12, top: 12 }}
        >
          <CloseIcon />
        </IconButton>
      </DialogTitle>
      <DialogContent dividers sx={{ p: 0 }}>
        {loading ? (
          <Box sx={{ py: 6, textAlign: 'center' }}>
            <CircularProgress size={32} />
          </Box>
        ) : employees.length === 0 ? (
          <Box sx={{ py: 4, px: 3 }}>
            <Typography variant="body2" color="text.secondary">
              Không có nhân viên trong mục này.
            </Typography>
          </Box>
        ) : (
          <TableContainer>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell>Mã NV</TableCell>
                  <TableCell>Họ tên</TableCell>
                  <TableCell>Phòng ban</TableCell>
                  <TableCell>Bộ phận</TableCell>
                  <TableCell>Chức vụ</TableCell>
                  {showHireDate && <TableCell>Ngày nhận việc</TableCell>}
                  <TableCell>Loại</TableCell>
                  <TableCell>Trạng thái</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {employees.map((row) => (
                  <TableRow key={row.id} hover>
                    <TableCell>{row.employeeCode || '—'}</TableCell>
                    <TableCell>
                      <Typography
                        component={Link}
                        to={`/employees/${row.id}`}
                        variant="body2"
                        sx={{ fontWeight: 600, color: 'primary.main', textDecoration: 'none', '&:hover': { textDecoration: 'underline' } }}
                      >
                        {row.fullName}
                      </Typography>
                    </TableCell>
                    <TableCell>{row.departmentName}</TableCell>
                    <TableCell>{row.workUnitDetail?.trim() || '—'}</TableCell>
                    <TableCell>{row.positionTitle}</TableCell>
                    {showHireDate && <TableCell>{formatDate(row.hireDate)}</TableCell>}
                    <TableCell>{isTrialEmployee(row) ? 'Thử việc / Thực tập' : 'Chính thức'}</TableCell>
                    <TableCell>
                      <Box sx={{ display: 'flex', gap: 0.75, flexWrap: 'wrap' }}>
                        <EmployeeStatusChip status={row.status} />
                        {row.maternityLeave && <MaternityLeaveChip />}
                      </Box>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        )}
      </DialogContent>
    </Dialog>
  );
}
