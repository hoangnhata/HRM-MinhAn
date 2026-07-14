package com.minhan.hrm.repository;

import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRole;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface UserAccountRepository extends JpaRepository<UserAccount, Long> {

    Optional<UserAccount> findByUsername(String username);

    boolean existsByUsername(String username);

    boolean existsByEmail(String email);

    boolean existsByEmailIgnoreCaseAndIdNot(String email, Long id);

    long countByRole(UserRole role);

    List<UserAccount> findByRoleIn(Collection<UserRole> roles);
}
