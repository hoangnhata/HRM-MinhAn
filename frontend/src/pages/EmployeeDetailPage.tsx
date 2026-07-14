import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  CircularProgress,
  Grid,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableRow,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useEffect, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import { PageHeader } from '../components/layout/PageHeader';
import { EmployeeStatusChip } from '../components/EmployeeStatusChip';
import { MaternityLeaveChip } from '../components/MaternityLeaveChip';
import * as employeeService from '../services/employeeService';
import * as documentService from '../services/documentService';
import api from '../services/api';
import { WORKFORCE_SECTIONS, workforceFieldLabel } from '../constants/workforceFieldLabels';
import { isMaternityLeaveInsurance } from '../utils/workforceInsurance';

function DetailRow({ label, value }: { label: string; value?: string | null }) {
  return (
    <Stack
      direction={{ xs: 'column', sm: 'row' }}
      spacing={{ xs: 0.25, sm: 2 }}
      sx={{
        py: 1,
        borderBottom: '1px solid',
        borderColor: 'divider',
        '&:last-of-type': { borderBottom: 'none' },
      }}
    >
      <Typography
        component="span"
        variant="body2"
        color="text.secondary"
        sx={{ minWidth: { sm: 160 }, flexShrink: 0, fontWeight: 500 }}
      >
        {label}
      </Typography>
      <Typography component="span" variant="body2" sx={{ fontWeight: 500, wordBreak: 'break-word' }}>
        {value && String(value).trim() !== '' ? value : '—'}
      </Typography>
    </Stack>
  );
}

function hasProfileValue(v: unknown): boolean {
  if (v == null) return false;
  return String(v).trim() !== '';
}

