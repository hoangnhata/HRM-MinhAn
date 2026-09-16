import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import PictureAsPdfOutlinedIcon from '@mui/icons-material/PictureAsPdfOutlined';
import { Button, CircularProgress, Stack, Tooltip } from '@mui/material';
import { alpha } from '@mui/material/styles';
import { MODULE_A_ACCENT } from './moduleAUiStyles';

const EXCEL = '#15803d';
const PDF = '#b91c1c';

type Props = {
  onExport: (kind: 'excel' | 'pdf') => void;
  exporting: 'excel' | 'pdf' | null;
  size?: 'small' | 'medium';
};

/** Cặp nút xuất Excel / PDF — tông màu phân biệt, đồng bộ báo cáo hoạt động ĐD. */
export function ReportExportButtons({ onExport, exporting, size = 'small' }: Props) {
  const busy = !!exporting;
  return (
    <Stack
      direction="row"
      spacing={0}
      sx={{
        borderRadius: 2,
        overflow: 'hidden',
        border: `1px solid ${alpha(MODULE_A_ACCENT, 0.16)}`,
        boxShadow: `0 1px 2px ${alpha('#0f172a', 0.04)}`,
        bgcolor: '#fff',
      }}
    >
      <Tooltip title="Xuất file Excel (.xlsx)" arrow>
        <span>
          <Button
            size={size}
            disableElevation
            disabled={busy}
            onClick={() => onExport('excel')}
            startIcon={
              exporting === 'excel' ? (
                <CircularProgress size={14} sx={{ color: EXCEL }} />
              ) : (
                <FileDownloadOutlinedIcon sx={{ fontSize: 17 }} />
              )
            }
            sx={{
              px: 1.35,
              py: 0.55,
              borderRadius: 0,
              borderRight: `1px solid ${alpha('#64748b', 0.12)}`,
              textTransform: 'none',
              fontWeight: 800,
              letterSpacing: '-0.01em',
              color: EXCEL,
              bgcolor: alpha(EXCEL, 0.06),
              '&:hover': { bgcolor: alpha(EXCEL, 0.12) },
              '&.Mui-disabled': { color: alpha(EXCEL, 0.45), bgcolor: alpha(EXCEL, 0.04) },
            }}
          >
            Excel
          </Button>
        </span>
      </Tooltip>
      <Tooltip title="Xuất file PDF" arrow>
        <span>
          <Button
            size={size}
            disableElevation
            disabled={busy}
            onClick={() => onExport('pdf')}
            startIcon={
              exporting === 'pdf' ? (
                <CircularProgress size={14} sx={{ color: PDF }} />
              ) : (
                <PictureAsPdfOutlinedIcon sx={{ fontSize: 17 }} />
              )
            }
            sx={{
              px: 1.35,
              py: 0.55,
              borderRadius: 0,
              textTransform: 'none',
              fontWeight: 800,
              letterSpacing: '-0.01em',
              color: PDF,
              bgcolor: alpha(PDF, 0.05),
              '&:hover': { bgcolor: alpha(PDF, 0.1) },
              '&.Mui-disabled': { color: alpha(PDF, 0.45), bgcolor: alpha(PDF, 0.035) },
            }}
          >
            PDF
          </Button>
        </span>
      </Tooltip>
    </Stack>
  );
}
