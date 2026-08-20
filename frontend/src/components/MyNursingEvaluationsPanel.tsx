import GradeOutlinedIcon from '@mui/icons-material/GradeOutlined';
import VisibilityIcon from '@mui/icons-material/Visibility';
import {
  Alert,
  Box,
  Button,
  Chip,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useCallback, useEffect, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import * as ne from '../services/nursingEvaluationService';
import { NursingEvaluationDetailDialog } from './NursingEvaluationDetailDialog';

type Props = {
  refreshKey?: number;
};

/**
 * Nhân viên xem mẫu đánh giá xếp loại của mình sau khi quy trình duyệt xong (APPROVED).
 */
export function MyNursingEvaluationsPanel({ refreshKey = 0 }: Props) {
  const theme = useTheme();
  const { user } = useAuth();
  const [rows, setRows] = useState<ne.NursingEvalRow[]>([]);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [detailId, setDetailId] = useState<number | null>(null);

  const canView = Boolean(user?.employeeId);

  const reload = useCallback(() => {
    if (!canView) return;
    setLoading(true);
    ne.fetchMyApprovedNursingEvaluations()
      .then((data) => {
        setRows(data);
        setErr(null);
      })
      .catch(() => {
        setErr('Không tải được kết quả đánh giá của bạn.');
        setRows([]);
      })
      .finally(() => setLoading(false));
  }, [canView]);

  useEffect(() => {
    reload();
  }, [reload, refreshKey]);

  if (!canView) return null;

  return (
    <Box
      sx={{
        mb: 2.5,
        p: { xs: 2, sm: 2.5 },
        borderRadius: 3,
        border: `1px solid ${alpha(theme.palette.primary.main, 0.12)}`,
        bgcolor: alpha(theme.palette.background.paper, 0.98),
        boxShadow: `0 6px 28px ${alpha('#0f172a', 0.05)}`,
      }}
    >
      <Stack
        direction={{ xs: 'column', sm: 'row' }}
        spacing={1.5}
        alignItems={{ sm: 'flex-start' }}
        justifyContent="space-between"
        sx={{ mb: 2 }}
      >
        <Stack direction="row" spacing={1.25} alignItems="center">
          <Box
            sx={{
              width: 40,
              height: 40,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              bgcolor: alpha(theme.palette.success.main, 0.12),
              color: theme.palette.success.dark,
            }}
          >
            <GradeOutlinedIcon fontSize="small" />
          </Box>
          <Box>
            <Typography variant="subtitle1" fontWeight={800} letterSpacing="-0.01em">
              Kết quả đánh giá của tôi
            </Typography>
            <Typography variant="body2" color="text.secondary">
              Xem mẫu đánh giá xếp loại sau khi Giám đốc duyệt xong
            </Typography>
          </Box>
        </Stack>
        <Chip
          size="small"
          color="success"
          variant="outlined"
          label={`${rows.length} phiếu`}
          sx={{ fontWeight: 700 }}
        />
      </Stack>

      {err && (
        <Alert severity="error" sx={{ mb: 1.5, borderRadius: 2 }}>
          {err}
        </Alert>
      )}

      <TableContainer
        sx={{
          borderRadius: 2.5,
          border: `1px solid ${alpha(theme.palette.divider, 0.9)}`,
          overflow: 'hidden',
        }}
      >
        <Table size="small">
          <TableHead>
            <TableRow
              sx={{
                bgcolor: alpha(theme.palette.primary.main, 0.07),
                '& th': { fontWeight: 800 },
              }}
            >
              <TableCell>Kỳ</TableCell>
              <TableCell>Khoa / phòng</TableCell>
              <TableCell align="right">Tổng điểm</TableCell>
              <TableCell>Xếp loại</TableCell>
              <TableCell align="center">Chi tiết</TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {!loading && rows.length === 0 && (
              <TableRow>
                <TableCell colSpan={5} sx={{ py: 3.5 }}>
                  <Typography variant="body2" color="text.secondary" textAlign="center">
                    Chưa có phiếu đánh giá đã duyệt. Khi quy trình duyệt xong, kết quả sẽ hiện tại đây.
                  </Typography>
                </TableCell>
              </TableRow>
            )}
            {rows.map((r) => (
              <TableRow
                key={String(r.id)}
                hover
                sx={{ cursor: 'pointer' }}
                onClick={() => setDetailId(Number(r.id))}
              >
                <TableCell>
                  <Typography variant="body2" fontWeight={750}>
                    {String(r.periodMonth).padStart(2, '0')}/{String(r.periodYear)}
                  </Typography>
                </TableCell>
                <TableCell>{String(r.departmentName || '—')}</TableCell>
                <TableCell align="right">
                  <Typography variant="body2" fontWeight={900} color="primary.main">
                    {r.totalScore != null ? String(r.totalScore) : '—'}
                  </Typography>
                </TableCell>
                <TableCell>
                  <Chip
                    size="small"
                    color="success"
                    variant="outlined"
                    label={String(r.overallGrade || '—')}
                    sx={{ height: 22, fontWeight: 750, borderRadius: '6px' }}
                  />
                </TableCell>
                <TableCell align="center" onClick={(e) => e.stopPropagation()}>
                  <Button
                    size="small"
                    variant="outlined"
                    startIcon={<VisibilityIcon />}
                    onClick={() => setDetailId(Number(r.id))}
                    sx={{ textTransform: 'none', fontWeight: 700, borderRadius: 2 }}
                  >
                    Xem mẫu
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      <NursingEvaluationDetailDialog
        open={detailId != null}
        evaluationId={detailId}
        onClose={() => setDetailId(null)}
      />
    </Box>
  );
}
