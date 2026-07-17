package com.minhan.hrm.sso;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.dto.auth.ErpLoginResponse;
import com.minhan.hrm.dto.auth.ErpProfileResponse;
import com.minhan.hrm.dto.auth.ErpProfileUpdateBody;
import com.minhan.hrm.dto.auth.ErpProfileUpdateResponse;
import com.minhan.hrm.exception.ApiException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

import java.util.Map;

/**
 * ERP SSO API — login + hồ sơ cá nhân (Bearer token ERP).
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ErpAuthClient {

    private final HrmProperties hrmProperties;

    public ErpLoginResponse login(String username, String password) {
        String url = resolveUrl(loginPath());
        try {
            ErpLoginResponse body = RestClient.create()
                    .post()
                    .uri(url)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                            "username", username.trim(),
                            "password", password))
                    .retrieve()
                    .body(ErpLoginResponse.class);

            if (body == null || body.getToken() == null || body.getToken().isBlank()) {
                throw new ApiException(HttpStatus.UNAUTHORIZED, "Đăng nhập ERP thất bại — không nhận được token");
            }
            return body;
        } catch (RestClientResponseException e) {
            throw mapHttpError(e, "login");
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.warn("ERP login error: {}", e.getMessage());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Không kết nối được máy chủ đăng nhập ERP");
        }
    }

    public ErpProfileResponse getProfile(String erpAccessToken) {
        requireToken(erpAccessToken);
        String url = resolveUrl(profilePath());
        try {
            ErpProfileResponse body = RestClient.create()
                    .get()
                    .uri(url)
                    .accept(MediaType.APPLICATION_JSON)
                    .header("Authorization", "Bearer " + erpAccessToken.trim())
                    .retrieve()
                    .body(ErpProfileResponse.class);
            if (body == null || body.getProfile() == null) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "ERP không trả về hồ sơ cá nhân");
            }
            return body;
        } catch (RestClientResponseException e) {
            throw mapHttpError(e, "profile");
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.warn("ERP get profile error: {}", e.getMessage());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Không tải được hồ sơ từ ERP");
        }
    }

    public ErpProfileUpdateResponse updateProfile(String erpAccessToken, ErpProfileUpdateBody body) {
        requireToken(erpAccessToken);
        String url = resolveUrl(profilePath());
        try {
            ErpProfileUpdateResponse res = RestClient.create()
                    .put()
                    .uri(url)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .header("Authorization", "Bearer " + erpAccessToken.trim())
                    .body(body)
                    .retrieve()
                    .body(ErpProfileUpdateResponse.class);
            if (res == null) {
                throw new ApiException(HttpStatus.BAD_GATEWAY, "ERP không phản hồi khi cập nhật hồ sơ");
            }
            return res;
        } catch (RestClientResponseException e) {
            throw mapHttpError(e, "profile-update");
        } catch (ApiException e) {
            throw e;
        } catch (Exception e) {
            log.warn("ERP update profile error: {}", e.getMessage());
            throw new ApiException(HttpStatus.BAD_GATEWAY, "Không cập nhật được hồ sơ trên ERP");
        }
    }

    /**
     * Tải ảnh avatar từ URL ERP (có thể cần Bearer). Trả về null nếu không lấy được.
     */
    public AvatarBytes fetchAvatar(String absoluteUrl, String erpAccessToken) {
        if (absoluteUrl == null || absoluteUrl.isBlank()) {
            return null;
        }
        AvatarBytes withAuth = fetchAvatarOnce(absoluteUrl, erpAccessToken);
        if (withAuth != null) {
            return withAuth;
        }
        // Một số static route chỉ cần cookie/public — thử lại không Bearer
        if (erpAccessToken != null && !erpAccessToken.isBlank()) {
            return fetchAvatarOnce(absoluteUrl, null);
        }
        return null;
    }

    private AvatarBytes fetchAvatarOnce(String absoluteUrl, String erpAccessToken) {
        try {
            RestClient.RequestHeadersSpec<?> request = RestClient.create()
                    .get()
                    .uri(absoluteUrl.trim())
                    .accept(MediaType.APPLICATION_OCTET_STREAM, MediaType.IMAGE_JPEG, MediaType.IMAGE_PNG, MediaType.ALL);
            if (erpAccessToken != null && !erpAccessToken.isBlank()) {
                request = request.header("Authorization", "Bearer " + erpAccessToken.trim());
            }
            byte[] bytes = request.retrieve().body(byte[].class);
            if (bytes == null || bytes.length < 24) {
                return null;
            }
            // Tránh nhận nhầm JSON lỗi (401 HTML/JSON) làm ảnh
            if (looksLikeJsonOrHtml(bytes)) {
                log.debug("ERP avatar candidate returned non-image: {}", absoluteUrl);
                return null;
            }
            return new AvatarBytes(bytes, guessImageContentType(absoluteUrl, bytes));
        } catch (Exception e) {
            log.debug("ERP fetch avatar failed ({}): {}", absoluteUrl, e.getMessage());
            return null;
        }
    }

    private static boolean looksLikeJsonOrHtml(byte[] bytes) {
        int i = 0;
        while (i < bytes.length && Character.isWhitespace((char) bytes[i])) {
            i++;
        }
        if (i >= bytes.length) {
            return true;
        }
        char c = (char) bytes[i];
        return c == '{' || c == '[' || c == '<';
    }

    public record AvatarBytes(byte[] data, String contentType) {}

    private static String guessImageContentType(String url, byte[] bytes) {
        String lower = url.toLowerCase();
        if (lower.contains(".png") || (bytes.length >= 8 && bytes[0] == (byte) 0x89 && bytes[1] == 0x50)) {
            return MediaType.IMAGE_PNG_VALUE;
        }
        if (lower.contains(".gif") || (bytes.length >= 3 && bytes[0] == 'G' && bytes[1] == 'I' && bytes[2] == 'F')) {
            return MediaType.IMAGE_GIF_VALUE;
        }
        if (lower.contains(".webp")) {
            return "image/webp";
        }
        if (bytes.length >= 3 && (bytes[0] & 0xFF) == 0xFF && (bytes[1] & 0xFF) == 0xD8) {
            return MediaType.IMAGE_JPEG_VALUE;
        }
        return MediaType.IMAGE_JPEG_VALUE;
    }

    private String loginPath() {
        HrmProperties.ErpAuth cfg = hrmProperties.getErpAuth();
        String path = cfg.getLoginPath();
        return path == null || path.isBlank() ? "/api/auth/login" : path.trim();
    }

    private String profilePath() {
        HrmProperties.ErpAuth cfg = hrmProperties.getErpAuth();
        String path = cfg.getProfilePath();
        return path == null || path.isBlank() ? "/api/auth/profile" : path.trim();
    }

    private String resolveUrl(String path) {
        HrmProperties.ErpAuth cfg = hrmProperties.getErpAuth();
        String base = cfg.getBaseUrl();
        if (base == null || base.isBlank()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "Chưa cấu hình ERP auth base-url");
        }
        String baseUrl = base.endsWith("/") ? base.substring(0, base.length() - 1) : base.trim();
        String p = path.startsWith("/") ? path : "/" + path;
        return baseUrl + p;
    }

    private static void requireToken(String erpAccessToken) {
        if (erpAccessToken == null || erpAccessToken.isBlank()) {
            throw new ApiException(HttpStatus.UNAUTHORIZED,
                    "Phiên ERP hết hạn hoặc chưa liên kết — vui lòng đăng nhập lại");
        }
    }

    private ApiException mapHttpError(RestClientResponseException e, String action) {
        int code = e.getStatusCode().value();
        if (code == 401 || code == 403) {
            if ("login".equals(action)) {
                return new ApiException(HttpStatus.UNAUTHORIZED, "Sai số điện thoại hoặc mật khẩu");
            }
            return new ApiException(HttpStatus.UNAUTHORIZED,
                    "Phiên ERP hết hạn — vui lòng đăng nhập lại");
        }
        log.warn("ERP {} HTTP {}: {}", action, code, e.getResponseBodyAsString());
        return new ApiException(HttpStatus.BAD_GATEWAY, "Không kết nối được máy chủ ERP");
    }
}
