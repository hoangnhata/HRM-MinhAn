package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.io.Serializable;

/** Nhân viên nuôi con nhỏ — giảm 1 giờ/ngày (tối đa 7 giờ = 1 công) theo từng tháng. */
@Entity
@Table(name = "employee_young_child_month")
@IdClass(EmployeeYoungChildMonth.Pk.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmployeeYoungChildMonth {

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
