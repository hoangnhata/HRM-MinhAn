import AccessTimeIcon from '@mui/icons-material/AccessTime';
import ArrowDropDownIcon from '@mui/icons-material/ArrowDropDown';
import CloudSyncIcon from '@mui/icons-material/CloudSync';
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import FileDownloadOutlinedIcon from '@mui/icons-material/FileDownloadOutlined';
import GroupAddOutlinedIcon from '@mui/icons-material/GroupAddOutlined';
import NightsStayIcon from '@mui/icons-material/NightsStay';
import SwapHorizOutlinedIcon from '@mui/icons-material/SwapHorizOutlined';
import RefreshIcon from '@mui/icons-material/Refresh';
import SavingsOutlinedIcon from '@mui/icons-material/SavingsOutlined';
import EventAvailableIcon from '@mui/icons-material/EventAvailable';
import TuneIcon from '@mui/icons-material/Tune';
import {
  Box,
  Button,
  CircularProgress,
  Divider,
  ListItemIcon,
  ListItemText,
  Menu,
  MenuItem,
  Paper,
  Stack,
  Tooltip,
  Typography,
} from '@mui/material';
import { alpha, useTheme } from '@mui/material/styles';
import { useMemo, useState } from 'react';

type Props = {
  onImportSql: () => void;
  onSyncChamcong?: () => void;
  chamcongSyncEnabled?: boolean;
  onExportReport: () => void;
  onRecalculate: () => void;
  onForgotPenaltyConfig: () => void;
  onLatePenaltyConfig: () => void;
  onHolidayWorkConfig: () => void;
  onBulkSupplement?: () => void;
  onBulkDeployment?: () => void;
  exporting?: boolean;
  recalculating?: boolean;
};

