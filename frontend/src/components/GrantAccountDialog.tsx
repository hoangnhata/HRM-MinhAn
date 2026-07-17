import CloseIcon from '@mui/icons-material/Close';
import SearchIcon from '@mui/icons-material/Search';
import KeyIcon from '@mui/icons-material/VpnKey';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogContent,
  DialogTitle,
  Divider,
  IconButton,
  InputAdornment,
  List,
  ListItemButton,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useState } from 'react';
import * as employeeService from '../services/employeeService';
import * as ssoAccountService from '../services/ssoAccountService';
import { getRoleLabel } from '../utils/roleLabels';

const ERP_ROLE_OPTIONS = [
  { value: 1, label: 'Nhân viên' },
  { value: 2, label: 'Tổ trưởng' },
  { value: 3, label: 'Quản lý' },
];

const ASSET_ROLE_OPTIONS = [
  { value: 1, label: 'Quản lý' },
  { value: 2, label: 'Duyệt' },
  { value: 3, label: 'Nhân viên' },
  { value: 4, label: 'BP Mua sắm' },
];

const FALLBACK_HRM_ROLES: ssoAccountService.SsoRoleCatalog[] = [
  { roleId: 0, appCode: 'HRM', roleCode: 'ADMIN', roleName: 'Quản trị hệ thống', active: true },
  { roleId: 0, appCode: 'HRM', roleCode: 'EMPLOYEE', roleName: 'Nhân viên', active: true },
  { roleId: 0, appCode: 'HRM', roleCode: 'HR', roleName: 'Hành chính nhân sự', active: true },
  { roleId: 0, appCode: 'HRM', roleCode: 'HEAD_DEPARTMENT', roleName: 'Trưởng khoa / phòng', active: true },
  { roleId: 0, appCode: 'HRM', roleCode: 'HEAD_NURSING', roleName: 'Điều dưỡng trưởng', active: true },
  { roleId: 0, appCode: 'HRM', roleCode: 'DIRECTOR', roleName: 'Giám đốc', active: true },
];

type Props = {
  open: boolean;
  onClose: () => void;
  onSuccess: (message: string) => void;
};

function extractErrorMessage(e: unknown, fallback: string): string {
  const msg = (e as { response?: { data?: { message?: string } } })?.response?.data?.message;
  return msg || fallback;
}

