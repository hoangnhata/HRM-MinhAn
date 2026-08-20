import { Navigate, Route, Routes } from 'react-router-dom';
import { ProtectedRoute } from '../components/ProtectedRoute';
import { RoleRoute } from '../components/RoleRoute';
import { ChangePasswordRequiredPage } from '../pages/ChangePasswordRequiredPage';
import { SignatureRequiredPage } from '../pages/SignatureRequiredPage';
import { MainLayout } from '../layouts/MainLayout';
import DashboardPage from '../pages/DashboardPage';
import DepartmentsPage from '../pages/DepartmentsPage';
import EmployeeDetailPage from '../pages/EmployeeDetailPage';
import EmployeesPage from '../pages/EmployeesPage';
import EvaluationsPage from '../pages/EvaluationsPage';
import LoginPage from '../pages/LoginPage';
import WorkPage from '../pages/WorkPage';
import RequestsPage from '../pages/RequestsPage';
import SalaryPage from '../pages/SalaryPage';
import SalaryScalePage from '../pages/SalaryScalePage';
import SalaryGradeReviewPage from '../pages/SalaryGradeReviewPage';
import ProfilePage from '../pages/ProfilePage';
import AccountAdminPage from '../pages/AccountAdminPage';
import SignaturePage from '../pages/SignaturePage';
import WorkforceReportsPage from '../pages/WorkforceReportsPage';

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/change-password-required"
        element={
          <ProtectedRoute>
            <ChangePasswordRequiredPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/signature-required"
        element={
          <ProtectedRoute>
            <SignatureRequiredPage />
          </ProtectedRoute>
        }
      />
      <Route
        path="/"
        element={
          <ProtectedRoute>
            <MainLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<DashboardPage />} />
        <Route
          path="departments"
          element={
            <RoleRoute allow={['ADMIN', 'HR']}>
              <DepartmentsPage />
            </RoleRoute>
          }
        />
        <Route path="employees" element={<Navigate to="/employees/official" replace />} />
        <Route
          path="employees/official"
          element={
              <RoleRoute allow={['ADMIN', 'HR', 'HEAD_DEPARTMENT', 'HEAD_NURSING']}>
              <EmployeesPage />
            </RoleRoute>
          }
        />
        <Route
          path="employees/trial"
          element={
            <RoleRoute allow={['ADMIN', 'HR', 'HEAD_DEPARTMENT', 'HEAD_NURSING']}>
              <EmployeesPage />
            </RoleRoute>
          }
        />
        <Route
          path="employees/terminated"
          element={
            <RoleRoute allow={['ADMIN', 'HR', 'HEAD_DEPARTMENT', 'HEAD_NURSING']}>
              <EmployeesPage />
            </RoleRoute>
          }
        />
        <Route path="employees/:id" element={<EmployeeDetailPage />} />
        <Route path="notifications" element={<Navigate to="/" replace />} />
        <Route path="evaluations" element={<EvaluationsPage />} />
        <Route
          path="work"
          element={
            <RoleRoute allow={['ADMIN', 'HR', 'HR2', 'HEAD_DEPARTMENT', 'HEAD_NURSING']}>
              <WorkPage />
            </RoleRoute>
          }
        />
        <Route path="work/me" element={<WorkPage />} />
        <Route path="requests" element={<RequestsPage />} />
        <Route
          path="reports/hospital-workforce"
          element={
            <RoleRoute allow={['ADMIN', 'HR', 'HR2', 'DIRECTOR', 'REPORT_VIEWER']}>
              <WorkforceReportsPage />
            </RoleRoute>
          }
        />
        <Route
          path="reports/daily-workforce"
          element={
            <RoleRoute allow={['ADMIN', 'HR', 'HR2', 'DIRECTOR', 'REPORT_VIEWER']}>
              <WorkforceReportsPage />
            </RoleRoute>
          }
        />
        <Route
          path="salary"
          element={
            <RoleRoute allow={['ADMIN', 'HR']}>
              <SalaryPage />
            </RoleRoute>
          }
        />
        <Route path="salary/me" element={<SalaryPage />} />
        <Route
          path="salary-scales"
          element={
            <RoleRoute allow={['ADMIN', 'HR']}>
              <SalaryScalePage />
            </RoleRoute>
          }
        />
        <Route path="salary-scales/me" element={<SalaryScalePage />} />
        <Route
          path="salary-grade-reviews"
          element={
            <RoleRoute allow={['ADMIN', 'HR']}>
              <SalaryGradeReviewPage />
            </RoleRoute>
          }
        />
        <Route path="profile" element={<ProfilePage />} />
        <Route path="signature" element={<SignaturePage />} />
        <Route
          path="account-admin"
          element={
            <RoleRoute allow={['ADMIN']}>
              <AccountAdminPage />
            </RoleRoute>
          }
        />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
