import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

type AppRole =
  | 'ADMIN'
  | 'EMPLOYEE'
  | 'HR'
  | 'HEAD_DEPARTMENT'
  | 'HEAD_NURSING'
  | 'DIRECTOR';

type Props = {
  allow: AppRole[];
  children: React.ReactNode;
};

export function RoleRoute({ allow, children }: Props) {
  const { user } = useAuth();
  if (!user || !allow.includes(user.role as AppRole)) {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}
