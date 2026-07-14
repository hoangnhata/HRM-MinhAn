package com.minhan.hrm.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.*;

import java.time.LocalDate;

/** Ngày lễ — đi làm được tính 2 công (nhân đôi công ca). */
@Entity
@Table(name = "attendance_holiday_work_day")
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceHolidayWorkDay {

    @Id
    @Column(name = "work_date", nullable = false)
    private LocalDate workDate;
}
