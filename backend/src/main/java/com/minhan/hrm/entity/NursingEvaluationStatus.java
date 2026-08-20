package com.minhan.hrm.entity;

public enum NursingEvaluationStatus {
    DRAFT,
    /** Chờ Trưởng phòng Điều dưỡng duyệt ký */
    PENDING_NURSING_HEAD,
    NURSING_HEAD_REJECTED,
    PENDING_HR,
    HR_REJECTED,
    PENDING_DIRECTOR,
    DIRECTOR_REJECTED,
    APPROVED,
    CANCELLED
}
