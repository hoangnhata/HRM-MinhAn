import EditOutlinedIcon from '@mui/icons-material/EditOutlined';
import UndoOutlinedIcon from '@mui/icons-material/UndoOutlined';
import { Button, CircularProgress, Stack } from '@mui/material';

type Props = {
  showEdit?: boolean;
  showCancel?: boolean;
  acting?: boolean;
  onEdit?: () => void;
  onCancel?: () => void;
  editLabel?: string;
  cancelLabel?: string;
};

/** Nút chỉnh sửa + thu hồi cho người lập đơn (đặt bên trái footer). */
export function RequestOwnerActions({
  showEdit,
  showCancel,
  acting = false,
  onEdit,
  onCancel,
  editLabel = 'Chỉnh sửa',
  cancelLabel = 'Thu hồi đơn',
}: Props) {
  if (!showEdit && !showCancel) return null;

  return (
    <Stack direction="row" spacing={1} sx={{ mr: 'auto' }} flexWrap="wrap" useFlexGap>
      {showEdit && (
        <Button
          variant="outlined"
          color="primary"
          startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <EditOutlinedIcon />}
          disabled={acting}
          onClick={onEdit}
          sx={{ borderRadius: 2, fontWeight: 700 }}
        >
          {editLabel}
        </Button>
      )}
      {showCancel && (
        <Button
          color="error"
          variant="outlined"
          startIcon={acting ? <CircularProgress size={16} color="inherit" /> : <UndoOutlinedIcon />}
          disabled={acting}
          onClick={onCancel}
          sx={{ borderRadius: 2, fontWeight: 700 }}
        >
          {cancelLabel}
        </Button>
      )}
    </Stack>
  );
}
