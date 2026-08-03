/** Society election & voting charter — shown at top of the Elections module. */

export const VOTING_CHARTER_TITLE = 'Voting Charter';

export const VOTING_CHARTER_SECTIONS = [
  {
    heading: 'Eligibility',
    points: [
      'Every registered owner and their spouse may cast one ranked ballot each.',
      'One vote per person — even if you own more than one flat, you vote only once (matched by login / phone).',
      'Up to two ballots may come from the same flat when both spouses vote separately.',
    ],
  },
  {
    heading: 'Nomination',
    points: [
      'When the admin opens the nomination window, members may propose themselves for three executive posts: President, Secretary, or Treasurer.',
      'Each nominee must write a short statement explaining why they should be chosen or given preference.',
      'Self-nomination is only allowed inside the admin-set nomination open and close dates.',
    ],
  },
  {
    heading: 'Voting method',
    points: [
      'Rank every candidate in each post — 1 = highest preference (maximum rating).',
      'You must rank all candidates in a post; duplicate ranks are not allowed.',
      'Scores use Borda priority points: top rank gets the highest score; the candidate with the highest total is elected if they meet the admin’s minimum winning score for that post.',
      'You may include yourself in your rankings.',
      'Voting is only allowed inside the admin-set voting open and close dates.',
    ],
  },
  {
    heading: 'Documents & results',
    points: [
      'Admin may attach circulars, letters, or other society/personal documents to the election; members can open them from the poll.',
      'After the voting window closes, the admin tallies results. Winners are visible in the admin portal first.',
      'Elected names appear in the residents’ Committee module only after the admin publishes them to the roster.',
    ],
  },
] as const;