export default function EmployeeDetailPage() {
  const theme = useTheme();
  const { id } = useParams();
  const nav = useNavigate();
  const [emp, setEmp] = useState<employeeService.EmployeeDetail | null>(null);
  const [docs, setDocs] = useState<documentService.DocMeta[]>([]);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;
    let cancelled = false;
    (async () => {
      try {
        const e = await employeeService.fetchEmployee(Number(id));
        const d = await documentService.fetchDocuments(Number(id));
        if (!cancelled) {
          setEmp(e);
          setDocs(d);
        }
      } catch {
        if (!cancelled) setErr('Không tải được hồ sơ (kiểm tra quyền).');
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [id]);

  async function openPdf(docId: number) {
    const res = await api.get(`/v1/documents/${docId}/file`, { responseType: 'blob' });
    const url = URL.createObjectURL(res.data);
    window.open(url, '_blank', 'noopener,noreferrer');
    setTimeout(() => URL.revokeObjectURL(url), 60_000);
  }

  if (err) {
    return (
      <Box>
        <PageHeader title="Không tải được hồ sơ" description={err} />
        <Button startIcon={<ArrowBackIcon />} variant="outlined" sx={{ mt: 1 }} onClick={() => nav(-1)}>
          Quay lại
        </Button>
      </Box>
    );
  }

  if (!emp) {
    return (
      <Card sx={{ borderRadius: 3, py: 6, textAlign: 'center' }}>
        <CircularProgress color="primary" />
        <Typography variant="body2" color="text.secondary" sx={{ mt: 2 }}>
          Đang tải hồ sơ…
        </Typography>
      </Card>
    );
  }

  const profile = (emp.workforceProfile ?? {}) as Record<string, unknown>;
  const trialOnlyView = emp.employeeCode?.toUpperCase().startsWith('TV-') ?? false;
  const salaryFromNotes =
    typeof profile.workforceNotes === 'string' && profile.workforceNotes.includes('Mức lương:')
      ? profile.workforceNotes.split('Mức lương:').pop()?.split('|')[0]?.trim()
      : null;
  const noteOnly =
    typeof profile.workforceNotes === 'string'
      ? profile.workforceNotes.replace(/\s*\|\s*Mức lương:.*$/, '').trim() || null
      : null;
  const allSectionKeys = new Set(WORKFORCE_SECTIONS.flatMap((s) => s.keys));
  const orphanKeys = Object.keys(profile).filter(
    (k) => hasProfileValue(profile[k]) && !allSectionKeys.has(k),
  );
  const maternityLeave = isMaternityLeaveInsurance(profile.insuranceParticipation);

  return (
    <Box sx={{ width: '100%' }}>
      <PageHeader
        overline="Hồ sơ nhân viên"
        title={emp.fullName}
        description={`${emp.departmentName} · ${emp.positionTitle}`}
        actions={
          <>
            {emp.employeeCode ? (
              <Chip label={`Mã NV: ${emp.employeeCode}`} size="small" variant="outlined" sx={{ fontWeight: 600 }} />
            ) : null}
            <EmployeeStatusChip status={emp.status} sx={{ height: 26, fontSize: '0.75rem' }} />
            {maternityLeave && <MaternityLeaveChip sx={{ height: 26, fontSize: '0.75rem' }} />}
            <Button startIcon={<ArrowBackIcon />} variant="outlined" onClick={() => nav(-1)}>
              Quay lại
            </Button>
          </>
        }
      />

      <Grid container spacing={2.5}>
        {trialOnlyView ? (
          <Grid item xs={12} lg={8}>
            <Card variant="outlined" sx={{ borderColor: alpha(theme.palette.primary.main, 0.15) }}>
              <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
                <Typography variant="subtitle1" fontWeight={700} gutterBottom sx={{ color: 'primary.main' }}>
                  Thông tin thử việc / thực tập
                </Typography>
                <DetailRow label="Họ tên" value={emp.fullName} />
                <DetailRow label="Ngày sinh" value={emp.dateOfBirth} />
                <DetailRow label="Vị trí" value={emp.positionTitle} />
                <DetailRow label="Bằng cấp" value={profile.degree as string | undefined} />
                <DetailRow label="Khoa/Phòng" value={emp.departmentName} />
                <DetailRow label="Mức lương" value={salaryFromNotes} />
                <DetailRow
                  label="Từ ngày"
                  value={emp.hireDate ?? (profile.probationStartDate as string | undefined)}
                />
                <DetailRow label="Ghi chú" value={noteOnly} />
              </CardContent>
            </Card>
          </Grid>
        ) : (
          <>
        <Grid item xs={12} lg={6}>
          <Card
            variant="outlined"
            sx={{
              borderColor: alpha(theme.palette.primary.main, 0.15),
              height: '100%',
            }}
          >
            <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
              <Typography variant="subtitle1" fontWeight={700} gutterBottom sx={{ color: 'primary.main' }}>
                Liên hệ & giấy tờ
              </Typography>
              <DetailRow label="Email" value={emp.email} />
              <DetailRow label="Điện thoại" value={emp.phone} />
              <DetailRow label="Giới tính" value={emp.gender} />
              <DetailRow label="Ngày sinh" value={emp.dateOfBirth} />
              <DetailRow label="CCCD/CMND" value={emp.idCardNumber} />
              <DetailRow label="Địa chỉ" value={emp.address} />
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} lg={6}>
          <Card
            variant="outlined"
            sx={{
              borderColor: alpha(theme.palette.primary.main, 0.15),
              height: '100%',
            }}
          >
            <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
              <Typography variant="subtitle1" fontWeight={700} gutterBottom sx={{ color: 'primary.main' }}>
                Công việc
              </Typography>
              <DetailRow label="Phòng ban" value={emp.departmentName} />
              <DetailRow label="Chức vụ" value={emp.positionTitle} />
              <DetailRow label="Ngày vào làm" value={emp.hireDate} />
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card variant="outlined" sx={{ height: '100%' }}>
            <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
              <Typography variant="subtitle1" fontWeight={700} gutterBottom>
                Số Hợp đồng
              </Typography>
              {emp.contracts.length === 0 && (
                <Typography variant="body2" color="text.secondary">
                  Chưa có hợp đồng
                </Typography>
              )}
              {emp.contracts.map((c) => (
                <Box key={c.id} sx={{ mb: 1.5, pb: 1.5, borderBottom: '1px solid', borderColor: 'divider' }}>
                  <Typography variant="body2" fontWeight={600}>
                    {c.contractType}
                  </Typography>
                  <Typography variant="body2" color="text.secondary">
                    Ngày ký: {c.startDate}
                  </Typography>
                </Box>
              ))}
            </CardContent>
          </Card>
        </Grid>

        {emp.workforceProfile && Object.keys(emp.workforceProfile).length > 0 && (
          <>
            <Grid item xs={12}>
              <Typography variant="h6" fontWeight={700} sx={{ mt: 1, mb: 0.5 }}>
                Dữ liệu nhân lực (Excel BVMA)
              </Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                Các mục được nhóm theo nội dung; chỉ hiển thị trường đã có dữ liệu.
              </Typography>
            </Grid>

            {WORKFORCE_SECTIONS.map((section) => {
              const rows = section.keys.filter((k) => hasProfileValue(profile[k])).map((k) => [k, profile[k]] as const);
              if (rows.length === 0) return null;

              return (
                <Grid item xs={12} md={6} key={section.title}>
                  <Card variant="outlined" sx={{ height: '100%' }}>
                    <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
                      <Typography variant="subtitle1" fontWeight={700} gutterBottom sx={{ color: 'text.primary' }}>
                        {section.title}
                      </Typography>
                      <Table size="small">
                        <TableBody>
                          {rows.map(([k, v]) => (
                            <TableRow key={k} sx={{ '&:last-child td': { border: 0 } }}>
                              <TableCell
                                sx={{
                                  fontWeight: 600,
                                  color: 'text.secondary',
                                  width: '42%',
                                  verticalAlign: 'top',
                                  borderColor: 'divider',
                                  py: 1.25,
                                }}
                              >
                                {workforceFieldLabel(k)}
                              </TableCell>
                              <TableCell
                                sx={{
                                  whiteSpace: 'pre-wrap',
                                  wordBreak: 'break-word',
                                  verticalAlign: 'top',
                                  py: 1.25,
                                }}
                              >
                                {k === 'insuranceParticipation' && isMaternityLeaveInsurance(v) ? (
                                  <Typography
                                    component="span"
                                    variant="body2"
                                    sx={{
                                      fontWeight: 600,
                                      color: '#9d174d',
                                    }}
                                  >
                                    {String(v)}
                                  </Typography>
                                ) : (
                                  String(v)
                                )}
                              </TableCell>
                            </TableRow>
                          ))}
                        </TableBody>
                      </Table>
                    </CardContent>
                  </Card>
                </Grid>
              );
            })}

            {orphanKeys.length > 0 && (
              <Grid item xs={12}>
                <Card variant="outlined">
                  <CardContent>
                    <Typography variant="subtitle1" fontWeight={700} gutterBottom>
                      Thông tin khác
                    </Typography>
                    <Table size="small">
                      <TableBody>
                        {orphanKeys.map((k) => (
                          <TableRow key={k}>
                            <TableCell sx={{ fontWeight: 600, width: '40%', verticalAlign: 'top' }}>
                              {workforceFieldLabel(k)}
                            </TableCell>
                            <TableCell sx={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word' }}>
                              {String(profile[k])}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </CardContent>
                </Card>
              </Grid>
            )}
          </>
        )}

        <Grid item xs={12}>
          <Card variant="outlined">
            <CardContent sx={{ p: 2.5, '&:last-child': { pb: 2.5 } }}>
              <Typography variant="subtitle1" fontWeight={700} gutterBottom>
                Hồ sơ PDF
              </Typography>
              {docs.length === 0 && (
                <Typography variant="body2" color="text.secondary">
                  Chưa có tệp đính kèm
                </Typography>
              )}
              <Stack spacing={1} sx={{ mt: 1 }}>
                {docs.map((d) => (
                  <Stack key={d.id} direction="row" spacing={1} alignItems="center" flexWrap="wrap">
                    <Typography variant="body2" sx={{ flex: 1 }}>
                      {d.originalName} ({d.docType})
                    </Typography>
                    <Button size="small" variant="outlined" onClick={() => openPdf(d.id)}>
                      Mở PDF
                    </Button>
                  </Stack>
                ))}
              </Stack>
            </CardContent>
          </Card>
        </Grid>
          </>
        )}
      </Grid>
    </Box>
  );
}
