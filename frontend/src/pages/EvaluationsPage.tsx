import { Box } from '@mui/material';
import { useCallback, useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { PageHeader } from '../components/layout/PageHeader';
import { EvaluationMonthlySummary } from '../components/EvaluationMonthlySummary';
import { NursingEvaluationPanel, type NursingEvaluationEditFocus } from '../components/NursingEvaluationPanel';
import { MA2026_EVAL_TEMPLATE_CODE } from '../services/nursingEvaluationService';

export default function EvaluationsPage() {
  const { user } = useAuth();
  const showMonthlySummary = user?.role === 'ADMIN' || user?.role === 'HR';
  const [panelEditFocus, setPanelEditFocus] = useState<NursingEvaluationEditFocus | null>(null);
  const consumePanelFocus = useCallback(() => setPanelEditFocus(null), []);
  const [summaryRefreshKey, setSummaryRefreshKey] = useState(0);
  const bumpEvalSummary = useCallback(() => setSummaryRefreshKey((n) => n + 1), []);

  return (
    <Box>
      <PageHeader overline="Năng suất & chất lượng" title="Đánh giá & xếp loại nhân viên" />

      {showMonthlySummary && (
        <EvaluationMonthlySummary
          templateCode={MA2026_EVAL_TEMPLATE_CODE}
          refreshKey={summaryRefreshKey}
          onRequestEditEvaluation={(p) => setPanelEditFocus(p)}
        />
      )}

      <NursingEvaluationPanel
        editFocus={panelEditFocus}
        onEditFocusConsumed={consumePanelFocus}
        onDataMutated={showMonthlySummary ? bumpEvalSummary : undefined}
      />
    </Box>
  );
}
