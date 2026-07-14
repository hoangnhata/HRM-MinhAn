package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeDocument;
import com.minhan.hrm.entity.UserAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface EmployeeDocumentRepository extends JpaRepository<EmployeeDocument, Long> {

    List<EmployeeDocument> findByEmployeeOrderByCreatedAtDesc(Employee employee);

    void deleteByEmployee_Id(Long employeeId);

    @Modifying
    @Query("UPDATE EmployeeDocument d SET d.uploadedBy = NULL WHERE d.uploadedBy = :user")
    void clearUploader(@Param("user") UserAccount user);
}
