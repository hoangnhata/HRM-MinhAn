package com.minhan.hrm.repository;

import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserDeviceToken;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserDeviceTokenRepository extends JpaRepository<UserDeviceToken, Long> {
    List<UserDeviceToken> findByUser(UserAccount user);

    List<UserDeviceToken> findByUserId(Long userId);

    Optional<UserDeviceToken> findByToken(String token);

    void deleteByToken(String token);

    void deleteByUserAndToken(UserAccount user, String token);
}
