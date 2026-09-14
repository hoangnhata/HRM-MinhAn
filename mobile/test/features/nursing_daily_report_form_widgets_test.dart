import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_mobile/features/nursing_daily_report/presentation/nursing_integer_stepper.dart';

/// Bọc widget trong khung điện thoại hẹp để bắt lỗi tràn bố cục.
Widget _phoneHost(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(360, 760)),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('NursingIntegerStepper', () {
    testWidgets('renders long labels on a narrow phone without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _phoneHost(
          NursingReportSection(
            step: '04',
            title: 'Hoạt động điều trị',
            children: [
              NursingIntegerStepper(
                label:
                    'Tổng ngày điều trị nội trú của người bệnh ra viện hôm qua',
                value: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Hoạt động điều trị'), findsOneWidget);
    });

    testWidgets('increments and decrements through the step buttons', (
      tester,
    ) async {
      var value = 0;

      await tester.pumpWidget(
        _phoneHost(
          StatefulBuilder(
            builder: (context, setState) => NursingIntegerStepper(
              label: 'Số nhân viên đi làm',
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(value, 1);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      expect(value, 0);
    });

    testWidgets('never drops below zero: minus is disabled at zero', (
      tester,
    ) async {
      var changes = 0;

      await tester.pumpWidget(
        _phoneHost(
          NursingIntegerStepper(
            label: 'Số ca té ngã ngày qua',
            value: 0,
            onChanged: (_) => changes++,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      expect(changes, 0);
    });

    testWidgets('typed digits are reported to the parent', (tester) async {
      var value = 0;

      await tester.pumpWidget(
        _phoneHost(
          StatefulBuilder(
            builder: (context, setState) => NursingIntegerStepper(
              label: 'Số người bệnh nội trú',
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '42');
      await tester.pumpAndSettle();
      expect(value, 42);
    });

    testWidgets('the value glyph sits centred between the two step buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        _phoneHost(
          NursingIntegerStepper(
            label: 'Số nhân viên đi làm',
            value: 5,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = find.byType(Icon);
      final minusX = tester.getRect(icons.at(0)).center.dx;
      final plusX = tester.getRect(icons.at(1)).center.dx;
      final expectedCentre = (minusX + plusX) / 2;

      // Vị trí thật của con số, không phải của ô chứa nó: TextField giữ chỗ cho
      // con trỏ nên ô có thể canh giữa mà chữ bên trong vẫn lệch.
      final editable = tester
          .state<EditableTextState>(find.byType(EditableText))
          .renderEditable;
      final endpoints = editable.getEndpointsForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 1),
      );
      final left = editable
          .localToGlobal(Offset(endpoints.first.point.dx, 0))
          .dx;
      final right = editable
          .localToGlobal(Offset(endpoints.last.point.dx, 0))
          .dx;
      final glyphCentre = (left + right) / 2;

      expect(
        (glyphCentre - expectedCentre).abs(),
        lessThan(0.5),
        reason:
            'Con số phải nằm giữa hai nút; lệch '
            '${(glyphCentre - expectedCentre).toStringAsFixed(2)}px',
      );
    });

    testWidgets('read-only mode blocks both buttons and the field', (
      tester,
    ) async {
      var changes = 0;

      await tester.pumpWidget(
        _phoneHost(
          NursingIntegerStepper(
            label: 'Số giường thực kê',
            value: 5,
            enabled: false,
            onChanged: (_) => changes++,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();

      expect(changes, 0);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });
  });

  group('NursingReportSection', () {
    testWidgets('renders every field row it is given', (tester) async {
      await tester.pumpWidget(
        _phoneHost(
          NursingReportSection(
            step: '01',
            title: 'Nhân lực',
            subtitle: 'Tình hình nhân sự trong ngày.',
            children: [
              for (final label in const [
                'Tổng số nhân viên khoa',
                'Số nhân viên đi làm',
                'Nghỉ theo kế hoạch',
              ])
                NursingIntegerStepper(
                  label: label,
                  value: 0,
                  onChanged: (_) {},
                ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(NursingIntegerStepper), findsNWidgets(3));
      expect(find.text('01'), findsOneWidget);
      expect(find.text('Tổng số nhân viên khoa'), findsOneWidget);
    });
  });
}
