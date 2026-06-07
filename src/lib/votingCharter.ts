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
      'When the admin opens nomination, members may propose themselves for executive posts (President, Vice-President, Secretary, Treasurer) or as a core committee member.',
      'Self-nomination closes when the admin starts the voting window.',
    ],
  },
  {
    heading: 'Voting method',
    points: [
      'Rank every candidate in each post — 1 = highest preference (maximum rating).',
      'You must rank all candidates in a post; duplicate ranks are not allowed.',
      'Scores use priority points: top rank gets the highest score; the candidate with the highest total is elected.',
      'You may include yourself in your rankings.',
    ],
  },
  {
    heading: 'Results & committee roster',
    points: [
      'After the voting window closes, the admin tallies results. Winners are visible in the admin portal first.',
      'Elected names appear in the residents’ Committee module only after the admin publishes them to the roster.',
      'Committee roster changes (tenure, post, removal) remain admin-only. Residents may edit only their own personal profile fields.',
    ],
  },
] as const;
