/// Port of `src/lib/tourGuide.ts`: tour chapters per role, admin permission filtering,
/// first-login steps and the completion storage key. Pure Dart (unit-tested).
library;

import '../../../services/admin_permissions.dart';

/// `guard` | `resident` | `admin` | `superadmin`
typedef AppTourRole = String;

const kTourRoles = ['guard', 'resident', 'admin', 'superadmin'];

/// Icon names from the web `TourIconName` union.
enum TourIcon {
  sparkles,
  layoutDashboard,
  zap,
  userPlus,
  truck,
  car,
  shieldAlert,
  bookUser,
  settings,
  home,
  bell,
  keyRound,
  users,
  dollar,
  vote,
  user,
  shield,
  mapPin,
  fingerprint,
  clipboard,
  barChart,
  fileText,
  crown,
  building,
  tag,
  database,
  heart,
  calendar,
  parking,
  split,
}

class TourStepSpec {
  const TourStepSpec(this.titleKey, this.bodyKey, this.icon);

  final String titleKey;
  final String bodyKey;
  final TourIcon icon;

  @override
  bool operator ==(Object other) =>
      other is TourStepSpec &&
      other.titleKey == titleKey &&
      other.bodyKey == bodyKey &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(titleKey, bodyKey, icon);
}

class TourChapterSpec {
  const TourChapterSpec(
      {required this.id, required this.titleKey, required this.steps});

  final String id;
  final String titleKey;
  final List<TourStepSpec> steps;
}

const _storagePrefix = 'sgb.tour.v1.done';

/// Same key as the web localStorage entry: `sgb.tour.v1.done:{role}:{encodeURIComponent(userId)}`.
String tourStorageKey(AppTourRole role, String userId) =>
    '$_storagePrefix:$role:${Uri.encodeComponent(userId)}';

List<TourStepSpec> flattenChapters(List<TourChapterSpec> chapters) =>
    [for (final c in chapters) ...c.steps];

const List<TourChapterSpec> kGuardTourChapters = [
  TourChapterSpec(id: 'welcome', titleKey: 'tour.ch.guard.welcome', steps: [
    TourStepSpec(
        'tour.guard.w1.title', 'tour.guard.w1.body', TourIcon.sparkles),
    TourStepSpec(
        'tour.guard.w2.title', 'tour.guard.w2.body', TourIcon.layoutDashboard),
  ]),
  TourChapterSpec(id: 'entries', titleKey: 'tour.ch.guard.entries', steps: [
    TourStepSpec('tour.guard.e1.title', 'tour.guard.e1.body', TourIcon.zap),
    TourStepSpec(
        'tour.guard.e2.title', 'tour.guard.e2.body', TourIcon.userPlus),
    TourStepSpec('tour.guard.e3.title', 'tour.guard.e3.body', TourIcon.truck),
  ]),
  TourChapterSpec(id: 'safety', titleKey: 'tour.ch.guard.safety', steps: [
    TourStepSpec('tour.guard.s1.title', 'tour.guard.s1.body', TourIcon.car),
    TourStepSpec(
        'tour.guard.s2.title', 'tour.guard.s2.body', TourIcon.shieldAlert),
    TourStepSpec(
        'tour.guard.s3.title', 'tour.guard.s3.body', TourIcon.bookUser),
    TourStepSpec(
        'tour.guard.s4.title', 'tour.guard.s4.body', TourIcon.settings),
  ]),
];

