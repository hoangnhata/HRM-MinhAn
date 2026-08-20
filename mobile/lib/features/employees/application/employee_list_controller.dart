import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/employee.dart';
import '../data/employee_repository.dart';

const _notProvided = Object();

class EmployeeListState {
  const EmployeeListState({
    this.items = const [],
    this.page = 0,
    this.totalElements = 0,
    this.hasMore = true,
    this.loading = false,
    this.loadingMore = false,
    this.query = '',
    this.status = 'OFFICIAL',
    this.departmentId,
    this.departmentName,
    this.workUnit,
    this.officialWorkFilter,
    this.error,
    this.loadMoreError,
  });

  final List<EmployeeSummary> items;
  final int page;
  final int totalElements;
  final bool hasMore;
  final bool loading;
  final bool loadingMore;
  final String query;
  /// `OFFICIAL` | `TRIAL` | `TERMINATED` | null.
  final String? status;
  final int? departmentId;
  final String? departmentName;
  final String? workUnit;
  /// `WORKING` | `MATERNITY_LEAVE` | `FULL_TIME` | `PART_TIME`.
  final String? officialWorkFilter;
  final String? error;
  final String? loadMoreError;

  int get activeFilterCount {
    var n = 0;
    if (departmentId != null) n++;
    if (workUnit != null && workUnit!.isNotEmpty) n++;
    if (officialWorkFilter != null && officialWorkFilter!.isNotEmpty) n++;
    return n;
  }

  bool get hasExtraFilters => activeFilterCount > 0;

  EmployeeListState copyWith({
    List<EmployeeSummary>? items,
    int? page,
    int? totalElements,
    bool? hasMore,
    bool? loading,
    bool? loadingMore,
    String? query,
    Object? status = _notProvided,
    Object? departmentId = _notProvided,
    Object? departmentName = _notProvided,
    Object? workUnit = _notProvided,
    Object? officialWorkFilter = _notProvided,
    Object? error = _notProvided,
    Object? loadMoreError = _notProvided,
  }) {
    return EmployeeListState(
      items: items ?? this.items,
      page: page ?? this.page,
      totalElements: totalElements ?? this.totalElements,
      hasMore: hasMore ?? this.hasMore,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      query: query ?? this.query,
      status: identical(status, _notProvided) ? this.status : status as String?,
      departmentId: identical(departmentId, _notProvided)
          ? this.departmentId
          : departmentId as int?,
      departmentName: identical(departmentName, _notProvided)
          ? this.departmentName
          : departmentName as String?,
      workUnit:
          identical(workUnit, _notProvided) ? this.workUnit : workUnit as String?,
      officialWorkFilter: identical(officialWorkFilter, _notProvided)
          ? this.officialWorkFilter
          : officialWorkFilter as String?,
      error: identical(error, _notProvided) ? this.error : error as String?,
      loadMoreError: identical(loadMoreError, _notProvided)
          ? this.loadMoreError
          : loadMoreError as String?,
    );
  }
}

class EmployeeListController extends StateNotifier<EmployeeListState> {
  EmployeeListController(this._repository) : super(const EmployeeListState()) {
    load();
  }

  final EmployeeRepository _repository;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null, loadMoreError: null);
    await _fetch(showLoading: true);
  }

  /// Làm mới nền — giữ danh sách cũ cho đến khi có dữ liệu mới.
  Future<void> refreshQuietly() => _fetch(showLoading: false);

  Future<void> _fetch({required bool showLoading}) async {
    try {
      final res = await _repository.list(
        page: 0,
        query: state.query,
        statusGroup: state.status,
        departmentId: state.departmentId,
        workUnit: state.workUnit,
        officialWorkFilter:
            state.status == 'OFFICIAL' ? state.officialWorkFilter : null,
      );
      state = state.copyWith(
        items: res.content,
        page: 0,
        totalElements: res.totalElements,
        hasMore: !res.last,
        loading: false,
        error: null,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: showLoading
            ? 'Không tải được danh sách nhân viên'
            : state.error,
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loading ||
        state.loadingMore ||
        !state.hasMore ||
        state.loadMoreError != null) {
      return;
    }
    state = state.copyWith(loadingMore: true, loadMoreError: null);
    try {
      final nextPage = state.page + 1;
      final res = await _repository.list(
        page: nextPage,
        query: state.query,
        statusGroup: state.status,
        departmentId: state.departmentId,
        workUnit: state.workUnit,
        officialWorkFilter:
            state.status == 'OFFICIAL' ? state.officialWorkFilter : null,
      );
      state = state.copyWith(
        items: [...state.items, ...res.content],
        page: nextPage,
        totalElements: res.totalElements,
        hasMore: !res.last,
        loadingMore: false,
        loadMoreError: null,
      );
    } catch (_) {
      state = state.copyWith(
        loadingMore: false,
        loadMoreError: 'Không tải thêm được nhân viên',
      );
    }
  }

  Future<void> retryLoadMore() async {
    state = state.copyWith(loadMoreError: null);
    await loadMore();
  }

  void setQuery(String value) {
    if (state.query == value) return;
    _resetAndReload(query: value);
  }

  void setStatus(String? value) {
    if (state.status == value) return;
    state = state.copyWith(
      status: value,
      // Bộ lọc tình trạng làm việc chỉ áp dụng tab chính thức.
      officialWorkFilter: value == 'OFFICIAL' ? state.officialWorkFilter : null,
      items: const [],
      page: 0,
      totalElements: 0,
      hasMore: true,
      error: null,
      loadMoreError: null,
    );
    load();
  }

  void applyFilters({
    int? departmentId,
    String? departmentName,
    String? workUnit,
    String? officialWorkFilter,
  }) {
    state = state.copyWith(
      departmentId: departmentId,
      departmentName: departmentName,
      workUnit: workUnit,
      officialWorkFilter: officialWorkFilter,
      items: const [],
      page: 0,
      totalElements: 0,
      hasMore: true,
      error: null,
      loadMoreError: null,
    );
    load();
  }

  void clearFilters() {
    if (!state.hasExtraFilters) return;
    state = state.copyWith(
      departmentId: null,
      departmentName: null,
      workUnit: null,
      officialWorkFilter: null,
      items: const [],
      page: 0,
      totalElements: 0,
      hasMore: true,
      error: null,
      loadMoreError: null,
    );
    load();
  }

  void _resetAndReload({String? query}) {
    state = state.copyWith(
      query: query ?? state.query,
      items: const [],
      page: 0,
      totalElements: 0,
      hasMore: true,
      error: null,
      loadMoreError: null,
    );
    load();
  }
}

final employeeListControllerProvider =
    StateNotifierProvider.autoDispose<
      EmployeeListController,
      EmployeeListState
    >((ref) {
      return EmployeeListController(ref.watch(employeeRepositoryProvider));
    });
