package com.minhan.hrm.service;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.entity.UserAccount;
import com.minhan.hrm.entity.UserRefreshToken;
import com.minhan.hrm.exception.ApiException;
import com.minhan.hrm.repository.UserRefreshTokenRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class RefreshTokenServiceTest {

    private UserRefreshTokenRepository repository;
    private RefreshTokenService service;
    private UserAccount user;

    @BeforeEach
    void setUp() {
        repository = mock(UserRefreshTokenRepository.class);
        HrmProperties props = new HrmProperties();
        service = new RefreshTokenService(repository, props);
        user = new UserAccount();
        user.setId(7L);
        user.setEnabled(true);
        when(repository.save(any(UserRefreshToken.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    @Test
    void issueStoresOnlyHashAndReturnsRawToken() {
        String raw = service.issue(user, "iPhone 15");

        ArgumentCaptor<UserRefreshToken> saved = ArgumentCaptor.forClass(UserRefreshToken.class);
        verify(repository).save(saved.capture());
        UserRefreshToken row = saved.getValue();
        assertNotNull(raw);
        assertNotEquals(raw, row.getTokenHash());
        assertEquals(RefreshTokenService.hash(raw), row.getTokenHash());
        assertEquals(64, row.getTokenHash().length());
        assertSame(user, row.getUser());
        // Mặc định 180 ngày.
        assertTrue(row.getExpiresAt().isAfter(Instant.now().plus(179, ChronoUnit.DAYS)));
    }

    @Test
    void useExtendsExpiryForActiveToken() {
        UserRefreshToken row = activeRow(Instant.now().plus(1, ChronoUnit.DAYS));
        when(repository.findByTokenHash(RefreshTokenService.hash("abc"))).thenReturn(Optional.of(row));

        UserAccount owner = service.use("abc");

        assertSame(user, owner);
        assertTrue(row.getExpiresAt().isAfter(Instant.now().plus(179, ChronoUnit.DAYS)));
    }

    @Test
    void useRejectsRevokedExpiredUnknownAndDisabled() {
        UserRefreshToken revoked = activeRow(Instant.now().plus(1, ChronoUnit.DAYS));
        revoked.setRevokedAt(Instant.now());
        when(repository.findByTokenHash(RefreshTokenService.hash("revoked"))).thenReturn(Optional.of(revoked));
        assertThrows(ApiException.class, () -> service.use("revoked"));

        UserRefreshToken expired = activeRow(Instant.now().minus(1, ChronoUnit.MINUTES));
        when(repository.findByTokenHash(RefreshTokenService.hash("expired"))).thenReturn(Optional.of(expired));
        assertThrows(ApiException.class, () -> service.use("expired"));

        when(repository.findByTokenHash(RefreshTokenService.hash("unknown"))).thenReturn(Optional.empty());
        assertThrows(ApiException.class, () -> service.use("unknown"));
        assertThrows(ApiException.class, () -> service.use(" "));

        user.setEnabled(false);
        UserRefreshToken locked = activeRow(Instant.now().plus(1, ChronoUnit.DAYS));
        when(repository.findByTokenHash(RefreshTokenService.hash("locked"))).thenReturn(Optional.of(locked));
        assertThrows(ApiException.class, () -> service.use("locked"));
        assertNotNull(locked.getRevokedAt());
    }

    @Test
    void revokeMarksTokenRevoked() {
        UserRefreshToken row = activeRow(Instant.now().plus(1, ChronoUnit.DAYS));
        when(repository.findByTokenHash(RefreshTokenService.hash("abc"))).thenReturn(Optional.of(row));

        service.revoke("abc");

        assertNotNull(row.getRevokedAt());
    }

    private UserRefreshToken activeRow(Instant expiresAt) {
        return UserRefreshToken.builder()
                .user(user)
                .tokenHash("x")
                .createdAt(Instant.now())
                .lastUsedAt(Instant.now())
                .expiresAt(expiresAt)
                .build();
    }
}
