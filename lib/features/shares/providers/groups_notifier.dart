import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/share_group_models.dart';
import '../controllers/group_controller.dart';

/// Loads and exposes the caller's share groups: the groups they own (with
/// rosters) and the groups they belong to. Re-fetched after every create,
/// delete, add-member, or remove-member so the screen reflects committed server
/// state. Cleared on logout alongside the other share providers.
class GroupsNotifier extends AsyncNotifier<GroupsResponse> {
  @override
  Future<GroupsResponse> build() => _load();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<GroupsResponse> _load() {
    return ref.read(groupControllerProvider).listGroups();
  }
}

final groupsNotifierProvider =
    AsyncNotifierProvider<GroupsNotifier, GroupsResponse>(GroupsNotifier.new);
