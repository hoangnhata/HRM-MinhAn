package com.minhan.hrm.repository;

import com.minhan.hrm.entity.Employee;
import com.minhan.hrm.entity.EmployeeStatus;
import com.minhan.hrm.entity.UserAccount;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import org.springframework.data.jpa.domain.Specification;

import java.util.ArrayList;
import java.util.List;

public final class EmployeeSpecifications {

    private EmployeeSpecifications() {
    }

    /**
     * Lọc theo từ khóa (họ tên, mã NV, username), phòng ban, trạng thái.
     */
    public static Specification<Employee> withFilters(String q, Long departmentId, EmployeeStatus status) {
        return (Root<Employee> root, jakarta.persistence.criteria.CriteriaQuery<?> query, jakarta.persistence.criteria.CriteriaBuilder cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (q != null && !q.isBlank()) {
                String pattern = "%" + q.trim().toLowerCase() + "%";
                Join<Employee, UserAccount> userJoin = root.join("user");
                Predicate byName = cb.like(cb.lower(root.get("fullName")), pattern);
                Predicate byCode = cb.and(
                        cb.isNotNull(root.get("employeeCode")),
                        cb.like(cb.lower(root.get("employeeCode")), pattern));
                Predicate byUser = cb.like(cb.lower(userJoin.get("username")), pattern);
                predicates.add(cb.or(byName, byCode, byUser));
            }
            if (departmentId != null) {
                predicates.add(cb.equal(root.get("department").get("id"), departmentId));
            }
            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            }
            if (predicates.isEmpty()) {
                return cb.conjunction();
            }
            return cb.and(predicates.toArray(Predicate[]::new));
        };
    }
}
