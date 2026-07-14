package com.minhan.hrm.duty;

import com.minhan.hrm.attendance.AttendanceShiftSchedule;
import com.minhan.hrm.entity.DutyRoleTier;
import com.minhan.hrm.entity.DutyShiftType;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;

public final class DutyShiftCalculator {

    public static final BigDecimal DUTY_WORK_UNITS = AttendanceShiftSchedule.AFTERNOON_UNITS;
    private static final BigDecimal TK_FACTOR = new BigDecimal("0.5");
    /** Mức thưởng trong biểu mẫu tính theo nghìn đồng (500 = 500.000đ). */
    private static final BigDecimal BONUS_UNIT_THOUSAND = BigDecimal.valueOf(1000);
    private static final int WORK_DAYS_PER_MONTH = 26;

    private DutyShiftCalculator() {}

    public record CalculationResult(
            BigDecimal bonusAmount,
            BigDecimal workUnits,
            BigDecimal postDutyPay) {}

    public static List<DutyRoleTier> tiersForShiftType(DutyShiftType type) {
        return switch (type) {
            case TRUC_TOI_CHINH -> List.of(
                    DutyRoleTier.BS_NSN_XQ_SA,
                    DutyRoleTier.NV_TAI_KHOA,
                    DutyRoleTier.THU_NGAN_DUOC);
            case TC1 -> List.of(DutyRoleTier.BS, DutyRoleTier.DIEU_DUONG);
            case TCC -> List.of(
                    DutyRoleTier.BS_DA_KHOA,
                    DutyRoleTier.DD_CAP_CUU,
                    DutyRoleTier.COC1_NOI_NHI);
            case TK -> List.of(DutyRoleTier.values());
        };
    }

    public static int baseBonusAmountThousands(DutyShiftType type, DutyRoleTier tier) {
        return switch (type) {
            case TRUC_TOI_CHINH -> switch (tier) {
                case BS_NSN_XQ_SA -> 350;
                case NV_TAI_KHOA -> 230;
                case THU_NGAN_DUOC -> 200;
                default -> 230;
            };
            case TC1 -> switch (tier) {
                case BS, BS_NSN_XQ_SA, BS_DA_KHOA -> 500;
                case DIEU_DUONG, DD_CAP_CUU -> 350;
                default -> 350;
            };
            case TCC -> switch (tier) {
                case BS, BS_NSN_XQ_SA, BS_DA_KHOA -> 300;
                case DIEU_DUONG, DD_CAP_CUU, COC1_NOI_NHI -> 250;
                default -> 250;
            };
            case TK -> referenceBonusForTk(tier);
        };
    }

    /** Trực kèm: 50% mức trực chính theo vị trí tương ứng. */
    private static int referenceBonusForTk(DutyRoleTier tier) {
        int base = switch (tier) {
            case BS_NSN_XQ_SA, BS, BS_DA_KHOA -> 350;
            case THU_NGAN_DUOC -> 200;
            case DIEU_DUONG, DD_CAP_CUU, COC1_NOI_NHI -> 230;
            default -> 230;
        };
        return BigDecimal.valueOf(base)
                .multiply(TK_FACTOR)
                .setScale(0, RoundingMode.HALF_UP)
                .intValue();
    }

    public static CalculationResult calculate(
            DutyShiftType type, DutyRoleTier tier, BigDecimal monthlyTotalSalary) {
        int bonusThousands = baseBonusAmountThousands(type, tier);
        BigDecimal bonusAmount = BigDecimal.valueOf(bonusThousands).multiply(BONUS_UNIT_THOUSAND);

        if (type == DutyShiftType.TK) {
            return new CalculationResult(bonusAmount, BigDecimal.ZERO, BigDecimal.ZERO);
        }

        BigDecimal salary = monthlyTotalSalary != null ? monthlyTotalSalary : BigDecimal.ZERO;
        BigDecimal postDutyPay = salary
                .divide(BigDecimal.valueOf(WORK_DAYS_PER_MONTH), 6, RoundingMode.HALF_UP)
                .multiply(DUTY_WORK_UNITS)
                .setScale(0, RoundingMode.HALF_UP);

        return new CalculationResult(bonusAmount, DUTY_WORK_UNITS, postDutyPay);
    }

    public static Set<DutyShiftType> typesWithWorkUnits() {
        return EnumSet.of(DutyShiftType.TRUC_TOI_CHINH, DutyShiftType.TC1, DutyShiftType.TCC);
    }
}
