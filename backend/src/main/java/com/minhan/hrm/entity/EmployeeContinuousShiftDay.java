package com.minhan.hrm.entity;

import jakarta.persistence.*;
import lombok.*;

import java.io.Serializable;
import java.time.LocalDate;
import java.time.LocalTime;

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

    /** Ca thông tầm đã chọn (tùy chọn — tên hiển thị). */
    @Column(name = "shift_type_id")
    private Long shiftTypeId;

    /** Giờ vào thông tầm của ngày; null = dùng cấu hình mùa/NV. */
    @Column(name = "continuous_start")
    private LocalTime continuousStart;

    /** Giờ ra thông tầm của ngày; null = dùng cấu hình mùa/NV. */
    @Column(name = "continuous_end")
    private LocalTime continuousEnd;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Pk implements Serializable {
        private Long employeeId;
        private LocalDate workDate;
    }
}
