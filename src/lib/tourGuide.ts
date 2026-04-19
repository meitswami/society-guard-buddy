import type { AdminPanelPermissions } from '@/lib/adminPermissions';
import { FULL_ADMIN_PERMISSIONS, isAdminTabAllowed, type AdminTab } from '@/lib/adminPermissions';

export type AppTourRole = 'guard' | 'resident' | 'admin' | 'superadmin';

export type TourIconName =
  | 'sparkles'
  | 'layoutDashboard'
  | 'zap'
  | 'userPlus'
  | 'truck'
  | 'car'
  | 'shieldAlert'
  | 'bookUser'
  | 'settings'
  | 'home'
  | 'bell'
  | 'keyRound'
  | 'users'
  | 'dollar'
  | 'vote'
  | 'user'
  | 'shield'
  | 'mapPin'
  | 'fingerprint'
  | 'clipboard'
  | 'barChart'
  | 'fileText'
  | 'crown'
  | 'building'
  | 'tag'
  | 'database'
  | 'heart'
  | 'calendar'
  | 'parking'
  | 'split';

export type TourStepSpec = {
  titleKey: string;
  bodyKey: string;
  icon: TourIconName;
};

export type TourChapterSpec = {
  id: string;
  titleKey: string;
  steps: TourStepSpec[];
};

const STORAGE_PREFIX = 'sgb.tour.v1.done';

export function tourStorageKey(role: AppTourRole, userId: string) {
  return `${STORAGE_PREFIX}:${role}:${encodeURIComponent(userId)}`;
}

export function isTourCompleted(role: AppTourRole, userId: string) {
  if (!userId) return true;
  try {
    return localStorage.getItem(tourStorageKey(role, userId)) === '1';
  } catch {
    return true;
  }
}

export function markTourCompleted(role: AppTourRole, userId: string) {
  if (!userId) return;
  try {
    localStorage.setItem(tourStorageKey(role, userId), '1');
  } catch {
    /* ignore */
  }
}

export function flattenChapters(chapters: TourChapterSpec[]): TourStepSpec[] {
  return chapters.flatMap((c) => c.steps);
}

const GUARD_CHAPTERS: TourChapterSpec[] = [
  {
    id: 'welcome',
    titleKey: 'tour.ch.guard.welcome',
    steps: [
      { titleKey: 'tour.guard.w1.title', bodyKey: 'tour.guard.w1.body', icon: 'sparkles' },
      { titleKey: 'tour.guard.w2.title', bodyKey: 'tour.guard.w2.body', icon: 'layoutDashboard' },
    ],
  },
  {
    id: 'entries',
    titleKey: 'tour.ch.guard.entries',
    steps: [
      { titleKey: 'tour.guard.e1.title', bodyKey: 'tour.guard.e1.body', icon: 'zap' },
      { titleKey: 'tour.guard.e2.title', bodyKey: 'tour.guard.e2.body', icon: 'userPlus' },
      { titleKey: 'tour.guard.e3.title', bodyKey: 'tour.guard.e3.body', icon: 'truck' },
    ],
  },
  {
    id: 'safety',
    titleKey: 'tour.ch.guard.safety',
    steps: [
      { titleKey: 'tour.guard.s1.title', bodyKey: 'tour.guard.s1.body', icon: 'car' },
      { titleKey: 'tour.guard.s2.title', bodyKey: 'tour.guard.s2.body', icon: 'shieldAlert' },
      { titleKey: 'tour.guard.s3.title', bodyKey: 'tour.guard.s3.body', icon: 'bookUser' },
      { titleKey: 'tour.guard.s4.title', bodyKey: 'tour.guard.s4.body', icon: 'settings' },
    ],
  },
];

const RESIDENT_CHAPTERS: TourChapterSpec[] = [
  {
    id: 'welcome',
    titleKey: 'tour.ch.resident.welcome',
    steps: [{ titleKey: 'tour.res.r1.title', bodyKey: 'tour.res.r1.body', icon: 'sparkles' }],
  },
  {
    id: 'gate',
    titleKey: 'tour.ch.resident.gate',
    steps: [
      { titleKey: 'tour.res.r2.title', bodyKey: 'tour.res.r2.body', icon: 'bell' },
      { titleKey: 'tour.res.r3.title', bodyKey: 'tour.res.r3.body', icon: 'keyRound' },
    ],
  },
  {
    id: 'household',
    titleKey: 'tour.ch.resident.household',
    steps: [
      { titleKey: 'tour.res.r4.title', bodyKey: 'tour.res.r4.body', icon: 'users' },
      { titleKey: 'tour.res.r5.title', bodyKey: 'tour.res.r5.body', icon: 'car' },
      { titleKey: 'tour.res.r6.title', bodyKey: 'tour.res.r6.body', icon: 'bookUser' },
    ],
  },
  {
    id: 'community',
    titleKey: 'tour.ch.resident.community',
    steps: [
      { titleKey: 'tour.res.r7.title', bodyKey: 'tour.res.r7.body', icon: 'bell' },
      { titleKey: 'tour.res.r8.title', bodyKey: 'tour.res.r8.body', icon: 'vote' },
      { titleKey: 'tour.res.r9.title', bodyKey: 'tour.res.r9.body', icon: 'dollar' },
      { titleKey: 'tour.res.r10.title', bodyKey: 'tour.res.r10.body', icon: 'user' },
    ],
  },
];

