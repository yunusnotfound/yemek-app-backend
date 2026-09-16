import 'dart:async';

import 'package:bitir_yemek_mobile/config/theme.dart';
import 'package:bitir_yemek_mobile/core/di/service_locator.dart';
import 'package:bitir_yemek_mobile/features/auth/data/models/user_model.dart';
import 'package:bitir_yemek_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:bitir_yemek_mobile/features/profile/presentation/bloc/profile_bloc.dart';
import 'package:bitir_yemek_mobile/features/profile/presentation/pages/profile_page.dart';
import 'package:bitir_yemek_mobile/features/profile/presentation/widgets/profile_header.dart';
import 'package:bitir_yemek_mobile/features/profile/presentation/widgets/profile_menu_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'campaign_ui_test.dart' show CampaignAdapter;

final _user = UserModel.fromJson({
  'id': 'profile-recovery-user',
  'name': 'Deniz Yılmaz',
  'email': 'deniz@example.com',
  'phone': '5551234567',
  'role': 'customer',
  'isEmailVerified': true,
  'createdAt': '2026-01-01T12:00:00Z',
  'updatedAt': '2026-01-01T12:00:00Z',
});

class _ProfileRepository extends ProfileRepository {
  var deleteResult = Completer<ProfileResult>();
  final pendingLoads = <Completer<ProfileResult>>[];
  UserModel user = _user;
  int loads = 0;
  int deletions = 0;
  int updates = 0;
  int logouts = 0;

  @override
  Future<ProfileResult> getProfile() async {
    loads++;
    if (pendingLoads.isNotEmpty) return pendingLoads.removeAt(0).future;
    return ProfileResult.success(user: user);
  }

  @override
  Future<ProfileResult> updateProfile({String? name, String? phone}) async {
    updates++;
    user = UserModel.fromJson({
      ...user.toJson(),
      'name': name ?? user.name,
      'phone': phone ?? user.phone,
    });
    return ProfileResult.success(user: user);
  }

  @override
  Future<ProfileResult> deleteAccount() {
    deletions++;
    return deleteResult.future;
  }

  @override
  Future<void> logout() async => logouts++;
}

Future<ProfileBloc> _loadedBloc(_ProfileRepository repository) async {
  final bloc = ProfileBloc(profileRepository: repository);
  final loaded = bloc.stream.firstWhere((state) => state is ProfileLoaded);
  bloc.add(LoadProfile());
  await loaded;
  addTearDown(bloc.close);
  return bloc;
}

ButtonStyleButton _button(WidgetTester tester, String label) =>
    tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      ),
    );

