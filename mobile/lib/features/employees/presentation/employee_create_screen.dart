import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/gradient_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../shared/models/department.dart';
import '../../../shared/models/employee.dart';
import '../data/department_repository.dart';
import '../data/employee_repository.dart';
import 'org_unit_picker.dart';

/// Tạo / sửa nhân viên — UI mobile, payload đồng bộ web (`POST` / `PUT /v1/employees`).
class EmployeeCreateScreen extends ConsumerStatefulWidget {
  const EmployeeCreateScreen({
    super.key,
    this.trialMode = false,
    this.editEmployeeId,
  });

  /// `true` = thử việc / thực tập; `false` = chính thức.
  final bool trialMode;

  /// Có giá trị = chế độ sửa hồ sơ.
  final int? editEmployeeId;

  bool get isEdit => editEmployeeId != null;

  @override
  ConsumerState<EmployeeCreateScreen> createState() =>
      _EmployeeCreateScreenState();
}

class _EmployeeCreateScreenState extends ConsumerState<EmployeeCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // Account
  final _phone = TextEditingController();
  final _email = TextEditingController();

  // Personal
  final _fullName = TextEditingController();
  final _idCard = TextEditingController();
  final _address = TextEditingController();
  final _ethnicity = TextEditingController();
  final _placeOfOrigin = TextEditingController();
  final _bloodType = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _emergencyPhone = TextEditingController();

  // Work
  final _attendance = TextEditingController();
  final _degree = TextEditingController();
  final _baseSalary = TextEditingController();

  // Expertise
  final _specialty = TextEditingController();
  final _professionalDiploma = TextEditingController();
  final _practiceScope = TextEditingController();
  final _practiceCertNumber = TextEditingController();
  final _practiceCertDate = TextEditingController();
  final _cki = TextEditingController();
  final _otherCerts = TextEditingController();

  // Bank / insurance / contract / notes
  final _payrollName = TextEditingController();
  final _bankAccount = TextEditingController();
  final _bankName = TextEditingController();
  final _socialInsurance = TextEditingController();
  final _contractNumber = TextEditingController();
  final _contractTerm = TextEditingController();
  final _dependents = TextEditingController();
  final _notes = TextEditingController();

  bool _saving = false;
  bool _loadingEdit = false;
  late bool _trialMode;
  String _status = 'ACTIVE';
  String _employmentType = 'FULL_TIME';
  String? _gender;
  String? _maritalStatus;
  String? _insuranceParticipation;
  Department? _department;
  WorkUnit? _workUnit;
  JobPosition? _position;
  DateTime? _hireDate;
  DateTime? _dateOfBirth;
  DateTime? _probationStart;
  DateTime? _officialStart;
  DateTime? _idCardIssueDate;
  DateTime? _contractSignDate;

  bool _expandPersonalExtra = false;
  bool _expandExpertise = true;
  bool _expandBank = true;
  bool _expandInsurance = false;
  bool _expandContract = false;
  bool _expandExtra = false;

  bool get _isEdit => widget.isEdit;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadingEdit = true;
      Future.microtask(_loadForEdit);
    } else {
      _trialMode = widget.trialMode;
      _status = _trialMode ? 'PROBATION' : 'ACTIVE';
      _hireDate = DateTime.now();
      if (_trialMode) {
        _probationStart = DateTime.now();
      } else {
        _officialStart = DateTime.now();
      }
    }
  }

  Future<void> _loadForEdit() async {
    try {
      final detail = await ref
          .read(employeeRepositoryProvider)
          .detail(widget.editEmployeeId!);
      if (!mounted) return;
      _applyDetail(detail);
      setState(() => _loadingEdit = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingEdit = false);
      showAppSnackBar(context, 'Không tải được hồ sơ để sửa', isError: true);
      context.pop();
    }
  }

  void _applyDetail(EmployeeDetail detail) {
    final s = detail.summary;
    final status = (s.status ?? 'ACTIVE').toUpperCase();
    final trial = status == 'PROBATION' ||
        status == 'INTERN' ||
        status == 'TRIAL' ||
        (s.employeeCode?.toUpperCase().startsWith('TV-') ?? false);

    _trialMode = trial;
    _status = status == 'INTERN'
        ? 'INTERN'
        : (trial ? 'PROBATION' : (status == 'TERMINATED' ? 'TERMINATED' : 'ACTIVE'));
    if (_status == 'TERMINATED') {
      // Form vẫn cho sửa hồ sơ đã nghỉ — giữ status.
    } else if (!trial && _status != 'ACTIVE' && _status != 'ON_LEAVE') {
      _status = 'ACTIVE';
    }

    final employment = (s.employmentType ?? 'FULL_TIME').toUpperCase();
    _employmentType =
        employment == 'PART_TIME' || employment == 'BTG' ? 'PART_TIME' : 'FULL_TIME';

    _phone.text = detail.phone ?? '';
    _email.text = detail.email ?? '';
    _fullName.text = s.fullName;
    _idCard.text = detail.idCardNumber ?? '';
    _address.text = detail.address ?? '';
    _gender = detail.gender;
    _dateOfBirth = AppFormat.tryParseDate(detail.dateOfBirth);
    _hireDate = AppFormat.tryParseDate(s.hireDate) ?? DateTime.now();

    if (detail.departmentId != null) {
      _department = Department(
        id: detail.departmentId!,
        code: '',
        name: s.departmentName ?? 'Phòng ban',
      );
    }
    final unitName = detail.workUnitFromProfile;
    if (unitName != null && unitName.trim().isNotEmpty) {
      _workUnit = WorkUnit(id: 0, name: unitName.trim());
    }
    if (detail.positionId != null) {
      _position = JobPosition(
        id: detail.positionId!,
        title: s.positionTitle ?? 'Chức vụ',
      );
    }

    String p(String key) => detail.profileString(key) ?? '';
    _attendance.text = detail.attendanceCode ?? p('attendanceCode');
    _degree.text = detail.degree ?? p('degree');
    _specialty.text = p('specialty');
    _professionalDiploma.text = p('professionalDiploma');
    _practiceScope.text = p('practiceScope');
    _practiceCertNumber.text = p('practiceCertNumber');
    _practiceCertDate.text = p('practiceCertDateRaw');
    _cki.text = p('cki');
    _otherCerts.text = p('otherTrainingCertificates');
    _payrollName.text = p('payrollDisplayName');
    _bankAccount.text = p('bankAccount');
    _bankName.text = p('bankName');
    _socialInsurance.text = p('socialInsuranceBook');
    _contractNumber.text = p('contractNumber');
    _contractTerm.text = p('contractTerm');
    _ethnicity.text = p('ethnicity');
    _placeOfOrigin.text = p('placeOfOrigin');
    _bloodType.text = p('bloodType');
    _emergencyContact.text = p('emergencyContact');
    _emergencyPhone.text = p('emergencyPhone');
    _dependents.text = p('dependentsInfo');
    _notes.text = detail.noteOnly ?? p('workforceNotes');
    _maritalStatus = detail.profileString('maritalStatus');
    _insuranceParticipation = detail.profileString('insuranceParticipation');

    _probationStart = AppFormat.tryParseDate(detail.probationStartDate);
    _officialStart = AppFormat.tryParseDate(p('officialStartDate')) ?? _hireDate;
    _idCardIssueDate = AppFormat.tryParseDate(p('idCardIssueDate'));
    _contractSignDate = AppFormat.tryParseDate(p('contractSignDate'));

    final salary = detail.salaryFromNotes;
    if (salary != null) _baseSalary.text = salary;

    _expandPersonalExtra = [
          _ethnicity,
          _placeOfOrigin,
          _bloodType,
          _emergencyContact,
          _emergencyPhone,
        ].any((c) => c.text.trim().isNotEmpty) ||
        _maritalStatus != null ||
        _idCardIssueDate != null;
    _expandInsurance = (_insuranceParticipation ?? '').isNotEmpty ||
        _socialInsurance.text.trim().isNotEmpty;
    _expandContract = _contractNumber.text.trim().isNotEmpty ||
        _contractSignDate != null ||
        _contractTerm.text.trim().isNotEmpty;
    _expandExtra =
        _dependents.text.trim().isNotEmpty || _notes.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    for (final c in [
      _phone,
      _email,
      _fullName,
      _idCard,
      _address,
      _ethnicity,
      _placeOfOrigin,
      _bloodType,
      _emergencyContact,
      _emergencyPhone,
      _attendance,
      _degree,
      _baseSalary,
      _specialty,
      _professionalDiploma,
      _practiceScope,
      _practiceCertNumber,
      _practiceCertDate,
      _cki,
      _otherCerts,
      _payrollName,
      _bankAccount,
      _bankName,
      _socialInsurance,
      _contractNumber,
      _contractTerm,
      _dependents,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _dmy(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  void _applyMode(bool trial) {
    setState(() {
      _trialMode = trial;
      _status = trial ? 'PROBATION' : 'ACTIVE';
      if (trial) {
        _probationStart ??= DateTime.now();
      } else {
        _officialStart ??= _hireDate ?? DateTime.now();
      }
    });
  }

  Future<void> _pickDepartment(List<Department> departments) async {
    final result = await showDepartmentPicker(
      context,
      departments: departments,
      selectedId: _department?.id,
      allowClear: false,
    );
    if (!mounted || result == null || result.department == null) return;
    setState(() {
      _department = result.department;
      _workUnit = null;
    });
  }

  Future<void> _pickWorkUnit() async {
    final dept = _department;
    if (dept == null) return;
    final units =
        await ref.read(departmentRepositoryProvider).listWorkUnits(dept.id);
    if (!mounted) return;
    if (units.isEmpty) {
      showAppSnackBar(context, 'Phòng ban này chưa có bộ phận');
      return;
    }
    final result = await showWorkUnitPicker(
      context,
      units: units,
      selectedName: _workUnit?.name,
      allowClear: true,
      clearLabel: 'Không chọn bộ phận',
      departmentName: dept.name,
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.cleared || result.name == null) {
        _workUnit = null;
      } else {
        _workUnit = units.firstWhere(
          (u) => u.name == result.name,
          orElse: () => WorkUnit(id: 0, name: result.name!),
        );
      }
    });
  }

  Future<void> _clearPositionViaSheet(List<JobPosition> positions) async {
    final picked = await showModalBottomSheet<_PosPick>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _PositionPickSheet(
          positions: positions,
          selectedId: _position?.id,
        );
      },
    );
    if (!mounted || picked == null) return;
    setState(() => _position = picked.cleared ? null : picked.position);
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
    required String title,
    bool allowClear = false,
  }) async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context,
      title: title,
      initialDate: current ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      onPicked(picked);
    } else if (allowClear && current != null) {
      // keep current on cancel
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_department == null) {
      showAppSnackBar(context, 'Vui lòng chọn phòng ban', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final salaryText = _baseSalary.text.trim().replaceAll(RegExp(r'[,\s]'), '');
      final baseSalary = salaryText.isEmpty ? null : num.tryParse(salaryText);

      final payload = EmployeeCreatePayload(
        role: 'EMPLOYEE',
        fullName: _fullName.text,
        phone: _phone.text,
        email: _email.text,
        idCardNumber: _idCard.text,
        address: _address.text,
        gender: _gender,
        dateOfBirth: _dateOfBirth == null ? null : _ymd(_dateOfBirth!),
        departmentId: _department!.id,
        positionId: _position?.id,
        attendanceCode: _attendance.text,
        status: _status,
        employmentType: _employmentType,
        hireDate: _hireDate == null ? null : _ymd(_hireDate!),
        baseSalary: baseSalary ?? (_trialMode ? 0 : null),
        workUnitDetail: _workUnit?.name,
        payrollDisplayName: _trialMode
            ? null
            : (_payrollName.text.trim().isEmpty
                ? _fullName.text
                : _payrollName.text),
        degree: _degree.text,
        specialty: _trialMode ? null : _specialty.text,
        professionalDiploma: _trialMode ? null : _professionalDiploma.text,
        practiceScope: _trialMode ? null : _practiceScope.text,
        practiceCertNumber: _trialMode ? null : _practiceCertNumber.text,
        practiceCertDateRaw: _trialMode ? null : _practiceCertDate.text,
        otherTrainingCertificates: _trialMode ? null : _otherCerts.text,
        cki: _trialMode ? null : _cki.text,
        bankAccount: _trialMode ? null : _bankAccount.text,
        bankName: _trialMode ? null : _bankName.text,
        insuranceParticipation:
            _trialMode ? null : _insuranceParticipation,
        socialInsuranceBook: _trialMode ? null : _socialInsurance.text,
        contractNumber: _trialMode ? null : _contractNumber.text,
        contractSignDate: !_trialMode && _contractSignDate != null
            ? _ymd(_contractSignDate!)
            : null,
        contractTerm: _trialMode ? null : _contractTerm.text,
        ethnicity: _trialMode ? null : _ethnicity.text,
        placeOfOrigin: _trialMode ? null : _placeOfOrigin.text,
        maritalStatus: _trialMode ? null : _maritalStatus,
        bloodType: _trialMode ? null : _bloodType.text,
        emergencyContact: _trialMode ? null : _emergencyContact.text,
        emergencyPhone: _trialMode ? null : _emergencyPhone.text,
        dependentsInfo: _trialMode ? null : _dependents.text,
        idCardIssueDate: !_trialMode && _idCardIssueDate != null
            ? _ymd(_idCardIssueDate!)
            : null,
        probationStartDate: _trialMode && _probationStart != null
            ? _ymd(_probationStart!)
            : null,
        officialStartDate: !_trialMode
            ? _ymd(_officialStart ?? _hireDate ?? DateTime.now())
            : null,
        workforceNotes: _notes.text,
      );

      final repo = ref.read(employeeRepositoryProvider);
      final saved = _isEdit
          ? await repo.update(widget.editEmployeeId!, payload)
          : await repo.create(payload);
      if (!mounted) return;
      showAppSnackBar(
        context,
        _isEdit ? 'Đã lưu hồ sơ' : 'Đã tạo nhân viên',
        isSuccess: true,
      );
      if (_isEdit) {
        context.pop(true);
      } else {
        context.pop();
        context.push(RoutePaths.employeeDetailPath(saved.summary.id));
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (mounted) {
        showAppSnackBar(
          context,
          _isEdit ? 'Không lưu được hồ sơ' : 'Không tạo được nhân viên',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departmentsAsync = ref.watch(departmentListProvider);
    final positionsAsync = ref.watch(positionListProvider);
    final title = _isEdit
        ? 'Sửa nhân viên'
        : (_trialMode
            ? 'Thêm thử việc / thực tập'
            : 'Thêm nhân viên chính thức');
    final subtitle = _isEdit
        ? 'Đồng bộ hồ sơ Excel BVMA · cập nhật đầy đủ'
        : (_trialMode
            ? 'Hồ sơ rút gọn — bổ sung khi lên chính thức'
            : 'Đồng bộ hồ sơ Excel BVMA · các mục tuỳ chọn có thể bỏ trống');

    if (_loadingEdit) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: GradientAppBar(title: title, subtitle: 'Đang tải hồ sơ…'),
        body: const SafeArea(child: SkeletonList(itemCount: 6)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: GradientAppBar(
        title: title,
        subtitle: subtitle,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            120,
          ),
          children: [
            if (!_isEdit) ...[
              _ModeToggle(trialMode: _trialMode, onChanged: _applyMode),
              const SizedBox(height: 14),
            ],
            _SectionCard(
              icon: Icons.lock_person_outlined,
              color: const Color(0xFF0F766E),
              title: 'Tài khoản đăng nhập',
              subtitle: _isEdit
                  ? 'Thông tin liên hệ đăng nhập hệ thống'
                  : 'SĐT = tên đăng nhập · mật khẩu mặc định 123',
              children: [
                _Field(
                  controller: _phone,
                  label: _isEdit
                      ? 'Số điện thoại *'
                      : 'Số điện thoại (tên đăng nhập) *',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Bắt buộc';
                    if (t.length < 9) return 'SĐT không hợp lệ';
                    return null;
                  },
                ),
                _Field(
                  controller: _email,
                  label: 'Email (tuỳ chọn)',
                  keyboardType: TextInputType.emailAddress,
                  hint: 'Trống thì tự sinh từ SĐT (@minhan.local)',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.badge_outlined,
              color: const Color(0xFF2563EB),
              title: 'Thông tin cá nhân',
              subtitle: 'Liên hệ & giấy tờ tùy thân',
              children: [
                _Field(
                  controller: _fullName,
                  label: 'Họ và tên *',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                _Field(
                  controller: _idCard,
                  label: 'CCCD/CMND (= mã nhân viên)',
                  hint: 'Trống thì dùng mã tạm TMP-SĐT',
                  keyboardType: TextInputType.number,
                ),
                _PickerTile(
                  label: 'Ngày sinh',
                  value:
                      _dateOfBirth == null ? 'Chọn ngày' : _dmy(_dateOfBirth!),
                  onTap: () => _pickDate(
                    current: _dateOfBirth,
                    title: 'Ngày sinh',
                    onPicked: (d) => setState(() => _dateOfBirth = d),
                  ),
                ),
                _ChoiceRow(
                  label: 'Giới tính',
                  options: const [
                    (null, '—'),
                    ('Nam', 'Nam'),
                    ('Nữ', 'Nữ'),
                    ('Khác', 'Khác'),
                  ],
                  value: _gender,
                  onChanged: (v) => setState(() => _gender = v),
                ),
                _Field(
                  controller: _address,
                  label: 'Địa chỉ',
                  maxLines: 2,
                ),
                if (!_trialMode) ...[
                  _ExpandToggle(
                    expanded: _expandPersonalExtra,
                    label: 'Thêm giấy tờ & liên hệ khẩn cấp',
                    onTap: () => setState(
                      () => _expandPersonalExtra = !_expandPersonalExtra,
                    ),
                  ),
                  if (_expandPersonalExtra) ...[
                    _PickerTile(
                      label: 'Ngày cấp CCCD/CMND',
                      value: _idCardIssueDate == null
                          ? 'Tuỳ chọn'
                          : _dmy(_idCardIssueDate!),
                      onTap: () => _pickDate(
                        current: _idCardIssueDate,
                        title: 'Ngày cấp CCCD',
                        onPicked: (d) => setState(() => _idCardIssueDate = d),
                      ),
                    ),
                    _Field(controller: _ethnicity, label: 'Dân tộc'),
                    _Field(controller: _placeOfOrigin, label: 'Nguyên quán'),
                    _ChoiceRow(
                      label: 'Tình trạng hôn nhân',
                      options: const [
                        (null, '—'),
                        ('Độc thân', 'Độc thân'),
                        ('Đã kết hôn', 'Đã kết hôn'),
                        ('Ly hôn', 'Ly hôn'),
                        ('Khác', 'Khác'),
                      ],
                      value: _maritalStatus,
                      onChanged: (v) => setState(() => _maritalStatus = v),
                    ),
                    _Field(controller: _bloodType, label: 'Nhóm máu'),
                    _Field(
                      controller: _emergencyContact,
                      label: 'Người liên hệ khẩn cấp',
                    ),
                    _Field(
                      controller: _emergencyPhone,
                      label: 'SĐT liên hệ khẩn cấp',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              icon: Icons.work_outline_rounded,
              color: const Color(0xFF7C3AED),
              title: 'Công việc',
              subtitle: 'Phòng ban · bộ phận · vị trí',
              children: [
                if (_trialMode)
                  _ChoiceRow(
                    label: 'Trạng thái *',
                    options: const [
                      ('PROBATION', 'Thử việc'),
                      ('INTERN', 'Thực tập'),
                    ],
                    value: _status,
                    onChanged: (v) {
                      if (v != null) setState(() => _status = v);
                    },
                  ),
                _ChoiceRow(
                  label: 'Hình thức làm việc *',
                  options: const [
                    ('FULL_TIME', 'Toàn thời gian (TTG)'),
                    ('PART_TIME', 'Bán thời gian (BTG)'),
                  ],
                  value: _employmentType,
                  onChanged: (v) {
                    if (v != null) setState(() => _employmentType = v);
                  },
                ),
                departmentsAsync.when(
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (_, _) => Text(
                    'Không tải được phòng ban',
                    style: AppTypography.caption(color: AppColors.error),
                  ),
                  data: (deps) => _PickerTile(
                    label: 'Phòng ban *',
                    value: _department?.name ?? 'Chọn khoa/phòng',
                    emphasized: _department == null,
                    onTap: () => _pickDepartment(deps),
                  ),
                ),
                positionsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (positions) => _PickerTile(
                    label: 'Chức vụ',
                    value: _position?.title ?? 'Tuỳ chọn · mặc định Nhân viên',
                    onTap: () => _clearPositionViaSheet(positions),
                  ),
                ),
                _PickerTile(
                  label: 'Bộ phận',
                  value: _workUnit?.name ??
                      (_department == null
                          ? 'Chọn phòng ban trước'
                          : 'Tuỳ chọn'),
                  enabled: _department != null,
                  onTap: _pickWorkUnit,
                ),
                _Field(
                  controller: _attendance,
                  label: 'Mã chấm công *',
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                _PickerTile(
                  label: _trialMode
                      ? 'Từ ngày (thử việc / thực tập)'
                      : 'Ngày vào làm',
                  value: _hireDate == null ? 'Hôm nay' : _dmy(_hireDate!),
                  onTap: () => _pickDate(
                    current: _hireDate,
                    title: _trialMode ? 'Từ ngày' : 'Ngày vào làm',
                    onPicked: (d) => setState(() {
                      _hireDate = d;
                      if (!_trialMode) _officialStart ??= d;
                    }),
                  ),
                ),
                if (_trialMode)
                  _PickerTile(
                    label: 'Ngày bắt đầu thử việc',
                    value: _probationStart == null
                        ? 'Chọn ngày'
                        : _dmy(_probationStart!),
                    onTap: () => _pickDate(
                      current: _probationStart,
                      title: 'Ngày bắt đầu thử việc',
                      onPicked: (d) => setState(() => _probationStart = d),
                    ),
                  )
                else
                  _PickerTile(
                    label: 'Ngày làm chính thức',
                    value: _officialStart == null
                        ? 'Theo ngày vào làm'
                        : _dmy(_officialStart!),
                    onTap: () => _pickDate(
                      current: _officialStart ?? _hireDate,
                      title: 'Ngày làm chính thức',
                      onPicked: (d) => setState(() => _officialStart = d),
                    ),
                  ),
                if (_trialMode) ...[
                  _Field(controller: _degree, label: 'Trình độ / bằng cấp'),
                  _Field(
                    controller: _baseSalary,
                    label: 'Lương cơ bản (khởi tạo)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                  ),
                  _Field(
                    controller: _notes,
                    label: 'Ghi chú',
                    maxLines: 3,
                  ),
                ],
              ],
            ),
            if (!_trialMode) ...[
              const SizedBox(height: 12),
              _CollapsibleSection(
                icon: Icons.school_rounded,
                color: const Color(0xFF0891B2),
                title: 'Chuyên môn & chứng chỉ',
                subtitle: 'Theo cột chuyên môn Excel nhân lực',
                expanded: _expandExpertise,
                onToggle: () =>
                    setState(() => _expandExpertise = !_expandExpertise),
                children: [
                  _Field(
                    controller: _specialty,
                    label: 'Chuyên ngành / chuyên môn',
                  ),
                  _Field(controller: _degree, label: 'Trình độ / bằng cấp'),
                  _Field(
                    controller: _professionalDiploma,
                    label: 'Văn bằng chuyên môn',
                  ),
                  _Field(
                    controller: _practiceScope,
                    label: 'Phạm vi hành nghề',
                  ),
                  _Field(controller: _practiceCertNumber, label: 'Số CCHN'),
                  _Field(
                    controller: _practiceCertDate,
                    label: 'Ngày cấp CCHN',
                    hint: 'dd/mm/yyyy',
                  ),
                  _Field(controller: _cki, label: 'CKI'),
                  _Field(
                    controller: _otherCerts,
                    label: 'Chứng chỉ đào tạo khác',
                    maxLines: 3,
                    hint: 'Mỗi dòng một chứng chỉ',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CollapsibleSection(
                icon: Icons.account_balance_outlined,
                color: const Color(0xFF059669),
                title: 'Lương & ngân hàng',
                subtitle: 'Thông tin nhận lương trên Excel',
                expanded: _expandBank,
                onToggle: () => setState(() => _expandBank = !_expandBank),
                children: [
                  _Field(
                    controller: _payrollName,
                    label: 'Tên hiển thị bảng lương',
                    hint: 'Trống thì dùng họ tên',
                  ),
                  _Field(
                    controller: _bankAccount,
                    label: 'STK nhận lương',
                    keyboardType: TextInputType.number,
                  ),
                  _Field(
                    controller: _bankName,
                    label: 'Ngân hàng nhận lương',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CollapsibleSection(
                icon: Icons.health_and_safety_outlined,
                color: const Color(0xFFDC2626),
                title: 'Bảo hiểm',
                subtitle: '«Nghỉ thai sản» chuyển NV sang chế độ thai sản',
                expanded: _expandInsurance,
                onToggle: () =>
                    setState(() => _expandInsurance = !_expandInsurance),
                children: [
                  _ChoiceRow(
                    label: 'Tham gia BHXH',
                    options: const [
                      (null, '—'),
                      ('Có tham gia', 'Có tham gia'),
                      ('Không tham gia', 'Không tham gia'),
                      ('Nghỉ thai sản', 'Nghỉ thai sản'),
                    ],
                    value: _insuranceParticipation,
                    onChanged: (v) =>
                        setState(() => _insuranceParticipation = v),
                  ),
                  _Field(
                    controller: _socialInsurance,
                    label: 'Số sổ BHXH',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CollapsibleSection(
                icon: Icons.description_outlined,
                color: const Color(0xFFEA580C),
                title: 'Hợp đồng lao động',
                subtitle: 'Số HĐ · ngày ký · thời hạn',
                expanded: _expandContract,
                onToggle: () =>
                    setState(() => _expandContract = !_expandContract),
                children: [
                  _Field(
                    controller: _contractNumber,
                    label: 'Số hợp đồng',
                  ),
                  _PickerTile(
                    label: 'Ngày ký hợp đồng',
                    value: _contractSignDate == null
                        ? 'Tuỳ chọn'
                        : _dmy(_contractSignDate!),
                    onTap: () => _pickDate(
                      current: _contractSignDate,
                      title: 'Ngày ký hợp đồng',
                      onPicked: (d) => setState(() => _contractSignDate = d),
                    ),
                  ),
                  _Field(
                    controller: _contractTerm,
                    label: 'Thời hạn hợp đồng',
                    hint: 'VD: 12 tháng / Không xác định thời hạn',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CollapsibleSection(
                icon: Icons.notes_rounded,
                color: AppColors.textSecondary,
                title: 'Thông tin bổ sung',
                subtitle: 'Người phụ thuộc · ghi chú',
                expanded: _expandExtra,
                onToggle: () => setState(() => _expandExtra = !_expandExtra),
                children: [
                  _Field(
                    controller: _dependents,
                    label: 'Người phụ thuộc',
                    maxLines: 2,
                  ),
                  _Field(
                    controller: _notes,
                    label: 'Ghi chú',
                    maxLines: 3,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            8,
            AppSpacing.page,
            12,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => context.pop(),
                  child: const Text('Huỷ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isEdit
                              ? Icons.save_rounded
                              : Icons.person_add_alt_1_rounded,
                          size: 20,
                        ),
                  label: Text(
                    _saving
                        ? (_isEdit ? 'Đang lưu…' : 'Đang tạo…')
                        : (_isEdit ? 'Lưu thay đổi' : 'Tạo nhân viên'),
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

class _PositionPickSheet extends StatelessWidget {
  const _PositionPickSheet({
    required this.positions,
    this.selectedId,
  });

  final List<JobPosition> positions;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn chức vụ',
                        style: AppTypography.style(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Tuỳ chọn — trống thì gán «Nhân viên»',
                        style: AppTypography.caption(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.clear_rounded,
              color: selectedId == null
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            title: Text(
              'Không chọn (mặc định Nhân viên)',
              style: AppTypography.style(
                fontWeight:
                    selectedId == null ? FontWeight.w800 : FontWeight.w600,
                color: selectedId == null
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
            onTap: () => Navigator.pop(context, const _PosPick.cleared()),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              itemCount: positions.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = positions[i];
                final selected = p.id == selectedId;
                return ListTile(
                  leading: Icon(
                    Icons.work_outline_rounded,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
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

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.trialMode, required this.onChanged});

  final bool trialMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              icon: Icons.verified_user_outlined,
              label: 'Chính thức',
              selected: !trialMode,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ModeChip(
              icon: Icons.school_outlined,
              label: 'Thử việc / TT',
              selected: trialMode,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({
    required this.expanded,
    required this.label,
    required this.onTap,
  });

  final bool expanded;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              expanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
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
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.style(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.caption(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final child in children) ...[
            child,
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.style(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: AppTypography.caption(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                children: [
                  for (final child in children) ...[
                    child,
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      validator: validator,
      inputFormatters: inputFormatters,
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
    this.enabled = true,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool enabled;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: AppRadius.brMd,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.brMd,
            border: Border.all(
              color: emphasized
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.borderSoft,
            ),
          ),
          child: Row(
            children: [
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
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
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

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<(String?, String)> options;
  final String? value;
  final ValueChanged<String?> onChanged;

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
                selectedColor: AppColors.primary.withValues(alpha: 0.18),
                labelStyle: AppTypography.style(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: value == opt.$1
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
                side: BorderSide(
                  color: value == opt.$1
                      ? AppColors.primary
                      : AppColors.borderSoft,
                ),
                backgroundColor: AppColors.surfaceMuted,
              ),
          ],
        ),
      ],
    );
  }
}
