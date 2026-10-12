/// Port of web `src/lib/flat360Types.ts`.
library;

enum Flat360TimelineKind {
  payment,
  notification,
  ticket,
  meeting,
  eventContribution,
  visitor
}

class Flat360TimelineItem {
  const Flat360TimelineItem({
    required this.id,
    required this.kind,
    required this.at,
    required this.title,
    this.detail,
    this.status,
    this.amount,
  });

  final String id;
  final Flat360TimelineKind kind;

  /// ISO timestamp or `yyyy-MM-dd` date.
  final String at;
  final String title;
  final String? detail;
  final String? status;
  final double? amount;
}

class Flat360ParkingSlot {
  const Flat360ParkingSlot({
    required this.id,
    required this.spaceNumber,
    required this.spaceType,
    this.floorLevel,
    this.vehicleNumber,
  });

  final String id;
  final String spaceNumber;
  final String spaceType;
  final String? floorLevel;
  final String? vehicleNumber;
}

class Flat360Member {
  const Flat360Member({
    required this.id,
    required this.name,
    this.phone,
    required this.relation,
    required this.isPrimary,
  });

  final String id;
  final String name;
  final String? phone;
  final String relation;
  final bool isPrimary;
}

class Flat360Summary {
  const Flat360Summary({
    required this.verifiedPaid12m,
    required this.pendingCount,
    required this.pendingAmount,
    required this.openTickets,
    required this.parkingSlots,
    required this.meetingsAttended,
    required this.meetingsTotal,
    required this.attendancePct,
  });

  final double verifiedPaid12m;
  final int pendingCount;
  final double pendingAmount;
  final int openTickets;
  final int parkingSlots;
  final int meetingsAttended;
  final int meetingsTotal;
  final int attendancePct;
}

class Flat360Profile {
  const Flat360Profile({
    required this.flatId,
    required this.flatNumber,
    this.ownerName,
    this.floor,
    this.wing,
    required this.isOccupied,
    required this.members,
    required this.parking,
    required this.summary,
    required this.timeline,
  });

  final String flatId;
  final String flatNumber;
  final String? ownerName;
  final String? floor;
  final String? wing;
  final bool isOccupied;
  final List<Flat360Member> members;
  final List<Flat360ParkingSlot> parking;
  final Flat360Summary summary;
  final List<Flat360TimelineItem> timeline;
}

/// Resident viewing their own flat: notifications are filtered for resident visibility.
class Flat360ResidentContext {
  const Flat360ResidentContext({required this.id, required this.name});

  final String id;
  final String name;
}

/// Web `Flat360FetchParams`.
class Flat360FetchParams {
  const Flat360FetchParams({
    required this.societyId,
    required this.flatId,
    required this.flatNumber,
    this.monthsBack = 12,
    this.residentContext,
    this.includeVisitors = false,
  });

  final String societyId;
  final String flatId;
  final String flatNumber;
  final int monthsBack;

  /// When set, notifications are filtered for resident visibility.
  final Flat360ResidentContext? residentContext;

  /// Admin-only: include recent gate visitors in timeline.
  final bool includeVisitors;
}
