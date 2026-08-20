import CloseIcon from '@mui/icons-material/Close';
import PhoneIcon from '@mui/icons-material/Phone';
import SearchIcon from '@mui/icons-material/Search';
import KeyIcon from '@mui/icons-material/VpnKey';
import BadgeOutlinedIcon from '@mui/icons-material/BadgeOutlined';
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
  Grid,
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
  { roleId: 0, appCode: 'HRM', roleCode: 'HR2', roleName: 'Hành chính nhân sự 2', active: true },
  { roleId: 0, appCode: 'HRM', roleCode: 'HEAD_DEPARTMENT', roleName: 'Trưởng khoa / Điều dưỡng trưởng', active: true },
  { roleId: 0, appCode: 'HRM', roleCode: 'HEAD_HR', roleName: 'Trưởng phòng HCNS', active: true },
  { roleId: 0, appCode: 'HRM', roleCode: 'HEAD_NURSING', roleName: 'Trưởng phòng Điều dưỡng', active: true },
  { roleId: 0, appCode: 'HRM', roleCode: 'DIRECTOR', roleName: 'Giám đốc', active: true },
];

function unifiedHrmRoles(roles: ssoAccountService.SsoRoleCatalog[]) {
  const byCode = new Map<string, ssoAccountService.SsoRoleCatalog>();
  for (const role of roles) {
    byCode.set(role.roleCode, {
      ...role,
      roleName:
        role.roleCode === 'HEAD_NURSING'
          ? 'Trưởng phòng Điều dưỡng'
          : role.roleCode === 'HEAD_HR'
            ? 'Trưởng phòng HCNS'
            : role.roleCode === 'HEAD_DEPARTMENT'
            ? 'Trưởng khoa / Điều dưỡng trưởng'
            : role.roleName,
    });
  }
  return [...byCode.values()];
}

type Props = {
  open: boolean;
  onClose: () => void;
  onSuccess: (message: string) => void;
};

const STAFF_GROUP_OPTIONS = [
  { value: '', label: 'Tất cả nhân sự' },
  { value: 'TRIAL', label: 'Thử việc / thực tập' },
  { value: 'OFFICIAL_TTG', label: 'Chính thức TTG' },
  { value: 'OFFICIAL_BTG', label: 'Chính thức BTG' },
  { value: 'OFFICIAL', label: 'Chính thức (TTG + BTG)' },
] as const;

function isTrialCandidate(c: ssoAccountService.EmployeeAccountCandidate): boolean {
  if (c.employeeStatus === 'PROBATION' || c.employeeStatus === 'INTERN') return true;
  return (c.employeeCode ?? '').toUpperCase().startsWith('TV-');
}

function employmentChip(c: ssoAccountService.EmployeeAccountCandidate) {
  if (isTrialCandidate(c)) return null;
  if (c.employmentType === 'PART_TIME') {
    return <Chip size="small" color="secondary" label="BTG" sx={{ height: 22, fontWeight: 600 }} />;
  }
  return <Chip size="small" variant="outlined" label="TTG" sx={{ height: 22, fontWeight: 600 }} />;
}

