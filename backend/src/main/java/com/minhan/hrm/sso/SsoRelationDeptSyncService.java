package com.minhan.hrm.sso;

import com.minhan.hrm.entity.Department;
import com.minhan.hrm.entity.DepartmentWorkUnit;
import com.minhan.hrm.repository.DepartmentRepository;
import com.minhan.hrm.repository.DepartmentWorkUnitRepository;
import lombok.Getter;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.text.Normalizer;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * Đồng bộ danh mục phòng ban / bộ phận HRM → {@code chamcong.dbo.RelationDept}
 * (cây tổ chức phần mềm tổng: tài sản, chấm công, …).
 *
 * <p>Không đổi tên bản ghi SSO đã có — chỉ khớp theo tên (bỏ dấu) rồi gán ID.
 * Thiếu thì tạo mới, gắn {@code RelationID} về phòng ban cha hoặc gốc MinhAn.
 */
@Slf4j
@Service
@ConditionalOnProperty(prefix = "minhan.hrm.chamcong", name = "enabled", havingValue = "true")
public class SsoRelationDeptSyncService {

    private final JdbcTemplate chamcongJdbc;
    private final DepartmentRepository departmentRepository;
    private final DepartmentWorkUnitRepository workUnitRepository;

    public SsoRelationDeptSyncService(
            @Qualifier("chamcongJdbcTemplate") JdbcTemplate chamcongJdbc,
            DepartmentRepository departmentRepository,
            DepartmentWorkUnitRepository workUnitRepository) {
        this.chamcongJdbc = chamcongJdbc;
        this.departmentRepository = departmentRepository;
        this.workUnitRepository = workUnitRepository;
    }

    @Transactional
    public RelationDeptCatalog syncCatalogFromHrm() {
        Map<String, RelationDeptRow> byKey = loadExisting();
        int rootId = resolveRootId(byKey);
        int created = 0;
        int matched = 0;

        Map<Long, Integer> hrmDeptToSsoId = new HashMap<>();

        List<Department> departments = departmentRepository.findAll();
        for (Department dept : departments) {
            if (dept == null || dept.getName() == null || dept.getName().isBlank()) {
                continue;
            }
            String name = dept.getName().trim();
            RelationDeptRow row = findBest(byKey, name);
            if (row != null) {
                matched++;
                hrmDeptToSsoId.put(dept.getId(), row.id());
                indexAliases(byKey, name, row);
                continue;
            }
            Integer id = insertRelationDept(name, rootId, 1, suggestDeptCode(name));
            if (id != null) {
                created++;
                RelationDeptRow createdRow = new RelationDeptRow(id, name, rootId, 1);
                indexAliases(byKey, name, createdRow);
                hrmDeptToSsoId.put(dept.getId(), id);
            }
        }

        int unitsCreated = 0;
        int unitsMatched = 0;
        Map<String, Integer> unitKeyToId = new LinkedHashMap<>();

        List<DepartmentWorkUnit> units = workUnitRepository.findAll();
        for (DepartmentWorkUnit unit : units) {
            if (unit == null || unit.getName() == null || unit.getName().isBlank()) {
                continue;
            }
            String unitName = unit.getName().trim();
            Department parent = unit.getDepartment();
            Integer parentSsoId = parent != null ? hrmDeptToSsoId.get(parent.getId()) : null;
            if (parentSsoId == null) {
                parentSsoId = rootId;
            }

            RelationDeptRow row = findBest(byKey, unitName);
            if (row != null) {
                unitsMatched++;
                indexUnitKeys(unitKeyToId, parent != null ? parent.getId() : null, unitName, row.id());
                indexAliases(byKey, unitName, row);
                continue;
            }
            Integer id = insertRelationDept(unitName, parentSsoId, 2, suggestDeptCode(unitName));
            if (id != null) {
                unitsCreated++;
                RelationDeptRow createdRow = new RelationDeptRow(id, unitName, parentSsoId, 2);
                indexAliases(byKey, unitName, createdRow);
                indexUnitKeys(unitKeyToId, parent != null ? parent.getId() : null, unitName, id);
            }
        }

        Map<String, RelationDeptRow> fresh = loadExisting();
        log.info("Sync RelationDept: matchedDept={}, createdDept={}, matchedUnit={}, createdUnit={}, total={}",
                matched, created, unitsMatched, unitsCreated, fresh.size());

        return new RelationDeptCatalog(
                fresh, hrmDeptToSsoId, unitKeyToId, created + unitsCreated, matched + unitsMatched);
    }

