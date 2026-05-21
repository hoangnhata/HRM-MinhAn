import { Navigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

type Props = {
  allow: Array<'ADMIN' | 'EMPLOYEE'>;
  children: React.ReactNode;
};

export function RoleRoute({ allow, children }: Props) {
  const { user } = useAuth();
  if (!user || !allow.includes(user.role as 'ADMIN' | 'EMPLOYEE')) {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}