void main() {
  setUpAll(() async => initializeDateFormatting('tr_TR'));

  test(
    'failed account deletion retains the user and permits editing and deletion retry',
    () async {
      final repository = _ProfileRepository();
      final bloc = await _loadedBloc(repository);
      final states = <ProfileState>[];
      final subscription = bloc.stream.listen(states.add);
      addTearDown(subscription.cancel);

      final deleting = bloc.stream.firstWhere(
        (state) => state is AccountDeleting,
      );
      bloc.add(DeleteAccountRequested());
      expect((await deleting as AccountDeleting).user, _user);

      final recovered = bloc.stream.firstWhere(
        (state) => state is ProfileLoaded,
      );
      repository.deleteResult.complete(
        ProfileResult.failure('Bağlantı kesildi'),
      );
      expect((await recovered as ProfileLoaded).user, _user);
      final failure = states.whereType<AccountDeleteError>().single;
      expect(failure.user, _user);
      expect(failure.message, 'Bağlantı kesildi');
      expect(states.map((state) => state.runtimeType), [
        AccountDeleting,
        AccountDeleteError,
        ProfileLoaded,
      ]);

      final updated = bloc.stream.firstWhere((state) => state is ProfileLoaded);
      bloc.add(const UpdateProfile(name: 'Deniz Kaya', phone: '5559876543'));
      final changedUser = (await updated as ProfileLoaded).user;
      expect(changedUser.name, 'Deniz Kaya');
      expect(changedUser.phone, '5559876543');
      expect(repository.updates, 1);

      repository.deleteResult = Completer<ProfileResult>();
      final retry = bloc.stream.firstWhere((state) => state is AccountDeleting);
      bloc.add(DeleteAccountRequested());
      expect((await retry as AccountDeleting).user, changedUser);
      final deleted = bloc.stream.firstWhere(
        (state) => state is AccountDeleted,
      );
      repository.deleteResult.complete(ProfileResult.success());
      await deleted;
      expect(repository.deletions, 2);
      expect(bloc.state, isA<AccountDeleted>());
    },
  );

  test(
    'pending account deletion ignores duplicates and concurrent profile actions',
    () async {
      final repository = _ProfileRepository();
      final bloc = await _loadedBloc(repository);
      final deleting = bloc.stream.firstWhere(
        (state) => state is AccountDeleting,
      );
      bloc.add(DeleteAccountRequested());
      await deleting;

      bloc
        ..add(DeleteAccountRequested())
        ..add(DeleteAccountRequested())
        ..add(const UpdateProfile(name: 'İstenmeyen değişiklik'))
        ..add(ProfileLogoutRequested())
        ..add(LoadProfile());
      // Drain already queued events while the repository request stays pending.
      await Future<void>.delayed(Duration.zero);
      expect(repository.deletions, 1);
      expect(repository.updates, 0);
      expect(repository.logouts, 0);
      expect(repository.loads, 1);
      expect((bloc.state as AccountDeleting).user, _user);

      final recovered = bloc.stream.firstWhere(
        (state) => state is ProfileLoaded,
      );
      repository.deleteResult.complete(ProfileResult.failure('Tekrar dene'));
      await recovered;
      expect((bloc.state as ProfileLoaded).user, _user);
    },
  );

  test(
    'a late profile response cannot unlock pending account deletion',
    () async {
      final repository = _ProfileRepository();
      final bloc = await _loadedBloc(repository);
      final firstLoad = Completer<ProfileResult>();
      final secondLoad = Completer<ProfileResult>();
      repository.pendingLoads.addAll([firstLoad, secondLoad]);
      bloc
        ..add(LoadProfile())
        ..add(LoadProfile());
      await Future<void>.delayed(Duration.zero);

      final loaded = bloc.stream.firstWhere((state) => state is ProfileLoaded);
      firstLoad.complete(ProfileResult.success(user: _user));
      await loaded;
      final deleting = bloc.stream.firstWhere(
        (state) => state is AccountDeleting,
      );
      bloc.add(DeleteAccountRequested());
      await deleting;

      secondLoad.complete(ProfileResult.success(user: _user));
      await Future<void>.delayed(Duration.zero);
      try {
        expect(bloc.state, isA<AccountDeleting>());
        expect(repository.deletions, 1);
      } finally {
        repository.deleteResult.complete(ProfileResult.failure('Tekrar dene'));
      }
    },
  );

  testWidgets(
    'profile content survives pending and failed deletion and can be edited again',
    (tester) async {
      final repository = _ProfileRepository();
      final bloc = await _loadedBloc(repository);
      final originalAdapter = appDioClient.dio.httpClientAdapter;
      final originalInterceptors = appDioClient.dio.interceptors.toList();
      final adapter = CampaignAdapter();
      appDioClient.dio.interceptors.clear();
      appDioClient.dio.httpClientAdapter = adapter;
      addTearDown(() {
        appDioClient.dio.httpClientAdapter = originalAdapter;
        appDioClient.dio.interceptors
          ..clear()
          ..addAll(originalInterceptors);
      });

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: BlocProvider.value(value: bloc, child: const ProfilePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfileHeader>(find.byType(ProfileHeader)).user,
        _user,
      );

      await tester.ensureVisible(find.text('Hesabı Sil'));
      await tester.tap(find.text('Hesabı Sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hesabı Sil').last);
      await tester.pumpAndSettle();
      expect(bloc.state, isA<AccountDeleting>());
      expect(
        tester.widget<ProfileHeader>(find.byType(ProfileHeader)).user,
        _user,
      );
      expect(find.text('Profil yüklenemedi'), findsNothing);
      expect(find.text(_user.email), findsWidgets);
      expect(_button(tester, 'Hesap siliniyor…').onPressed, isNull);
      expect(_button(tester, 'Profili Düzenle').onPressed, isNull);
      expect(_button(tester, 'Çıkış Yap').onPressed, isNull);
      for (final title in ['Kişisel Bilgiler', 'Telefon']) {
        final item = tester.widget<ProfileMenuItem>(
          find.byWidgetPredicate(
            (widget) => widget is ProfileMenuItem && widget.title == title,
          ),
        );
        expect(item.onTap, isNull);
      }

      repository.deleteResult.complete(
        ProfileResult.failure('Bağlantı kesildi, tekrar dene.'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Bağlantı kesildi, tekrar dene.'), findsOneWidget);
      expect(
        tester.widget<ProfileHeader>(find.byType(ProfileHeader)).user,
        _user,
      );
      expect(find.text('Profil yüklenemedi'), findsNothing);
      expect(_button(tester, 'Hesabı Sil').onPressed, isNotNull);
      expect(_button(tester, 'Profili Düzenle').onPressed, isNotNull);
      expect(_button(tester, 'Çıkış Yap').onPressed, isNotNull);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Profili Düzenle'));
      await tester.tap(find.text('Profili Düzenle'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Deniz Kaya');
      await tester.ensureVisible(find.text('Kaydet'));
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ProfileHeader>(find.byType(ProfileHeader)).user.name,
        'Deniz Kaya',
      );
      expect(repository.updates, 1);
      expect(repository.deletions, 1);
      expect(
        adapter.calls.every((request) => request.path == '/coupons/mine'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
