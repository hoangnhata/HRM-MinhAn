package com.minhan.hrm.service;

import com.minhan.hrm.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.xssf.usermodel.XSSFCellStyle;
import org.apache.poi.xssf.usermodel.XSSFColor;
import org.apache.poi.xssf.usermodel.XSSFFont;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.format.TextStyle;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * Xuất báo cáo công toàn viện theo tháng ra file Excel (.xlsx) với định dạng chuyên nghiệp.
 */
@Service
@RequiredArgsConstructor
public class AttendanceReportExcelService {

    private final AttendanceSummaryService summaryService;

    private static final String BRAND = "0F766E";        // teal đậm
    private static final String BRAND_LIGHT = "CCFBF1";   // teal nhạt
    private static final String HEADER_TEXT = "FFFFFF";
    private static final String ZEBRA = "F1F5F9";         // xám nhạt xen kẽ
    private static final String TOTAL_FILL = "E2E8F0";
    private static final String WARN_FILL = "FEE2E2";     // đỏ nhạt (kỷ luật)

    private static final Locale VI = new Locale("vi", "VN");

    private static final String[] SUMMARY_HEADERS = {
            "STT", "Mã NV", "Họ và tên", "Phòng ban", "Chức vụ",
            "Công chấm", "Công trực", "Tổng công", "Số ca trực",
            "Phút đi muộn", "Phạt đi muộn (đ)", "Số lần quên chấm", "Phạt quên chấm (đ)",
            "Thưởng trực (đ)", "Phụ cấp ăn (đ)", "Kỷ luật"
    };

    private static final String[] DETAIL_HEADERS = {
            "Mã NV", "Họ và tên", "Phòng ban", "Ngày", "Thứ", "Trạng thái",
            "Vào sáng", "Ra sáng", "Vào chiều", "Ra chiều",
            "Công sáng", "Công chiều", "Ngoài giờ", "Tổng công ngày", "Phút muộn", "Ghi chú"
    };

