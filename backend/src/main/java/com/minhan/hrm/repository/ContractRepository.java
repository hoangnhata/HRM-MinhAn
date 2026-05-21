package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Contract;
import com.minhan.hrm.entity.Employee;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface ContractRepository extends JpaRepository<Contract, Long> {

    List<Contract> findByEmployeeOrderByStartDateDesc(Employee employee);
}