export function WorkAdminToolbar({
  onImportSql,
  onSyncChamcong,
  chamcongSyncEnabled,
  onExportReport,
  onRecalculate,
  onForgotPenaltyConfig,
  onLatePenaltyConfig,
  onHolidayWorkConfig,
  onBulkSupplement,
  onBulkDeployment,
  exporting,
  recalculating,
}: Props) {
  const theme = useTheme();
  const [configAnchor, setConfigAnchor] = useState<null | HTMLElement>(null);
  const [bulkAnchor, setBulkAnchor] = useState<null | HTMLElement>(null);

  const btnSx = useMemo(
    () => ({
      minHeight: 36,
      px: 1.75,
      borderRadius: 1.75,
      fontSize: '0.8125rem',
      fontWeight: 600,
      textTransform: 'none' as const,
      borderColor: alpha(theme.palette.divider, 0.95),
      color: 'text.primary',
      bgcolor: 'background.paper',
      boxShadow: 'none',
      whiteSpace: 'nowrap' as const,
      '&:hover': {
        bgcolor: alpha(theme.palette.primary.main, 0.04),
        borderColor: alpha(theme.palette.primary.main, 0.35),
      },
      '& .MuiButton-startIcon': { mr: 0.75, '& > svg': { fontSize: 18 } },
      '& .MuiButton-endIcon': { ml: 0.25, '& > svg': { fontSize: 18 } },
    }),
    [theme],
  );

  const accentBtnSx = useMemo(
    () => ({
      ...btnSx,
      bgcolor: alpha(theme.palette.primary.main, 0.08),
      color: 'primary.main',
      borderColor: alpha(theme.palette.primary.main, 0.28),
      '&:hover': {
        bgcolor: alpha(theme.palette.primary.main, 0.14),
        borderColor: alpha(theme.palette.primary.main, 0.45),
      },
    }),
    [btnSx, theme],
  );

  return (
    <Paper
      variant="outlined"
      sx={{
        borderRadius: 2.5,
        bgcolor: alpha(theme.palette.background.paper, 0.96),
        borderColor: alpha(theme.palette.divider, 0.9),
        overflow: 'hidden',
        p: { xs: 1.5, sm: 2 },
      }}
    >
      <Box
        sx={{
          display: 'grid',
          gridTemplateColumns: { xs: '1fr', md: '1fr auto 1fr' },
          gap: { xs: 2, md: 0 },
          alignItems: 'stretch',
        }}
      >
        <ToolbarGroup label="Dữ liệu">
          {chamcongSyncEnabled && onSyncChamcong && (
            <Tooltip title="Đồng bộ từ SQL Server máy chấm công — 7 ngày hoặc chọn ngày bắt đầu">
              <Button
                size="small"
                variant="outlined"
                startIcon={<CloudSyncIcon />}
                onClick={onSyncChamcong}
                sx={accentBtnSx}
              >
                Đồng bộ máy CC
              </Button>
            </Tooltip>
          )}

          <Tooltip title="File dump CheckInOut từ máy chấm công (dự phòng)">
            <Button
              size="small"
              variant="outlined"
              startIcon={<CloudUploadIcon />}
              onClick={onImportSql}
              sx={accentBtnSx}
            >
              Import SQL
            </Button>
          </Tooltip>

          <Tooltip title="Xuất báo cáo công toàn viện tháng đang xem">
            <Button
              size="small"
              variant="outlined"
              startIcon={<FileDownloadOutlinedIcon />}
              onClick={onExportReport}
              disabled={exporting}
              sx={btnSx}
            >
              {exporting ? 'Đang xuất…' : 'Xuất Excel'}
            </Button>
          </Tooltip>

          <Tooltip title={recalculating ? 'Đang tính lại…' : 'Tính lại bảng công tháng đang xem'}>
            <span>
              <Button
                size="small"
                variant="outlined"
                startIcon={
                  recalculating ? <CircularProgress size={16} color="inherit" /> : <RefreshIcon />
                }
                onClick={onRecalculate}
                disabled={recalculating}
                sx={btnSx}
              >
                {recalculating ? 'Đang tính…' : 'Tính lại'}
              </Button>
            </span>
          </Tooltip>
        </ToolbarGroup>

        <Divider
          orientation="vertical"
          flexItem
          sx={{
            display: { xs: 'none', md: 'block' },
            mx: 2.5,
            borderColor: alpha(theme.palette.divider, 0.85),
          }}
        />

        <ToolbarGroup label="Vận hành">
          <Button
            size="small"
            variant="outlined"
            startIcon={<TuneIcon />}
            endIcon={<ArrowDropDownIcon />}
            onClick={(e) => setConfigAnchor(e.currentTarget)}
            sx={btnSx}
          >
            Cấu hình phạt
          </Button>
          <Menu
            anchorEl={configAnchor}
            open={Boolean(configAnchor)}
            onClose={() => setConfigAnchor(null)}
            anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
            transformOrigin={{ vertical: 'top', horizontal: 'left' }}
            slotProps={{ paper: { sx: { minWidth: 260, borderRadius: 2, mt: 0.5 } } }}
          >
            <MenuItem
              onClick={() => {
                setConfigAnchor(null);
                onForgotPenaltyConfig();
              }}
            >
              <ListItemIcon>
                <SavingsOutlinedIcon fontSize="small" />
              </ListItemIcon>
              <ListItemText primary="Phạt quên chấm công" secondary="Theo số lần trong tháng" />
            </MenuItem>
            <MenuItem
              onClick={() => {
                setConfigAnchor(null);
                onLatePenaltyConfig();
              }}
            >
              <ListItemIcon>
                <AccessTimeIcon fontSize="small" />
              </ListItemIcon>
              <ListItemText primary="Phạt đi muộn / về sớm" secondary="Theo tổng phút trong tháng" />
            </MenuItem>
          </Menu>

          <Tooltip title="Chọn ngày lễ — đi làm tính 2 công">
            <Button
              size="small"
              variant="outlined"
              startIcon={<EventAvailableIcon />}
              onClick={onHolidayWorkConfig}
              sx={btnSx}
            >
              Cấu hình công lễ
            </Button>
          </Tooltip>

          <Button
            size="small"
            variant="outlined"
            startIcon={<GroupAddOutlinedIcon />}
            endIcon={<ArrowDropDownIcon />}
            onClick={(e) => setBulkAnchor(e.currentTarget)}
            sx={accentBtnSx}
            disabled={!onBulkSupplement && !onBulkDeployment}
          >
            Bổ sung hàng loạt
          </Button>
          <Menu
            anchorEl={bulkAnchor}
            open={Boolean(bulkAnchor)}
            onClose={() => setBulkAnchor(null)}
            anchorOrigin={{ vertical: 'bottom', horizontal: 'left' }}
            transformOrigin={{ vertical: 'top', horizontal: 'left' }}
            slotProps={{ paper: { sx: { minWidth: 300, borderRadius: 2, mt: 0.5 } } }}
          >
            <MenuItem
              disabled={!onBulkSupplement}
              onClick={() => {
                setBulkAnchor(null);
                onBulkSupplement?.();
              }}
            >
              <ListItemIcon>
                <NightsStayIcon fontSize="small" />
              </ListItemIcon>
              <ListItemText
                primary="Công trực / Quang Trung"
                secondary="Bổ sung theo khoa — ca trực hoặc công QT"
              />
            </MenuItem>
            <MenuItem
              disabled={!onBulkDeployment}
              onClick={() => {
                setBulkAnchor(null);
                onBulkDeployment?.();
              }}
            >
              <ListItemIcon>
                <SwapHorizOutlinedIcon fontSize="small" />
              </ListItemIcon>
              <ListItemText
                primary="Điều động hàng loạt"
                secondary="Tạo đơn điều động ×1,5 cho nhiều NV cùng khoa"
              />
            </MenuItem>
          </Menu>
        </ToolbarGroup>
      </Box>
    </Paper>
  );
}

function ToolbarGroup({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <Stack spacing={1.25} sx={{ minWidth: 0, height: '100%', justifyContent: 'center' }}>
      <Typography
        variant="overline"
        color="text.secondary"
        sx={{
          fontWeight: 700,
          letterSpacing: '0.1em',
          lineHeight: 1,
          fontSize: '0.65rem',
        }}
      >
        {label}
      </Typography>
      <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap alignItems="center">
        {children}
      </Stack>
    </Stack>
  );
}