const List<TourChapterSpec> kResidentTourChapters = [
  TourChapterSpec(id: 'welcome', titleKey: 'tour.ch.resident.welcome', steps: [
    TourStepSpec('tour.res.r1.title', 'tour.res.r1.body', TourIcon.sparkles),
  ]),
  TourChapterSpec(id: 'gate', titleKey: 'tour.ch.resident.gate', steps: [
    TourStepSpec('tour.res.r2.title', 'tour.res.r2.body', TourIcon.bell),
    TourStepSpec('tour.res.r3.title', 'tour.res.r3.body', TourIcon.keyRound),
  ]),
  TourChapterSpec(
      id: 'household',
      titleKey: 'tour.ch.resident.household',
      steps: [
        TourStepSpec('tour.res.r4.title', 'tour.res.r4.body', TourIcon.users),
        TourStepSpec('tour.res.r5.title', 'tour.res.r5.body', TourIcon.car),
        TourStepSpec(
            'tour.res.r6.title', 'tour.res.r6.body', TourIcon.bookUser),
      ]),
  TourChapterSpec(
      id: 'community',
      titleKey: 'tour.ch.resident.community',
      steps: [
        TourStepSpec('tour.res.r7.title', 'tour.res.r7.body', TourIcon.bell),
        TourStepSpec('tour.res.r8.title', 'tour.res.r8.body', TourIcon.vote),
        TourStepSpec('tour.res.r9.title', 'tour.res.r9.body', TourIcon.dollar),
        TourStepSpec('tour.res.r10.title', 'tour.res.r10.body', TourIcon.user),
      ]),
];

const List<TourChapterSpec> kSuperadminTourChapters = [
  TourChapterSpec(id: 'welcome', titleKey: 'tour.ch.super.welcome', steps: [
    TourStepSpec('tour.super.s1.title', 'tour.super.s1.body', TourIcon.crown),
    TourStepSpec(
        'tour.super.s2.title', 'tour.super.s2.body', TourIcon.building),
  ]),
  TourChapterSpec(id: 'access', titleKey: 'tour.ch.super.access', steps: [
    TourStepSpec('tour.super.s3.title', 'tour.super.s3.body', TourIcon.tag),
    TourStepSpec('tour.super.s4.title', 'tour.super.s4.body', TourIcon.users),
    TourStepSpec(
        'tour.super.s5.title', 'tour.super.s5.body', TourIcon.database),
    TourStepSpec(
        'tour.super.s6.title', 'tour.super.s6.body', TourIcon.settings),
  ]),
];

class _AdminTourBlock {
  const _AdminTourBlock(
      this.chapterId, this.chapterTitleKey, this.tab, this.steps);

  final String chapterId;
  final String chapterTitleKey;

  /// Web `AdminTab` id gating the chapter.
  final String tab;
  final List<TourStepSpec> steps;
}

