import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { roleAllowsAny } from '../utils/roleAccess';

type AppRole =
  | 'ADMIN'
  | 'EMPLOYEE'
  | 'HR'
  | 'HR2'
  | 'HEAD_DEPARTMENT'
  | 'HEAD_HR'
  | 'HEAD_NURSING'
  | 'DIRECTOR'
  | 'REPORT_VIEWER'
  | 'HOSPITAL_EMPLOYEE_VIEWER'
  | 'PROFESSIONAL_QUALIFICATION_VIEWER';

type Props = {
  allow: AppRole[];
  children: React.ReactNode;
};

export function RoleRoute({ allow, children }: Props) {
  const { user } = useAuth();
  if (!user) {
    return <Navigate to="/" replace />;
  }
  const role = user.role as AppRole;
  const allowed =
    roleAllowsAny(role, allow) ||
    (user.reportViewEnabled === true && allow.includes('REPORT_VIEWER')) ||
    (user.hospitalWideEmployeeViewEnabled === true && allow.includes('HOSPITAL_EMPLOYEE_VIEWER')) ||
    (user.professionalQualificationReportEnabled === true &&
      allow.includes('PROFESSIONAL_QUALIFICATION_VIEWER'));
  if (!allowed) {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}
