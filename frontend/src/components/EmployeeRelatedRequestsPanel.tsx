import { Stack, Typography } from '@mui/material';
import { MyRelatedRequestsSection, type RelatedRequestKind } from './MyRelatedRequestsSection';
import { EMPLOYEE_RELATED_TABS } from './employeeRelatedRequestsMeta';

type Props = {
  kind: RelatedRequestKind;
  employeeId: number;
};

export function EmployeeRelatedRequestsPanel({ kind, employeeId }: Props) {
  const meta = EMPLOYEE_RELATED_TABS.find((t) => t.kind === kind);
  if (!meta) return null;

  return (
    <Stack spacing={2}>
      <Typography variant="body2" color="text.secondary">
        {meta.description}
      </Typography>
      <MyRelatedRequestsSection employeeId={employeeId} filterKind={kind} embedded emptyLabel={`Chưa có đơn ${meta.label.toLowerCase()} nào liên quan đến bạn.`} />
    </Stack>
  );
}
