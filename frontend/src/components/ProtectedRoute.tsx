import { Box, CircularProgress } from '@mui/material';
import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { token, user, sessionReady } = useAuth();
  const loc = useLocation();

  if (!sessionReady) {
    return (
      <Box sx={{ display: 'flex', minHeight: '100vh', alignItems: 'center', justifyContent: 'center' }}>
        <CircularProgress />
      </Box>
    );
  }

  if (!token) {
    return <Navigate to="/login" replace state={{ from: loc }} />;
  }

  if (user?.mustChangePassword && loc.pathname !== '/change-password-required') {
    return <Navigate to="/change-password-required" replace />;
  }

  if (
    !user?.mustChangePassword &&
    user?.mustSetSignature &&
    loc.pathname !== '/signature-required' &&
    loc.pathname !== '/change-password-required'
  ) {
    return <Navigate to="/signature-required" replace />;
  }

  return <>{children}</>;
}
