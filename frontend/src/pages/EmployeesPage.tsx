import CheckCircleOutlineIcon from '@mui/icons-material/CheckCircleOutline';
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import DeleteForeverIcon from '@mui/icons-material/DeleteForever';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline';
import DownloadIcon from '@mui/icons-material/Download';
import EditIcon from '@mui/icons-material/Edit';
import PersonAddIcon from '@mui/icons-material/PersonAdd';
import PictureAsPdfIcon from '@mui/icons-material/PictureAsPdf';
import SwapHorizIcon from '@mui/icons-material/SwapHoriz';
import SchoolOutlinedIcon from '@mui/icons-material/SchoolOutlined';
import GroupsOutlinedIcon from '@mui/icons-material/GroupsOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import VisibilityIcon from '@mui/icons-material/Visibility';
import WarningAmberIcon from '@mui/icons-material/WarningAmber';
import {
  Alert,
  Backdrop,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  IconButton,
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
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { EmployeeFormDialog } from '../components/EmployeeFormDialog';
import { EmployeeStatusChip } from '../components/EmployeeStatusChip';
import { MaternityLeaveChip } from '../components/MaternityLeaveChip';
import { TrainingOnChip } from '../components/TrainingOnChip';
import { PageHeader } from '../components/layout/PageHeader';
import { DepartmentTransferDialog } from '../components/DepartmentTransferDialog';
import { ProbationConversionDialog } from '../components/ProbationConversionDialog';
import { TrainingProposalDialog } from '../components/TrainingProposalDialog';
import { TrainingProposalDetailDialog } from '../components/TrainingProposalDetailDialog';
import { SeminarProposalDialog } from '../components/SeminarProposalDialog';
import { MainDutyAuthorizationDialog } from '../components/MainDutyAuthorizationDialog';
import { WorkforceImportDialog } from '../components/WorkforceImportDialog';
import { AccompanyingDutyImportDialog } from '../components/AccompanyingDutyImportDialog';
import { useAuth } from '../context/AuthContext';
import * as documentService from '../services/documentService';
import * as departmentService from '../services/departmentService';
import * as employeeService from '../services/employeeService';
import * as importService from '../services/importService';
import * as tps from '../services/trainingProposalService';
import { formatDateVi } from '../utils/dateFormat';
import { isNursingBlockTitle } from '../utils/nursingBlock';
import { isHeadDepartmentRole, isHr2Role } from '../utils/roleAccess';

type StatusTab = employeeService.EmployeeStatusGroup;

const CATEGORY_META: Record<
  StatusTab,
  { title: string; description: string }
> = {
  WORKING: {
    title: 'Nhân viên đang làm việc',
    description: 'Danh sách nhân viên đang làm việc và nghỉ phép tạm.',
  },
  OFFICIAL: {
    title: 'Nhân viên chính thức',
    description: 'Danh sách nhân viên đang làm việc chính thức và nghỉ phép tạm.',
  },
  TRIAL: {
    title: 'Thử việc / Thực tập',
    description: 'Theo dõi thời gian thử việc, cảnh báo quá 3 tháng và chuyển chính thức.',
  },
  TERMINATED: {
    title: 'Nhân viên nghỉ việc',
    description: 'Hồ sơ nhân viên đã nghỉ việc — tra cứu và quản lý lưu trữ.',
  },
};

function categoryFromPath(pathname: string): StatusTab {
  if (pathname.includes('/employees/trial')) return 'TRIAL';
  if (pathname.includes('/employees/terminated')) return 'TERMINATED';
  return 'OFFICIAL';
}

function formatDate(iso?: string | null) {
  return formatDateVi(iso);
}

export default function EmployeesPage() {
  const theme = useTheme();
  const location = useLocation();
  const { user } = useAuth();
  const statusTab = useMemo(() => categoryFromPath(location.pathname), [location.pathname]);
  const categoryMeta = CATEGORY_META[statusTab];
  const isHrOrAdmin = user?.role === 'ADMIN' || user?.role === 'HR';
  const isHeadRole = isHeadDepartmentRole(user?.role);
  const isNursingHead = user?.role === 'HEAD_NURSING';
  /** ADMIN và HCNS 1 được import, thêm, sửa và xóa hồ sơ nhân viên. */
  const canManageStaff = isHrOrAdmin;
  const ownDepartmentId = user?.departmentId ?? null;
  const deptFilterLocked = isHeadRole && !isHrOrAdmin && !isHr2Role(user?.role) && ownDepartmentId != null;
  const canCreateConversion =
    user?.role === 'ADMIN' || isHeadDepartmentRole(user?.role);
  const canCreateTrainingProposal = canCreateConversion;
  const canCreateSeminarProposal = canCreateConversion;
  const canCreateMainDutyAuthorization = canCreateConversion;
  const [page, setPage] = useState(0);
  const [rows, setRows] = useState<employeeService.EmployeeSummary[]>([]);
  const [total, setTotal] = useState(0);
  const [size, setSize] = useState(10);
  const [importOpen, setImportOpen] = useState(false);
  const [accompanyingImportOpen, setAccompanyingImportOpen] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [transferTarget, setTransferTarget] = useState<{
    id: number;
    fullName: string;
    departmentName?: string;
  } | null>(null);
  const [listVersion, setListVersion] = useState(0);

  const [qInput, setQInput] = useState('');
  const [q, setQ] = useState('');
  const [filterDept, setFilterDept] = useState<number | ''>('');
  const [filterWorkUnit, setFilterWorkUnit] = useState('');
  const [filterWork, setFilterWork] = useState<employeeService.OfficialWorkFilter | ''>('');
  const [departments, setDepartments] = useState<employeeService.DepartmentOption[]>([]);
  const [allWorkUnits, setAllWorkUnits] = useState<departmentService.WorkUnitRow[]>([]);

  const [formOpen, setFormOpen] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');
  const [editEmployeeId, setEditEmployeeId] = useState<number | undefined>();

  const [terminateTarget, setTerminateTarget] = useState<{ id: number; name: string } | null>(null);
  const [terminating, setTerminating] = useState(false);

  const [purgeTarget, setPurgeTarget] = useState<{ id: number; name: string } | null>(null);
  const [purging, setPurging] = useState(false);

  const [confirmTarget, setConfirmTarget] = useState<{
    id: number;
    fullName: string;
    departmentName?: string;
    positionTitle?: string;
    status?: string;
  } | null>(null);
  const [trainingTarget, setTrainingTarget] = useState<{
    id: number;
    fullName: string;
    departmentName?: string;
    positionTitle?: string;
  } | null>(null);
  const [trainingViewId, setTrainingViewId] = useState<number | null>(null);
  const [trainingViewLoading, setTrainingViewLoading] = useState(false);
  const [seminarTarget, setSeminarTarget] = useState<{
    id: number;
    fullName: string;
    departmentName?: string;
    positionTitle?: string;
  } | null>(null);
  const [mainDutyTarget, setMainDutyTarget] = useState<{
    id: number;
    fullName: string;
    departmentName?: string;
    positionTitle?: string;
  } | null>(null);

  const [replaceDialogEmployeeId, setReplaceDialogEmployeeId] = useState<number | null>(null);
  const [pdfLoadingId, setPdfLoadingId] = useState<number | null>(null);
  const [uploading, setUploading] = useState(false);
  const [snackbar, setSnackbar] = useState<{ open: boolean; message: string }>({ open: false, message: '' });

  const pdfTargetRef = useRef<{ employeeId: number; replace: boolean } | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const isTrialTab = statusTab === 'TRIAL';
  const isTerminatedTab = statusTab === 'TERMINATED';
  const isOfficialTab = statusTab === 'OFFICIAL';
  const overdueCount = rows.filter((r) => r.probationOverdue).length;

  useEffect(() => {
    const t = setTimeout(() => {
      setQ(qInput);
      setPage(0);
    }, 400);
    return () => clearTimeout(t);
  }, [qInput]);

  useEffect(() => {
    setPage(0);
    setFilterWork('');
    setFilterWorkUnit('');
  }, [statusTab]);

  const workUnitOptions = useMemo(() => {
    const scoped =
      filterDept === ''
        ? allWorkUnits
        : allWorkUnits.filter((u) => u.departmentId === filterDept);
    const names = Array.from(new Set(scoped.map((u) => u.name).filter(Boolean)));
    names.sort((a, b) => a.localeCompare(b, 'vi'));
    return names;
  }, [allWorkUnits, filterDept]);

  useEffect(() => {
    if (filterWorkUnit && !workUnitOptions.includes(filterWorkUnit)) {
      setFilterWorkUnit('');
    }
  }, [workUnitOptions, filterWorkUnit]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const data = await employeeService.fetchEmployees({
          page,
          size,
          q: q.trim() || undefined,
          departmentId: filterDept === '' ? undefined : filterDept,
          workUnit: filterWorkUnit.trim() || undefined,
          statusGroup: statusTab,
          officialWorkFilter: isOfficialTab && filterWork ? filterWork : undefined,
        });
        if (!cancelled) {
          setRows(data.content);
          setTotal(data.totalElements);
        }
      } catch (e: unknown) {
        if (cancelled) return;
        setRows([]);
        setTotal(0);
        const msg =
          (e as { response?: { data?: { message?: string } } })?.response?.data?.message ||
          'Không tải được danh sách nhân viên';
        setSnackbar({ open: true, message: msg });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [page, size, listVersion, q, filterDept, filterWorkUnit, statusTab, filterWork, isOfficialTab]);

  useEffect(() => {
    if (deptFilterLocked && ownDepartmentId != null) {
      setFilterDept(ownDepartmentId);
    }
  }, [deptFilterLocked, ownDepartmentId]);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      let rows: employeeService.DepartmentOption[] = [];
      try {
        rows = await employeeService.fetchDepartments();
      } catch {
        /* fallback below */
      }
      if (rows.length === 0 && isNursingHead) {
        try {
          const stats = await employeeService.fetchNursingDashboardStats();
          rows = (stats.byDepartment ?? [])
            .filter((d) => d.departmentId != null && d.departmentName?.trim())
            .map((d) => ({
              id: Number(d.departmentId),
              code: `DEPT-${d.departmentId}`,
              name: d.departmentName.trim(),
            }))
            .sort((a, b) => a.name.localeCompare(b.name, 'vi'));
        } catch {
          /* keep empty */
        }
      }
      if (!cancelled) setDepartments(rows);
    })();
    departmentService.fetchAllWorkUnits().then(setAllWorkUnits).catch(() => setAllWorkUnits([]));
    return () => {
      cancelled = true;
    };
  }, [isNursingHead]);

  function openCreate() {
    setFormMode('create');
    setEditEmployeeId(undefined);
    setFormOpen(true);
  }

  function openEdit(id: number) {
    setFormMode('edit');
    setEditEmployeeId(id);
    setFormOpen(true);
  }

  async function confirmPurge() {
    if (!purgeTarget) return;
    setPurging(true);
    try {
      await employeeService.permanentlyDeleteEmployee(purgeTarget.id);
      setSnackbar({ open: true, message: 'Đã xóa hồ sơ nhân viên.' });
      setPurgeTarget(null);
      setListVersion((v) => v + 1);
    } catch {
      setSnackbar({ open: true, message: 'Không xóa được hồ sơ nhân viên.' });
    } finally {
      setPurging(false);
    }
  }

  async function confirmTerminate() {
    if (!terminateTarget) return;
    setTerminating(true);
    try {
      await employeeService.deleteEmployee(terminateTarget.id);
      setSnackbar({ open: true, message: 'Đã cập nhật trạng thái nghỉ việc.' });
      setTerminateTarget(null);
      setListVersion((v) => v + 1);
    } catch {
      setSnackbar({ open: true, message: 'Không cập nhật được trạng thái.' });
    } finally {
      setTerminating(false);
    }
  }

  async function handlePdfClick(employeeId: number) {
    setPdfLoadingId(employeeId);
    try {
      const docs = await documentService.fetchDocuments(employeeId);
      if (docs.length > 0) {
        setReplaceDialogEmployeeId(employeeId);
      } else {
        pdfTargetRef.current = { employeeId, replace: false };
        fileInputRef.current?.click();
      }
    } catch {
      setSnackbar({ open: true, message: 'Không kiểm tra được tài liệu đính kèm.' });
    } finally {
      setPdfLoadingId(null);
    }
  }

  function handleReplaceConfirm() {
    const id = replaceDialogEmployeeId;
    setReplaceDialogEmployeeId(null);
    if (id != null) {
      pdfTargetRef.current = { employeeId: id, replace: true };
      fileInputRef.current?.click();
    }
  }

  function handleReplaceCancel() {
    setReplaceDialogEmployeeId(null);
  }

  async function handleFileSelected(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    const target = pdfTargetRef.current;
    e.target.value = '';
    pdfTargetRef.current = null;
    if (!file || !target) return;

    setUploading(true);
    try {
      if (target.replace) {
        await documentService.deleteAllEmployeeDocuments(target.employeeId);
      }
      await documentService.uploadEmployeePdf(target.employeeId, file);
      setSnackbar({ open: true, message: 'Đã đính kèm PDF thành công.' });
    } catch {
      setSnackbar({ open: true, message: 'Upload PDF thất bại. Chỉ chấp nhận file .pdf.' });
    } finally {
      setUploading(false);
    }
  }

  return (
    <Box>
      <input
        ref={fileInputRef}
        type="file"
        hidden
        accept="application/pdf,.pdf"
        onChange={handleFileSelected}
      />

      <EmployeeFormDialog
        open={formOpen}
        onClose={() => setFormOpen(false)}
        mode={formMode}
        employeeId={editEmployeeId}
        onSuccess={() => setListVersion((v) => v + 1)}
        defaultStatus={
          isTrialTab ? 'PROBATION' : isTerminatedTab ? 'TERMINATED' : 'ACTIVE'
        }
        allowedCreateStatuses={
          isTrialTab
            ? ['PROBATION', 'INTERN']
            : isTerminatedTab
              ? ['TERMINATED']
              : ['ACTIVE', 'ON_LEAVE']
        }
      />

      <Dialog open={replaceDialogEmployeeId != null} onClose={handleReplaceCancel} maxWidth="xs" fullWidth>
        <DialogTitle>Thay thế hồ sơ PDF?</DialogTitle>
        <DialogContent>
          <Typography variant="body2" color="text.secondary">
            Nhân viên đã có hồ sơ. Bạn có muốn thay thế?
          </Typography>
        </DialogContent>
        <DialogActions sx={{ px: 3, pb: 2 }}>
          <Button onClick={handleReplaceCancel}>Không</Button>
          <Button variant="contained" onClick={handleReplaceConfirm}>
            Có
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={purgeTarget != null} onClose={() => !purging && setPurgeTarget(null)}>
        <DialogTitle>Xóa hồ sơ vĩnh viễn</DialogTitle>
        <DialogContent>
          <Typography variant="body2">
            Xóa hoàn toàn hồ sơ <strong>{purgeTarget?.name}</strong>? Thao tác này không thể hoàn tác — tài khoản,
            tài liệu và dữ liệu liên quan sẽ bị xóa.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setPurgeTarget(null)} disabled={purging}>
            Hủy
          </Button>
          <Button color="error" variant="contained" onClick={confirmPurge} disabled={purging}>
            {purging ? 'Đang xử lý…' : 'Xóa vĩnh viễn'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={terminateTarget != null} onClose={() => !terminating && setTerminateTarget(null)}>
        <DialogTitle>Xác nhận nghỉ việc</DialogTitle>
        <DialogContent>
          <Typography variant="body2">
            Ghi nhận nghỉ việc cho <strong>{terminateTarget?.name}</strong>? Tài khoản sẽ bị khóa; SĐT, CCCD và
            tên đăng nhập được giải phóng để có thể tạo lại hồ sơ mới nếu cần.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setTerminateTarget(null)} disabled={terminating}>
            Hủy
          </Button>
          <Button color="error" variant="contained" onClick={confirmTerminate} disabled={terminating}>
            {terminating ? 'Đang xử lý…' : 'Nghỉ việc'}
          </Button>
        </DialogActions>
      </Dialog>

      <ProbationConversionDialog
        open={confirmTarget != null}
        employee={confirmTarget}
        onClose={() => setConfirmTarget(null)}
        onSubmitted={() => {
          setSnackbar({
            open: true,
            message: isNursingBlockTitle(confirmTarget?.positionTitle)
              ? 'Đã gửi đơn đề nghị ký HĐLĐ chính thức — chờ Trưởng phòng Điều dưỡng duyệt.'
              : 'Đã gửi đơn đề nghị ký HĐLĐ chính thức — chờ HCNS xử lý.',
          });
          setListVersion((v) => v + 1);
        }}
      />

      <TrainingProposalDialog
        open={trainingTarget != null}
        employee={trainingTarget}
        onClose={() => setTrainingTarget(null)}
        onSubmitted={() => {
          setSnackbar({
            open: true,
            message: 'Đã gửi phiếu đề xuất đào tạo — chờ HCNS duyệt.',
          });
          setListVersion((v) => v + 1);
        }}
      />

      <TrainingProposalDetailDialog
        open={trainingViewId != null}
        proposalId={trainingViewId}
        onClose={() => setTrainingViewId(null)}
        canComplete={canCreateTrainingProposal || isHrOrAdmin}
        onChanged={() => {
          setListVersion((v) => v + 1);
          setSnackbar({
            open: true,
            message: 'Đã cập nhật phiếu đào tạo.',
          });
        }}
      />

      <SeminarProposalDialog
        open={seminarTarget != null}
        employee={seminarTarget}
        onClose={() => setSeminarTarget(null)}
        onSubmitted={() => {
          setSnackbar({
            open: true,
            message: 'Đã gửi phiếu đề xuất hội thảo — chờ Giám đốc duyệt.',
          });
        }}
      />

      <MainDutyAuthorizationDialog
        open={mainDutyTarget != null}
        employee={mainDutyTarget}
        onClose={() => setMainDutyTarget(null)}
        onSubmitted={() => {
          setSnackbar({
            open: true,
            message: isNursingBlockTitle(mainDutyTarget?.positionTitle)
              ? 'Đã gửi đơn trực chính — chờ Trưởng phòng Điều dưỡng duyệt.'
              : 'Đã gửi đơn trực chính — chờ Giám đốc duyệt.',
          });
          setListVersion((v) => v + 1);
        }}
      />

      <Backdrop sx={{ color: '#fff', zIndex: (t) => t.zIndex.drawer + 1 }} open={uploading}>
        <CircularProgress color="inherit" />
      </Backdrop>

      <Snackbar
        open={snackbar.open}
        autoHideDuration={5000}
        onClose={() => setSnackbar((s) => ({ ...s, open: false }))}
        message={snackbar.message}
      />

      <PageHeader
        overline="Nhân sự"
        title={categoryMeta.title}
        description={
          isNursingHead
            ? 'Chỉ xem nhân sự khối Điều dưỡng – KTV – Hộ sinh – Thư ký y khoa (toàn viện). Không thêm/sửa hồ sơ.'
            : isTrialTab && canCreateConversion && !isHrOrAdmin
              ? 'Lập đơn đề nghị chuyển nhân viên thử việc / thực tập lên chính thức. Khối ĐD–KTV–HS–Thư ký: Trưởng phòng ĐD → HCNS → Giám đốc; còn lại: HCNS → Giám đốc.'
              : categoryMeta.description
        }
        actions={
          canManageStaff ? (
            <>
              <Button variant="outlined" startIcon={<PersonAddIcon />} onClick={openCreate}>
                Thêm nhân viên
              </Button>
              {isHrOrAdmin && (
                <>
                  <Button
                    variant="outlined"
                    startIcon={exporting ? <CircularProgress size={16} color="inherit" /> : <DownloadIcon />}
                    disabled={exporting}
                    onClick={async () => {
                      setExporting(true);
                      try {
                        await importService.downloadWorkforceExcel();
                        setSnackbar({ open: true, message: 'Đã tải file Excel nhân lực.' });
                      } catch {
                        setSnackbar({ open: true, message: 'Xuất Excel thất bại. Kiểm tra quyền ADMIN/HCNS.' });
                      } finally {
                        setExporting(false);
                      }
                    }}
                  >
                    Xuất Excel
                  </Button>
                  <Button variant="contained" startIcon={<CloudUploadIcon />} onClick={() => setImportOpen(true)}>
                    Import Excel
                  </Button>
                  <Button
                    variant="outlined"
                    startIcon={<NightsStayIcon />}
                    onClick={() => setAccompanyingImportOpen(true)}
                  >
                    Import DS trực kèm
                  </Button>
                </>
              )}
            </>
          ) : undefined
        }
      />

      <WorkforceImportDialog
        open={importOpen}
        onClose={() => setImportOpen(false)}
        onImported={() => setListVersion((v) => v + 1)}
      />

      <AccompanyingDutyImportDialog
        open={accompanyingImportOpen}
        onClose={() => setAccompanyingImportOpen(false)}
        onImported={() => setListVersion((v) => v + 1)}
      />

      <DepartmentTransferDialog
        open={Boolean(transferTarget)}
        employee={transferTarget}
        onClose={() => setTransferTarget(null)}
        onSubmitted={() => {
          setSnackbar({ open: true, message: 'Đã gửi đề nghị luân chuyển cho Giám đốc duyệt.' });
          setListVersion((v) => v + 1);
        }}
      />

      {isOfficialTab && filterWork === 'MATERNITY_LEAVE' && total > 0 && (
        <Alert severity="info" sx={{ mb: 2 }}>
          Đang hiển thị <strong>{total}</strong> nhân viên nghỉ thai sản.
        </Alert>
      )}

      {isTrialTab && overdueCount > 0 && (
        <Alert severity="warning" icon={<WarningAmberIcon />} sx={{ mb: 2 }}>
          Có <strong>{overdueCount}</strong> nhân viên thử việc/thực tập quá 3 tháng — cần chuyển chính thức hoặc gia hạn.
        </Alert>
      )}

      <Paper
        elevation={0}
        sx={{
          p: 2.25,
          mb: 2.5,
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
          bgcolor: alpha(theme.palette.background.paper, 0.92),
          boxShadow: `0 4px 20px ${alpha('#0f172a', 0.04)}`,
        }}
      >
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} alignItems={{ xs: 'stretch', md: 'center' }}>
          <TextField
            size="small"
            label="Tìm theo tên, mã NV, username"
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
              setFilterWorkUnit('');
              setPage(0);
            }}
            disabled={deptFilterLocked}
            sx={{ minWidth: 200 }}
            helperText={deptFilterLocked ? 'Chỉ xem nhân lực khoa của bạn' : undefined}
          >
            {!deptFilterLocked && <MenuItem value="">Tất cả phòng ban</MenuItem>}
            {departments.map((d) => (
              <MenuItem key={d.id} value={d.id}>
                {d.name}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            size="small"
            select
            label="Bộ phận"
            value={filterWorkUnit}
            onChange={(e) => {
              setFilterWorkUnit(e.target.value);
              setPage(0);
            }}
            sx={{ minWidth: 200 }}
            helperText={
              filterDept !== '' && workUnitOptions.length === 0
                ? 'Phòng ban chưa có bộ phận'
                : undefined
            }
          >
            <MenuItem value="">Tất cả bộ phận</MenuItem>
            {workUnitOptions.map((name) => (
              <MenuItem key={name} value={name}>
                {name}
              </MenuItem>
            ))}
          </TextField>
          {isOfficialTab && (
            <TextField
              size="small"
              select
              label="Tình trạng làm việc"
              value={filterWork}
              onChange={(e) => {
                setFilterWork(e.target.value as employeeService.OfficialWorkFilter | '');
                setPage(0);
              }}
              sx={{ minWidth: 200 }}
            >
              <MenuItem value="">Tất cả</MenuItem>
              <MenuItem value="FULL_TIME">Toàn thời gian (TTG)</MenuItem>
              <MenuItem value="PART_TIME">Bán thời gian (BTG)</MenuItem>
              <MenuItem value="WORKING">Đang làm việc</MenuItem>
              <MenuItem value="MATERNITY_LEAVE">Nghỉ thai sản</MenuItem>
            </TextField>
          )}
          <Button
            size="small"
            onClick={() => {
              setQInput('');
              setFilterDept('');
              setFilterWorkUnit('');
              setFilterWork('');
              setPage(0);
            }}
          >
            Xóa bộ lọc
          </Button>
        </Stack>
      </Paper>

      <TableContainer
        component={Paper}
        elevation={0}
        sx={{
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.divider, 1)}`,
          overflowX: 'auto',
          overflowY: 'hidden',
          boxShadow: `0 4px 24px ${alpha('#0f172a', 0.05)}`,
        }}
      >
        <Table stickyHeader size="small" sx={{ minWidth: isTrialTab ? 1240 : 1120 }}>
          <TableHead>
            <TableRow>
              <TableCell>Mã NV</TableCell>
              <TableCell>Họ tên</TableCell>
              <TableCell>Phòng ban</TableCell>
              <TableCell>Bộ phận</TableCell>
              <TableCell>Chức vụ</TableCell>
              {isTrialTab && <TableCell>Ngày bắt đầu</TableCell>}
              {isTrialTab && <TableCell>Tháng TV</TableCell>}
              <TableCell>Trạng thái</TableCell>
              <TableCell align="right" sx={{ width: isTrialTab ? 344 : 320, whiteSpace: 'nowrap' }}>
                Thao tác
              </TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {rows.map((r) => (
              <TableRow
                key={r.id}
                hover
                sx={
                  r.probationOverdue
                    ? { bgcolor: alpha(theme.palette.warning.main, 0.08) }
                    : r.onTraining
                      ? { bgcolor: alpha('#eab308', 0.075) }
                      : r.maternityLeave
                        ? { bgcolor: alpha('#db2777', 0.07) }
                        : undefined
                }
              >
                <TableCell>{r.employeeCode || '—'}</TableCell>
                <TableCell>{r.fullName}</TableCell>
                <TableCell>{r.departmentName}</TableCell>
                <TableCell>{r.workUnitDetail?.trim() || '—'}</TableCell>
                <TableCell>{r.positionTitle}</TableCell>
                {isTrialTab && <TableCell>{formatDate(r.probationStartDate ?? r.hireDate)}</TableCell>}
                {isTrialTab && (
                  <TableCell>
                    {r.probationMonths != null ? (
                      <Stack direction="row" spacing={0.75} alignItems="center">
                        <span>{r.probationMonths}</span>
                        {r.probationOverdue && (
                          <Chip
                            label="Quá 3 tháng"
                            size="small"
                            variant="outlined"
                            sx={{
                              height: 22,
                              fontSize: '0.68rem',
                              fontWeight: 600,
                              color: '#b45309',
                              bgcolor: (t) => alpha(t.palette.warning.main, 0.08),
                              borderColor: (t) => alpha(t.palette.warning.main, 0.35),
                              borderRadius: '5px',
                              '& .MuiChip-label': { px: 0.75 },
                            }}
                          />
                        )}
                      </Stack>
                    ) : (
                      '—'
                    )}
                  </TableCell>
                )}
                <TableCell>
                  <Stack direction="row" spacing={0.75} alignItems="center" flexWrap="wrap" useFlexGap>
                    <EmployeeStatusChip status={r.status} />
                    {r.employmentType === 'PART_TIME' && (
                      <Chip size="small" label="BTG" color="secondary" variant="outlined" />
                    )}
                    {r.employmentType === 'FULL_TIME' && isOfficialTab && (
                      <Chip size="small" label="TTG" variant="outlined" />
                    )}
                    {r.onTraining && <TrainingOnChip />}
                    {r.maternityLeave && <MaternityLeaveChip />}
                    {!isTerminatedTab && (
                      <Chip
                        size="small"
                        label={r.mainDutyAuthorized ? 'Trực chính' : 'Trực kèm'}
                        variant="outlined"
                        color={r.mainDutyAuthorized ? 'primary' : 'warning'}
                        sx={{ height: 22, fontSize: '0.68rem', fontWeight: 600 }}
                      />
                    )}
                  </Stack>
                </TableCell>
                <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                  <Stack
                    direction="row"
                    spacing={0.25}
                    justifyContent="flex-end"
                    alignItems="center"
                    flexWrap="nowrap"
                    sx={{ width: 'max-content', ml: 'auto' }}
                  >
                    {isTrialTab && canCreateConversion && (
                      <Tooltip title="Lập đơn chuyển chính thức">
                        <IconButton
                          size="small"
                          color="success"
                          aria-label="Lập đơn chuyển chính thức"
                          onClick={() =>
                            setConfirmTarget({
                              id: r.id,
                              fullName: r.fullName,
                              departmentName: r.departmentName,
                              positionTitle: r.positionTitle,
                              status: r.status,
                            })
                          }
                        >
                          <CheckCircleOutlineIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    {canCreateTrainingProposal && !isTerminatedTab && (
                      <Tooltip
                        title={
                          r.onTraining
                            ? 'Xem phiếu đào tạo đang diễn ra'
                            : 'Đề xuất đi đào tạo, bồi dưỡng'
                        }
                      >
                        <span>
                          <IconButton
                            size="small"
                            color="info"
                            aria-label={r.onTraining ? 'Xem đào tạo' : 'Đề xuất đào tạo'}
                            disabled={trainingViewLoading}
                            onClick={async () => {
                              if (r.onTraining) {
                                setTrainingViewLoading(true);
                                try {
                                  const list = await tps.fetchTrainingProposalsByEmployee(r.id);
                                  const active =
                                    list.find((p) => p.status === 'APPROVED') ||
                                    list.find(
                                      (p) =>
                                        p.status === 'PENDING_HR' ||
                                        p.status === 'PENDING_DIRECTOR',
                                    ) ||
                                    list[0];
                                  if (!active) {
                                    setSnackbar({
                                      open: true,
                                      message: 'Không tìm thấy phiếu đào tạo của nhân viên này.',
                                    });
                                    return;
                                  }
                                  setTrainingViewId(active.id);
                                } catch {
                                  setSnackbar({
                                    open: true,
                                    message: 'Không tải được phiếu đào tạo.',
                                  });
                                } finally {
                                  setTrainingViewLoading(false);
                                }
                                return;
                              }
                              setTrainingTarget({
                                id: r.id,
                                fullName: r.fullName,
                                departmentName: r.departmentName,
                                positionTitle: r.positionTitle,
                              });
                            }}
                          >
                            <SchoolOutlinedIcon fontSize="small" />
                          </IconButton>
                        </span>
                      </Tooltip>
                    )}
                    {canCreateSeminarProposal && !isTerminatedTab && (
                      <Tooltip title="Đề xuất đi hội thảo">
                        <IconButton
                          size="small"
                          color="secondary"
                          aria-label="Đề xuất hội thảo"
                          onClick={() =>
                            setSeminarTarget({
                              id: r.id,
                              fullName: r.fullName,
                              departmentName: r.departmentName,
                              positionTitle: r.positionTitle,
                            })
                          }
                        >
                          <GroupsOutlinedIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    {canCreateMainDutyAuthorization && !isTerminatedTab && !r.mainDutyAuthorized && (
                      <Tooltip title="Lập đơn được trực chính">
                        <IconButton
                          size="small"
                          color="primary"
                          aria-label="Lập đơn trực chính"
                          onClick={() =>
                            setMainDutyTarget({
                              id: r.id,
                              fullName: r.fullName,
                              departmentName: r.departmentName,
                              positionTitle: r.positionTitle,
                            })
                          }
                        >
                          <NightsStayIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    {isTrialTab && canManageStaff && (
                      <Tooltip title="Nghỉ việc">
                        <IconButton
                          size="small"
                          color="error"
                          aria-label="Nghỉ việc"
                          onClick={() => setTerminateTarget({ id: r.id, name: r.fullName })}
                        >
                          <DeleteOutlineIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    <Tooltip title="Xem chi tiết">
                      <IconButton component={Link} to={`/employees/${r.id}`} size="small" color="primary" aria-label="Chi tiết">
                        <VisibilityIcon fontSize="small" />
                      </IconButton>
                    </Tooltip>
                    {canManageStaff && (
                      <Tooltip title="Sửa">
                        <IconButton size="small" color="primary" aria-label="Sửa" onClick={() => openEdit(r.id)}>
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    {isHrOrAdmin && !isTerminatedTab && (
                      <Tooltip title="Luân chuyển phòng ban">
                        <IconButton
                          size="small"
                          color="primary"
                          aria-label="Luân chuyển"
                          onClick={() =>
                            setTransferTarget({
                              id: r.id,
                              fullName: r.fullName,
                              departmentName: r.departmentName,
                            })
                          }
                        >
                          <SwapHorizIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    {canManageStaff && !isTrialTab && !isTerminatedTab && (
                      <Tooltip title="Nghỉ việc">
                        <IconButton
                          size="small"
                          color="error"
                          aria-label="Nghỉ việc"
                          onClick={() => setTerminateTarget({ id: r.id, name: r.fullName })}
                        >
                          <DeleteOutlineIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    {isHrOrAdmin && isTerminatedTab && (
                      <Tooltip title="Xóa hồ sơ vĩnh viễn">
                        <IconButton
                          size="small"
                          color="error"
                          aria-label="Xóa hồ sơ"
                          onClick={() => setPurgeTarget({ id: r.id, name: r.fullName })}
                        >
                          <DeleteForeverIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    )}
                    {canManageStaff && (
                    <Tooltip title="Đính kèm PDF">
                      <span>
                        <IconButton
                          size="small"
                          color="primary"
                          aria-label="Đính kèm PDF"
                          disabled={pdfLoadingId === r.id}
                          onClick={() => handlePdfClick(r.id)}
                        >
                          {pdfLoadingId === r.id ? <CircularProgress size={20} /> : <PictureAsPdfIcon fontSize="small" />}
                        </IconButton>
                      </span>
                    </Tooltip>
                    )}
                  </Stack>
                </TableCell>
              </TableRow>
            ))}
            {rows.length === 0 && (
              <TableRow>
                <TableCell colSpan={isTrialTab ? 9 : 7} align="center" sx={{ py: 4, color: 'text.secondary' }}>
                  Không có nhân viên trong nhóm này.
                </TableCell>
              </TableRow>
            )}
          </TableBody>
        </Table>
        <TablePagination
          component="div"
          count={total}
          page={page}
          onPageChange={(_, p) => setPage(p)}
          rowsPerPage={size}
          onRowsPerPageChange={(e) => {
            setSize(parseInt(e.target.value, 10));
            setPage(0);
          }}
          rowsPerPageOptions={[10, 25, 50, 100]}
          labelRowsPerPage="Số dòng"
        />
      </TableContainer>
    </Box>
  );
}