const List<_AdminTourBlock> _adminBlocks = [
  _AdminTourBlock('welcome', 'tour.ch.admin.welcome', 'overview', [
    TourStepSpec(
        'tour.admin.a1.title', 'tour.admin.a1.body', TourIcon.sparkles),
    TourStepSpec('tour.admin.a2.title', 'tour.admin.a2.body', TourIcon.home),
    TourStepSpec(
        'tour.admin.a3.title', 'tour.admin.a3.body', TourIcon.layoutDashboard),
  ]),
  _AdminTourBlock('guards', 'tour.ch.admin.guards', 'guards', [
    TourStepSpec('tour.admin.g1.title', 'tour.admin.g1.body', TourIcon.shield),
  ]),
  _AdminTourBlock('residents', 'tour.ch.admin.residents', 'residents', [
    TourStepSpec('tour.admin.rv1.title', 'tour.admin.rv1.body', TourIcon.users),
  ]),
  _AdminTourBlock('geofence', 'tour.ch.admin.geofence', 'geofence', [
    TourStepSpec(
        'tour.admin.gf1.title', 'tour.admin.gf1.body', TourIcon.mapPin),
  ]),
  _AdminTourBlock('finance', 'tour.ch.admin.finance', 'finance', [
    TourStepSpec(
        'tour.admin.fn1.title', 'tour.admin.fn1.body', TourIcon.dollar),
    TourStepSpec('tour.admin.fn2.title', 'tour.admin.fn2.body', TourIcon.heart),
  ]),
  _AdminTourBlock('community', 'tour.ch.admin.community', 'events', [
    TourStepSpec(
        'tour.admin.cm1.title', 'tour.admin.cm1.body', TourIcon.calendar),
    TourStepSpec('tour.admin.fn3.title', 'tour.admin.fn3.body', TourIcon.split),
    TourStepSpec(
        'tour.admin.cm1m.title', 'tour.admin.cm1m.body', TourIcon.fileText),
    TourStepSpec('tour.admin.cm2.title', 'tour.admin.cm2.body', TourIcon.vote),
    TourStepSpec('tour.admin.cm3.title', 'tour.admin.cm3.body', TourIcon.bell),
    TourStepSpec(
        'tour.admin.cm4.title', 'tour.admin.cm4.body', TourIcon.parking),
  ]),
  _AdminTourBlock('ops', 'tour.ch.admin.ops', 'visitor', [
    TourStepSpec(
        'tour.admin.op1.title', 'tour.admin.op1.body', TourIcon.userPlus),
    TourStepSpec('tour.admin.op2.title', 'tour.admin.op2.body', TourIcon.truck),
    TourStepSpec('tour.admin.op3.title', 'tour.admin.op3.body', TourIcon.car),
    TourStepSpec(
        'tour.admin.op4.title', 'tour.admin.op4.body', TourIcon.shieldAlert),
    TourStepSpec(
        'tour.admin.op5.title', 'tour.admin.op5.body', TourIcon.bookUser),
    TourStepSpec('tour.admin.op6.title', 'tour.admin.op6.body', TourIcon.zap),
  ]),
  _AdminTourBlock('reports', 'tour.ch.admin.reports', 'report', [
    TourStepSpec(
        'tour.admin.rp1.title', 'tour.admin.rp1.body', TourIcon.barChart),
    TourStepSpec(
        'tour.admin.rp2.title', 'tour.admin.rp2.body', TourIcon.fileText),
    TourStepSpec(
        'tour.admin.rp3.title', 'tour.admin.rp3.body', TourIcon.clipboard),
  ]),
  _AdminTourBlock('security', 'tour.ch.admin.security', 'password', [
    TourStepSpec(
        'tour.admin.sc1.title', 'tour.admin.sc1.body', TourIcon.settings),
    TourStepSpec(
        'tour.admin.sc2.title', 'tour.admin.sc2.body', TourIcon.fingerprint),
  ]),
];

/// Web `TAB_PERM` (null → always allowed).
const Map<String, String?> _tabPermission = {
  'overview': null,
  'tour': null,
  'guards': 'guards_rw',
  'residents': 'residents_rw',
  'geofence': 'geofence_rw',
  'password': 'password',
  'biometric': 'biometric',
  'audit': 'audit',
  'finance': 'finance',
  'fixed_assets': 'fixed_assets',
  'donations': 'donations',
  'events': 'events',
  'meetings': 'meetings',
  'documents': 'documents',
  'committee': 'committee',
  'polls': 'polls',
  'parking': 'parking',
  'splits': 'splits',
  'notifications': 'notifications',
  'visitor': 'visitor',
  'delivery': 'delivery',
  'vehicle': 'vehicle',
  'blacklist': 'blacklist',
  'directory': 'directory',
  'quick': 'quick',
  'report': 'report',
  'logs': 'logs',
  'settings': 'settings',
};

/// Web `isAdminTabAllowed` for tab ids used by the tour.
bool tourAdminTabAllowed(String tab, AdminPanelPermissions p) {
  final json = p.toJson();
  bool flag(String key) => json[key] == true;
  if (tab == 'splits') return flag('events') || flag('splits');
  // Unknown tab ids are not allowed (web: `!!p[undefined]`).
  if (!_tabPermission.containsKey(tab)) return false;
  final key = _tabPermission[tab];
  if (key == null) return true;
  return flag(key);
}

