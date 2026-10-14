import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/superadmin/logic/role_permissions.dart';

/// Mirrors `src/lib/adminPermissions.ts` behaviour.
void main() {
  test('26 keys in web order, including fixed_assets and documents', () {
    expect(AdminPerm.values.map((p) => p.key).toList(), [
      'residents_rw', 'guards_rw', 'geofence_rw', 'finance', 'fixed_assets',
      'donations', 'splits', 'events', //
      'meetings', 'documents', 'committee', 'polls', 'notifications', 'parking',
      'visitor', 'delivery', //
      'vehicle', 'blacklist', 'directory', 'quick', 'report', 'logs', 'audit',
      'settings', 'password', 'biometric',
    ]);
    expect(AdminPerm.fromKey('fixed_assets'), AdminPerm.fixedAssets);
    expect(AdminPerm.fromKey('nope'), isNull);
  });

  test('NEW_CUSTOM_ROLE_PERMISSIONS', () {
    final p = RolePermissions.newCustom;
    expect(
      AdminPerm.values.where((k) => p[k]).toSet(),
      {
        AdminPerm.finance,
        AdminPerm.directory,
        AdminPerm.password,
        AdminPerm.biometric
      },
    );
    expect(p.toJson().length, 26);
    expect(p.toJson()['fixed_assets'], isFalse);
    expect(p.toJson()['finance'], isTrue);
  });

  group('mergeRolePermissions', () {
    test('non-object → full access', () {
      for (final raw in [null, 'x', 3, true]) {
        expect(RolePermissions.merge(raw).sameAs(RolePermissions.full), isTrue,
            reason: '$raw');
      }
    });

    test('object without booleans → locked-down default', () {
      expect(
          RolePermissions.merge(<String, dynamic>{})
              .sameAs(RolePermissions.newCustom),
          isTrue);
      expect(
          RolePermissions.merge({'finance': 'true', 'x': 1})
              .sameAs(RolePermissions.newCustom),
          isTrue);
      expect(
          RolePermissions.merge(<dynamic>[]).sameAs(RolePermissions.newCustom),
          isTrue);
    });

    test(
        'partial booleans override a full base (legacy rows lacking new keys stay open)',
        () {
      // Seeded legacy Treasurer row (before fixed_assets / meetings / documents / committee existed).
      final legacy = {
        'residents_rw': false, 'guards_rw': false, 'geofence_rw': false,
        'finance': true, 'donations': true, //
        'splits': true, 'events': true, 'polls': false, 'notifications': true,
        'parking': false, 'visitor': false,
        'delivery': false, 'vehicle': false, 'blacklist': false,
        'directory': true, 'quick': false, 'report': true,
        'logs': false, 'audit': false, 'settings': false, 'password': true,
        'biometric': true,
      };
      final p = RolePermissions.merge(legacy);
      expect(p[AdminPerm.residentsRw], isFalse);
      expect(p[AdminPerm.finance], isTrue);
      expect(p[AdminPerm.fixedAssets], isTrue);
      expect(p[AdminPerm.meetings], isTrue);
      expect(p[AdminPerm.documents], isTrue);
      expect(p[AdminPerm.committee], isTrue);
      expect(p[AdminPerm.polls], isFalse);
      expect(
          RolePermissions.merge(
              {'finance': false, 'unknown': true})[AdminPerm.finance],
          isFalse);
      expect(
          RolePermissions.merge({'unknown': true}).sameAs(RolePermissions.full),
          isTrue);
    });

    test('toJson → merge round-trip is lossless', () {
      final p = RolePermissions.newCustom
          .withValue(AdminPerm.documents, true)
          .withValue(AdminPerm.finance, false);
      expect(RolePermissions.merge(p.toJson()).sameAs(p), isTrue);
      expect(p.enabledCount, 4);
    });
  });

  group('permissionsFromAdminJoin', () {
    test('no role → full', () {
      expect(
          RolePermissions.fromAdminJoin(roleId: null)
              .sameAs(RolePermissions.full),
          isTrue);
      expect(
          RolePermissions.fromAdminJoin(roleId: '')
              .sameAs(RolePermissions.full),
          isTrue);
    });

    test(
        'role without permissions object → full; with → merged; list relation uses first',
        () {
      expect(
          RolePermissions.fromAdminJoin(roleId: 'r', societyRoles: null)
              .sameAs(RolePermissions.full),
          isTrue);
      expect(
          RolePermissions.fromAdminJoin(
              roleId: 'r',
              societyRoles: {'slug': 'x'}).sameAs(RolePermissions.full),
          isTrue);
      expect(
          RolePermissions.fromAdminJoin(
              roleId: 'r',
              societyRoles: {'permissions': null}).sameAs(RolePermissions.full),
          isTrue);
      expect(
        RolePermissions.fromAdminJoin(
                roleId: 'r', societyRoles: {'permissions': <String, dynamic>{}})
            .sameAs(RolePermissions.newCustom),
        isTrue,
      );
      final p = RolePermissions.fromAdminJoin(roleId: 'r', societyRoles: [
        {
          'permissions': {'audit': false}
        },
      ]);
      expect(p[AdminPerm.audit], isFalse);
      expect(p[AdminPerm.finance], isTrue);
    });
  });

  group('isAdminTabAllowed', () {
    test(
        'overview / tour always; splits via events or splits; unknown tab denied',
        () {
      final none = RolePermissions.all(false);
      expect(isAdminTabAllowed('overview', none), isTrue);
      expect(isAdminTabAllowed('tour', none), isTrue);
      expect(isAdminTabAllowed('splits', none), isFalse);
      expect(
          isAdminTabAllowed('splits', none.withValue(AdminPerm.events, true)),
          isTrue);
      expect(
          isAdminTabAllowed('splits', none.withValue(AdminPerm.splits, true)),
          isTrue);
      expect(
          isAdminTabAllowed(
              'fixed_assets', none.withValue(AdminPerm.fixedAssets, true)),
          isTrue);
      expect(
          isAdminTabAllowed(
              'residents', none.withValue(AdminPerm.residentsRw, true)),
          isTrue);
      expect(isAdminTabAllowed('residents', none), isFalse);
      expect(isAdminTabAllowed('something', RolePermissions.full), isFalse);
      expect(allowedAdminTabs(none), ['overview', 'tour']);
      expect(allowedAdminTabs(RolePermissions.full).length,
          kAdminTabPermission.length);
    });
  });

  test('seeded templates match phonepe-callback', () {
    final byslug = {
      for (final t in kSeededRoleTemplates) t.slug: t.permissions
    };
    expect(byslug['admin']!.sameAs(RolePermissions.full), isTrue);
    expect(byslug['treasurer']![AdminPerm.fixedAssets], isTrue);
    expect(byslug['treasurer']![AdminPerm.meetings], isFalse);
    expect(byslug['president']![AdminPerm.audit], isTrue);
    expect(byslug['vice_president']![AdminPerm.audit], isFalse);
    expect(byslug['secretary']![AdminPerm.report], isFalse);
    expect(byslug['secretary']![AdminPerm.documents], isTrue);
    expect(byslug['secretary']!.enabledCount, 9);
  });

  test('every permission belongs to exactly one matrix group', () {
    final all = kPermGroups.values.expand((e) => e).toList();
    expect(all.length, AdminPerm.values.length);
    expect(all.toSet(), AdminPerm.values.toSet());
  });
}
