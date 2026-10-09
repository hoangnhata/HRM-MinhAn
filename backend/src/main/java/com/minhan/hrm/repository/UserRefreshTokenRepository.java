package com.minhan.hrm.repository;

import com.minhan.hrm.entity.UserRefreshToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.Optional;

public interface UserRefreshTokenRepository extends JpaRepository<UserRefreshToken, Long> {

    Optional<UserRefreshToken> findByTokenHash(String tokenHash);

    @Modifying
    @Query("update UserRefreshToken t set t.revokedAt = :now "
            + "where t.user.id = :userId and t.revokedAt is null")
    int revokeAllForUser(@Param("userId") Long userId, @Param("now") Instant now);

    @Modifying
    @Query("delete from UserRefreshToken t where t.expiresAt < :cutoff or t.revokedAt < :cutoff")
    int deleteStale(@Param("cutoff") Instant cutoff);
}
