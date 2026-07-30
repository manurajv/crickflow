import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/admin_app_type.dart';
import '../../../models/admin_role.dart';
import '../../../models/admin_user.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/users_repository.dart';
import '../models/admin_audit_log.dart';
import '../models/managed_user.dart';
import '../models/user_account_status.dart';
import '../models/user_filters.dart';

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository();
});

class UsersListState {
  const UsersListState({
    this.users = const [],
    this.filters = UserListFilters.empty,
    this.sort = const UserSort(),
    this.pageSize = 25,
    this.hasMore = false,
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedUserId,
    this.summary = const UserSummaryStats(),
  });

  final List<ManagedUser> users;
  final UserListFilters filters;
  final UserSort sort;
  final int pageSize;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? selectedUserId;
  final UserSummaryStats summary;

  UsersListState copyWith({
    List<ManagedUser>? users,
    UserListFilters? filters,
    UserSort? sort,
    int? pageSize,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? selectedUserId,
    bool clearSelection = false,
    UserSummaryStats? summary,
  }) {
    return UsersListState(
      users: users ?? this.users,
      filters: filters ?? this.filters,
      sort: sort ?? this.sort,
      pageSize: pageSize ?? this.pageSize,
      hasMore: hasMore ?? this.hasMore,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      selectedUserId:
          clearSelection ? null : (selectedUserId ?? this.selectedUserId),
      summary: summary ?? this.summary,
    );
  }
}

class UsersListController extends StateNotifier<UsersListState> {
  UsersListController(this._ref) : super(const UsersListState(isLoading: true)) {
    // Event-queue deferral avoids ConcurrentModificationError on web (microtask
    // can still run while Riverpod is flushing dependents).
    Future(() {
      if (mounted) refresh();
    });
  }

  final Ref _ref;
  UsersRepository get _repo => _ref.read(usersRepositoryProvider);

  AdminAppType get _appType => _ref.read(adminAppTypeProvider);
  AdminUser? get _actor => _ref.read(adminSessionProvider).adminUser;

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
      users: const [],
    );
    try {
      final summary = await _repo.fetchSummary(
        appType: _appType,
        actor: _actor,
      );
      final page = await _repo.fetchPage(
        appType: _appType,
        actor: _actor,
        filters: state.filters,
        sort: state.sort,
        limit: state.pageSize,
      );
      if (!mounted) return;
      state = state.copyWith(
        users: page.users,
        hasMore: page.hasMore,
        cursor: page.cursor,
        isLoading: false,
        summary: summary,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repo.fetchPage(
        appType: _appType,
        actor: _actor,
        filters: state.filters,
        sort: state.sort,
        startAfter: state.cursor,
        limit: state.pageSize,
      );
      state = state.copyWith(
        users: [...state.users, ...page.users],
        hasMore: page.hasMore,
        cursor: page.cursor,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void setQuery(String query) {
    state = state.copyWith(filters: state.filters.copyWith(query: query));
  }

  Future<void> applyFilters(UserListFilters filters) async {
    state = state.copyWith(filters: filters);
    await refresh();
  }

  Future<void> setSort(UserSortField field) async {
    state = state.copyWith(sort: state.sort.toggle(field));
    await refresh();
  }

  void selectUser(String? id) {
    if (id == null) {
      state = state.copyWith(clearSelection: true);
    } else {
      state = state.copyWith(selectedUserId: id);
    }
  }

  Future<void> setStatus(
    ManagedUser user,
    UserAccountStatus status, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.updateAccountStatus(
      target: user,
      status: status,
      actor: actor,
      reason: reason,
    );
    await refresh();
    if (state.selectedUserId == user.id) {
      state = state.copyWith(selectedUserId: user.id);
    }
  }

  Future<void> setVerified(ManagedUser user, bool verified,
      {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.setVerified(
      target: user,
      verified: verified,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> resetPassword(ManagedUser user, {String? reason}) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.sendPasswordReset(
      target: user,
      actor: actor,
      reason: reason,
    );
  }

  Future<void> setAdminRole(
    ManagedUser user,
    AdminRole? role, {
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    // Only Super Admin can grant Super Admin.
    if (role == AdminRole.superAdmin &&
        AdminRole.tryParse(actor.roleId) != AdminRole.superAdmin) {
      throw StateError('Only Super Admin can promote to Super Admin');
    }
    await _repo.setAdminRole(
      target: user,
      role: role,
      actor: actor,
      reason: reason,
    );
    await refresh();
  }

  Future<void> saveBasicInfo(
    ManagedUser user, {
    String? displayName,
    String? phoneNumber,
    String? bio,
    String? country,
    String? stateProvince,
    String? city,
    String? reason,
  }) async {
    final actor = _actor;
    if (actor == null) return;
    await _repo.updateBasicInfo(
      target: user,
      actor: actor,
      displayName: displayName,
      phoneNumber: phoneNumber,
      bio: bio,
      country: country,
      stateProvince: stateProvince,
      city: city,
      reason: reason,
    );
    await refresh();
  }
}

final usersListControllerProvider =
    StateNotifierProvider.autoDispose<UsersListController, UsersListState>(
        (ref) {
  return UsersListController(ref);
});

final selectedManagedUserProvider =
    FutureProvider.autoDispose<ManagedUser?>((ref) async {
  final id =
      ref.watch(usersListControllerProvider.select((s) => s.selectedUserId));
  if (id == null) return null;
  return ref.watch(usersRepositoryProvider).fetchById(
        id,
        appType: ref.watch(adminAppTypeProvider),
        actor: ref.watch(adminSessionProvider).adminUser,
      );
});

final selectedUserActivityProvider =
    FutureProvider.autoDispose<List<UserActivityItem>>((ref) async {
  final user = await ref.watch(selectedManagedUserProvider.future);
  if (user == null) return const [];
  return ref.watch(usersRepositoryProvider).fetchActivityTimeline(user);
});