    private void indexUnitKeys(Map<String, Integer> map, Long hrmDeptId, String unitName, int ssoId) {
        map.put(orgKey(unitName), ssoId);
        if (hrmDeptId != null) {
            map.put(hrmDeptId + "|" + orgKey(unitName), ssoId);
        }
    }

    private Map<String, RelationDeptRow> loadExisting() {
        Map<String, RelationDeptRow> byKey = new LinkedHashMap<>();
        try {
            List<Map<String, Object>> rows = chamcongJdbc.queryForList(
                    """
                    SELECT ID, Description, RelationID, LevelID
                    FROM dbo.RelationDept
                    """);
            for (Map<String, Object> r : rows) {
                Integer id = toInt(r.get("ID"));
                String desc = r.get("Description") != null ? String.valueOf(r.get("Description")).trim() : null;
                if (id == null || desc == null || desc.isBlank()) {
                    continue;
                }
                RelationDeptRow row = new RelationDeptRow(
                        id,
                        desc,
                        toInt(r.get("RelationID")),
                        toInt(r.get("LevelID")));
                indexAliases(byKey, desc, row);
            }
        } catch (DataAccessException ex) {
            log.error("Không đọc được dbo.RelationDept trên chamcong: {}", ex.getMessage());
            throw ex;
        }
        return byKey;
    }

    private void indexAliases(Map<String, RelationDeptRow> byKey, String rawName, RelationDeptRow row) {
        byKey.put(orgKey(rawName), row);
        for (String alias : aliasesOf(rawName)) {
            byKey.putIfAbsent(orgKey(alias), row);
        }
    }

    private RelationDeptRow findBest(Map<String, RelationDeptRow> byKey, String name) {
        String key = orgKey(name);
        RelationDeptRow hit = byKey.get(key);
        if (hit != null) {
            return hit;
        }
        for (String alias : aliasesOf(name)) {
            hit = byKey.get(orgKey(alias));
            if (hit != null) {
                return hit;
            }
        }
        return null;
    }

    private int resolveRootId(Map<String, RelationDeptRow> byKey) {
        for (String candidate : List.of("minhan", "benhvienminhan")) {
            RelationDeptRow row = byKey.get(candidate);
            if (row != null) {
                return row.id();
            }
        }
        Optional<RelationDeptRow> id1 = byKey.values().stream().filter(r -> r.id() == 1).findFirst();
        if (id1.isPresent()) {
            return 1;
        }
        return byKey.values().stream()
                .filter(r -> r.relationId() == null || r.relationId() == 0 || r.relationId() == r.id())
                .map(RelationDeptRow::id)
                .findFirst()
                .orElse(1);
    }

    private Integer insertRelationDept(String description, int relationId, int levelId, String deptCode) {
        try {
            KeyHolder keys = new GeneratedKeyHolder();
            chamcongJdbc.update(con -> {
                PreparedStatement ps = con.prepareStatement(
                        """
                        INSERT INTO dbo.RelationDept (Description, RelationID, LevelID, DeptCode)
                        VALUES (?, ?, ?, ?)
                        """,
                        Statement.RETURN_GENERATED_KEYS);
                ps.setNString(1, description);
                ps.setInt(2, relationId);
                ps.setInt(3, levelId);
                ps.setString(4, deptCode);
                return ps;
            }, keys);
            Number key = keys.getKey();
            if (key != null) {
                return key.intValue();
            }
            RelationDeptRow row = findBest(loadExisting(), description);
            return row != null ? row.id() : null;
        } catch (DataAccessException ex) {
            log.warn("Không tạo RelationDept \"{}\": {} — thử INSERT tối giản", description, ex.getMessage());
            try {
                chamcongJdbc.update(
                        "INSERT INTO dbo.RelationDept (Description, RelationID) VALUES (?, ?)",
                        description, relationId);
                RelationDeptRow row = findBest(loadExisting(), description);
                return row != null ? row.id() : null;
            } catch (DataAccessException ex2) {
                log.error("Tạo RelationDept thất bại \"{}\": {}", description, ex2.getMessage());
                return null;
            }
        }
    }

    private static String suggestDeptCode(String name) {
        String base = orgKey(name);
        if (base.length() > 20) {
            base = base.substring(0, 20);
        }
        if (base.isBlank()) {
            return "D" + Integer.toHexString(Math.abs(name.hashCode())).toUpperCase(Locale.ROOT);
        }
        return base.toUpperCase(Locale.ROOT);
    }

