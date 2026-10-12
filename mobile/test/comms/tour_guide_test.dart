import 'package:flutter_test/flutter_test.dart';
import 'package:kutumbika_mobile/features/comms/tour/tour_guide.dart';
import 'package:kutumbika_mobile/services/admin_permissions.dart';

/// Permissions with only [on] enabled (uses the constructor so the test does not depend on
/// the JSON merge rules).
AdminPanelPermissions only(Set<String> on) => AdminPanelPermissions(
      residentsRw: on.contains('residents_rw'),
      guardsRw: on.contains('guards_rw'),
      geofenceRw: on.contains('geofence_rw'),
      finance: on.contains('finance'),
      donations: on.contains('donations'),
      splits: on.contains('splits'),
      events: on.contains('events'),
      meetings: on.contains('meetings'),
      committee: on.contains('committee'),
      polls: on.contains('polls'),
      notifications: on.contains('notifications'),
      parking: on.contains('parking'),
      visitor: on.contains('visitor'),
      delivery: on.contains('delivery'),
      vehicle: on.contains('vehicle'),
      blacklist: on.contains('blacklist'),
      directory: on.contains('directory'),
      quick: on.contains('quick'),
      report: on.contains('report'),
      logs: on.contains('logs'),
      audit: on.contains('audit'),
      settings: on.contains('settings'),
      password: on.contains('password'),
      biometric: on.contains('biometric'),
    );

void main() {
  group('storage key (web tourStorageKey)', () {
    test('role + encodeURIComponent(userId)', () {
      expect(tourStorageKey('guard', 'G001'), 'sgb.tour.v1.done:guard:G001');
      expect(tourStorageKey('resident', 'a b/c'),
          'sgb.tour.v1.done:resident:a%20b%2Fc');
      expect(
          tourStorageKey('admin', "x!~*'()"), "sgb.tour.v1.done:admin:x!~*'()");
    });
  });

  group('chapters per role', () {
    test('guard / resident / superadmin chapters', () {
      expect(getTourChapters('guard').map((c) => c.id),
          ['welcome', 'entries', 'safety']);
      expect(flattenChapters(getTourChapters('guard')), hasLength(9));
      expect(getTourChapters('resident').map((c) => c.id),
          ['welcome', 'gate', 'household', 'community']);
      expect(flattenChapters(getTourChapters('resident')), hasLength(10));
      expect(getTourChapters('superadmin').map((c) => c.id),
          ['welcome', 'access']);
    });

    test('full admin sees every admin chapter', () {
      final ch = getTourChapters('admin', AdminPanelPermissions.full);
      expect(ch.map((c) => c.id), [
        'welcome',
        'guards',
        'residents',
        'geofence',
        'finance',
        'community',
        'ops',
        'reports',
        'security'
      ]);
      expect(ch.firstWhere((c) => c.id == 'community').steps, hasLength(6));
    });

    test('admin without role permissions falls back to full access', () {
      expect(getTourChapters('admin').length, 9);
    });

    test('locked-down role keeps welcome and only allowed steps', () {
      // Web NEW_CUSTOM_ROLE_PERMISSIONS: finance, directory, password, biometric only.
      final p = only({'finance', 'directory', 'password', 'biometric'});
      final ch = getTourChapters('admin', p);
      expect(ch.map((c) => c.id), ['welcome', 'finance', 'ops', 'security']);
      final finance = ch.firstWhere((c) => c.id == 'finance');
      expect(finance.steps.map((s) => s.titleKey), ['tour.admin.fn1.title'],
          reason: 'donations step hidden');
      final ops = ch.firstWhere((c) => c.id == 'ops');
      expect(ops.steps.map((s) => s.titleKey), ['tour.admin.op5.title'],
          reason: 'only the directory step');
      final sec = ch.firstWhere((c) => c.id == 'security');
      expect(sec.steps, hasLength(2));
    });

    test('splits step is gated by events (fn3 → events)', () {
      final p = only({'polls'});
      final ch = getTourChapters('admin', p);
      final community = ch.firstWhere((c) => c.id == 'community');
      expect(community.steps.map((s) => s.titleKey), ['tour.admin.cm2.title']);
    });
  });

  group('tab permission mapping (web isAdminTabAllowed)', () {
    test('overview / tour always allowed, unknown tabs refused', () {
      final none = only({});
      expect(tourAdminTabAllowed('overview', none), isTrue);
      expect(tourAdminTabAllowed('tour', none), isTrue);
      expect(tourAdminTabAllowed('guards', none), isFalse);
      expect(
          tourAdminTabAllowed('nonsense', AdminPanelPermissions.full), isFalse);
    });

    test('splits allowed by events or splits', () {
      expect(tourAdminTabAllowed('splits', only({'events'})), isTrue);
      expect(tourAdminTabAllowed('splits', only({'splits'})), isTrue);
      expect(tourAdminTabAllowed('splits', only({'finance'})), isFalse);
    });

    test('step → tab overrides', () {
      expect(stepToAdminTab('tour.admin.fn2.title'), 'donations');
      expect(stepToAdminTab('tour.admin.cm1m.title'), 'meetings');
      expect(stepToAdminTab('tour.admin.sc2.title'), 'biometric');
      expect(stepToAdminTab('tour.admin.g1.title'), isNull);
    });
  });

  group('first-login steps', () {
    test('guard / resident / superadmin: welcome step + explore step', () {
      final g = getFirstLoginSteps('guard');
      expect(g.map((s) => s.titleKey),
          ['tour.guard.w1.title', 'tour.first.guard.more.title']);
      final r = getFirstLoginSteps('resident');
      expect(r.map((s) => s.titleKey),
          ['tour.res.r1.title', 'tour.first.res.more.title']);
      final s = getFirstLoginSteps('superadmin');
      expect(s.map((x) => x.titleKey),
          ['tour.super.s1.title', 'tour.first.super.more.title']);
    });

    test('admin: the whole welcome chapter + explore', () {
      final a = getFirstLoginSteps('admin');
      expect(a.map((s) => s.titleKey), [
        'tour.admin.a1.title',
        'tour.admin.a2.title',
        'tour.admin.a3.title',
        'tour.first.admin.more.title',
      ]);
    });
  });

  group('overlay state', () {
    test('initial index is clamped into range', () {
      expect(clampTourIndex(0, 3), 0);
      expect(clampTourIndex(5, 3), 2);
      expect(clampTourIndex(-1, 3), 0);
      expect(clampTourIndex(2, 0), 0);
    });

    test('persist on finish, or on skip only with persistOnSkip', () {
      expect(tourShouldPersist(skipped: false, persistOnSkip: false), isTrue);
      expect(tourShouldPersist(skipped: true, persistOnSkip: false), isFalse);
      expect(tourShouldPersist(skipped: true, persistOnSkip: true), isTrue);
    });
  });
}
