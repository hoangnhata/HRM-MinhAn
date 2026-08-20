import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_ambient_background.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_time_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/skeleton.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../../shared/models/department.dart';
import '../../../shared/models/employee.dart';
import '../../employees/data/department_repository.dart';
import '../../employees/data/employee_repository.dart';
import '../../employees/presentation/org_unit_picker.dart';
import '../application/generic_request_controller.dart';
import '../data/generic_request_repository.dart';
import '../data/request_type_config.dart';
import '../data/seminar_proposal_utils.dart';

/// Tạo phiếu từ hồ sơ NV — luân chuyển / đào tạo / hội thảo (đồng bộ web).
class EmployeeProposalCreateScreen extends ConsumerStatefulWidget {
  const EmployeeProposalCreateScreen({
    super.key,
    required this.typeKey,
    required this.employeeId,
    this.requestId,
  });

  final String typeKey;
  final int employeeId;
  final int? requestId;

  @override
  ConsumerState<EmployeeProposalCreateScreen> createState() =>
      _EmployeeProposalCreateScreenState();
}

class _EmployeeProposalCreateScreenState
    extends ConsumerState<EmployeeProposalCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _reason = TextEditingController();
  final _proposingDept = TextEditingController();

  Department? _toDepartment;
  JobPosition? _toPosition;
  DateTime? _effectiveDate;

  final _courseName = TextEditingController();
  final _trainingLocation = TextEditingController();
  final _tuitionFee = TextEditingController();
  final _trainingGoal = TextEditingController();
  DateTime? _trainFrom;
  DateTime? _trainTo;

  final _seminarName = TextEditingController();
  final _seminarLocation = TextEditingController();
  DateTime? _seminarFrom;
  DateTime? _seminarTo;
  bool _seminarMultiDay = false;
  String _attendanceScope = 'FULL_DAY';

  bool _employeeAck = false;
  bool _departmentAck = false;

  bool _loading = true;
  bool _saving = false;
  EmployeeDetail? _employee;
  List<Map<String, dynamic>> _existingSeminarProposals = const [];

  // ===== Shift config change (shift-config-change) =====
  bool _applySummer = true;
  bool _applyWinter = true;

  TimeOfDay? _summerMorningIn;
  TimeOfDay? _summerMorningOut;
  TimeOfDay? _summerAfternoonIn;
  TimeOfDay? _summerAfternoonOut;

  TimeOfDay? _winterMorningIn;
  TimeOfDay? _winterMorningOut;
  TimeOfDay? _winterAfternoonIn;
  TimeOfDay? _winterAfternoonOut;

  double _morningUnits = 0.67;
  double _afternoonUnits = 0.33;

  static const _empCommitmentTraining =
      'Thực hiện đầy đủ khoá học, tuân thủ quy định Bệnh viện và đơn vị đào tạo; báo cáo kết quả học tập; thực hiện nghĩa vụ làm việc sau đào tạo theo Hợp đồng đào tạo chuyên môn.';
  static const _deptCommitmentTraining =
      'Bố trí, sắp xếp công việc và nhân lực trong thời gian đi học; theo dõi, giám sát và phối hợp HCNS đánh giá hiệu quả; tạo điều kiện ứng dụng kết quả đào tạo vào chuyên môn.';
  static const _empCommitmentSeminar =
      'Tuân thủ chương trình, nội quy đơn vị tổ chức; báo cáo kết quả sau khi tham dự hội thảo / công tác.';
  static const _deptCommitmentSeminar =
      'Bố trí nhân sự thay thế; theo dõi và tạo điều kiện ứng dụng kết quả sau hội thảo / công tác.';

  RequestTypeConfig? get _config => RequestTypeConfig.byKey(widget.typeKey);

  bool get _isTransfer => widget.typeKey == 'department-transfer';
  bool get _isTraining => widget.typeKey == 'training-proposal';
  bool get _isSeminar => widget.typeKey == 'seminar-proposal';
  bool get _isShiftConfigChange => widget.typeKey == 'shift-config-change';
  bool get _isEdit => widget.requestId != null;

  List<_FlowStepData> get _flowSteps {
    if (_isShiftConfigChange) {
      return const [
        _FlowStepData(
          Icons.send_rounded,
          'Đề xuất',
          'Trưởng khoa / ĐD trưởng',
        ),
        _FlowStepData(
          Icons.apartment_rounded,
          'HCNS duyệt',
          'Áp dụng vào hồ sơ',
        ),
      ];
    }
    if (_isTransfer) {
      return const [
        _FlowStepData(
          Icons.edit_note_rounded,
          'HCNS lập phiếu',
          'Hành chính nhân sự',
        ),
        _FlowStepData(
          Icons.verified_rounded,
          'Giám đốc duyệt',
          'Ban Giám đốc',
        ),
      ];
    }
    if (_isTraining) {
      return const [
        _FlowStepData(
          Icons.send_rounded,
          'Lập phiếu',
          'Trưởng khoa / ĐD trưởng',
        ),
        _FlowStepData(
          Icons.apartment_rounded,
          'HCNS duyệt',
          'Bổ sung hỗ trợ · cam kết',
        ),
        _FlowStepData(
          Icons.verified_rounded,
          'Giám đốc duyệt',
          'Ban Giám đốc',
        ),
      ];
    }
    return const [
      _FlowStepData(
        Icons.send_rounded,
        'Lập phiếu',
        'Trưởng khoa / ĐD trưởng',
      ),
      _FlowStepData(
        Icons.verified_rounded,
        'Giám đốc duyệt',
        'Có/không công · tiền hỗ trợ',
      ),
    ];
  }

  String get _flowInfo {
    if (_isShiftConfigChange) {
      return 'Sau khi HCNS duyệt, ca sáng/chiều theo mùa đã chọn sẽ được áp dụng cho hồ sơ của nhân viên.';
    }
    if (_isTransfer) {
      return 'Nhân viên chỉ chuyển phòng ban đúng ngày hiệu lực đã chọn.';
    }
    if (_isTraining) {
      return 'Sau khi gửi, phiếu chuyển HCNS (bổ sung tiền hỗ trợ & cam kết) rồi Ban Giám đốc.';
    }
    return 'Có thể lập nhiều phiếu cho các ngày không liên tiếp, nhưng không được trùng khoảng thời gian với phiếu khác đang chờ hoặc đã duyệt. Phiếu gửi thẳng Giám đốc duyệt (có công / không công, tuỳ chọn tiền hỗ trợ).';
  }

  String get _submitLabel {
    if (_isEdit) return 'Lưu thay đổi';
    if (_isShiftConfigChange) return 'Gửi đề xuất';
    if (_isTransfer) return 'Gửi Giám đốc duyệt';
    return 'Gửi phiếu';
  }

  @override
  void initState() {
    super.initState();
    _effectiveDate = DateTime.now();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _reason.dispose();
    _proposingDept.dispose();
    _courseName.dispose();
    _trainingLocation.dispose();
    _tuitionFee.dispose();
    _trainingGoal.dispose();
    _seminarName.dispose();
    _seminarLocation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final config = _config;
      if (config == null) throw StateError('config');
      final detail =
          await ref.read(employeeRepositoryProvider).detail(widget.employeeId);
      Map<String, dynamic>? existing;
      if (_isEdit) {
        existing = await ref
            .read(genericRequestRepositoryProvider)
            .byId(config, widget.requestId!);
        if (existing.isEmpty) throw StateError('empty');
      }
      final empId = detail.summary.id;
      List<Map<String, dynamic>> existingSeminars = const [];
      if (_isSeminar) {
        try {
          final seminarConfig = RequestTypeConfig.byKey('seminar-proposal');
          final response = await ref.read(apiClientProvider).get<List<dynamic>>(
            '/v1${seminarConfig.basePath}/employee/$empId',
          );
          existingSeminars =
              (response.data ?? []).cast<Map<String, dynamic>>();
          if (_isEdit) {
            existingSeminars = existingSeminars
                .where(
                  (p) => (p['id'] as num?)?.toInt() != widget.requestId,
                )
                .toList();
          }
        } catch (_) {
          existingSeminars = const [];
        }
      }
      if (_isShiftConfigChange && !_isEdit) {
        try {
          await _loadShiftConfigChangeDefaults(empId);
        } catch (_) {
          // Nếu không lấy được cấu hình giờ mẫu thì vẫn cho phép người dùng nhập thủ công.
        }
      }
      if (existing != null) {
        await _prefillFromRequest(existing);
      }
      if (!mounted) return;
      setState(() {
        _employee = detail;
        if (!_isEdit || _proposingDept.text.trim().isEmpty) {
          _proposingDept.text = detail.summary.departmentName ?? '';
        }
        _existingSeminarProposals = existingSeminars;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      showAppSnackBar(
        context,
        _isEdit ? 'Không tải được đơn để chỉnh sửa' : 'Không tải được hồ sơ nhân viên',
        isError: true,
      );
      context.pop();
    }
  }

  Future<void> _prefillFromRequest(Map<String, dynamic> req) async {
    if (_isTransfer) {
      _reason.text = req['reason']?.toString() ?? '';
      _effectiveDate =
          DateTime.tryParse(req['effectiveDate']?.toString() ?? '');
      final toDeptId = (req['toDepartmentId'] as num?)?.toInt();
      if (toDeptId != null) {
        final deps = await ref.read(departmentListProvider.future);
        for (final d in deps) {
          if (d.id == toDeptId) {
            _toDepartment = d;
            break;
          }
        }
      }
      final toPosId = (req['toPositionId'] as num?)?.toInt();
      if (toPosId != null) {
        final positions = await ref.read(positionListProvider.future);
        for (final p in positions) {
          if (p.id == toPosId) {
            _toPosition = p;
            break;
          }
        }
      }
      return;
    }

    if (_isTraining) {
      _proposingDept.text = req['proposingDepartment']?.toString() ?? '';
      _courseName.text = req['courseName']?.toString() ?? '';
      _trainingLocation.text = req['location']?.toString() ?? '';
      _tuitionFee.text = req['tuitionFee']?.toString() ?? '';
      _trainingGoal.text = req['trainingGoal']?.toString() ?? '';
      _reason.text = req['reason']?.toString() ?? '';
      _trainFrom = DateTime.tryParse(req['startDate']?.toString() ?? '');
      _trainTo = DateTime.tryParse(req['endDate']?.toString() ?? '');
      _employeeAck = req['employeeCommitmentAck'] == true;
      _departmentAck = req['departmentCommitmentAck'] == true;
      return;
    }

    if (_isSeminar) {
      _proposingDept.text = req['proposingDepartment']?.toString() ?? '';
      _seminarName.text = req['seminarName']?.toString() ?? '';
      _seminarLocation.text = req['location']?.toString() ?? '';
      _seminarFrom = DateTime.tryParse(req['startDate']?.toString() ?? '');
      final end = DateTime.tryParse(req['endDate']?.toString() ?? '');
      _seminarTo = end;
      if (_seminarFrom != null &&
          end != null &&
          !_sameDay(_seminarFrom!, end)) {
        _seminarMultiDay = true;
      } else {
        _seminarMultiDay = false;
        _seminarTo = null;
      }
      _attendanceScope = req['attendanceScope']?.toString() ?? 'FULL_DAY';
      _reason.text = req['reason']?.toString() ?? '';
      _employeeAck = req['employeeCommitmentAck'] == true;
      _departmentAck = req['departmentCommitmentAck'] == true;
      return;
    }

    if (_isShiftConfigChange) {
      final season = (req['season'] as String?)?.toUpperCase() ?? 'BOTH';
      _applySummer = season == 'SUMMER' || season == 'BOTH';
      _applyWinter = season == 'WINTER' || season == 'BOTH';
      if (season == 'WINTER') {
        _winterMorningIn = _parseHhmm(req['morningStart']?.toString());
        _winterMorningOut = _parseHhmm(req['morningEnd']?.toString());
        _winterAfternoonIn = _parseHhmm(req['afternoonStart']?.toString());
        _winterAfternoonOut = _parseHhmm(req['afternoonEnd']?.toString());
      } else {
        _summerMorningIn = _parseHhmm(req['morningStart']?.toString());
        _summerMorningOut = _parseHhmm(req['morningEnd']?.toString());
        _summerAfternoonIn = _parseHhmm(req['afternoonStart']?.toString());
        _summerAfternoonOut = _parseHhmm(req['afternoonEnd']?.toString());
        if (season == 'BOTH') {
          _winterMorningIn = _parseHhmm(req['winterMorningStart']?.toString());
          _winterMorningOut = _parseHhmm(req['winterMorningEnd']?.toString());
          _winterAfternoonIn =
              _parseHhmm(req['winterAfternoonStart']?.toString());
          _winterAfternoonOut =
              _parseHhmm(req['winterAfternoonEnd']?.toString());
        }
      }
      _morningUnits = (req['morningUnits'] as num?)?.toDouble() ?? 0.67;
      _afternoonUnits = (req['afternoonUnits'] as num?)?.toDouble() ?? 0.33;
      _reason.text = req['reason']?.toString() ?? '';
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  TimeOfDay? _parseHhmm(String? hhmm) {
    final text = hhmm?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtTimePayload(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _loadShiftConfigChangeDefaults(int employeeId) async {
    // Lấy "giờ ca mẫu" theo mùa từ API lịch ca (đồng bộ web).
    final repo = ref.read(attendanceRepositoryProvider);
    final year = DateTime.now().year;
    final summerDate = DateTime(year, 8, 15); // nằm trong khoảng mùa hè
    final winterDate = DateTime(year, 1, 15); // nằm trong khoảng mùa đông

    final summer = await repo.daySchedule(
      date: summerDate,
      employeeId: employeeId,
    );
    final winter = await repo.daySchedule(
      date: winterDate,
      employeeId: employeeId,
    );

    // Nếu API trả về thiếu dữ liệu, fallback về chuẩn UI (theo ảnh web).
    _summerMorningIn = _parseHhmm(summer.morningStart) ?? const TimeOfDay(hour: 6, minute: 45);
    _summerMorningOut = _parseHhmm(summer.morningEnd) ?? const TimeOfDay(hour: 11, minute: 45);
    _summerAfternoonIn = _parseHhmm(summer.afternoonStart) ?? const TimeOfDay(hour: 14, minute: 0);
    _summerAfternoonOut = _parseHhmm(summer.afternoonEnd) ?? const TimeOfDay(hour: 17, minute: 0);

    _winterMorningIn = _parseHhmm(winter.morningStart) ?? const TimeOfDay(hour: 7, minute: 0);
    _winterMorningOut = _parseHhmm(winter.morningEnd) ?? const TimeOfDay(hour: 12, minute: 0);
    _winterAfternoonIn = _parseHhmm(winter.afternoonStart) ?? const TimeOfDay(hour: 13, minute: 30);
    _winterAfternoonOut = _parseHhmm(winter.afternoonEnd) ?? const TimeOfDay(hour: 17, minute: 0);

    _applySummer = true;
    _applyWinter = true;

    _morningUnits = summer.morningUnits?.toDouble() ?? 0.67;
    _afternoonUnits = summer.afternoonUnits?.toDouble() ?? 0.33;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required String title,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      title: title,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickToDepartment() async {
    final deps = await ref.read(departmentListProvider.future);
    if (!mounted) return;
    final result = await showDepartmentPicker(
      context,
      departments: deps,
      selectedId: _toDepartment?.id,
      allowClear: false,
      title: 'Phòng ban đích',
    );
    if (!mounted || result?.department == null) return;
    setState(() => _toDepartment = result!.department);
  }

  Future<void> _pickToPosition() async {
    final positions = await ref.read(positionListProvider.future);
    if (!mounted) return;
    final picked = await showModalBottomSheet<_PosPick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PositionSheet(
        positions: positions,
        selectedId: _toPosition?.id,
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _toPosition = picked.cleared ? null : picked.position);
  }

  Future<void> _submit() async {
    final config = _config;
    final emp = _employee;
    if (config == null || emp == null) return;
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic>? body;
    try {
      body = _buildBody(emp);
    } on _FormError catch (e) {
      showAppSnackBar(context, e.message, isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final Map<String, dynamic> result;
      if (_isEdit) {
        result = await ref.read(genericRequestRepositoryProvider).update(
              config,
              widget.requestId!,
              body,
            );
      } else {
        result = await ref
            .read(genericRequestRepositoryProvider)
            .create(config, body);
      }
      if (!mounted) return;
      ref.invalidate(genericRequestControllerProvider(widget.typeKey));
      final id = _isEdit
          ? widget.requestId
          : (result['id'] as num?)?.toInt();
      showAppSnackBar(
        context,
        _isEdit ? 'Đã lưu thay đổi' : 'Đã gửi phiếu',
        isSuccess: true,
      );
      context.pop();
      if (id != null) {
        context.push(RoutePaths.requestDetailPath(widget.typeKey, id));
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Không gửi được phiếu', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _buildBody(EmployeeDetail emp) {
    if (_isTransfer) {
      if (_toDepartment == null) throw _FormError('Chọn phòng ban đích');
      if (_effectiveDate == null) throw _FormError('Chọn ngày luân chuyển');
      if (_reason.text.trim().isEmpty) {
        throw _FormError('Nhập lý do luân chuyển');
      }
      return {
        'employeeId': emp.summary.id,
        'toDepartmentId': _toDepartment!.id,
        if (_toPosition != null) 'toPositionId': _toPosition!.id,
        'effectiveDate': _ymd(_effectiveDate!),
        'reason': _reason.text.trim(),
      };
    }

    if (_isTraining) {
      if (_proposingDept.text.trim().isEmpty) {
        throw _FormError('Nhập Khoa/Phòng đề xuất');
      }
      if (_courseName.text.trim().isEmpty) {
        throw _FormError('Nhập tên khóa học');
      }
      if (_trainingLocation.text.trim().isEmpty) {
        throw _FormError('Nhập địa điểm học');
      }
      if (_trainFrom == null || _trainTo == null) {
        throw _FormError('Chọn thời gian dự kiến');
      }
      if (_trainTo!.isBefore(_trainFrom!)) {
        throw _FormError('Ngày kết thúc phải sau hoặc bằng ngày bắt đầu');
      }
      if (_trainingGoal.text.trim().isEmpty) {
        throw _FormError('Nhập mục tiêu đào tạo');
      }
      if (_reason.text.trim().isEmpty) {
        throw _FormError('Nhập lý do đề xuất');
      }
      if (!_employeeAck || !_departmentAck) {
        throw _FormError('Cần xác nhận đủ hai cam kết trước khi gửi');
      }
      return {
        'employeeId': emp.summary.id,
        'proposingDepartment': _proposingDept.text.trim(),
        'courseName': _courseName.text.trim(),
        'location': _trainingLocation.text.trim(),
        'plannedPeriod': '${_dmy(_trainFrom!)} – ${_dmy(_trainTo!)}',
        if (_tuitionFee.text.trim().isNotEmpty)
          'tuitionFee': _tuitionFee.text.trim(),
        'trainingGoal': _trainingGoal.text.trim(),
        'reason': _reason.text.trim(),
        'employeeCommitmentAck': true,
        'departmentCommitmentAck': true,
      };
    }

    if (_isSeminar) {
      if (_proposingDept.text.trim().isEmpty) {
        throw _FormError('Nhập Khoa/Phòng đề xuất');
      }
      if (_seminarName.text.trim().isEmpty) {
        throw _FormError('Nhập tên hội thảo');
      }
      if (_seminarLocation.text.trim().isEmpty) {
        throw _FormError('Nhập địa điểm');
      }
      if (_seminarFrom == null) throw _FormError('Chọn ngày hội thảo');
      final to = _seminarMultiDay ? _seminarTo : _seminarFrom;
      if (to == null) throw _FormError('Chọn thời gian đến ngày');
      if (to.isBefore(_seminarFrom!)) {
        throw _FormError('Ngày kết thúc phải sau hoặc bằng ngày bắt đầu');
      }
      final overlapMessage = seminarOverlapMessage(
        _existingSeminarProposals,
        _ymd(_seminarFrom!),
        _ymd(to),
      );
      if (overlapMessage != null) {
        throw _FormError(overlapMessage);
      }
      if (_reason.text.trim().isEmpty) {
        throw _FormError('Nhập lý do đề xuất');
      }
      if (!_employeeAck || !_departmentAck) {
        throw _FormError('Cần xác nhận đủ hai cam kết trước khi gửi');
      }
      return {
        'employeeId': emp.summary.id,
        'proposingDepartment': _proposingDept.text.trim(),
        'seminarName': _seminarName.text.trim(),
        'location': _seminarLocation.text.trim(),
        'startDate': _ymd(_seminarFrom!),
        'endDate': _ymd(to),
        'attendanceScope':
            _seminarMultiDay ? 'FULL_DAY' : _attendanceScope,
        'reason': _reason.text.trim(),
        'employeeCommitmentAck': true,
        'departmentCommitmentAck': true,
      };
    }

    if (_isShiftConfigChange) {
      final hasAnySeason = _applySummer || _applyWinter;
      if (!hasAnySeason) throw _FormError('Chọn ít nhất một mùa áp dụng');
      if (_reason.text.trim().isEmpty) {
        throw _FormError('Nhập lý do đề xuất');
      }

      final season = _applySummer && _applyWinter
          ? 'BOTH'
          : (_applySummer ? 'SUMMER' : 'WINTER');

      // DTO: morningStart/morningEnd/afternoonStart/afternoonEnd dùng cho:
      // - SUMMER
      // - WINTER (mùa duy nhất)
      // - BOTH (mùa hè)
      final useSummerAsBase = season == 'SUMMER' || season == 'BOTH';
      final baseMorningIn = useSummerAsBase ? _summerMorningIn : _winterMorningIn;
      final baseMorningOut =
          useSummerAsBase ? _summerMorningOut : _winterMorningOut;
      final baseAfternoonIn =
          useSummerAsBase ? _summerAfternoonIn : _winterAfternoonIn;
      final baseAfternoonOut =
          useSummerAsBase ? _summerAfternoonOut : _winterAfternoonOut;

      void fmtBase() {
        if (baseMorningIn == null ||
            baseMorningOut == null ||
            baseAfternoonIn == null ||
            baseAfternoonOut == null) {
          throw _FormError('Chọn đủ giờ ca sáng/chiều');
        }
      }
      fmtBase();

      final payload = <String, dynamic>{
        'employeeId': emp.summary.id,
        'season': season,
        'morningStart': _fmtTimePayload(baseMorningIn!),
        'morningEnd': _fmtTimePayload(baseMorningOut!),
        'afternoonStart': _fmtTimePayload(baseAfternoonIn!),
        'afternoonEnd': _fmtTimePayload(baseAfternoonOut!),
        'morningUnits': _morningUnits,
        'afternoonUnits': _afternoonUnits,
        'reason': _reason.text.trim(),
      };

      if (season == 'BOTH') {
        if (_winterMorningIn == null ||
            _winterMorningOut == null ||
            _winterAfternoonIn == null ||
            _winterAfternoonOut == null) {
          throw _FormError('Chọn đủ giờ ca mùa đông');
        }
        payload.addAll({
          'winterMorningStart': _fmtTimePayload(_winterMorningIn!),
          'winterMorningEnd': _fmtTimePayload(_winterMorningOut!),
          'winterAfternoonStart': _fmtTimePayload(_winterAfternoonIn!),
          'winterAfternoonEnd': _fmtTimePayload(_winterAfternoonOut!),
        });
      }

      return payload;
    }

    throw _FormError('Loại phiếu không hỗ trợ');
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final emp = _employee;
    final title = _isEdit
        ? 'Chỉnh sửa ${config?.shortLabel ?? 'phiếu'}'
        : (config?.label ?? 'Tạo phiếu');
    final accent = config?.color ?? AppColors.primary;
    final icon = config?.icon ?? Icons.description_outlined;

    if (_loading || emp == null || config == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const Positioned.fill(child: AppAmbientBackground(intensity: 0.7)),
            Column(
              children: [
                AppScreenHeader(
                  dense: true,
                  title: title,
                  icon: icon,
                  subtitle: 'Đang tải hồ sơ…',
                  onBack: () => context.pop(),
                ),
                const Expanded(child: SkeletonList(itemCount: 5)),
              ],
            ),
          ],
        ),
      );
    }

    final subtitle =
        '${emp.summary.fullName}${emp.summary.departmentName != null ? ' · ${emp.summary.departmentName}' : ''}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: AppAmbientBackground(intensity: 0.85)),
          Column(
            children: [
              AppScreenHeader(
                dense: true,
                title: title,
                icon: icon,
                subtitle: subtitle,
                eyebrow: _isEdit ? 'Chỉnh sửa phiếu' : 'Phiếu đề xuất',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      12,
                      AppSpacing.page,
                      120,
                    ),
                    children: [
                      _ProposalFlowStrip(
                        accent: accent,
                        steps: _flowSteps,
                      ),
                      const SizedBox(height: 10),
                      NoticeBanner(
                        color: accent,
                        icon: Icons.info_outline_rounded,
                        message: _flowInfo,
                      ),
                      const SizedBox(height: 12),
                      _EmployeeIdentityCard(
                        employee: emp,
                        accent: accent,
                        onChange: _isEdit
                            ? null
                            : () => context.pushReplacement(
                                  RoutePaths.requestCreatePath(widget.typeKey),
                                ),
                      ),
                      const SizedBox(height: 12),
                      if (!_isTransfer && !_isShiftConfigChange)
                        AppCard(
                          accentColor: accent,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                icon: Icons.apartment_rounded,
                                title: 'Đơn vị đề xuất',
                                accent: accent,
                              ),
                              const SizedBox(height: 10),
                              _Field(
                                controller: _proposingDept,
                                label: 'Khoa/Phòng đề xuất *',
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Bắt buộc'
                                        : null,
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      if (_isShiftConfigChange)
                        AppCard(
                          accentColor: accent,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle(
                                icon: Icons.apartment_rounded,
                                title: 'Khoa/Phòng',
                                accent: accent,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                (_proposingDept.text.trim().isEmpty
                                        ? '—'
                                        : _proposingDept.text.trim()),
                                style: AppTypography.style(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!_isTransfer) const SizedBox(height: 12),
                      if (_isTransfer) _buildTransferBody(accent),
                      if (_isTraining) _buildTrainingBody(accent),
                      if (_isSeminar) _buildSeminarBody(accent),
                      if (_isShiftConfigChange)
                        _buildShiftConfigChangeBody(accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        accent: accent,
        saving: _saving,
        submitLabel: _submitLabel,
        onCancel: () => context.pop(),
        onSubmit: _submit,
      ),
    );
  }

  Widget _buildTransferBody(Color accent) {
    return AppCard(
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.compare_arrows_rounded,
            title: 'Nội dung luân chuyển',
            accent: accent,
          ),
          const SizedBox(height: 12),
          _PickerTile(
            label: 'Phòng ban đích *',
            value: _toDepartment?.name ?? 'Chọn khoa/phòng',
            emphasized: _toDepartment == null,
            icon: Icons.apartment_rounded,
            onTap: _pickToDepartment,
          ),
          const SizedBox(height: 10),
          _PickerTile(
            label: 'Chức vụ mới (tuỳ chọn)',
            value: _toPosition?.title ?? 'Không đổi / tuỳ chọn',
            icon: Icons.work_outline_rounded,
            onTap: _pickToPosition,
          ),
          const SizedBox(height: 10),
          _PickerTile(
            label: 'Ngày luân chuyển (hiệu lực) *',
            value:
                _effectiveDate == null ? 'Chọn ngày' : _dmy(_effectiveDate!),
            icon: Icons.event_rounded,
            onTap: () => _pickDate(
              current: _effectiveDate,
              title: 'Ngày hiệu lực',
              onPicked: (d) => setState(() => _effectiveDate = d),
            ),
          ),
          const SizedBox(height: 10),
          _Field(
            controller: _reason,
            label: 'Lý do luân chuyển *',
            maxLines: 4,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildTrainingBody(Color accent) {
    return Column(
      children: [
        AppCard(
          accentColor: accent,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.school_rounded,
                title: 'Nội dung đào tạo',
                accent: accent,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _courseName,
                label: 'Tên khóa học *',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _trainingLocation,
                label: 'Địa điểm học *',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PickerTile(
                      label: 'Từ ngày *',
                      value: _trainFrom == null
                          ? 'Chọn ngày'
                          : _dmy(_trainFrom!),
                      icon: Icons.event_rounded,
                      onTap: () => _pickDate(
                        current: _trainFrom,
                        title: 'Từ ngày',
                        onPicked: (d) => setState(() {
                          _trainFrom = d;
                          _trainTo ??= d;
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerTile(
                      label: 'Đến ngày *',
                      value:
                          _trainTo == null ? 'Chọn ngày' : _dmy(_trainTo!),
                      icon: Icons.event_available_rounded,
                      onTap: () => _pickDate(
                        current: _trainTo ?? _trainFrom,
                        title: 'Đến ngày',
                        onPicked: (d) => setState(() => _trainTo = d),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _tuitionFee,
                label: 'Học phí (tuỳ chọn)',
                hint: 'Ghi rõ đơn vị VNĐ nếu có',
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _trainingGoal,
                label: 'Mục tiêu đào tạo *',
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _reason,
                label: 'Lý do đề xuất *',
                maxLines: 3,
                hint: 'Nhu cầu chuyên môn và lợi ích Khoa/Phòng',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CommitmentsCard(
          accent: accent,
          employeeLabel: 'Cam kết của nhân viên được cử đi đào tạo',
          employeeText: _empCommitmentTraining,
          departmentLabel: 'Cam kết của Khoa/Phòng đề xuất',
          departmentText: _deptCommitmentTraining,
          employeeAck: _employeeAck,
          departmentAck: _departmentAck,
          onEmployeeChanged: (v) => setState(() => _employeeAck = v),
          onDepartmentChanged: (v) => setState(() => _departmentAck = v),
        ),
      ],
    );
  }

  Widget _buildSeminarBody(Color accent) {
    final effectiveTo = _seminarMultiDay ? _seminarTo : _seminarFrom;
    final overlapMessage = (_seminarFrom != null &&
            effectiveTo != null &&
            !effectiveTo.isBefore(_seminarFrom!))
        ? seminarOverlapMessage(
            _existingSeminarProposals,
            _ymd(_seminarFrom!),
            _ymd(effectiveTo),
          )
        : null;

    return Column(
      children: [
        AppCard(
          accentColor: accent,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                icon: Icons.groups_rounded,
                title: 'Nội dung hội thảo / công tác',
                accent: accent,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _seminarName,
                label: 'Tên hội thảo *',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _seminarLocation,
                label: 'Địa điểm *',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 10),
              _ChoiceRow(
                label: 'Thời gian tham gia',
                options: const [
                  (false, 'Trong một ngày'),
                  (true, 'Nhiều ngày'),
                ],
                value: _seminarMultiDay,
                accent: accent,
                onChanged: (v) => setState(() {
                  _seminarMultiDay = v;
                  if (!v) _seminarTo = null;
                }),
              ),
              const SizedBox(height: 10),
              _PickerTile(
                label: _seminarMultiDay ? 'Từ ngày *' : 'Ngày hội thảo *',
                value: _seminarFrom == null
                    ? 'Chọn ngày'
                    : _dmy(_seminarFrom!),
                icon: Icons.event_rounded,
                onTap: () => _pickDate(
                  current: _seminarFrom,
                  title: 'Ngày hội thảo',
                  onPicked: (d) => setState(() => _seminarFrom = d),
                ),
              ),
              const SizedBox(height: 10),
              if (_seminarMultiDay)
                _PickerTile(
                  label: 'Đến ngày *',
                  value: _seminarTo == null
                      ? 'Chọn ngày'
                      : _dmy(_seminarTo!),
                  icon: Icons.event_available_rounded,
                  onTap: () => _pickDate(
                    current: _seminarTo ?? _seminarFrom,
                    title: 'Đến ngày',
                    onPicked: (d) => setState(() => _seminarTo = d),
                  ),
                )
              else
                _ChoiceRow(
                  label: 'Buổi được tính hội thảo',
                  options: const [
                    ('FULL_DAY', 'Cả ngày'),
                    ('MORNING', 'Buổi sáng'),
                    ('AFTERNOON', 'Buổi chiều'),
                  ],
                  value: _attendanceScope,
                  accent: accent,
                  onChanged: (v) => setState(() => _attendanceScope = v),
                ),
              if (!_seminarMultiDay) const SizedBox(height: 4),
              Text(
                'Buổi không chọn chỉ có công khi nhân viên chấm công và đi làm bình thường.',
                style: AppTypography.style(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                  height: 1.35,
                ),
              ),
              if (overlapMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  overlapMessage,
                  style: AppTypography.style(
                    fontSize: 12,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _Field(
                controller: _reason,
                label: 'Lý do đề xuất *',
                maxLines: 3,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CommitmentsCard(
          accent: accent,
          employeeLabel: 'Cam kết của nhân viên được cử đi hội thảo',
          employeeText: _empCommitmentSeminar,
          departmentLabel: 'Cam kết của Khoa/Phòng đề xuất',
          departmentText: _deptCommitmentSeminar,
          employeeAck: _employeeAck,
          departmentAck: _departmentAck,
          onEmployeeChanged: (v) => setState(() => _employeeAck = v),
          onDepartmentChanged: (v) => setState(() => _departmentAck = v),
        ),
      ],
    );
  }

  Future<void> _pickTime({
    required TimeOfDay? current,
    required String title,
    required ValueChanged<TimeOfDay> onSet,
  }) async {
    final picked = await showAppTimePicker(
      context,
      initialTime: current ?? TimeOfDay.now(),
      title: title,
    );
    if (!mounted || picked == null) return;
    setState(() => onSet(picked));
  }

  String _timeDisplay(TimeOfDay? t) {
    if (t == null) return 'Chọn giờ';
    return '${t.hour}h${t.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSeasonEditor({
    required bool isSummer,
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required TimeOfDay? morningIn,
    required TimeOfDay? morningOut,
    required TimeOfDay? afternoonIn,
    required TimeOfDay? afternoonOut,
    required ValueChanged<TimeOfDay> setMorningIn,
    required ValueChanged<TimeOfDay> setMorningOut,
    required ValueChanged<TimeOfDay> setAfternoonIn,
    required ValueChanged<TimeOfDay> setAfternoonOut,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          icon: icon,
          title: title,
          accent: accent,
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: AppTypography.style(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _PickerTile(
                    label: 'Vào ca sáng',
                    value: _timeDisplay(morningIn),
                    icon: Icons.access_time_rounded,
                    onTap: () {
                      _pickTime(
                        current: morningIn,
                        title: 'Vào ca sáng',
                        onSet: setMorningIn,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _PickerTile(
                    label: 'Vào ca chiều',
                    value: _timeDisplay(afternoonIn),
                    icon: Icons.access_time_rounded,
                    onTap: () {
                      _pickTime(
                        current: afternoonIn,
                        title: 'Vào ca chiều',
                        onSet: setAfternoonIn,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                children: [
                  _PickerTile(
                    label: 'Ra ca sáng',
                    value: _timeDisplay(morningOut),
                    icon: Icons.access_time_rounded,
                    onTap: () {
                      _pickTime(
                        current: morningOut,
                        title: 'Ra ca sáng',
                        onSet: setMorningOut,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _PickerTile(
                    label: 'Ra ca chiều',
                    value: _timeDisplay(afternoonOut),
                    icon: Icons.access_time_rounded,
                    onTap: () {
                      _pickTime(
                        current: afternoonOut,
                        title: 'Ra ca chiều',
                        onSet: setAfternoonOut,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Công mặc định ~${_morningUnits.toStringAsFixed(2).replaceAll('.', ',')} công sáng / '
          '~${_afternoonUnits.toStringAsFixed(2).replaceAll('.', ',')} công chiều (theo cấu hình).',
          style: AppTypography.style(
            fontSize: 11.5,
            color: AppColors.textTertiary,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildShiftConfigChangeBody(Color accent) {
    final summerColor = const Color(0xFFB45309);
    final winterColor = const Color(0xFF0369A1);

    return AppCard(
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.tune_rounded,
            title: 'Đề xuất thay đổi ca sáng/chiều',
            accent: accent,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SeasonSelectCard(
                  selected: _applySummer,
                  color: summerColor,
                  icon: Icons.wb_sunny_rounded,
                  title: 'Mùa hè',
                  subtitle: 'Áp dụng 15/4 – 15/10',
                  onTap: () => setState(() => _applySummer = !_applySummer),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SeasonSelectCard(
                  selected: _applyWinter,
                  color: winterColor,
                  icon: Icons.ac_unit_rounded,
                  title: 'Mùa đông',
                  subtitle: 'Ngoài khoảng mùa hè',
                  onTap: () => setState(() => _applyWinter = !_applyWinter),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_applySummer)
            _buildSeasonEditor(
              isSummer: true,
              accent: summerColor,
              icon: Icons.wb_sunny_rounded,
              title: 'Giờ ca mùa hè',
              subtitle: 'Vào/ra buổi sáng và chiều',
              morningIn: _summerMorningIn,
              morningOut: _summerMorningOut,
              afternoonIn: _summerAfternoonIn,
              afternoonOut: _summerAfternoonOut,
              setMorningIn: (v) => _summerMorningIn = v,
              setMorningOut: (v) => _summerMorningOut = v,
              setAfternoonIn: (v) => _summerAfternoonIn = v,
              setAfternoonOut: (v) => _summerAfternoonOut = v,
            ),
          if (_applySummer && _applyWinter) const SizedBox(height: 14),
          if (_applyWinter)
            _buildSeasonEditor(
              isSummer: false,
              accent: winterColor,
              icon: Icons.ac_unit_rounded,
              title: 'Giờ ca mùa đông',
              subtitle: 'Vào/ra buổi sáng và chiều',
              morningIn: _winterMorningIn,
              morningOut: _winterMorningOut,
              afternoonIn: _winterAfternoonIn,
              afternoonOut: _winterAfternoonOut,
              setMorningIn: (v) => _winterMorningIn = v,
              setMorningOut: (v) => _winterMorningOut = v,
              setAfternoonIn: (v) => _winterAfternoonIn = v,
              setAfternoonOut: (v) => _winterAfternoonOut = v,
            ),
          const SizedBox(height: 12),
          _Field(
            controller: _reason,
            label: 'Lý do đề xuất *',
            maxLines: 3,
            hint: 'Ví dụ: điều chỉnh theo nhu cầu khoa/phòng, tối ưu giờ vào/ra',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _FormError implements Exception {
  _FormError(this.message);
  final String message;
}

class _FlowStepData {
  const _FlowStepData(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

/// Luồng duyệt — cùng pattern với đơn nghỉ phép (thu gọn / mở rộng).
class _ProposalFlowStrip extends StatefulWidget {
  const _ProposalFlowStrip({required this.accent, required this.steps});

  final Color accent;
  final List<_FlowStepData> steps;

  @override
  State<_ProposalFlowStrip> createState() => _ProposalFlowStripState();
}

class _ProposalFlowStripState extends State<_ProposalFlowStrip> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final current = steps.first;
    final accent = widget.accent;
    final total = steps.length;

    return AppCard(
      accentColor: accent,
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _toggle,
              borderRadius: AppRadius.brCard,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Icon(
                        Icons.account_tree_rounded,
                        size: 15,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Luồng duyệt',
                            style: AppTypography.style(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: AppDurations.fast,
                            child: Text(
                              _expanded
                                  ? '$total bước · đồng bộ với web'
                                  : 'Bước 1/$total · ${current.title}',
                              key: ValueKey(_expanded),
                              style: AppTypography.style(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: AppRadius.brPill,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        'Bước 1/$total',
                        style: AppTypography.style(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: AppDurations.fast,
                      child: const Icon(
                        Icons.expand_more_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstCurve: Curves.easeOutCubic,
            secondCurve: Curves.easeOutCubic,
            sizeCurve: Curves.easeOutCubic,
            duration: AppDurations.normal,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _CollapsedStep(
                accent: accent,
                step: current,
                onExpand: _toggle,
              ),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    _ExpandedStep(
                      accent: accent,
                      step: steps[i],
                      index: i,
                      active: i == 0,
                      isLast: i == steps.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedStep extends StatelessWidget {
  const _CollapsedStep({
    required this.accent,
    required this.step,
    required this.onExpand,
  });

  final Color accent;
  final _FlowStepData step;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExpand,
        borderRadius: AppRadius.brMd,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: AppRadius.brMd,
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(step.icon, size: 15, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      step.subtitle,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: AppRadius.brPill,
                ),
                child: Text(
                  'Hiện tại',
                  style: AppTypography.style(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedStep extends StatelessWidget {
  const _ExpandedStep({
    required this.accent,
    required this.step,
    required this.index,
    required this.active,
    required this.isLast,
  });

  final Color accent;
  final _FlowStepData step;
  final int index;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : AppColors.textTertiary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active
                        ? accent
                        : AppColors.surfaceMuted,
                    border: Border.all(
                      color: active
                          ? accent
                          : AppColors.borderSoft,
                    ),
                  ),
                  child: active
                      ? Icon(step.icon, size: 14, color: Colors.white)
                      : Text(
                          '${index + 1}',
                          style: AppTypography.style(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.borderSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: AppTypography.style(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: active ? accent : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    step.subtitle,
                    style: AppTypography.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeIdentityCard extends StatelessWidget {
  const _EmployeeIdentityCard({
    required this.employee,
    required this.accent,
    this.onChange,
  });

  final EmployeeDetail employee;
  final Color accent;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final s = employee.summary;
    return AppCard(
      accentColor: accent,
      padding: const EdgeInsets.all(14),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          AppAvatar(
            name: s.fullName,
            imageUrl: s.avatarUrl,
            size: 52,
            borderColor: accent.withValues(alpha: 0.25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.fullName,
                  style: AppTypography.style(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                if ((s.positionTitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    s.positionTitle!,
                    style: AppTypography.style(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
                if ((s.departmentName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.departmentName!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.style(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onChange != null) ...[
            const SizedBox(width: 8),
            Material(
              color: accent.withValues(alpha: 0.1),
              borderRadius: AppRadius.brPill,
              child: InkWell(
                onTap: onChange,
                borderRadius: AppRadius.brPill,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 16, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        'Đổi',
                        style: AppTypography.style(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: AppRadius.brSm,
          ),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: AppTypography.style(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(borderRadius: AppRadius.brMd),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.brMd,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: emphasized
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.style(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: AppTypography.style(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonSelectCard extends StatelessWidget {
  const _SeasonSelectCard({
    required this.selected,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.08)
                : AppColors.surfaceMuted,
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.35)
                  : AppColors.borderSoft,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.style(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: color,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.style(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String label;
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.style(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in options)
              ChoiceChip(
                label: Text(opt.$2),
                selected: value == opt.$1,
                onSelected: (_) => onChanged(opt.$1),
                selectedColor: accent.withValues(alpha: 0.16),
                labelStyle: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: value == opt.$1 ? accent : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color: value == opt.$1 ? accent : AppColors.borderSoft,
                ),
                backgroundColor: AppColors.surfaceMuted,
              ),
          ],
        ),
      ],
    );
  }
}

class _CommitmentsCard extends StatelessWidget {
  const _CommitmentsCard({
    required this.accent,
    required this.employeeLabel,
    required this.employeeText,
    required this.departmentLabel,
    required this.departmentText,
    required this.employeeAck,
    required this.departmentAck,
    required this.onEmployeeChanged,
    required this.onDepartmentChanged,
  });

  final Color accent;
  final String employeeLabel;
  final String employeeText;
  final String departmentLabel;
  final String departmentText;
  final bool employeeAck;
  final bool departmentAck;
  final ValueChanged<bool> onEmployeeChanged;
  final ValueChanged<bool> onDepartmentChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accentColor: accent,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.fact_check_rounded,
            title: 'Cam kết',
            accent: accent,
          ),
          const SizedBox(height: 4),
          Text(
            'Bắt buộc xác nhận đủ hai cam kết trước khi gửi',
            style: AppTypography.style(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _AckTile(
            selected: employeeAck,
            accent: accent,
            title: employeeLabel,
            body: employeeText,
            onTap: () => onEmployeeChanged(!employeeAck),
          ),
          const SizedBox(height: 8),
          _AckTile(
            selected: departmentAck,
            accent: accent,
            title: departmentLabel,
            body: departmentText,
            onTap: () => onDepartmentChanged(!departmentAck),
          ),
        ],
      ),
    );
  }
}

class _AckTile extends StatelessWidget {
  const _AckTile({
    required this.selected,
    required this.accent,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final Color accent;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? accent.withValues(alpha: 0.08)
          : AppColors.surfaceMuted,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.35)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? accent : AppColors.textTertiary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: AppTypography.style(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.accent,
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  final Color accent;
  final bool saving;
  final String submitLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: AppColors.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            10,
            AppSpacing.page,
            12,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    side: BorderSide(color: accent.withValues(alpha: 0.45)),
                    foregroundColor: accent,
                  ),
                  child: const Text('Huỷ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: saving ? null : onSubmit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                  ),
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          submitLabel == 'Lưu thay đổi'
                              ? Icons.save_outlined
                              : Icons.send_rounded,
                          size: 18,
                        ),
                  label: Text(
                    saving
                        ? (submitLabel == 'Lưu thay đổi'
                            ? 'Đang lưu…'
                            : 'Đang gửi…')
                        : submitLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosPick {
  const _PosPick.cleared()
      : position = null,
        cleared = true;
  const _PosPick.value(this.position) : cleared = false;

  final JobPosition? position;
  final bool cleared;
}

class _PositionSheet extends StatelessWidget {
  const _PositionSheet({required this.positions, this.selectedId});

  final List<JobPosition> positions;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSoft,
              borderRadius: AppRadius.brPill,
            ),
          ),
          ListTile(
            title: const Text('Không chọn chức vụ'),
            onTap: () => Navigator.pop(context, const _PosPick.cleared()),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: positions.length,
              itemBuilder: (context, i) {
                final p = positions[i];
                final selected = p.id == selectedId;
                return ListTile(
                  title: Text(
                    p.title,
                    style: AppTypography.style(
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, _PosPick.value(p)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
