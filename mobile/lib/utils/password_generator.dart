import 'dart:math';

final _random = Random();

const _animals = [
  'Tiger', 'Eagle', 'Panda', 'Lion', 'Fox', 'Wolf', 'Bear', 'Hawk', 'Deer', 'Owl',
];
const _fruits = [
  'Mango', 'Apple', 'Grape', 'Peach', 'Lemon', 'Berry', 'Melon', 'Guava', 'Plum', 'Cherry',
];
const _symbols = ['@', '#', r'$', '!', '&', '*', '%'];

String generateFlatPassword() {
  final animal = _animals[_random.nextInt(_animals.length)];
  final fruit = _fruits[_random.nextInt(_fruits.length)];
  final num = 10 + _random.nextInt(90);
  final sym = _symbols[_random.nextInt(_symbols.length)];
  return '$animal$fruit$num$sym';
}
