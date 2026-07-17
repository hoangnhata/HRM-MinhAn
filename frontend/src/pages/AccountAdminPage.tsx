import ManageAccountsIcon from '@mui/icons-material/ManageAccounts';
import PersonAddAlt1Icon from '@mui/icons-material/PersonAddAlt1';
import {
  Alert,
  Box,
  Button,
  CircularProgress,
  MenuItem,
  Paper,
  Snackbar,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TablePagination,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { GrantAccountDialog } from '../components/GrantAccountDialog';
import { PageHeader } from '../components/layout/PageHeader';
import * as employeeService from '../services/employeeService';
import * as ssoAccountService from '../services/ssoAccountService';
import { getRoleLabel } from '../utils/roleLabels';

export default function AccountAdminPage() {
  const theme = useTheme();
  const [rows, setRows] = useState<ssoAccountService.SsoAccountRow[]>([]);
  const [roles, setRoles] = useState<ssoAccountService.SsoRoleCatalog[]>([]);
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [loading, setLoading] = useState(true);
  const [qInput, setQInput] = useState('');
  const [q, setQ] = useState('');
  const [filterDept, setFilterDept] = useState<number | ''>('');
  const [page, setPage] = useState(0);
  const [rowsPerPage, setRowsPerPage] = useState(25);
  const [savingId, setSavingId] = useState<number | null>(null);
  const [grantDialogOpen, setGrantDialogOpen] = useState(false);
  const [snack, setSnack] = useState<{ open: boolean; message: string; severity: 'success' | 'error' }>({
    open: false,
    message: '',
    severity: 'success',
  });

  useEffect(() => {
    const t = setTimeout(() => {
      setQ(qInput);
      setPage(0);
    }, 350);
    return () => clearTimeout(t);
  }, [qInput]);

  useEffect(() => {
    employeeService.fetchDepartments().then(setDepartments).catch(() => setDepartments([]));
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [list, catalog] = await Promise.all([
        ssoAccountService.fetchSsoAccounts({
          q,
          departmentId: filterDept === '' ? undefined : filterDept,
        }),
        ssoAccountService.fetchSsoHrmRoles().catch(() => [] as ssoAccountService.SsoRoleCatalog[]),
      ]);
      setRows(list);
      setRoles(catalog);
    } catch {
      setRows([]);
      setSnack({ open: true, message: 'Không tải được danh sách tài khoản SSO.', severity: 'error' });
    } finally {
      setLoading(false);
    }
  }, [q, filterDept]);

  useEffect(() => {
    void load();
  }, [load]);

  const paged = useMemo(() => {
    const start = page * rowsPerPage;
    return rows.slice(start, start + rowsPerPage);
  }, [rows, page, rowsPerPage]);

  const roleOptions = useMemo(() => {
    if (roles.length > 0) {
      return [
        { value: '', label: '— Chọn chức danh —' },
        ...roles.map((r) => ({ value: r.roleCode, label: r.roleName || getRoleLabel(r.roleCode) })),
      ];
    }
    return [
      { value: '', label: '— Chọn chức danh —' },
      { value: 'ADMIN', label: 'Quản trị hệ thống' },
      { value: 'EMPLOYEE', label: 'Nhân viên' },
      { value: 'HR', label: 'Hành chính nhân sự' },
      { value: 'HEAD_DEPARTMENT', label: 'Trưởng khoa / phòng' },
      { value: 'HEAD_NURSING', label: 'Điều dưỡng trưởng' },
      { value: 'DIRECTOR', label: 'Giám đốc' },
    ];
  }, [roles]);

  async function onChangeRole(accountId: number, roleCode: string) {
    if (!roleCode) return;
    setSavingId(accountId);
    try {
      await ssoAccountService.assignSsoHrmRole(accountId, roleCode);
      setSnack({ open: true, message: 'Đã cập nhật chức danh (role) trên SSO.', severity: 'success' });
      await load();
    } catch (e: unknown) {
      const msg =
        (e as { response?: { data?: { message?: string } } })?.response?.data?.message ||
        'Không cập nhật được role.';
      setSnack({ open: true, message: msg, severity: 'error' });
    } finally {
      setSavingId(null);
    }
  }

  return (
    <Box sx={{ width: '100%' }}>
      <PageHeader
        overline="Hệ thống"
        title="Quản trị tài khoản"
        description="Xem và cấp chức danh (role HRM) cho tài khoản SSO. Lọc theo tên, số điện thoại, mã chấm công hoặc phòng ban."
        actions={
          <Button
            variant="contained"
            startIcon={<PersonAddAlt1Icon />}
            onClick={() => setGrantDialogOpen(true)}
          >
            Cấp tài khoản đăng nhập
          </Button>
        }
      />

      <Paper
        elevation={0}
        sx={{
          p: 2.25,
          mb: 2.5,
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
        }}
      >
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} alignItems={{ md: 'center' }}>
          <TextField
            size="small"
            label="Tìm theo tên, số điện thoại, mã chấm công"
            placeholder="Nhập từ khóa…"
            value={qInput}
            onChange={(e) => setQInput(e.target.value)}
            sx={{ flex: 1, minWidth: 200 }}
          />
          <TextField
            size="small"
            select
            label="Phòng ban"
            value={filterDept}
            onChange={(e) => {
              setFilterDept(e.target.value === '' ? '' : Number(e.target.value));
              setPage(0);
            }}
            sx={{ minWidth: 200 }}
          >
            <MenuItem value="">Tất cả phòng ban</MenuItem>
            {departments.map((d) => (
              <MenuItem key={d.id} value={d.id}>
                {d.name}
              </MenuItem>
            ))}
          </TextField>
        </Stack>
      </Paper>

      <TableContainer
        component={Paper}
        elevation={0}
        sx={{
          borderRadius: 2.5,
          border: `1px solid ${theme.palette.divider}`,
          overflow: 'hidden',
        }}
      >
        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
            <CircularProgress />
          </Box>
        ) : (
          <>
            <Table size="small">
              <TableHead>
                <TableRow>
                  <TableCell sx={{ fontWeight: 700 }}>Họ tên</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Số điện thoại</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Mã chấm công</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Phòng ban</TableCell>
                  <TableCell sx={{ fontWeight: 700 }}>Chức danh hiện tại</TableCell>
                  <TableCell sx={{ fontWeight: 700, minWidth: 220 }}>Cấp / đổi chức danh</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {paged.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6}>
                      <Typography variant="body2" color="text.secondary">
                        Không có tài khoản phù hợp bộ lọc.
                      </Typography>
                    </TableCell>
                  </TableRow>
                ) : (
                  paged.map((r) => (
                    <TableRow key={r.accountId} hover>
                      <TableCell>
                        <Stack direction="row" spacing={1} alignItems="center">
                          <ManageAccountsIcon fontSize="small" color="action" />
                          <span>{r.fullName || '—'}</span>
                        </Stack>
                      </TableCell>
                      <TableCell>{r.loginPhone || '—'}</TableCell>
                      <TableCell>{r.userEnrollNumber ?? '—'}</TableCell>
                      <TableCell>{r.departmentName || '—'}</TableCell>
                      <TableCell>
                        {r.roleName || (r.roleCode ? getRoleLabel(r.roleCode) : 'Chưa gán')}
                      </TableCell>
                      <TableCell>
                        <TextField
                          size="small"
                          select
                          fullWidth
                          disabled={savingId === r.accountId}
                          value={r.roleCode || ''}
                          onChange={(e) => void onChangeRole(r.accountId, e.target.value)}
                        >
                          {roleOptions.map((o) => (
                            <MenuItem key={o.value || 'empty'} value={o.value} disabled={!o.value}>
                              {o.label}
                            </MenuItem>
                          ))}
                        </TextField>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
            <TablePagination
              component="div"
              count={rows.length}
              page={page}
              onPageChange={(_, p) => setPage(p)}
              rowsPerPage={rowsPerPage}
              onRowsPerPageChange={(e) => {
                setRowsPerPage(parseInt(e.target.value, 10));
                setPage(0);
              }}
              rowsPerPageOptions={[10, 25, 50, 100]}
              labelRowsPerPage="Số dòng"
              labelDisplayedRows={({ from, to, count }) => `${from}–${to} / ${count}`}
            />
          </>
        )}
      </TableContainer>

      <Snackbar
        open={snack.open}
        autoHideDuration={4000}
        onClose={() => setSnack((s) => ({ ...s, open: false }))}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert
          severity={snack.severity}
          variant="filled"
          onClose={() => setSnack((s) => ({ ...s, open: false }))}
        >
          {snack.message}
        </Alert>
      </Snackbar>

      <GrantAccountDialog
        open={grantDialogOpen}
        onClose={() => setGrantDialogOpen(false)}
        onSuccess={(message) => {
          setGrantDialogOpen(false);
          setSnack({ open: true, message, severity: 'success' });
          void load();
        }}
      />
    </Box>
  );
}
