// Fun auto-generated passwords: animal + fruit/vegetable + 2-digit number + symbol
const animals = ['Tiger', 'Eagle', 'Panda', 'Lion', 'Fox', 'Wolf', 'Bear', 'Hawk', 'Deer', 'Owl', 'Dolphin', 'Falcon', 'Cobra', 'Rhino', 'Shark'];
const fruits = ['Mango', 'Apple', 'Grape', 'Peach', 'Lemon', 'Berry', 'Melon', 'Guava', 'Plum', 'Cherry', 'Kiwi', 'Papaya', 'Fig', 'Olive', 'Coconut'];
const symbols = ['@', '#', '$', '!', '&', '*', '%'];

const pick = <T,>(arr: T[]): T => arr[Math.floor(Math.random() * arr.length)];

export const generateFlatPassword = (): string => {
  const animal = pick(animals);
  const fruit = pick(fruits);
  const num = Math.floor(10 + Math.random() * 90); // 10-99
  const sym = pick(symbols);
  return `${animal}${fruit}${num}${sym}`;
};
