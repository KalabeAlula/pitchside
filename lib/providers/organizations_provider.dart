import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match_model.dart';
import '../models/organization.dart';
import 'service_provider.dart';

/// Clubs the signed-in player belongs to, with their seat in each.
final myOrganizationsProvider = FutureProvider<List<OrganizationMembership>>(
  (ref) => ref.watch(pitchsideServiceProvider).getMyOrganizations(),
);

/// The public club directory, used to pick a challenge opponent.
final organizationsDirectoryProvider = FutureProvider<List<Organization>>(
  (ref) => ref.watch(pitchsideServiceProvider).getOrganizations(),
);

final organizationMembersProvider =
    FutureProvider.family<List<OrganizationMember>, String>((ref, orgId) {
      return ref.watch(pitchsideServiceProvider).getOrganizationMembers(orgId);
    });

/// Null for members who are not managers: the server hides the code from them.
final organizationJoinCodeProvider = FutureProvider.family<String?, String>((
  ref,
  orgId,
) {
  return ref.watch(pitchsideServiceProvider).getOrganizationJoinCode(orgId);
});

/// Upcoming club matches. Null means every club the viewer belongs to.
final orgMatchesProvider = FutureProvider.family<List<MatchOverview>, String?>((
  ref,
  orgId,
) {
  return ref
      .watch(pitchsideServiceProvider)
      .getOrgMatches(organizationId: orgId);
});

final createOrganizationControllerProvider =
    AsyncNotifierProvider<CreateOrganizationController, void>(
      CreateOrganizationController.new,
    );

class CreateOrganizationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Organization> create({
    required String name,
    String? about,
    String? subCityId,
  }) async {
    state = const AsyncLoading();
    try {
      final organization = await ref
          .read(pitchsideServiceProvider)
          .createOrganization(name: name, about: about, subCityId: subCityId);
      state = const AsyncData(null);
      ref.invalidate(myOrganizationsProvider);
      ref.invalidate(organizationsDirectoryProvider);
      return organization;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final joinOrganizationControllerProvider =
    AsyncNotifierProvider<JoinOrganizationController, void>(
      JoinOrganizationController.new,
    );

class JoinOrganizationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Organization> join(String code) async {
    state = const AsyncLoading();
    try {
      final organization = await ref
          .read(pitchsideServiceProvider)
          .joinOrganization(code);
      state = const AsyncData(null);
      ref.invalidate(myOrganizationsProvider);
      ref.invalidate(organizationMembersProvider);
      return organization;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final leaveOrganizationControllerProvider =
    AsyncNotifierProvider<LeaveOrganizationController, void>(
      LeaveOrganizationController.new,
    );

class LeaveOrganizationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> leave(String organizationId) async {
    state = const AsyncLoading();
    try {
      await ref
          .read(pitchsideServiceProvider)
          .leaveOrganization(organizationId);
      state = const AsyncData(null);
      ref.invalidate(myOrganizationsProvider);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

/// Maps the database error codes raised by the club RPCs to player-facing text.
String organizationErrorMessage(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      '45210' => 'Club name must be between 2 and 60 characters.',
      '45211' => 'A club with that name already exists. Try another name.',
      '45212' => 'That join code is not valid. Check it with your club admin.',
      '45213' => 'You are already a member of this club.',
      '45214' => 'The owner cannot leave the club.',
      '45215' => 'You are not a member of this club.',
      '42501' => 'Sign in to use clubs.',
      _ => 'Could not update the club. Please try again.',
    };
  }
  return 'No connection. Check your internet and try again.';
}
