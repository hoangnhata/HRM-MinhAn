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

    /**
     * Lưu công văn đính kèm (ảnh, PDF, Word, Excel). Trả về đường dẫn tương đối.
     */
    public String storeDocument(MultipartFile file, String subdirectory, Set<String> allowedExtensions, long maxBytes) {
        if (file == null || file.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "File rỗng");
        }
        if (file.getSize() > maxBytes) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Mỗi tệp đính kèm tối đa " + (maxBytes / (1024 * 1024)) + "MB");
        }
        String original = file.getOriginalFilename();
        String ext = extensionOf(original);
        if (ext.isEmpty() || !allowedExtensions.contains(ext)) {
            throw new ApiException(HttpStatus.BAD_REQUEST,
                    "Chỉ đính kèm ảnh (PNG, JPG, WEBP), PDF, Word hoặc Excel");
        }
        try {
            Path base = Paths.get(hrmProperties.getUpload().getDir()).toAbsolutePath().normalize();
            Path dir = base.resolve(subdirectory).normalize();
            if (!dir.startsWith(base)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Đường dẫn không hợp lệ");
            }
            Files.createDirectories(dir);
            String storedName = UUID.randomUUID() + "." + ext;
            Path target = dir.resolve(storedName);
            Files.copy(file.getInputStream(), target, StandardCopyOption.REPLACE_EXISTING);
            return base.relativize(target).toString().replace('\\', '/');
        } catch (ApiException e) {
            throw e;
        } catch (IOException e) {
            log.error("Lưu công văn thất bại", e);
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không thể lưu tệp đính kèm");
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

    /** Lưu ảnh PNG/JPEG chữ ký — trả về đường dẫn tương đối. */
    public String storeImageBytes(byte[] data, String contentType, String subdirectory, String filePrefix) {
        if (data == null || data.length == 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ảnh rỗng");
        }
        if (data.length > 2 * 1024 * 1024) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Ảnh chữ ký tối đa 2MB");
        }
        String ct = contentType != null ? contentType.toLowerCase(Locale.ROOT) : "image/png";
        String ext = ct.contains("jpeg") || ct.contains("jpg") ? ".jpg" : ".png";
        try {
            Path base = Paths.get(hrmProperties.getUpload().getDir()).toAbsolutePath().normalize();
            Path dir = base.resolve(subdirectory).normalize();
            if (!dir.startsWith(base)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "Đường dẫn không hợp lệ");
            }
            Files.createDirectories(dir);
            String storedName = (filePrefix != null ? filePrefix : UUID.randomUUID().toString()) + ext;
            Path target = dir.resolve(storedName);
            Files.write(target, data);
            return base.relativize(target).toString().replace('\\', '/');
        } catch (IOException e) {
            log.error("Lưu ảnh chữ ký thất bại", e);
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không thể lưu chữ ký");
        }
    }

    private static String sanitize(String name) {
        return name.replaceAll("[^a-zA-Z0-9._-]", "_");
    }

    private static String extensionOf(String name) {
        if (name == null) {
            return "";
        }
        String base = Paths.get(name).getFileName().toString();
        int dot = base.lastIndexOf('.');
        if (dot < 0 || dot == base.length() - 1) {
            return "";
        }
        return base.substring(dot + 1).toLowerCase(Locale.ROOT);
    }
}
