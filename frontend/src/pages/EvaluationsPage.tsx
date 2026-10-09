import TuneRoundedIcon from '@mui/icons-material/TuneRounded';
import { Box, Button, Chip, Stack } from '@mui/material';
import { useCallback, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { isHeadDepartmentRole, isHr2Role } from '../utils/roleAccess';
import { PageHeader } from '../components/layout/PageHeader';
import { EvaluationMonthlySummary } from '../components/EvaluationMonthlySummary';
import { MyNursingEvaluationsPanel } from '../components/MyNursingEvaluationsPanel';
import { NursingEvaluationPanel, type NursingEvaluationEditFocus } from '../components/NursingEvaluationPanel';
import { NursingEvaluationPendingPanel } from '../components/NursingEvaluationPendingPanel';
import { NursingEvaluationTemplateEditor } from '../components/NursingEvaluationTemplateEditor';
import { MA2026_EVAL_TEMPLATE_CODE } from '../services/nursingEvaluationService';

export default function EvaluationsPage() {
  const { user } = useAuth();
  const showMonthlySummary =
    user?.role === 'ADMIN'
    || user?.role === 'HR'
    || isHr2Role(user?.role)
    || user?.role === 'HEAD_NURSING'
    || user?.role === 'DIRECTOR'
    || user?.directorApprovalEnabled === true;
  const showPending =
    user?.role === 'ADMIN'
    || user?.role === 'HEAD_NURSING'
    || isHr2Role(user?.role)
    || user?.role === 'DIRECTOR'
    || user?.directorApprovalEnabled === true;
  /** Trưởng khoa / ĐDT khoa (khối ĐD) lập / chấm phiếu cho khoa, bộ phận của mình. */
  const showScoringPanel = isHeadDepartmentRole(user?.role) || user?.role === 'ADMIN';
  const showMyResults = Boolean(user?.employeeId);
  /** ADMIN / Trưởng phòng Điều dưỡng chỉnh sửa mẫu tiêu chí + thang xếp loại. */
  const canEditTemplate = user?.role === 'ADMIN' || user?.role === 'HEAD_NURSING';
  const [templateEditorOpen, setTemplateEditorOpen] = useState(false);
  const [templateRefreshKey, setTemplateRefreshKey] = useState(0);

  const [panelEditFocus, setPanelEditFocus] = useState<NursingEvaluationEditFocus | null>(null);
  const consumePanelFocus = useCallback(() => setPanelEditFocus(null), []);
  const [summaryRefreshKey, setSummaryRefreshKey] = useState(0);
  const bumpEvalSummary = useCallback(() => setSummaryRefreshKey((n) => n + 1), []);

  const isEmployeeOnly =
    user?.role === 'EMPLOYEE'
    || (!showPending && !showMonthlySummary && !showScoringPanel);

  return (
    <Box>
      <PageHeader
        overline="Năng suất & chất lượng"
        title={isEmployeeOnly ? 'Đánh giá & xếp loại của tôi' : 'Đánh giá NV khối Điều dưỡng'}
        description={
          isEmployeeOnly
            ? 'Xem mẫu đánh giá xếp loại sau khi Trưởng khoa/ĐDT → Trưởng phòng ĐD → HCNS → Giám đốc duyệt xong.'
            : 'Trưởng khoa / ĐDT khoa lập + chấm + ký → Trưởng phòng Điều dưỡng duyệt ký → HCNS duyệt ký → Giám đốc duyệt ký. Khối ĐD–KTV–HS–Thư ký; thêm Nhân viên khoa YHCT / Khoa khám bệnh và Dược sĩ khoa YHCT (phạm vi khoa/bộ phận của người lập).'
        }
        actions={
          <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
            <Chip size="small" color="primary" variant="outlined" label="Mẫu MA 2026" sx={{ fontWeight: 700 }} />
            {!isEmployeeOnly && (
              <Chip size="small" variant="outlined" label="4 bước duyệt" sx={{ fontWeight: 650 }} />
            )}
            {canEditTemplate && (
              <Button
                size="small"
                variant="contained"
                startIcon={<TuneRoundedIcon />}
                onClick={() => setTemplateEditorOpen(true)}
                sx={{ textTransform: 'none', fontWeight: 800, borderRadius: 2 }}
              >
                Cấu hình mẫu đánh giá
              </Button>
            )}
          </Stack>
        }
      />

      {showMyResults && <MyNursingEvaluationsPanel refreshKey={summaryRefreshKey} />}

      {showPending && (
        <NursingEvaluationPendingPanel refreshKey={summaryRefreshKey} onChanged={bumpEvalSummary} />
      )}

      {showMonthlySummary && (
        <EvaluationMonthlySummary
          templateCode={MA2026_EVAL_TEMPLATE_CODE}
          refreshKey={summaryRefreshKey}
          onRequestEditEvaluation={
            showScoringPanel ? (p) => setPanelEditFocus(p) : undefined
          }
        />
      )}

      {showScoringPanel && (
        <NursingEvaluationPanel
          editFocus={panelEditFocus}
          onEditFocusConsumed={consumePanelFocus}
          onDataMutated={bumpEvalSummary}
          templateRefreshKey={templateRefreshKey}
        />
      )}

      {canEditTemplate && (
        <NursingEvaluationTemplateEditor
          open={templateEditorOpen}
          templateCode={MA2026_EVAL_TEMPLATE_CODE}
          onClose={() => setTemplateEditorOpen(false)}
          onSaved={() => setTemplateRefreshKey((n) => n + 1)}
        />
      )}
    </Box>
  );
}
