package com.minhan.hrm.service;

import com.minhan.hrm.entity.AttendanceRecord;
import com.minhan.hrm.repository.AttendanceRecordRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class CheckInOutImportBatchService {

    private final AttendanceRecordRepository attendanceRecordRepository;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void saveBatch(List<AttendanceRecord> batch) {
        attendanceRecordRepository.saveAll(batch);
    }
}
