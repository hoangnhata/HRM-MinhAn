package com.minhan.hrm.config;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.MediaTypeFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Phục vụ React build từ thư mục ngoài JAR trước khi vào Spring MVC.
 * Tránh 500 do ResourceHandler / NoResourceFoundException.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 20)
@ConditionalOnProperty(prefix = "minhan.hrm.frontend", name = "enabled", havingValue = "true")
public class FrontendStaticFilter extends OncePerRequestFilter {

    private final Path root;

    public FrontendStaticFilter(@Value("${minhan.hrm.frontend.dir}") String frontendDir) {
        this.root = Paths.get(frontendDir).toAbsolutePath().normalize();
        if (!Files.isDirectory(root)) {
            throw new IllegalStateException("Thu muc frontend khong ton tai: " + root);
        }
        if (!Files.isRegularFile(root.resolve("index.html"))) {
            throw new IllegalStateException("Khong tim thay index.html trong: " + root);
        }
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        if (!HttpMethod.GET.matches(request.getMethod()) && !HttpMethod.HEAD.matches(request.getMethod())) {
            return true;
        }
        String path = normalize(request.getRequestURI());
        return path.startsWith("/j1-api/")
                || path.startsWith("/actuator/")
                || path.startsWith("/swagger-ui")
                || path.startsWith("/api-docs")
                || path.startsWith("/v3/");
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String path = normalize(request.getRequestURI());
        if (path.isEmpty() || "/".equals(path)) {
            serve(root.resolve("index.html"), response, false);
            return;
        }

        String relative = path.startsWith("/") ? path.substring(1) : path;
        Path candidate = root.resolve(relative).normalize();
        if (candidate.startsWith(root) && Files.isRegularFile(candidate)) {
            serve(candidate, response, relative.startsWith("assets/"));
            return;
        }

        // SPA fallback: route React (khong co extension)
        if (!relative.contains(".")) {
            serve(root.resolve("index.html"), response, false);
            return;
        }

        response.setStatus(HttpServletResponse.SC_NOT_FOUND);
    }

    private void serve(Path file, HttpServletResponse response, boolean longCache) throws IOException {
        MediaType mediaType = MediaTypeFactory.getMediaType(file.getFileName().toString())
                .orElse(MediaType.APPLICATION_OCTET_STREAM);
        response.setStatus(HttpServletResponse.SC_OK);
        response.setContentType(mediaType.toString());
        response.setHeader("Cache-Control", longCache
                ? "public, max-age=31536000, immutable"
                : "no-cache");
        long size = Files.size(file);
        response.setContentLengthLong(size);
        try (InputStream in = Files.newInputStream(file); OutputStream out = response.getOutputStream()) {
            in.transferTo(out);
        }
    }

    private static String normalize(String uri) {
        if (uri == null || uri.isEmpty()) {
            return "/";
        }
        int q = uri.indexOf('?');
        if (q >= 0) {
            uri = uri.substring(0, q);
        }
        return uri;
    }
}
