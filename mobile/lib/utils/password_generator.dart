import 'dart:math';

/// Port of web `src/lib/passwordGenerator.ts`:
/// animal + fruit/vegetable + 2-digit number + symbol (e.g. `TigerMango42@`).
final _random = Random();

const kPasswordAnimals = [
  'Tiger', 'Eagle', 'Panda', 'Lion', 'Fox', 'Wolf', 'Bear', 'Hawk', 'Deer', 'Owl', //
  'Dolphin', 'Falcon', 'Cobra', 'Rhino', 'Shark',
];
const kPasswordFruits = [
  'Mango', 'Apple', 'Grape', 'Peach', 'Lemon', 'Berry', 'Melon', 'Guava', 'Plum', 'Cherry', //
  'Kiwi', 'Papaya', 'Fig', 'Olive', 'Coconut',
];
const kPasswordSymbols = ['@', '#', r'$', '!', '&', '*', '%'];

/// Shared flat login password (all household logins of a flat use the same one).
String generateFlatPassword([Random? random]) {
  final r = random ?? _random;
  final animal = kPasswordAnimals[r.nextInt(kPasswordAnimals.length)];
  final fruit = kPasswordFruits[r.nextInt(kPasswordFruits.length)];
  final num = 10 + r.nextInt(90); // 10-99
  final sym = kPasswordSymbols[r.nextInt(kPasswordSymbols.length)];
  return '$animal$fruit$num$sym';
}
