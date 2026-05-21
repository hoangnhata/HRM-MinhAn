package com.minhan.hrm.service;

import com.minhan.hrm.config.HrmProperties;
import com.minhan.hrm.exception.ApiException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class FileStorageService {

    private final HrmProperties hrmProperties;

    public String storePdf(MultipartFile file, String subdirectory) {
        if (file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "File rỗng");
        }
        String ct = file.getContentType();
        if (ct == null || !ct.toLowerCase(Locale.ROOT).contains("pdf")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Chỉ chấp nhận file PDF");
        }
        String original = file.getOriginalFilename();
        if (original == null || !original.toLowerCase(Locale.ROOT).endsWith(".pdf")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Phải là file .pdf");
        }

        try {
            Path base = Paths.get(hrmProperties.getUpload().getDir()).toAbsolutePath().normalize();
            Path dir = base.resolve(subdirectory).normalize();
            if (!dir.startsWith(base)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Đường dẫn không hợp lệ");
            }
            Files.createDirectories(dir);
            String storedName = UUID.randomUUID() + "_" + sanitize(original);
            Path target = dir.resolve(storedName);
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
            return base.relativize(target).toString().replace('\\', '/');
        } catch (IOException e) {
            log.error("Lưu file thất bại", e);
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không thể lưu file");
        }
    }

    private static final Set<String> ANNOUNCE_ALLOWED_EXT = Set.of(
            ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".jpg", ".jpeg", ".png", ".gif", ".webp", ".zip");

    /**
     * Đính kèm thông báo: PDF, Office, ảnh, zip (không giới hạn chỉ PDF).
     */
    public String storeAnnouncementFile(MultipartFile file, String subdirectory) {
        if (file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "File rỗng");
        }
        String original = file.getOriginalFilename();
        if (original == null || original.isBlank()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Thiếu tên file");
        }
        String lower = original.toLowerCase(Locale.ROOT);
        boolean okExt = ANNOUNCE_ALLOWED_EXT.stream().anyMatch(lower::endsWith);
        if (!okExt) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Định dạng file không được hỗ trợ");
        }

        try {
            Path base = Paths.get(hrmProperties.getUpload().getDir()).toAbsolutePath().normalize();
            Path dir = base.resolve(subdirectory).normalize();
            if (!dir.startsWith(base)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Đường dẫn không hợp lệ");
            }
            Files.createDirectories(dir);
            String storedName = UUID.randomUUID() + "_" + sanitize(original);
            Path target = dir.resolve(storedName);
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
            return base.relativize(target).toString().replace('\\', '/');
        } catch (IOException e) {
            log.error("Lưu file thất bại", e);
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không thể lưu file");
        }
    }

    public void deleteStoredFile(String relativePath) {
        if (relativePath == null || relativePath.isBlank()) {
            return;
        }
        try {
            Path p = resolveStoredPath(relativePath);
            Files.deleteIfExists(p);
        } catch (Exception e) {
            log.warn("Không xóa được file đính kèm: {}", relativePath, e);
        }
    }

    public Path resolveStoredPath(String relativePath) {
        Path base = Paths.get(hrmProperties.getUpload().getDir()).toAbsolutePath().normalize();
        Path resolved = base.resolve(relativePath).normalize();
        if (!resolved.startsWith(base)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Đường dẫn không hợp lệ");
        }
        return resolved;
    }

    private static String sanitize(String name) {
        return name.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}
