const _householdLoginRelations = {
  'owner', 'spouse', 'son', 'daughter', 'father', 'mother',
  'family', 'brother', 'sister', 'tenant',
};

String normalizeMemberRelation(String? relation) =>
    (relation ?? '').trim().toLowerCase();

bool allowsResidentLogin(String? relation) =>
    _householdLoginRelations.contains(normalizeMemberRelation(relation));

bool allowsPrimaryMember(String? relation) {
  final r = normalizeMemberRelation(relation);
  return r != 'tenant' && allowsResidentLogin(r);
}

bool isRestrictedMemberCategory(String? relation) =>
    !allowsResidentLogin(relation);