const SUPER_CHAPTERS: TourChapterSpec[] = [
  {
    id: 'welcome',
    titleKey: 'tour.ch.super.welcome',
    steps: [
      { titleKey: 'tour.super.s1.title', bodyKey: 'tour.super.s1.body', icon: 'crown' },
      { titleKey: 'tour.super.s2.title', bodyKey: 'tour.super.s2.body', icon: 'building' },
    ],
  },
  {
    id: 'access',
    titleKey: 'tour.ch.super.access',
    steps: [
      { titleKey: 'tour.super.s3.title', bodyKey: 'tour.super.s3.body', icon: 'tag' },
      { titleKey: 'tour.super.s4.title', bodyKey: 'tour.super.s4.body', icon: 'users' },
      { titleKey: 'tour.super.s5.title', bodyKey: 'tour.super.s5.body', icon: 'database' },
      { titleKey: 'tour.super.s6.title', bodyKey: 'tour.super.s6.body', icon: 'settings' },
    ],
  },
];

type AdminTourBlock = {
  chapterId: string;
  chapterTitleKey: string;
  tab: AdminTab;
  steps: TourStepSpec[];
};

const ADMIN_BLOCKS: AdminTourBlock[] = [
  {
    chapterId: 'welcome',
    chapterTitleKey: 'tour.ch.admin.welcome',
    tab: 'overview',
    steps: [
      { titleKey: 'tour.admin.a1.title', bodyKey: 'tour.admin.a1.body', icon: 'sparkles' },
      { titleKey: 'tour.admin.a2.title', bodyKey: 'tour.admin.a2.body', icon: 'home' },
      { titleKey: 'tour.admin.a3.title', bodyKey: 'tour.admin.a3.body', icon: 'layoutDashboard' },
    ],
  },
  {
    chapterId: 'guards',
    chapterTitleKey: 'tour.ch.admin.guards',
    tab: 'guards',
    steps: [{ titleKey: 'tour.admin.g1.title', bodyKey: 'tour.admin.g1.body', icon: 'shield' }],
  },
  {
    chapterId: 'residents',
    chapterTitleKey: 'tour.ch.admin.residents',
    tab: 'residents',
    steps: [{ titleKey: 'tour.admin.rv1.title', bodyKey: 'tour.admin.rv1.body', icon: 'users' }],
  },
  {
    chapterId: 'geofence',
    chapterTitleKey: 'tour.ch.admin.geofence',
    tab: 'geofence',
    steps: [{ titleKey: 'tour.admin.gf1.title', bodyKey: 'tour.admin.gf1.body', icon: 'mapPin' }],
  },
  {
    chapterId: 'finance',
    chapterTitleKey: 'tour.ch.admin.finance',
    tab: 'finance',
    steps: [
      { titleKey: 'tour.admin.fn1.title', bodyKey: 'tour.admin.fn1.body', icon: 'dollar' },
      { titleKey: 'tour.admin.fn2.title', bodyKey: 'tour.admin.fn2.body', icon: 'heart' },
      { titleKey: 'tour.admin.fn3.title', bodyKey: 'tour.admin.fn3.body', icon: 'split' },
    ],
  },
  {
    chapterId: 'community',
    chapterTitleKey: 'tour.ch.admin.community',
    tab: 'events',
    steps: [
      { titleKey: 'tour.admin.cm1.title', bodyKey: 'tour.admin.cm1.body', icon: 'calendar' },
      { titleKey: 'tour.admin.cm2.title', bodyKey: 'tour.admin.cm2.body', icon: 'vote' },
      { titleKey: 'tour.admin.cm3.title', bodyKey: 'tour.admin.cm3.body', icon: 'bell' },
      { titleKey: 'tour.admin.cm4.title', bodyKey: 'tour.admin.cm4.body', icon: 'parking' },
    ],
  },
  {
    chapterId: 'ops',
    chapterTitleKey: 'tour.ch.admin.ops',
    tab: 'visitor',
    steps: [
      { titleKey: 'tour.admin.op1.title', bodyKey: 'tour.admin.op1.body', icon: 'userPlus' },
      { titleKey: 'tour.admin.op2.title', bodyKey: 'tour.admin.op2.body', icon: 'truck' },
      { titleKey: 'tour.admin.op3.title', bodyKey: 'tour.admin.op3.body', icon: 'car' },
      { titleKey: 'tour.admin.op4.title', bodyKey: 'tour.admin.op4.body', icon: 'shieldAlert' },
      { titleKey: 'tour.admin.op5.title', bodyKey: 'tour.admin.op5.body', icon: 'bookUser' },
      { titleKey: 'tour.admin.op6.title', bodyKey: 'tour.admin.op6.body', icon: 'zap' },
    ],
  },
  {
    chapterId: 'reports',
    chapterTitleKey: 'tour.ch.admin.reports',
    tab: 'report',
    steps: [
      { titleKey: 'tour.admin.rp1.title', bodyKey: 'tour.admin.rp1.body', icon: 'barChart' },
      { titleKey: 'tour.admin.rp2.title', bodyKey: 'tour.admin.rp2.body', icon: 'fileText' },
      { titleKey: 'tour.admin.rp3.title', bodyKey: 'tour.admin.rp3.body', icon: 'clipboard' },
    ],
  },
  {
    chapterId: 'security',
    chapterTitleKey: 'tour.ch.admin.security',
    tab: 'password',
    steps: [
      { titleKey: 'tour.admin.sc1.title', bodyKey: 'tour.admin.sc1.body', icon: 'settings' },
      { titleKey: 'tour.admin.sc2.title', bodyKey: 'tour.admin.sc2.body', icon: 'fingerprint' },
    ],
  },
];