function candidateCodeLabel(c: ssoAccountService.EmployeeAccountCandidate): string {
  if (c.employeeCode?.trim()) return c.employeeCode.trim();
  return String(c.id);
}

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
  const [trialGroupFilter, setTrialGroupFilter] = useState('');
  const [candidates, setCandidates] = useState<ssoAccountService.EmployeeAccountCandidate[]>([]);
  const [loadingList, setLoadingList] = useState(false);
  const [listError, setListError] = useState<string | null>(null);

  const [selected, setSelected] = useState<ssoAccountService.EmployeeAccountCandidate | null>(null);
  const [phone, setPhone] = useState('');
  const [attendanceCode, setAttendanceCode] = useState('');
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
    setTrialGroupFilter('');
    setCandidates([]);
    setSelected(null);
    setPhone('');
    setAttendanceCode('');
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
        if (roles.length > 0) setHrmRoles(unifiedHrmRoles(roles));
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
      .fetchEmployeesWithoutAccount({
        search,
        dept: deptFilter || undefined,
        trialGroup: trialGroupFilter || undefined,
        limit: 100,
      })
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
  }, [open, search, deptFilter, trialGroupFilter, selected]);

  function selectCandidate(c: ssoAccountService.EmployeeAccountCandidate) {
    setSelected(c);
    setPhone(c.phone?.trim() || '');
    setAttendanceCode(c.attendanceCode?.trim() || '');
    setFormError(null);
  }

  async function handleSubmit() {
    if (!selected || !password.trim()) return;
    if (!phone.trim()) {
      setFormError('Nhập số điện thoại — sẽ lưu vào hồ sơ HRM và dùng làm tài khoản đăng nhập.');
      return;
    }
    if (!attendanceCode.trim()) {
      setFormError('Nhập mã chấm công — lưu vào HRM để NV xem được số công.');
      return;
    }
    setSubmitting(true);
    setFormError(null);
    try {
      const result = await ssoAccountService.grantEmployeeAccount(selected.id, {
        phone: phone.trim(),
        attendanceCode: attendanceCode.trim(),
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
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth scroll="paper">
      <DialogTitle sx={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', pb: 0.5, px: { xs: 2, sm: 3 } }}>
        <Box>
          <Typography variant="h6" fontWeight={700}>
            Cấp tài khoản mới
          </Typography>
          <Typography variant="body2" color="text.secondary">
            Chọn nhân sự chưa có TK (gồm NV thử việc TV-). Nhập SĐT + mã chấm công — lưu HRM, dùng SSO đăng nhập
            (MK mặc định 123).
          </Typography>
        </Box>
        <IconButton onClick={onClose} size="small">
          <CloseIcon fontSize="small" />
        </IconButton>
      </DialogTitle>
      <DialogContent sx={{ pt: 1, px: { xs: 2, sm: 3 } }}>
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
                  value={trialGroupFilter}
                  onChange={(e) => setTrialGroupFilter(e.target.value)}
                  SelectProps={{ displayEmpty: true }}
                  sx={{ minWidth: { xs: '100%', sm: 240 } }}
                >
                  {STAFF_GROUP_OPTIONS.map((o) => (
                    <MenuItem key={o.value || 'all'} value={o.value}>
                      {o.label}
                    </MenuItem>
                  ))}
                </TextField>
                <TextField
                  select
                  size="small"
                  value={deptFilter}
                  onChange={(e) => setDeptFilter(e.target.value)}
                  SelectProps={{ displayEmpty: true }}
                  sx={{ minWidth: { xs: '100%', sm: 260 } }}
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
                  maxHeight: 440,
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
                        <ListItemButton onClick={() => selectCandidate(c)} sx={{ py: 1.5, px: 2.5 }}>
                          <Stack
                            direction={{ xs: 'column', sm: 'row' }}
                            spacing={1.25}
                            alignItems={{ xs: 'stretch', sm: 'flex-start' }}
                            justifyContent="space-between"
                            sx={{ width: '100%' }}
                          >
                            <Box sx={{ minWidth: 0, flex: 1 }}>
                              <Stack direction="row" spacing={0.75} alignItems="center" flexWrap="wrap" useFlexGap>
                                <Typography variant="body2" fontWeight={600}>
                                  {c.name}
                                </Typography>
                                {isTrialCandidate(c) && (
                                  <Chip size="small" color="info" label="Thử việc" sx={{ height: 22, fontWeight: 600 }} />
                                )}
                                {employmentChip(c)}
                              </Stack>
                              <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 0.35 }}>
                                Mã: {candidateCodeLabel(c)}
                                {c.attendanceCode ? ` · CC: ${c.attendanceCode}` : ' · Chưa có mã chấm công'}
                                {c.dept ? ` · ${c.dept}` : ''}
                              </Typography>
                            </Box>
                            <Stack
                              direction="row"
                              spacing={0.75}
                              flexWrap="wrap"
                              useFlexGap
                              justifyContent={{ xs: 'flex-start', sm: 'flex-end' }}
                              sx={{ flexShrink: 0, maxWidth: { sm: 360 } }}
                            >
                              {c.missingAttendanceCode ? (
                                <Chip size="small" color="warning" label="Chưa có mã CC" sx={{ fontWeight: 600 }} />
                              ) : null}
                              {c.missingPhone ? (
                                <Chip
                                  size="small"
                                  color="warning"
                                  label="Chưa có SĐT — nhấn để nhập"
                                  sx={{ fontWeight: 600 }}
                                />
                              ) : c.phone ? (
                                <Chip
                                  size="small"
                                  label={c.phone}
                                  sx={{ bgcolor: alpha(theme.palette.primary.main, 0.08), fontWeight: 600 }}
                                />
                              ) : null}
                            </Stack>
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
                      Mã: {candidateCodeLabel(selected)}
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

              {selected.missingAttendanceCode && (
                <Alert severity="warning">
                  Nhân viên chưa có mã chấm công — nhập bên dưới để đồng bộ công và SSO (UserEnrollNumber).
                </Alert>
              )}

              {selected.missingPhone && (
                <Alert severity="info">
                  Nhân viên chưa có SĐT — nhập bên dưới, hệ thống sẽ lưu vào hồ sơ HRM rồi tạo tài khoản.
                </Alert>
              )}

              <Grid container spacing={2}>
                <Grid item xs={12} sm={6}>
                  <TextField
                    fullWidth
                    size="small"
                    required
                    label="Mã chấm công"
                    placeholder="vd: 1234 hoặc 01234"
                    helperText="Lưu HRM — NV xem công; SSO = UserEnrollNumber"
                    value={attendanceCode}
                    onChange={(e) => setAttendanceCode(e.target.value)}
                    InputProps={{
                      startAdornment: (
                        <InputAdornment position="start">
                          <BadgeOutlinedIcon fontSize="small" color="action" />
                        </InputAdornment>
                      ),
                    }}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <TextField
                    fullWidth
                    size="small"
                    required
                    label="Số điện thoại (tài khoản đăng nhập)"
                    placeholder="0912345678"
                    helperText="Lưu HRM — dùng làm LoginPhone SSO"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    InputProps={{
                      startAdornment: (
                        <InputAdornment position="start">
                          <PhoneIcon fontSize="small" color="action" />
                        </InputAdornment>
                      ),
                    }}
                  />
                </Grid>
                <Grid item xs={12} sm={6}>
                  <TextField
                    fullWidth
                    size="small"
                    type="password"
                    required
                    label="Mật khẩu đăng nhập"
                    helperText="Mặc định 123"
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
                </Grid>
                <Grid item xs={12} sm={6}>
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
                </Grid>
                <Grid item xs={12} sm={6}>
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
                </Grid>
                <Grid item xs={12} sm={6}>
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
                </Grid>
              </Grid>
            </>
          )}
        </Stack>
      </DialogContent>
      <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 1.5, px: { xs: 2, sm: 3 }, pb: 2.5, pt: 1 }}>
        <Button onClick={onClose} disabled={submitting}>
          Hủy
        </Button>
        {selected && (
          <Button
            variant="contained"
            color="success"
            onClick={handleSubmit}
            disabled={submitting || !password.trim() || !phone.trim() || !attendanceCode.trim()}
          >
            {submitting ? 'Đang cấp...' : 'Cấp tài khoản'}
          </Button>
        )}
      </Box>
    </Dialog>
  );
}