    private static List<String> aliasesOf(String name) {
        String key = orgKey(name);
        return switch (key) {
            case "bangiamdoc", "bangd", "bgd" -> List.of("Ban GĐ", "BAN GIÁM ĐỐC", "Ban Giám đốc");
            case "khoanoinhi", "noinhi" -> List.of("KHOA NỘI NHI", "KHOA NỘI - NHI", "Khoa Nội - Nhi");
            case "kinhdoanhphattrien", "phongkinhdoanhphattrien" ->
                    List.of("PHÒNG KINH DOANH & PHÁT TRIỂN", "PHÒNG KINH DOANH PHÁT TRIỂN");
            case "hoisuccapcuu", "hscc" ->
                    List.of("KHOA HỒI SỨC CẤP CỨU", "HỒI SỨC CẤP CỨU");
            case "congnghethongtin", "cntt", "it" -> List.of("CÔNG NGHỆ THÔNG TIN");
            case "thungan" -> List.of("THU NGÂN");
            case "chamsockhachhang", "cskh" -> List.of("CHĂM SÓC KHÁCH HÀNG");
            default -> List.of(name);
        };
    }

    static String orgKey(String s) {
        if (s == null) {
            return "";
        }
        String n = Normalizer.normalize(s, Normalizer.Form.NFD)
                .replaceAll("\\p{InCombiningDiacriticalMarks}+", "")
                .replace('\u0111', 'd')
                .replace('\u0110', 'D')
                .toLowerCase(Locale.ROOT)
                .replaceAll("^(khoa|phong)\\s+", "")
                .replaceAll("[^a-z0-9]", "");
        return n;
    }

    private static Integer toInt(Object v) {
        if (v == null) {
            return null;
        }
        if (v instanceof Number n) {
            return n.intValue();
        }
        try {
            return Integer.parseInt(String.valueOf(v).trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    public record RelationDeptRow(int id, String description, Integer relationId, Integer levelId) {
    }

    @Getter
    public static final class RelationDeptCatalog {
        private final Map<String, RelationDeptRow> byKey;
        private final Map<Long, Integer> hrmDepartmentToSsoId;
        private final Map<String, Integer> unitKeyToId;
        private final int created;
        private final int matched;

        RelationDeptCatalog(
                Map<String, RelationDeptRow> byKey,
                Map<Long, Integer> hrmDepartmentToSsoId,
                Map<String, Integer> unitKeyToId,
                int created,
                int matched) {
            this.byKey = byKey;
            this.hrmDepartmentToSsoId = hrmDepartmentToSsoId;
            this.unitKeyToId = unitKeyToId;
            this.created = created;
            this.matched = matched;
        }

        public ResolvedDept resolve(Long hrmDepartmentId, String departmentName, String workUnitDetail) {
            String unit = blankToNull(workUnitDetail);
            String dept = blankToNull(departmentName);

            if (unit != null && hrmDepartmentId != null) {
                Integer id = unitKeyToId.get(hrmDepartmentId + "|" + orgKey(unit));
                if (id != null) {
                    return toResolved(id);
                }
            }
            if (unit != null) {
                Integer id = unitKeyToId.get(orgKey(unit));
                if (id != null) {
                    return toResolved(id);
                }
                RelationDeptRow row = byKey.get(orgKey(unit));
                if (row != null) {
                    return new ResolvedDept(row.id(), row.description());
                }
            }
            if (hrmDepartmentId != null) {
                Integer id = hrmDepartmentToSsoId.get(hrmDepartmentId);
                if (id != null) {
                    return toResolved(id);
                }
            }
            if (dept != null) {
                RelationDeptRow row = byKey.get(orgKey(dept));
                if (row != null) {
                    return new ResolvedDept(row.id(), row.description());
                }
            }
            return null;
        }

        private ResolvedDept toResolved(int id) {
            for (RelationDeptRow row : byKey.values()) {
                if (row.id() == id) {
                    return new ResolvedDept(row.id(), row.description());
                }
            }
            return new ResolvedDept(id, null);
        }

        private static String blankToNull(String s) {
            if (s == null || s.isBlank()) {
                return null;
            }
            return s.trim();
        }
    }

    public record ResolvedDept(int id, String description) {
    }
}
