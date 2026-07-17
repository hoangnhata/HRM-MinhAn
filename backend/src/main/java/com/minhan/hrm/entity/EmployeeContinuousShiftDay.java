package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.io.Serializable;
import java.time.LocalDate;

@Entity
@Table(name = "employee_continuous_shift_day")
@IdClass(EmployeeContinuousShiftDay.Pk.class)
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class EmployeeContinuousShiftDay {

    @Id
    @Column(name = "employee_id", nullable = false)
    private Long employeeId;

    @Id
    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Pk implements Serializable {
        private Long employeeId;
        private LocalDate workDate;
    }
}