/// Web `stepToAdminTab`: granular gating for steps inside a chapter.
String? stepToAdminTab(String titleKey) {
  switch (titleKey) {
    case 'tour.admin.fn1.title':
      return 'finance';
    case 'tour.admin.fn2.title':
      return 'donations';
    case 'tour.admin.fn3.title':
      return 'events';
    case 'tour.admin.cm1.title':
      return 'events';
    case 'tour.admin.cm1m.title':
      return 'meetings';
    case 'tour.admin.cm2.title':
      return 'polls';
    case 'tour.admin.cm3.title':
      return 'notifications';
    case 'tour.admin.cm4.title':
      return 'parking';
    case 'tour.admin.op1.title':
      return 'visitor';
    case 'tour.admin.op2.title':
      return 'delivery';
    case 'tour.admin.op3.title':
      return 'vehicle';
    case 'tour.admin.op4.title':
      return 'blacklist';
    case 'tour.admin.op5.title':
      return 'directory';
    case 'tour.admin.op6.title':
      return 'quick';
    case 'tour.admin.rp1.title':
      return 'report';
    case 'tour.admin.rp2.title':
      return 'logs';
    case 'tour.admin.rp3.title':
      return 'audit';
    case 'tour.admin.sc1.title':
      return 'password';
    case 'tour.admin.sc2.title':
      return 'biometric';
    default:
      return null;
  }
}

String _stepGateTab(TourStepSpec step, _AdminTourBlock block) =>
    stepToAdminTab(step.titleKey) ?? block.tab;

bool _adminBlockAllowed(_AdminTourBlock block, AdminPanelPermissions p) {
  if (block.tab == 'overview') return true;
  return block.steps.any((s) => tourAdminTabAllowed(_stepGateTab(s, block), p));
}

/// Chapters with at least one step the admin may open (welcome always).
List<TourChapterSpec> getAdminTourChapters(AdminPanelPermissions permissions) {
  final out = <TourChapterSpec>[];
  for (final block in _adminBlocks) {
    if (!_adminBlockAllowed(block, permissions)) continue;
    final steps = block.steps
        .where((s) => tourAdminTabAllowed(_stepGateTab(s, block), permissions))
        .toList();
    if (steps.isEmpty) continue;
    out.add(TourChapterSpec(
        id: block.chapterId, titleKey: block.chapterTitleKey, steps: steps));
  }
  return out;
}

List<TourChapterSpec> getTourChapters(AppTourRole role,
    [AdminPanelPermissions? permissions]) {
  if (role == 'guard') return kGuardTourChapters;
  if (role == 'resident') return kResidentTourChapters;
  if (role == 'superadmin') return kSuperadminTourChapters;
  return getAdminTourChapters(permissions ?? AdminPanelPermissions.full);
}

/// Shorter first-login flow: welcome chapter + one "explore" step per role.
List<TourStepSpec> getFirstLoginSteps(AppTourRole role,
    [AdminPanelPermissions? permissions]) {
  if (role == 'admin') {
    final ch = getAdminTourChapters(permissions ?? AdminPanelPermissions.full);
    final welcome = ch.where((c) => c.id == 'welcome').toList();
    final wSteps =
        welcome.isEmpty ? const <TourStepSpec>[] : welcome.first.steps;
    return [
      ...wSteps,
      const TourStepSpec('tour.first.admin.more.title',
          'tour.first.admin.more.body', TourIcon.sparkles),
    ];
  }
  if (role == 'guard') {
    return [
      kGuardTourChapters[0].steps[0],
      const TourStepSpec('tour.first.guard.more.title',
          'tour.first.guard.more.body', TourIcon.layoutDashboard),
    ];
  }
  if (role == 'resident') {
    return [
      kResidentTourChapters[0].steps[0],
      const TourStepSpec('tour.first.res.more.title',
          'tour.first.res.more.body', TourIcon.bell),
    ];
  }
  return [
    kSuperadminTourChapters[0].steps[0],
    const TourStepSpec('tour.first.super.more.title',
        'tour.first.super.more.body', TourIcon.building),
  ];
}

/// Overlay navigation state (web `TourGuideOverlay`): index clamped into the step list.
int clampTourIndex(int initialIndex, int stepCount) {
  if (stepCount <= 0) return 0;
  final maxIndex = stepCount - 1;
  if (initialIndex < 0) return 0;
  return initialIndex > maxIndex ? maxIndex : initialIndex;
}

/// Web `finish(skipped)`: `onFinished` runs when the tour was completed, or on skip when
/// `persistOnSkip` is set (first-login tour).
bool tourShouldPersist({required bool skipped, required bool persistOnSkip}) =>
    persistOnSkip || !skipped;
