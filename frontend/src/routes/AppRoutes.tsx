import { Navigate, Route, Routes } from 'react-router-dom';
import { ProtectedRoute } from '../components/ProtectedRoute';
import { RoleRoute } from '../components/RoleRoute';
import { MainLayout } from '../layouts/MainLayout';
import AnnouncementsPage from '../pages/AnnouncementsPage';
import DashboardPage from '../pages/DashboardPage';
import DepartmentsPage from '../pages/DepartmentsPage';
import EmployeeDetailPage from '../pages/EmployeeDetailPage';
import EmployeesPage from '../pages/EmployeesPage';
import EvaluationsPage from '../pages/EvaluationsPage';
import LoginPage from '../pages/LoginPage';
import WorkPage from '../pages/WorkPage';
import ProfilePage from '../pages/ProfilePage';

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <MainLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<DashboardPage />} />
        <Route path="announcements" element={<AnnouncementsPage />} />
        <Route
          path="departments"
          element={
            <RoleRoute allow={['ADMIN']}>
              <DepartmentsPage />
            </RoleRoute>
          }
        />
        <Route
          path="employees"
          element={
            <RoleRoute allow={['ADMIN']}>
              <EmployeesPage />
            </RoleRoute>
          }
        />
        <Route path="employees/:id" element={<EmployeeDetailPage />} />
        <Route path="notifications" element={<Navigate to="/" replace />} />
        <Route path="evaluations" element={<EvaluationsPage />} />
        <Route path="work" element={<WorkPage />} />
        <Route path="profile" element={<ProfilePage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
