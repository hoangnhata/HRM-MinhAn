package com.minhan.hrm.salary;

import java.math.BigDecimal;

public final class SalaryAmounts {

    private SalaryAmounts() {
    }

    /** Mức lương hợp lý cho 1 nhân viên (VND). */
    public static boolean isPlausibleSalary(BigDecimal value) {
        return value != null
                && value.compareTo(BigDecimal.ZERO) > 0
                && value.compareTo(new BigDecimal("100000000")) < 0;
    }
}
