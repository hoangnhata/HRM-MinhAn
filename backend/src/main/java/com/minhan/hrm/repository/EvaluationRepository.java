package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.Evaluation;
import com.minhan.hrm.entity.UserAccount;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface EvaluationRepository extends JpaRepository<Evaluation, Long> {

    List<Evaluation> findByEmployeeOrderByPeriodYearDescPeriodMonthDesc(Employee employee);

    void deleteByEmployee_Id(Long employeeId);

    @Modifying
    @Query("UPDATE Evaluation e SET e.evaluator = :to WHERE e.evaluator = :from")
    void reassignEvaluator(@Param("from") UserAccount from, @Param("to") UserAccount to);
}