function stepGateTab(step: TourStepSpec, block: AdminTourBlock): AdminTab {
  return stepToAdminTab(step.titleKey) ?? block.tab;
}

function adminBlockAllowed(block: AdminTourBlock, p: AdminPanelPermissions): boolean {
  if (block.tab === 'overview') return true;
  return block.steps.some((step) => isAdminTabAllowed(stepGateTab(step, block), p));
}

/** Chapters with at least one step the admin may open (welcome always). */
export function getAdminTourChapters(permissions: AdminPanelPermissions): TourChapterSpec[] {
  const out: TourChapterSpec[] = [];
  for (const block of ADMIN_BLOCKS) {
    if (!adminBlockAllowed(block, permissions)) continue;
    const steps = block.steps.filter((step) => isAdminTabAllowed(stepGateTab(step, block), permissions));
    if (steps.length === 0) continue;
    out.push({ id: block.chapterId, titleKey: block.chapterTitleKey, steps });
  }
  return out;
}

/** Map known step keys to tabs for granular permission (finance sub-steps). */
function stepToAdminTab(titleKey: string): AdminTab | null {
  if (titleKey === 'tour.admin.fn1.title') return 'finance';
  if (titleKey === 'tour.admin.fn2.title') return 'donations';
  if (titleKey === 'tour.admin.fn3.title') return 'splits';
  if (titleKey === 'tour.admin.cm1.title') return 'events';
  if (titleKey === 'tour.admin.cm2.title') return 'polls';
  if (titleKey === 'tour.admin.cm3.title') return 'notifications';
  if (titleKey === 'tour.admin.cm4.title') return 'parking';
  if (titleKey === 'tour.admin.op1.title') return 'visitor';
  if (titleKey === 'tour.admin.op2.title') return 'delivery';
  if (titleKey === 'tour.admin.op3.title') return 'vehicle';
  if (titleKey === 'tour.admin.op4.title') return 'blacklist';
  if (titleKey === 'tour.admin.op5.title') return 'directory';
  if (titleKey === 'tour.admin.op6.title') return 'quick';
  if (titleKey === 'tour.admin.rp1.title') return 'report';
  if (titleKey === 'tour.admin.rp2.title') return 'logs';
  if (titleKey === 'tour.admin.rp3.title') return 'audit';
  if (titleKey === 'tour.admin.sc1.title') return 'password';
  if (titleKey === 'tour.admin.sc2.title') return 'biometric';
  return null;
}

export function getTourChapters(role: AppTourRole, permissions?: AdminPanelPermissions): TourChapterSpec[] {
  if (role === 'guard') return GUARD_CHAPTERS;
  if (role === 'resident') return RESIDENT_CHAPTERS;
  if (role === 'superadmin') return SUPER_CHAPTERS;
  return getAdminTourChapters(permissions ?? FULL_ADMIN_PERMISSIONS);
}

/** Shorter first-login flow: welcome chapter + one “explore” step per role. */
export function getFirstLoginSteps(role: AppTourRole, permissions?: AdminPanelPermissions): TourStepSpec[] {
  if (role === 'admin') {
    const ch = getAdminTourChapters(permissions ?? FULL_ADMIN_PERMISSIONS);
    const welcome = ch.find((c) => c.id === 'welcome');
    const wSteps = welcome?.steps ?? [];
    return [
      ...wSteps,
      { titleKey: 'tour.first.admin.more.title', bodyKey: 'tour.first.admin.more.body', icon: 'sparkles' },
    ];
  }
  if (role === 'guard') {
    return [
      GUARD_CHAPTERS[0].steps[0],
      { titleKey: 'tour.first.guard.more.title', bodyKey: 'tour.first.guard.more.body', icon: 'layoutDashboard' },
    ];
  }
  if (role === 'resident') {
    return [
      RESIDENT_CHAPTERS[0].steps[0],
      { titleKey: 'tour.first.res.more.title', bodyKey: 'tour.first.res.more.body', icon: 'bell' },
    ];
  }
  return [
    SUPER_CHAPTERS[0].steps[0],
    { titleKey: 'tour.first.super.more.title', bodyKey: 'tour.first.super.more.body', icon: 'building' },
  ];
}