    @Transactional(readOnly = true)
    public byte[] buildMonthlyReport(int year, int month, Long departmentId) {
        if (month < 1 || month > 12) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "Tháng không hợp lệ");
        }
        List<Map<String, Object>> rows = summaryService.monthReport(year, month, departmentId);

        try (XSSFWorkbook wb = new XSSFWorkbook(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Styles styles = new Styles(wb);
            String deptName = rows.isEmpty() || departmentId == null
                    ? "Toàn bệnh viện"
                    : String.valueOf(rows.get(0).get("department"));
            writeSummarySheet(wb, styles, rows, year, month, deptName);
            writeCalendarSheet(wb, styles, rows, year, month, deptName);
            writeDutyCalendarSheet(wb, styles, rows, year, month, deptName);
            writeDetailSheet(wb, styles, rows);
            wb.write(out);
            return out.toByteArray();
        } catch (Exception ex) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "Không tạo được file Excel: " + ex.getMessage());
        }
    }

    // ----------------------------------------------------------------- Sheet 1

    private void writeSummarySheet(
            Workbook wb, Styles s, List<Map<String, Object>> rows, int year, int month, String deptName) {
        Sheet sheet = wb.createSheet("Tổng hợp");
        sheet.setDisplayGridlines(false);
        int lastCol = SUMMARY_HEADERS.length - 1;

        // Tiêu đề
        int r = 0;
        r = title(sheet, s, r, lastCol, "BỆNH VIỆN MINH AN");
        r = subtitle(sheet, s, r, lastCol, "BÁO CÁO CÔNG THÁNG " + String.format("%02d/%d", month, year));
        r = meta(sheet, s, r, lastCol, "Phạm vi: " + deptName
                + "     •     Tổng số nhân viên: " + rows.size()
                + "     •     Xuất ngày: " + LocalDate.now().format(DateTimeFormatter.ofPattern("dd/MM/yyyy")));
        r++; // dòng trống

        int headerRowIdx = r;
        Row header = sheet.createRow(r++);
        header.setHeightInPoints(26f);
        for (int c = 0; c <= lastCol; c++) {
            Cell cell = header.createCell(c);
            cell.setCellValue(SUMMARY_HEADERS[c]);
            cell.setCellStyle(s.header);
        }

        BigDecimal sumAtt = BigDecimal.ZERO;
        BigDecimal sumDuty = BigDecimal.ZERO;
        BigDecimal sumTotal = BigDecimal.ZERO;
        long sumDutyShifts = 0;
        long sumLateMin = 0;
        BigDecimal sumLatePenalty = BigDecimal.ZERO;
        long sumForgotCount = 0;
        BigDecimal sumForgotPenalty = BigDecimal.ZERO;
        BigDecimal sumDutyBonus = BigDecimal.ZERO;
        BigDecimal sumMeal = BigDecimal.ZERO;

        int idx = 1;
        for (Map<String, Object> row : rows) {
            boolean discipline = Boolean.TRUE.equals(row.get("requiresDiscipline"));
            boolean zebra = idx % 2 == 0;
            Row dr = sheet.createRow(r++);
            dr.setHeightInPoints(18f);

            BigDecimal att = num(row.get("attendanceWorkUnits"));
            BigDecimal duty = num(row.get("dutyWorkUnitsTotal"));
            BigDecimal total = num(row.get("totalWorkUnits"));
            long dutyShifts = lng(row.get("dutyShiftCount"));
            long lateMin = lng(row.get("lateMinutesTotal"));
            BigDecimal latePenalty = num(row.get("latePenalty"));
            long forgotCount = lng(row.get("forgotFineCount"));
            BigDecimal forgotPenalty = num(row.get("forgotPenalty"));
            BigDecimal dutyBonus = num(row.get("dutyBonusTotal"));
            BigDecimal meal = num(row.get("mealAllowance"));

            sumAtt = sumAtt.add(att);
            sumDuty = sumDuty.add(duty);
            sumTotal = sumTotal.add(total);
            sumDutyShifts += dutyShifts;
            sumLateMin += lateMin;
            sumLatePenalty = sumLatePenalty.add(latePenalty);
            sumForgotCount += forgotCount;
            sumForgotPenalty = sumForgotPenalty.add(forgotPenalty);
            sumDutyBonus = sumDutyBonus.add(dutyBonus);
            sumMeal = sumMeal.add(meal);

            CellStyle textStyle = discipline ? s.warnText : (zebra ? s.textZebra : s.text);
            CellStyle centerStyle = discipline ? s.warnCenter : (zebra ? s.centerZebra : s.center);
            CellStyle numStyle = discipline ? s.warnNum2 : (zebra ? s.num2Zebra : s.num2);
            CellStyle moneyStyle = discipline ? s.warnMoney : (zebra ? s.moneyZebra : s.money);

            int c = 0;
            setCell(dr, c++, idx, centerStyle);
            setCell(dr, c++, str(row.get("employeeCode")), centerStyle);
            setCell(dr, c++, str(row.get("fullName")), textStyle);
            setCell(dr, c++, str(row.get("department")), textStyle);
            setCell(dr, c++, str(row.get("position")), textStyle);
            setCell(dr, c++, att, numStyle);
            setCell(dr, c++, duty, numStyle);
            setCell(dr, c++, total, discipline ? s.warnNum2Bold : (zebra ? s.num2BoldZebra : s.num2Bold));
            setCell(dr, c++, dutyShifts, centerStyle);
            setCell(dr, c++, lateMin, centerStyle);
            setCell(dr, c++, latePenalty, moneyStyle);
            setCell(dr, c++, forgotCount, centerStyle);
            setCell(dr, c++, forgotPenalty, moneyStyle);
            setCell(dr, c++, dutyBonus, moneyStyle);
            setCell(dr, c++, meal, moneyStyle);
            setCell(dr, c, discipline ? "Cần xử lý" : "", discipline ? s.warnCenterBold : centerStyle);
            idx++;
        }

        // Dòng tổng cộng
        Row totalRow = sheet.createRow(r++);
        totalRow.setHeightInPoints(20f);
        setCell(totalRow, 0, "TỔNG CỘNG", s.totalText);
        for (int c = 1; c <= 4; c++) {
            setCell(totalRow, c, "", s.totalText);
        }
        setCell(totalRow, 5, sumAtt, s.totalNum2);
        setCell(totalRow, 6, sumDuty, s.totalNum2);
        setCell(totalRow, 7, sumTotal, s.totalNum2);
        setCell(totalRow, 8, sumDutyShifts, s.totalCenter);
        setCell(totalRow, 9, sumLateMin, s.totalCenter);
        setCell(totalRow, 10, sumLatePenalty, s.totalMoney);
        setCell(totalRow, 11, sumForgotCount, s.totalCenter);
        setCell(totalRow, 12, sumForgotPenalty, s.totalMoney);
        setCell(totalRow, 13, sumDutyBonus, s.totalMoney);
        setCell(totalRow, 14, sumMeal, s.totalMoney);
        setCell(totalRow, 15, "", s.totalText);

        // Độ rộng cột
        int[] widths = {1600, 2600, 6600, 6200, 5200, 2600, 2600, 2600, 2200,
                2600, 4200, 3400, 4200, 4200, 4200, 3000};
        for (int c = 0; c <= lastCol; c++) {
            sheet.setColumnWidth(c, widths[c]);
        }

        sheet.createFreezePane(0, headerRowIdx + 1);
        sheet.setAutoFilter(new CellRangeAddress(headerRowIdx, headerRowIdx, 0, lastCol));

        // Ghi chú cuối
        r++;
        Row noteRow = sheet.createRow(r);
        Cell noteCell = noteRow.createCell(0);
        noteCell.setCellValue("Ghi chú: Đơn vị công = ngày công (1.0 = cả ngày, 0.5 = nửa ngày). "
                + "Dòng tô đỏ là nhân viên cần xem xét kỷ luật do vi phạm giờ giấc.");
        noteCell.setCellStyle(s.footnote);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
    }

    // ----------------------------------------------------------------- Sheet 2 (bảng chấm công)

    private void writeCalendarSheet(
            XSSFWorkbook wb, Styles s, List<Map<String, Object>> rows, int year, int month, String deptName) {
        Sheet sheet = wb.createSheet("Bảng chấm công");
        sheet.setDisplayGridlines(false);

        java.time.YearMonth ym = java.time.YearMonth.of(year, month);
        int daysInMonth = ym.lengthOfMonth();
        int fixedCols = 4; // STT, Mã NV, Họ tên, Chức vụ
        int firstDayCol = fixedCols;
        int totalCol = firstDayCol + daysInMonth;
        int lastCol = totalCol;

        int r = 0;
        r = title(sheet, s, r, lastCol, "BẢNG CHẤM CÔNG THÁNG " + String.format("%02d/%d", month, year));
        r = meta(sheet, s, r, lastCol, "Phạm vi: " + deptName + "     •     Số công theo từng ngày (1.0 = cả ngày)");
        r++;

        // Hàng 1 tiêu đề: nhóm "Ngày trong tháng"
        int headerTop = r;
        Row top = sheet.createRow(r++);
        top.setHeightInPoints(20f);
        // Hàng 2 tiêu đề: số ngày
        int headerBottom = r;
        Row bottom = sheet.createRow(r++);
        bottom.setHeightInPoints(20f);

        String[] fixed = {"TT", "Mã NV", "Họ và tên", "Chức vụ"};
        for (int c = 0; c < fixedCols; c++) {
            Cell t = top.createCell(c);
            t.setCellValue(fixed[c]);
            t.setCellStyle(s.header);
            Cell b = bottom.createCell(c);
            b.setCellStyle(s.header);
            sheet.addMergedRegion(new CellRangeAddress(headerTop, headerBottom, c, c));
        }

        Cell groupCell = top.createCell(firstDayCol);
        groupCell.setCellValue("Ngày trong tháng");
        groupCell.setCellStyle(s.header);
        sheet.addMergedRegion(new CellRangeAddress(headerTop, headerTop, firstDayCol, firstDayCol + daysInMonth - 1));

        for (int d = 1; d <= daysInMonth; d++) {
            int col = firstDayCol + d - 1;
            LocalDate date = ym.atDay(d);
            boolean weekend = date.getDayOfWeek() == java.time.DayOfWeek.SATURDAY
                    || date.getDayOfWeek() == java.time.DayOfWeek.SUNDAY;
            // top: bỏ trống ô (đã merge nhóm ở trên nên ô top của cột ngày nằm trong vùng merge)
            Cell dayHead = bottom.createCell(col);
            dayHead.setCellValue(d);
            dayHead.setCellStyle(weekend ? s.dayHeaderWeekend : s.dayHeader);
        }

        Cell totalTop = top.createCell(totalCol);
        totalTop.setCellValue("Tổng công");
        totalTop.setCellStyle(s.header);
        bottom.createCell(totalCol).setCellStyle(s.header);
        sheet.addMergedRegion(new CellRangeAddress(headerTop, headerBottom, totalCol, totalCol));

        // Dữ liệu
        int idx = 1;
        for (Map<String, Object> emp : rows) {
            boolean zebra = idx % 2 == 0;
            Row dr = sheet.createRow(r++);
            dr.setHeightInPoints(17f);

            setCell(dr, 0, idx, zebra ? s.centerZebra : s.center);
            setCell(dr, 1, str(emp.get("employeeCode")), zebra ? s.centerZebra : s.center);
            setCell(dr, 2, str(emp.get("fullName")), zebra ? s.textZebra : s.text);
            setCell(dr, 3, str(emp.get("position")), zebra ? s.textZebra : s.text);

            // map ngày -> tổng công
            Map<Integer, BigDecimal> unitsByDay = new java.util.HashMap<>();
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> days = (List<Map<String, Object>>) emp.get("days");
            if (days != null) {
                for (Map<String, Object> day : days) {
                    LocalDate date = LocalDate.parse(str(day.get("workDate")));
                    unitsByDay.merge(date.getDayOfMonth(), num(day.get("totalWorkUnits")), BigDecimal::add);
                }
            }

            for (int d = 1; d <= daysInMonth; d++) {
                int col = firstDayCol + d - 1;
                LocalDate date = ym.atDay(d);
                boolean weekend = date.getDayOfWeek() == java.time.DayOfWeek.SATURDAY
                        || date.getDayOfWeek() == java.time.DayOfWeek.SUNDAY;
                CellStyle style = weekend
                        ? (zebra ? s.dayCellWeekendZebra : s.dayCellWeekend)
                        : (zebra ? s.dayCellZebra : s.dayCell);
                BigDecimal v = unitsByDay.get(d);
                Cell cell = dr.createCell(col);
                if (v != null && v.compareTo(BigDecimal.ZERO) > 0) {
                    cell.setCellValue(v.doubleValue());
                }
                cell.setCellStyle(style);
            }

            setCell(dr, totalCol, num(emp.get("attendanceWorkUnits")), zebra ? s.num2BoldZebra : s.num2Bold);
            idx++;
        }

        // Độ rộng cột
        sheet.setColumnWidth(0, 1400);
        sheet.setColumnWidth(1, 2600);
        sheet.setColumnWidth(2, 6200);
        sheet.setColumnWidth(3, 5000);
        for (int d = 1; d <= daysInMonth; d++) {
            sheet.setColumnWidth(firstDayCol + d - 1, 1150);
        }
        sheet.setColumnWidth(totalCol, 2800);

        sheet.createFreezePane(fixedCols, headerBottom + 1);

        r++;
        Row noteRow = sheet.createRow(r);
        Cell noteCell = noteRow.createCell(0);
        noteCell.setCellValue("Ghi chú: Ô trống = không có công. Cột ngày cuối tuần được tô nền nhạt. "
                + "Cột «Tổng công» là tổng công chấm trong tháng (chưa gồm công trực).");
        noteCell.setCellStyle(s.footnote);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
    }

    // ----------------------------------------------------------------- Sheet công trực (lịch)

    private void writeDutyCalendarSheet(
            XSSFWorkbook wb, Styles s, List<Map<String, Object>> rows, int year, int month, String deptName) {
        Sheet sheet = wb.createSheet("Bảng công trực");
        sheet.setDisplayGridlines(false);

        java.time.YearMonth ym = java.time.YearMonth.of(year, month);
        int daysInMonth = ym.lengthOfMonth();
        int fixedCols = 4; // STT, Mã NV, Họ tên, Chức vụ
        int firstDayCol = fixedCols;
        int countCol = firstDayCol + daysInMonth;     // Số ca trực
        int unitsCol = countCol + 1;                  // Tổng công trực
        int bonusCol = unitsCol + 1;                  // Thưởng trực (đ)
        int lastCol = bonusCol;

        int r = 0;
        r = title(sheet, s, r, lastCol, "BẢNG CÔNG TRỰC THÁNG " + String.format("%02d/%d", month, year));
        r = meta(sheet, s, r, lastCol, "Phạm vi: " + deptName
                + "     •     Công trực theo từng ngày (mỗi ca = " + "0,33 công" + ")");
        r++;

        int headerTop = r;
        Row top = sheet.createRow(r++);
        top.setHeightInPoints(20f);
        int headerBottom = r;
        Row bottom = sheet.createRow(r++);
        bottom.setHeightInPoints(20f);

        String[] fixed = {"TT", "Mã NV", "Họ và tên", "Chức vụ"};
        for (int c = 0; c < fixedCols; c++) {
            Cell t = top.createCell(c);
            t.setCellValue(fixed[c]);
            t.setCellStyle(s.header);
            Cell b = bottom.createCell(c);
            b.setCellStyle(s.header);
            sheet.addMergedRegion(new CellRangeAddress(headerTop, headerBottom, c, c));
        }

        Cell groupCell = top.createCell(firstDayCol);
        groupCell.setCellValue("Ngày trong tháng");
        groupCell.setCellStyle(s.header);
        sheet.addMergedRegion(new CellRangeAddress(headerTop, headerTop, firstDayCol, firstDayCol + daysInMonth - 1));

        for (int d = 1; d <= daysInMonth; d++) {
            int col = firstDayCol + d - 1;
            LocalDate date = ym.atDay(d);
            boolean weekend = date.getDayOfWeek() == java.time.DayOfWeek.SATURDAY
                    || date.getDayOfWeek() == java.time.DayOfWeek.SUNDAY;
            Cell dayHead = bottom.createCell(col);
            dayHead.setCellValue(d);
            dayHead.setCellStyle(weekend ? s.dayHeaderWeekend : s.dayHeader);
        }

        String[] tail = {"Số ca", "Tổng công", "Thưởng (đ)"};
        int[] tailCols = {countCol, unitsCol, bonusCol};
        for (int i = 0; i < tail.length; i++) {
            Cell t = top.createCell(tailCols[i]);
            t.setCellValue(tail[i]);
            t.setCellStyle(s.header);
            bottom.createCell(tailCols[i]).setCellStyle(s.header);
            sheet.addMergedRegion(new CellRangeAddress(headerTop, headerBottom, tailCols[i], tailCols[i]));
        }

        long sumShiftsAll = 0;
        BigDecimal sumUnitsAll = BigDecimal.ZERO;
        BigDecimal sumBonusAll = BigDecimal.ZERO;

        int idx = 1;
        for (Map<String, Object> emp : rows) {
            boolean zebra = idx % 2 == 0;
            Row dr = sheet.createRow(r++);
            dr.setHeightInPoints(17f);

            setCell(dr, 0, idx, zebra ? s.centerZebra : s.center);
            setCell(dr, 1, str(emp.get("employeeCode")), zebra ? s.centerZebra : s.center);
            setCell(dr, 2, str(emp.get("fullName")), zebra ? s.textZebra : s.text);
            setCell(dr, 3, str(emp.get("position")), zebra ? s.textZebra : s.text);

            Map<Integer, BigDecimal> unitsByDay = new java.util.HashMap<>();
            Map<Integer, String> labelByDay = new java.util.HashMap<>();
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> dutyDays = (List<Map<String, Object>>) emp.get("dutyDays");
            if (dutyDays != null) {
                for (Map<String, Object> duty : dutyDays) {
                    LocalDate date = LocalDate.parse(str(duty.get("workDate")));
                    unitsByDay.merge(date.getDayOfMonth(), num(duty.get("workUnits")), BigDecimal::add);
                    labelByDay.put(date.getDayOfMonth(), str(duty.get("shiftTypeLabel")));
                }
            }

            for (int d = 1; d <= daysInMonth; d++) {
                int col = firstDayCol + d - 1;
                LocalDate date = ym.atDay(d);
                boolean weekend = date.getDayOfWeek() == java.time.DayOfWeek.SATURDAY
                        || date.getDayOfWeek() == java.time.DayOfWeek.SUNDAY;
                CellStyle style = weekend
                        ? (zebra ? s.dayCellWeekendZebra : s.dayCellWeekend)
                        : (zebra ? s.dayCellZebra : s.dayCell);
                BigDecimal v = unitsByDay.get(d);
                Cell cell = dr.createCell(col);
                if (v != null && v.compareTo(BigDecimal.ZERO) > 0) {
                    cell.setCellValue(v.doubleValue());
                }
                cell.setCellStyle(style);
            }

            long shifts = lng(emp.get("dutyShiftCount"));
            BigDecimal units = num(emp.get("dutyWorkUnitsTotal"));
            BigDecimal bonus = num(emp.get("dutyBonusTotal"));
            sumShiftsAll += shifts;
            sumUnitsAll = sumUnitsAll.add(units);
            sumBonusAll = sumBonusAll.add(bonus);

            setCell(dr, countCol, shifts, zebra ? s.centerZebra : s.center);
            setCell(dr, unitsCol, units, zebra ? s.num2BoldZebra : s.num2Bold);
            setCell(dr, bonusCol, bonus, zebra ? s.moneyZebra : s.money);
            idx++;
        }

        // Dòng tổng cộng
        Row totalRow = sheet.createRow(r++);
        totalRow.setHeightInPoints(20f);
        setCell(totalRow, 0, "TỔNG CỘNG", s.totalText);
        for (int c = 1; c < countCol; c++) {
            setCell(totalRow, c, "", s.totalText);
        }
        setCell(totalRow, countCol, sumShiftsAll, s.totalCenter);
        setCell(totalRow, unitsCol, sumUnitsAll, s.totalNum2);
        setCell(totalRow, bonusCol, sumBonusAll, s.totalMoney);

        sheet.setColumnWidth(0, 1400);
        sheet.setColumnWidth(1, 2600);
        sheet.setColumnWidth(2, 6200);
        sheet.setColumnWidth(3, 5000);
        for (int d = 1; d <= daysInMonth; d++) {
            sheet.setColumnWidth(firstDayCol + d - 1, 1150);
        }
        sheet.setColumnWidth(countCol, 2200);
        sheet.setColumnWidth(unitsCol, 2800);
        sheet.setColumnWidth(bonusCol, 4200);

        sheet.createFreezePane(fixedCols, headerBottom + 1);

        r++;
        Row noteRow = sheet.createRow(r);
        Cell noteCell = noteRow.createCell(0);
        noteCell.setCellValue("Ghi chú: Ô trống = không có ca trực. Cột «Tổng công» là tổng công trực trong tháng "
                + "(mỗi ca trực chính cộng 0,33 công). Cột «Thưởng» là tổng tiền thưởng trực.");
        noteCell.setCellStyle(s.footnote);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
    }

    // ----------------------------------------------------------------- Sheet 3

    private void writeDetailSheet(Workbook wb, Styles s, List<Map<String, Object>> rows) {
        Sheet sheet = wb.createSheet("Chi tiết theo ngày");
        sheet.setDisplayGridlines(false);
        int lastCol = DETAIL_HEADERS.length - 1;

        int r = 0;
        r = title(sheet, s, r, lastCol, "CHI TIẾT CÔNG THEO NGÀY (GIỜ CHẤM)");
        r++;

        int headerRowIdx = r;
        Row header = sheet.createRow(r++);
        header.setHeightInPoints(24f);
        for (int c = 0; c <= lastCol; c++) {
            Cell cell = header.createCell(c);
            cell.setCellValue(DETAIL_HEADERS[c]);
            cell.setCellStyle(s.header);
        }

        int block = 0;
        for (Map<String, Object> emp : rows) {
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> days = (List<Map<String, Object>>) emp.get("days");
            if (days == null || days.isEmpty()) {
                continue;
            }
            boolean zebra = block % 2 == 1;
            CellStyle textStyle = zebra ? s.textZebra : s.text;
            CellStyle centerStyle = zebra ? s.centerZebra : s.center;
            CellStyle numStyle = zebra ? s.num2Zebra : s.num2;
            for (Map<String, Object> day : days) {
                Row dr = sheet.createRow(r++);
                dr.setHeightInPoints(16.5f);
                LocalDate date = LocalDate.parse(str(day.get("workDate")));
                int c = 0;
                setCell(dr, c++, str(emp.get("employeeCode")), centerStyle);
                setCell(dr, c++, str(emp.get("fullName")), textStyle);
                setCell(dr, c++, str(emp.get("department")), textStyle);
                setCell(dr, c++, date.format(DateTimeFormatter.ofPattern("dd/MM/yyyy")), centerStyle);
                setCell(dr, c++, weekdayVi(date), centerStyle);
                setCell(dr, c++, statusLabel(str(day.get("status"))), centerStyle);
                setCell(dr, c++, str(day.get("morningCheckIn")), centerStyle);
                setCell(dr, c++, str(day.get("morningCheckOut")), centerStyle);
                setCell(dr, c++, str(day.get("afternoonCheckIn")), centerStyle);
                setCell(dr, c++, str(day.get("afternoonCheckOut")), centerStyle);
                setCell(dr, c++, num(day.get("morningWorkUnits")), numStyle);
                setCell(dr, c++, num(day.get("afternoonWorkUnits")), numStyle);
                setCell(dr, c++, num(day.get("overtimeWorkUnits")), numStyle);
                setCell(dr, c++, num(day.get("totalWorkUnits")), numStyle);
                setCell(dr, c++, lng(day.get("lateMinutes")), centerStyle);
                setCell(dr, c, str(day.get("note")), textStyle);
            }
            block++;
        }

        int[] widths = {2600, 6200, 6000, 2800, 1600, 3000,
                2200, 2200, 2200, 2200, 2200, 2200, 2200, 3000, 2200, 8000};
        for (int c = 0; c <= lastCol; c++) {
            sheet.setColumnWidth(c, widths[c]);
        }
        sheet.createFreezePane(0, headerRowIdx + 1);
        sheet.setAutoFilter(new CellRangeAddress(headerRowIdx, headerRowIdx, 0, lastCol));
    }

    // ----------------------------------------------------------------- helpers

    private int title(Sheet sheet, Styles s, int r, int lastCol, String text) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(28f);
        Cell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(s.title);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    private int subtitle(Sheet sheet, Styles s, int r, int lastCol, String text) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(22f);
        Cell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(s.subtitle);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    private int meta(Sheet sheet, Styles s, int r, int lastCol, String text) {
        Row row = sheet.createRow(r);
        row.setHeightInPoints(18f);
        Cell cell = row.createCell(0);
        cell.setCellValue(text);
        cell.setCellStyle(s.meta);
        sheet.addMergedRegion(new CellRangeAddress(r, r, 0, lastCol));
        return r + 1;
    }

    private static void setCell(Row row, int col, String value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(value != null ? value : "");
        cell.setCellStyle(style);
    }

    private static void setCell(Row row, int col, long value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(value);
        cell.setCellStyle(style);
    }

    private static void setCell(Row row, int col, BigDecimal value, CellStyle style) {
        Cell cell = row.createCell(col);
        cell.setCellValue(value != null ? value.doubleValue() : 0d);
        cell.setCellStyle(style);
    }

    private static String str(Object v) {
        return v != null ? String.valueOf(v) : "";
    }

    private static BigDecimal num(Object v) {
        if (v == null) return BigDecimal.ZERO;
        if (v instanceof BigDecimal b) return b;
        if (v instanceof Number n) return BigDecimal.valueOf(n.doubleValue());
        try {
            return new BigDecimal(v.toString());
        } catch (NumberFormatException ex) {
            return BigDecimal.ZERO;
        }
    }

    private static long lng(Object v) {
        if (v instanceof Number n) return n.longValue();
        try {
            return v != null ? Long.parseLong(v.toString()) : 0L;
        } catch (NumberFormatException ex) {
            return 0L;
        }
    }

    private static String weekdayVi(LocalDate d) {
        return switch (d.getDayOfWeek()) {
            case MONDAY -> "T2";
            case TUESDAY -> "T3";
            case WEDNESDAY -> "T4";
            case THURSDAY -> "T5";
            case FRIDAY -> "T6";
            case SATURDAY -> "T7";
            case SUNDAY -> "CN";
        };
    }

    private static String statusLabel(String status) {
        if (status == null) return "";
        return switch (status) {
            case "PRESENT" -> "Đủ công";
            case "PARTIAL" -> "Thiếu ca";
            case "ABSENT" -> "Vắng";
            case "LEAVE" -> "Phép";
            case "UNPAID_LEAVE" -> "Không lương";
            case "BUSINESS_TRIP" -> "Công tác";
            default -> status;
        };
    }

    @SuppressWarnings("unused")
    private static String monthNameVi(int month) {
        return LocalDate.of(2000, month, 1)
                .getMonth()
                .getDisplayName(TextStyle.FULL, VI);
    }

    /** Tập hợp các CellStyle dùng chung. */
    private static final class Styles {
        final CellStyle title;
        final CellStyle subtitle;
        final CellStyle meta;
        final CellStyle footnote;
        final CellStyle header;

        final CellStyle text;
        final CellStyle center;
        final CellStyle num2;
        final CellStyle num2Bold;
        final CellStyle money;

        final CellStyle textZebra;
        final CellStyle centerZebra;
        final CellStyle num2Zebra;
        final CellStyle num2BoldZebra;
        final CellStyle moneyZebra;

        final CellStyle warnText;
        final CellStyle warnCenter;
        final CellStyle warnCenterBold;
        final CellStyle warnNum2;
        final CellStyle warnNum2Bold;
        final CellStyle warnMoney;

        final CellStyle totalText;
        final CellStyle totalCenter;
        final CellStyle totalNum2;
        final CellStyle totalMoney;

        final CellStyle dayHeader;
        final CellStyle dayHeaderWeekend;
        final CellStyle dayCell;
        final CellStyle dayCellZebra;
        final CellStyle dayCellWeekend;
        final CellStyle dayCellWeekendZebra;

        Styles(XSSFWorkbook wb) {
            DataFormat fmt = wb.createDataFormat();
            short money = fmt.getFormat("#,##0");
            short num2 = fmt.getFormat("0.00");

            XSSFFont titleFont = font(wb, 16, true, BRAND);
            XSSFFont subFont = font(wb, 13, true, "1F2937");
            XSSFFont metaFont = font(wb, 10, false, "475569");
            XSSFFont headFont = font(wb, 10, true, HEADER_TEXT);
            XSSFFont bodyFont = font(wb, 10, false, "1F2937");
            XSSFFont boldBody = font(wb, 10, true, "0F172A");
            XSSFFont warnFont = font(wb, 10, false, "991B1B");
            XSSFFont warnBold = font(wb, 10, true, "991B1B");
            XSSFFont totalFont = font(wb, 10, true, "0F172A");
            XSSFFont footFont = font(wb, 9, false, "64748B");
            footFont.setItalic(true);

            this.title = base(wb, titleFont, HorizontalAlignment.CENTER, null, false);
            this.subtitle = base(wb, subFont, HorizontalAlignment.CENTER, null, false);
            this.meta = base(wb, metaFont, HorizontalAlignment.CENTER, null, false);
            this.footnote = base(wb, footFont, HorizontalAlignment.LEFT, null, false);

            this.header = base(wb, headFont, HorizontalAlignment.CENTER, BRAND, true);
            this.header.setVerticalAlignment(VerticalAlignment.CENTER);
            this.header.setWrapText(true);

            this.text = body(wb, bodyFont, HorizontalAlignment.LEFT, null, (short) 0);
            this.center = body(wb, bodyFont, HorizontalAlignment.CENTER, null, (short) 0);
            this.num2 = body(wb, bodyFont, HorizontalAlignment.CENTER, null, num2);
            this.num2Bold = body(wb, boldBody, HorizontalAlignment.CENTER, null, num2);
            this.money = body(wb, bodyFont, HorizontalAlignment.RIGHT, null, money);

            this.textZebra = body(wb, bodyFont, HorizontalAlignment.LEFT, ZEBRA, (short) 0);
            this.centerZebra = body(wb, bodyFont, HorizontalAlignment.CENTER, ZEBRA, (short) 0);
            this.num2Zebra = body(wb, bodyFont, HorizontalAlignment.CENTER, ZEBRA, num2);
            this.num2BoldZebra = body(wb, boldBody, HorizontalAlignment.CENTER, ZEBRA, num2);
            this.moneyZebra = body(wb, bodyFont, HorizontalAlignment.RIGHT, ZEBRA, money);

            this.warnText = body(wb, warnFont, HorizontalAlignment.LEFT, WARN_FILL, (short) 0);
            this.warnCenter = body(wb, warnFont, HorizontalAlignment.CENTER, WARN_FILL, (short) 0);
            this.warnCenterBold = body(wb, warnBold, HorizontalAlignment.CENTER, WARN_FILL, (short) 0);
            this.warnNum2 = body(wb, warnFont, HorizontalAlignment.CENTER, WARN_FILL, num2);
            this.warnNum2Bold = body(wb, warnBold, HorizontalAlignment.CENTER, WARN_FILL, num2);
            this.warnMoney = body(wb, warnFont, HorizontalAlignment.RIGHT, WARN_FILL, money);

            this.totalText = body(wb, totalFont, HorizontalAlignment.LEFT, TOTAL_FILL, (short) 0);
            this.totalCenter = body(wb, totalFont, HorizontalAlignment.CENTER, TOTAL_FILL, (short) 0);
            this.totalNum2 = body(wb, totalFont, HorizontalAlignment.CENTER, TOTAL_FILL, num2);
            this.totalMoney = body(wb, totalFont, HorizontalAlignment.RIGHT, TOTAL_FILL, money);

            XSSFFont dayHeadFont = font(wb, 9, true, HEADER_TEXT);
            XSSFFont dayFont = font(wb, 9, false, "1F2937");
            short dayFmt = fmt.getFormat("0.##");
            this.dayHeader = body(wb, dayHeadFont, HorizontalAlignment.CENTER, BRAND, (short) 0);
            this.dayHeaderWeekend = body(wb, dayHeadFont, HorizontalAlignment.CENTER, "0B5C55", (short) 0);
            this.dayCell = body(wb, dayFont, HorizontalAlignment.CENTER, null, dayFmt);
            this.dayCellZebra = body(wb, dayFont, HorizontalAlignment.CENTER, ZEBRA, dayFmt);
            this.dayCellWeekend = body(wb, dayFont, HorizontalAlignment.CENTER, "FEF3C7", dayFmt);
            this.dayCellWeekendZebra = body(wb, dayFont, HorizontalAlignment.CENTER, "FDE9B8", dayFmt);
        }

        private static XSSFFont font(XSSFWorkbook wb, int size, boolean bold, String hex) {
            XSSFFont f = wb.createFont();
            f.setFontName("Calibri");
            f.setFontHeightInPoints((short) size);
            f.setBold(bold);
            f.setColor(rgb(hex));
            return f;
        }

        private static XSSFCellStyle base(
                XSSFWorkbook wb, XSSFFont font, HorizontalAlignment align, String fillHex, boolean bordered) {
            XSSFCellStyle st = wb.createCellStyle();
            st.setFont(font);
            st.setAlignment(align);
            st.setVerticalAlignment(VerticalAlignment.CENTER);
            if (fillHex != null) {
                st.setFillForegroundColor(rgb(fillHex));
                st.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            }
            if (bordered) {
                thin(st);
            }
            return st;
        }

        private static XSSFCellStyle body(
                XSSFWorkbook wb, XSSFFont font, HorizontalAlignment align, String fillHex, short format) {
            XSSFCellStyle st = base(wb, font, align, fillHex, true);
            if (format != 0) {
                st.setDataFormat(format);
            }
            return st;
        }

        private static void thin(XSSFCellStyle st) {
            XSSFColor color = rgb("CBD5E1");
            st.setBorderTop(BorderStyle.THIN);
            st.setBorderBottom(BorderStyle.THIN);
            st.setBorderLeft(BorderStyle.THIN);
            st.setBorderRight(BorderStyle.THIN);
            st.setTopBorderColor(color);
            st.setBottomBorderColor(color);
            st.setLeftBorderColor(color);
            st.setRightBorderColor(color);
        }

        private static XSSFColor rgb(String hex) {
            int r = Integer.valueOf(hex.substring(0, 2), 16);
            int g = Integer.valueOf(hex.substring(2, 4), 16);
            int b = Integer.valueOf(hex.substring(4, 6), 16);
            return new XSSFColor(new byte[]{(byte) r, (byte) g, (byte) b}, null);
        }
    }
}
