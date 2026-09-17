import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_mobile/core/utils/user_role.dart';
import 'package:hrm_mobile/features/nursing_daily_report/data/nursing_daily_report_models.dart';
import 'package:hrm_mobile/features/qtkt/data/qtkt_models.dart';
import 'package:hrm_mobile/features/reports/data/nursing_activity_report_repository.dart';

void main() {
  test('keeps mobile permissions aligned with web/backend roles', () {
    expect(
      RoleGroups.canEnterNursingDailyReports(UserRole.headNursing),
      isTrue,
    );
    expect(RoleGroups.canEnterQtkt(UserRole.headNursing), isTrue);
    expect(RoleGroups.canScoreQtkt(UserRole.headNursing), isFalse);
    expect(RoleGroups.canScoreQtkt(UserRole.headDepartment), isTrue);
    expect(RoleGroups.canScoreQtkt(UserRole.admin), isTrue);
    expect(RoleGroups.canEnterQtkt(UserRole.employee), isFalse);
  });

  group('Nursing daily report contract', () {
    test('maps all numeric fields returned by the shared backend', () {
      final report = NursingDailyReport.fromJson({
        'id': 9,
        'departmentId': 3,
        'departmentCode': 'KHOA_NOI',
        'departmentName': 'Khoa Nội - Nhi',
        'reportDate': '2026-08-22',
        'totalStaff': 20,
        'workingStaff': 12,
        'plannedLeave': 1,
        'unplannedLeave': 1,
        'maternityLeave': 2,
        'longLeave': 1,
        'dutyAfternoonOff': 2,
        'externalMission': 1,
        'inpatients': 34,
        'inpatientsCareLevel1': 10,
        'inpatientsCareLevel2': 14,
        'inpatientsCareLevel3': 10,
        'outpatients': 8,
        'paraclinical': 5,
        'surgery': 2,
        'dischargedYesterday': 4,
        'actualBeds': 42,
        'plannedBeds': 36,
        'inpatientTreatmentDays': 19,
        'falls': 1,
        'newPressureUlcers': 2,
        'idMixups': 0,
        'medicationErrors': 1,
      });

      expect(report.values, hasLength(23));
      expect(report.staffAccounted, 20);
      expect(report.safetyIncidents, 4);
      expect(report.values['inpatients'], 34);
      expect(report.values['inpatientsCareLevel1'], 10);
      expect(report.values['inpatientTreatmentDays'], 19);
    });

    test('maps month/day envelope and embedded report', () {
      final row = NursingDailyReportRow.fromJson({
        'departmentId': 3,
        'departmentName': 'Khoa Nội - Nhi',
        'reportDate': '2026-08-22',
        'submitted': true,
        'canEdit': true,
        'report': {
          'id': 9,
          'departmentId': 3,
          'departmentName': 'Khoa Nội - Nhi',
          'reportDate': '2026-08-22',
          'totalStaff': 20,
          'workingStaff': 12,
        },
      });

      expect(row.submitted, isTrue);
      expect(row.canEdit, isTrue);
      expect(row.report?.id, 9);
      expect(row.report?.workingStaff, 12);
    });
  });

  group('QTKT contract', () {
    test('maps server template, sections and score limits', () {
      final template = QtktTemplate.fromJson({
        'version': 1,
        'name': 'Đánh giá quy trình kỹ thuật điều dưỡng',
        'procedures': [
          {
            'code': 'IV_INJECTION',
            'name': 'Kỹ thuật tiêm tĩnh mạch',
            'durationMinutes': 8,
            'maxTotal': 10,
            'sections': [
              {
                'id': 'PREP',
                'title': 'I. Chuẩn bị',
                'steps': [
                  {
                    'id': 'IV_INJ_P1',
                    'no': 1,
                    'title': 'Chuẩn bị điều dưỡng',
                    'maxPoints': 0.5,
                  },
                ],
              },
              {
                'id': 'TECH',
                'title': 'II. Kỹ thuật tiến hành',
                'steps': [
                  {
                    'id': 'IV_INJ_T1',
                    'no': 1,
                    'title': 'Sát khuẩn tay nhanh',
                    'detail': 'Nội dung đầy đủ',
                    'maxPoints': 0.25,
                  },
                ],
              },
            ],
          },
        ],
      });

      final procedure = template.procedureByCode('IV_INJECTION');
      expect(procedure, isNotNull);
      expect(procedure?.stepCount, 2);
      expect(procedure?.sections.last.steps.first.detail, 'Nội dung đầy đủ');
      expect(procedure?.sections.first.maxPoints, 0.5);
    });

    test('maps evaluation score map and API status', () {
      final evaluation = QtktEvaluation.fromJson({
        'id': 88,
        'employeeId': 12,
        'employeeName': 'Nguyễn Thị Minh',
        'departmentId': 3,
        'departmentName': 'Khoa Nội - Nhi',
        'procedureCode': 'IV_INJECTION',
        'procedureName': 'Kỹ thuật tiêm tĩnh mạch',
        'evalDate': '2026-08-22',
        'scores': {'IV_INJ_P1': 0.5, 'IV_INJ_T1': 0.25},
        'totalScore': 0.75,
        'maxScore': 10,
        'status': 'SUBMITTED',
      });

      expect(evaluation.status, QtktEvaluationStatus.submitted);
      expect(evaluation.scores['IV_INJ_T1'], 0.25);
      expect(evaluation.percent, closeTo(0.075, 0.0001));
    });
  });

  group('QTKT score formatting', () {
    test('keeps whole numbers intact', () {
      // Bản cũ cắt số 0 cuối chuỗi nên thang điểm 10 hiện thành "1".
      expect(formatQtktScore(10), '10');
      expect(formatQtktScore(20), '20');
      expect(formatQtktScore(100), '100');
    });

    test('renders zero as "0", never an empty string', () {
      expect(formatQtktScore(0), '0');
    });

    test('trims only redundant decimal zeros', () {
      expect(formatQtktScore(0.5), '0.5');
      expect(formatQtktScore(1.25), '1.25');
      expect(formatQtktScore(9.75), '9.75');
      expect(formatQtktScore(2), '2');
      expect(formatQtktScore(1.1), '1.1');
    });
  });

  group('Nursing activity metric labels', () {
    test('splits a backend label into number and unit', () {
      final ratio = MetricLabelParts.parse('0.54 điều dưỡng/người bệnh');
      expect(ratio.value, '0.54');
      expect(ratio.unit, 'điều dưỡng/người bệnh');
      expect(ratio.hasData, isTrue);

      final rate = MetricLabelParts.parse('0.00%');
      expect(rate.value, '0.00%');
      expect(rate.unit, isNull);
      expect(rate.hasData, isTrue);

      final freq = MetricLabelParts.parse(
        '1.25 lượt té ngã/1.000 ngày điều trị',
      );
      expect(freq.value, '1.25');
      expect(freq.unit, 'lượt té ngã/1.000 ngày điều trị');
    });

    test('flags the backend placeholders as having no data', () {
      for (final text in const ['Chưa đủ dữ liệu', 'Không xác định', '—', '']) {
        expect(MetricLabelParts.parse(text).hasData, isFalse, reason: text);
      }
    });

    test(
      'nurse ratio is labelled per patient, matching the backend formula',
      () {
        // Backend: nurseBedRatio = workingStaff / inpatients (điều dưỡng đi làm
        // trên người bệnh nội trú) — nhãn "ĐD/giường" là sai chỉ số.
        final overview = NursingActivityMetricUi.forMetric(
          NursingActivityMetric.overview,
        );
        final ratioLabels = [
          ...overview.kpiFields,
          ...overview.deptLines,
        ].where((f) => f.$1 == 'nurseBedRatioLabel').map((f) => f.$2);

        expect(ratioLabels, isNotEmpty);
        for (final label in ratioLabels) {
          expect(label.toLowerCase(), isNot(contains('giường')), reason: label);
        }
        expect(NursingActivityMetric.nurseBed.label, 'ĐD/NB');
      },
    );
  });

  group('QTKT check options contract', () {
    test('parses the hand-hygiene moment group from the template', () {
      final procedure = QtktProcedure.fromJson({
        'code': 'HAND_WASH',
        'name': 'Quy trình rửa tay thường quy',
        'durationMinutes': 4,
        'maxTotal': 10,
        'sections': <dynamic>[],
        'checkOptions': {
          'label': 'Thời điểm rửa tay',
          'hint': 'Lựa chọn 1 trong 5 thời điểm trên',
          'options': [
            {
              'code': 'BEFORE_PATIENT',
              'label': 'Trước khi tiếp xúc với người bệnh',
            },
            {
              'code': 'AFTER_PATIENT',
              'label': 'Sau khi tiếp xúc với người bệnh',
            },
          ],
        },
      });

      final options = procedure.checkOptions;
      expect(options, isNotNull);
      expect(options!.label, 'Thời điểm rửa tay');
      expect(options.hint, 'Lựa chọn 1 trong 5 thời điểm trên');
      expect(options.options, hasLength(2));
      expect(
        options.labelForCode('AFTER_PATIENT'),
        'Sau khi tiếp xúc với người bệnh',
      );
      expect(options.labelForCode('KHONG_CO'), isNull);
    });

    test('procedures without the group parse to null', () {
      final procedure = QtktProcedure.fromJson({
        'code': 'OTHER',
        'name': 'Quy trình khác',
        'durationMinutes': 5,
        'maxTotal': 10,
        'sections': <dynamic>[],
      });
      expect(procedure.checkOptions, isNull);
    });

    test('evaluation keeps the chosen context returned by the API', () {
      final evaluation = QtktEvaluation.fromJson({
        'id': 7,
        'employeeId': 3,
        'employeeName': 'Hồ Thị Lan Anh',
        'departmentId': 2,
        'departmentName': 'KHOA CHẨN ĐOÁN HÌNH ẢNH',
        'procedureCode': 'HAND_WASH',
        'procedureName': 'Quy trình rửa tay thường quy',
        'evalDate': '2026-09-09',
        'scores': <String, dynamic>{},
        'totalScore': 9.75,
        'maxScore': 10,
        'status': 'SUBMITTED',
        'checkContextCode': 'BEFORE_ASEPTIC',
        'checkContextLabel': 'Trước khi làm thủ thuật vô khuẩn',
      });

      expect(evaluation.checkContextCode, 'BEFORE_ASEPTIC');
      expect(evaluation.checkContextLabel, 'Trước khi làm thủ thuật vô khuẩn');
    });
  });
}