export function GrantAccountDialog({ open, onClose, onSuccess }: Props) {
  const theme = useTheme();
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [deptFilter, setDeptFilter] = useState('');
  const [candidates, setCandidates] = useState<ssoAccountService.EmployeeAccountCandidate[]>([]);
  const [loadingList, setLoadingList] = useState(false);
  const [listError, setListError] = useState<string | null>(null);

  const [selected, setSelected] = useState<ssoAccountService.EmployeeAccountCandidate | null>(null);
  const [password, setPassword] = useState('123');
  const [hrmRoleCode, setHrmRoleCode] = useState('EMPLOYEE');
  const [hrmRoles, setHrmRoles] = useState<ssoAccountService.SsoRoleCatalog[]>(FALLBACK_HRM_ROLES);
  const [roleId, setRoleId] = useState(1);
  const [roleIdTs, setRoleIdTs] = useState(3);
  const [submitting, setSubmitting] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const resetState = useCallback(() => {
    setSearchInput('');
    setSearch('');
    setDepartments([]);
    setDeptFilter('');
    setCandidates([]);
    setSelected(null);
    setPassword('123');
    setHrmRoleCode('EMPLOYEE');
    setHrmRoles(FALLBACK_HRM_ROLES);
    setRoleId(1);
    setRoleIdTs(3);
    setFormError(null);
    setListError(null);
  }, []);

  useEffect(() => {
    if (open) {
      resetState();
    }
  }, [open, resetState]);

  useEffect(() => {
    if (!open) return;
    employeeService.fetchDepartments().then(setDepartments).catch(() => setDepartments([]));
    ssoAccountService
      .fetchSsoHrmRoles()
      .then((roles) => {
        if (roles.length > 0) setHrmRoles(roles);
      })
      .catch(() => {
        /* giữ FALLBACK_HRM_ROLES */
      });
  }, [open]);

  useEffect(() => {
    const t = setTimeout(() => setSearch(searchInput), 350);
    return () => clearTimeout(t);
  }, [searchInput]);

  useEffect(() => {
    if (!open || selected) return;
    let active = true;
    setLoadingList(true);
    setListError(null);
    ssoAccountService
      .fetchEmployeesWithoutAccount({ search, dept: deptFilter || undefined, limit: 100 })
      .then((page) => {
        if (active) setCandidates(page.data);
      })
      .catch(() => {
        if (active) setListError('Không tải được danh sách nhân sự chưa có tài khoản.');
      })
      .finally(() => {
        if (active) setLoadingList(false);
      });
    return () => {
      active = false;
    };
  }, [open, search, deptFilter, selected]);

  async function handleSubmit() {
    if (!selected || !password.trim()) return;
    setSubmitting(true);
    setFormError(null);
    try {
      const result = await ssoAccountService.grantEmployeeAccount(selected.id, {
        password: password.trim(),
        roleId,
        roleIdTs,
        hrmRoleCode,
      });
      onSuccess(result.message || 'Cấp tài khoản đăng nhập thành công');
    } catch (e: unknown) {
      setFormError(extractErrorMessage(e, 'Không cấp được tài khoản đăng nhập.'));
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog open={open} onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle sx={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', pb: 0.5 }}>
        <Box>
          <Typography variant="h6" fontWeight={700}>
            Cấp tài khoản đăng nhập
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Chọn nhân sự từ danh sách HRM để khởi tạo tài khoản đăng nhập
          </Typography>
        </Box>
        <IconButton onClick={onClose} size="small">
          <CloseIcon fontSize="small" />
        </IconButton>
      </DialogTitle>
      <DialogContent sx={{ pt: 1 }}>
        <Stack spacing={2}>
          {!selected ? (
            <>
              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1.5}>
                <TextField
                  fullWidth
                  size="small"
                  placeholder="Tìm nhanh nhân viên cần cấp tài khoản..."
                  value={searchInput}
                  onChange={(e) => setSearchInput(e.target.value)}
                  InputProps={{
                    startAdornment: (
                      <InputAdornment position="start">
                        <SearchIcon fontSize="small" color="action" />
                      </InputAdornment>
                    ),
                  }}
                />
                <TextField
                  select
                  size="small"
                  value={deptFilter}
                  onChange={(e) => setDeptFilter(e.target.value)}
                  SelectProps={{ displayEmpty: true }}
                  sx={{ minWidth: { xs: '100%', sm: 220 } }}
                >
                  <MenuItem value="">Tất cả phòng ban</MenuItem>
                  {departments.map((d) => (
                    <MenuItem key={d.id} value={d.name}>
                      {d.name}
                    </MenuItem>
                  ))}
                </TextField>
              </Stack>
              {listError && <Alert severity="error">{listError}</Alert>}
              <Box
                sx={{
                  border: `1px solid ${theme.palette.divider}`,
                  borderRadius: 2,
                  maxHeight: 320,
                  overflowY: 'auto',
                }}
              >
                {loadingList ? (
                  <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
                    <CircularProgress size={28} />
                  </Box>
                ) : candidates.length === 0 ? (
                  <Box sx={{ p: 3, textAlign: 'center' }}>
                    <Typography variant="body2" color="text.secondary">
                      Không có nhân sự phù hợp — hoặc tất cả đã có tài khoản.
                    </Typography>
                  </Box>
                ) : (
                  <List disablePadding>
                    {candidates.map((c, idx) => (
                      <Box key={c.id}>
                        <ListItemButton onClick={() => setSelected(c)} sx={{ py: 1.25, px: 2 }}>
                          <Stack
                            direction="row"
                            justifyContent="space-between"
                            alignItems="center"
                            sx={{ width: '100%' }}
                          >
                            <Box>
                              <Typography variant="body2" fontWeight={600}>
                                {c.name}
                              </Typography>
                              <Typography variant="caption" color="text.secondary">
                                Mã NV: {c.id}
                                {c.dept ? ` · ${c.dept}` : ''}
                              </Typography>
                            </Box>
                            {c.phone && (
                              <Chip
                                size="small"
                                label={c.phone}
                                sx={{ bgcolor: alpha(theme.palette.primary.main, 0.08), fontWeight: 600 }}
                              />
                            )}
                          </Stack>
                        </ListItemButton>
                        {idx < candidates.length - 1 && <Divider component="li" />}
                      </Box>
                    ))}
                  </List>
                )}
              </Box>
            </>
          ) : (
            <>
              <Box
                sx={{
                  p: 1.5,
                  borderRadius: 2,
                  bgcolor: alpha(theme.palette.success.main, 0.08),
                  border: `1px solid ${alpha(theme.palette.success.main, 0.3)}`,
                }}
              >
                <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                  <Box>
                    <Typography
                      variant="caption"
                      sx={{ fontWeight: 700, letterSpacing: 0.5, color: theme.palette.success.dark }}
                    >
                      NHÂN SỰ ĐƯỢC CHỌN
                    </Typography>
                    <Typography variant="subtitle2" fontWeight={700}>
                      {selected.name}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      Mã NV: {selected.id}
                      {selected.dept ? ` · ${selected.dept}` : ''}
                    </Typography>
                  </Box>
                  <Button
                    size="small"
                    color="error"
                    onClick={() => setSelected(null)}
                    sx={{ minWidth: 0, whiteSpace: 'nowrap' }}
                  >
                    Đổi nhân sự
                  </Button>
                </Stack>
              </Box>

              {formError && <Alert severity="error">{formError}</Alert>}

              <TextField
                fullWidth
                size="small"
                type="password"
                required
                label="Mật khẩu đăng nhập"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                InputProps={{
                  startAdornment: (
                    <InputAdornment position="start">
                      <KeyIcon fontSize="small" color="action" />
                    </InputAdornment>
                  ),
                }}
              />

              <TextField
                select
                fullWidth
                size="small"
                label="Chức danh HRM"
                value={hrmRoleCode}
                onChange={(e) => setHrmRoleCode(e.target.value)}
                helperText="Vai trò trong phần mềm HRM (6 chức danh)"
              >
                {hrmRoles.map((r) => (
                  <MenuItem key={r.roleCode} value={r.roleCode}>
                    {r.roleName || getRoleLabel(r.roleCode)}
                  </MenuItem>
                ))}
              </TextField>

              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                <TextField
                  select
                  fullWidth
                  size="small"
                  label="Vai trò ERP"
                  value={roleId}
                  onChange={(e) => setRoleId(Number(e.target.value))}
                >
                  {ERP_ROLE_OPTIONS.map((o) => (
                    <MenuItem key={o.value} value={o.value}>
                      {o.label}
                    </MenuItem>
                  ))}
                </TextField>
                <TextField
                  select
                  fullWidth
                  size="small"
                  label="Vai trò Tài sản"
                  value={roleIdTs}
                  onChange={(e) => setRoleIdTs(Number(e.target.value))}
                >
                  {ASSET_ROLE_OPTIONS.map((o) => (
                    <MenuItem key={o.value} value={o.value}>
                      {o.label}
                    </MenuItem>
                  ))}
                </TextField>
              </Stack>
            </>
          )}
        </Stack>
      </DialogContent>
      <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 1.5, px: 3, pb: 2.5, pt: 1 }}>
        <Button onClick={onClose} disabled={submitting}>
          Hủy
        </Button>
        {selected && (
          <Button
            variant="contained"
            color="success"
            onClick={handleSubmit}
            disabled={submitting || !password.trim()}
          >
            {submitting ? 'Đang cấp...' : 'Cấp tài khoản'}
          </Button>
        )}
      </Box>
    </Dialog>
  );
}
