package com.minhan.hrm.dashboard;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;

public final class DashboardHireClassification {

    private DashboardHireClassification() {
    }

    public static boolean isTrialHire(Employee employee) {
        if (employee == null) {
            return false;
        }
        String code = employee.getEmployeeCode();
        if (code != null && code.toUpperCase().startsWith("TV-")) {
            return true;
        }
        EmployeeStatus status = employee.getStatus();
        return status == EmployeeStatus.PROBATION || status == EmployeeStatus.INTERN;
    }
}
