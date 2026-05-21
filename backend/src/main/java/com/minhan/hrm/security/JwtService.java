package com.minhan.hrm.security;

import com.minhan.hrm.config.HrmProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.Map;
import java.util.function.Function;

@Service
@RequiredArgsConstructor
public class JwtService {

    public static final String CLAIM_USER_ID = "uid";
    public static final String CLAIM_ROLE = "role";

    private final HrmProperties hrmProperties;

    public String extractUsername(String token) {
        return extractClaim(token, Claims::getSubject);
    }

    public <T> T extractClaim(String token, Function<Claims, T> resolver) {
        Claims claims = extractAllClaims(token);
        return resolver.apply(claims);
    }

    public String generateToken(UserDetails userDetails, Long userId, String roleName) {
        return Jwts.builder()
                .subject(userDetails.getUsername())
                .claims(Map.of(
                        CLAIM_USER_ID, userId,
                        CLAIM_ROLE, roleName))
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + hrmProperties.getJwt().getExpirationMs()))
                .signWith(signingKey())
                .compact();
    }

    public boolean isTokenValid(String token, UserDetails userDetails) {
        String user = extractUsername(token);
        return user != null && user.equals(userDetails.getUsername()) && !isTokenExpired(token);
    }

    private boolean isTokenExpired(String token) {
        return extractClaim(token, Claims::getExpiration).before(new Date());
    }

    private Claims extractAllClaims(String token) {
        return Jwts.parser()
                .verifyWith(signingKey())
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    private SecretKey signingKey() {
        String secret = hrmProperties.getJwt().getSecret();
        byte[] keyBytes;
        if (secret.length() < 32) {
            keyBytes = secret.getBytes(StandardCharsets.UTF_8);
        } else {
            try {
                keyBytes = Decoders.BASE64.decode(secret);
            } catch (RuntimeException e) {
                // Plain-text secrets (e.g. default in application.yml) are not Base64; jjwt throws DecodingException.
                keyBytes = secret.getBytes(StandardCharsets.UTF_8);
            }
        }
        return Keys.hmacShaKeyFor(keyBytes);
    }
}
