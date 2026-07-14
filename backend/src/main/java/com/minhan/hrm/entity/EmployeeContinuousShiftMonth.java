package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.io.Serializable;

@Entity
@Table(name = "employee_continuous_shift_month")
@IdClass(EmployeeContinuousShiftMonth.Pk.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmployeeContinuousShiftMonth {

    @Id
    @Column(name = "employee_id", nullable = false)
    private Long employeeId;

    @Id
    @Column(name = "period_year", nullable = false)
    private int periodYear;

    @Id
    @Column(name = "period_month", nullable = false)
    private int periodMonth;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Pk implements Serializable {
        private Long employeeId;
        private int periodYear;
        private int periodMonth;
    }
}
