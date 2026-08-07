import { useState, useCallback, useEffect, useMemo } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Landmark, Trash2, UserPlus, Award, CalendarClock } from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction, showSuccess } from '@/lib/swal';
import { DateInput } from '@/components/DateInput';
import VotingCharterPanel from '@/components/VotingCharterPanel';
import CommitteeFormationPanel from '@/components/CommitteeFormationPanel';
import PollDocumentsPanel from '@/components/PollDocumentsPanel';
import VotingMethodConsentPanel from '@/components/VotingMethodConsentPanel';
import { PersonPhotoSide } from '@/components/PersonPhotoSide';
import { fetchMemberPhotoMap, photoForOption } from '@/lib/memberPhotos';
import {
  validateElectionChoices,
  tallyElection,
  type BallotChoices,
  type ElectionPost,
  type ElectionResultsPayload,
  type PollOptionRow,
} from '@/lib/electionTally';
import {
  electionPhase,
  isPostOpenForNomination,
  isNominationWindowOpen,
  isVotingWindowOpen,
  votingWindowLabel,
  nominationWindowLabel,
  phaseBadgeLabel,
  POST_DISPLAY,
  MANAGEMENT_COMMITTEE_POSTS,
  DEFAULT_OPEN_POSTS,
  DEFAULT_TARGET_COMMITTEE_SIZE,
  MIN_COMMITTEE_SIZE,
  BYE_LAW,
  electionQuorumRequired,
  toDatetimeLocalValue,
  postsForPoll,
  DEFAULT_WINNING_VOTES,
} from '@/lib/electionGovernance';
import { applyElectionToCommittee, countFormedCommittee } from '@/lib/electionApply';
import { notifyElectionEvent } from '@/lib/electionNotify';
import { capsFieldChange } from '@/lib/entryCaps';
import type { PollDocumentRow } from '@/lib/pollDocuments';
import {
  fetchMemberElectionEligibility,
  eligibilityReasonLabel,
} from '@/lib/electionEligibility';
import { logElectionAudit } from '@/lib/electionAudit';

type SeedPost = 'president' | 'vice_president' | 'secretary' | 'treasurer' | 'committee';

type VoterProfile = { name: string; flatNumber: string };

interface Props {
  embedded?: boolean;
  adminName?: string;
  isResident?: boolean;
  societyId: string | null;
  voterId?: string;
  voterPhone?: string;
  memberId?: string;
  memberName?: string;
  flatNumber?: string;
  flatId?: string;
  electionPolls: any[];
  options: any[];
  ballots: any[];
  documents?: PollDocumentRow[];
  voterProfiles: Record<string, VoterProfile>;
  onReload: () => void;
}

const ElectionModule = ({
  embedded = false,
  adminName = 'Admin',
  isResident = false,
  societyId,
  voterId = '',
  voterPhone = '',
  memberId = '',
  memberName = '',
  flatNumber = '',
  flatId = '',
  electionPolls,
  options,
  ballots,
  documents = [],
  voterProfiles,
  onReload,
}: Props) => {
  const [showElectionForm, setShowElectionForm] = useState(false);
  const [ef, setEf] = useState({
    question: '',
    description: '',
    nominationStarts: '',
    nominationEnds: '',
    votingStarts: '',
    votingEnds: '',
    termFrom: '',
    termTo: '',
    president: [''] as string[],
    vice_president: [''] as string[],
    secretary: [''] as string[],
    treasurer: [''] as string[],
    committee: [''] as string[],
  });
  /** pollId → ballot choices (non-ranked). */
  const [ballotDraft, setBallotDraft] = useState<Record<string, BallotChoices>>({});
  const [nominatePost, setNominatePost] = useState<ElectionPost | null>(null);
  const [nominateStatement, setNominateStatement] = useState('');
  const [nominatePollId, setNominatePollId] = useState<string | null>(null);
  const [scheduleEditId, setScheduleEditId] = useState<string | null>(null);
  const [scheduleForm, setScheduleForm] = useState({
    nominationStarts: '',
    nominationEnds: '',
    votingStarts: '',
    votingEnds: '',
  });
  const [photoByMemberId, setPhotoByMemberId] = useState<Record<string, string>>({});

  const nomineeMemberIds = useMemo(() => {
    const ids = options.map((o) => o.member_id as string | null | undefined).filter(Boolean) as string[];
    return [...new Set(ids)].sort().join(',');
  }, [options]);

  useEffect(() => {
    if (!nomineeMemberIds) {
      setPhotoByMemberId({});
      return;
    }
    let cancelled = false;
    void fetchMemberPhotoMap(nomineeMemberIds.split(',')).then((map) => {
      if (!cancelled) setPhotoByMemberId(map);
    });
    return () => {
      cancelled = true;
    };
  }, [nomineeMemberIds]);

  useEffect(() => {
    if (!voterId) return;
    setBallotDraft((prev) => {
      const merged = { ...prev };
      for (const b of ballots) {
        if (b.voter_id === voterId && b.choices && typeof b.choices === 'object') {
          merged[b.poll_id] = b.choices as BallotChoices;
        }
      }
      return merged;
    });
  }, [ballots, voterId]);

  const toggleCombinedPick = useCallback((pollId: string, optionId: string, maxMarks: number) => {
    setBallotDraft((prev) => {
      const cur = { ...(prev[pollId] ?? {}) };
      const selected = new Set(Array.isArray(cur.selected) ? cur.selected : []);
      if (selected.has(optionId)) selected.delete(optionId);
      else if (selected.size < maxMarks) selected.add(optionId);
      cur.selected = [...selected];
      return { ...prev, [pollId]: cur };
    });
  }, []);

  const setOfficePick = useCallback((pollId: string, post: ElectionPost, optionId: string) => {
    setBallotDraft((prev) => {
      const cur: BallotChoices = { ...(prev[pollId] ?? {}) };
      if (post === 'committee') {
        const picks = new Set(
          Array.isArray(cur.committee)
            ? cur.committee
            : typeof cur.committee === 'string'
              ? [cur.committee]
              : [],
        );
        if (picks.has(optionId)) picks.delete(optionId);
        else if (picks.size < BYE_LAW.executiveMembers) picks.add(optionId);
        cur.committee = [...picks];
      } else if (post === 'president') cur.president = optionId;
      else if (post === 'vice_president') cur.vice_president = optionId;
      else if (post === 'secretary') cur.secretary = optionId;
      else if (post === 'treasurer') cur.treasurer = optionId;
      return { ...prev, [pollId]: cur };
    });
  }, []);

  const resetCreateForm = () =>
    setEf({
      question: '',
      description: '',
      nominationStarts: '',
      nominationEnds: '',
      votingStarts: '',
      votingEnds: '',
      termFrom: '',
      termTo: '',
      president: [''],
      vice_president: [''],
      secretary: [''],
      treasurer: [''],
      committee: [''],
    });

  const addElection = async () => {
    if (!societyId || !ef.question.trim()) return;
    if (!ef.nominationStarts || !ef.nominationEnds || !ef.votingStarts || !ef.votingEnds) {
      toast.error('Set open and close dates for both nomination and voting.');
      return;
    }
    if (new Date(ef.nominationEnds) < new Date(ef.nominationStarts)) {
      toast.error('Nomination close must be after open.');
      return;
    }
    if (new Date(ef.votingEnds) < new Date(ef.votingStarts)) {
      toast.error('Voting close must be after open.');
      return;
    }

    const { data: poll, error: pe } = await supabase
      .from('polls')
      .insert([
        {
          question: ef.question.trim(),
          description: ef.description.trim() || null,
          created_by: adminName,
          society_id: societyId,
          poll_kind: 'election',
          election_committee_seats: BYE_LAW.executiveMembers,
          target_committee_size: DEFAULT_TARGET_COMMITTEE_SIZE,
          bye_law_mode: true,
          separate_office_votes: false,
          election_phase: 'nomination',
          is_active: true,
          nomination_starts_at: new Date(ef.nominationStarts).toISOString(),
          nomination_ends_at: new Date(ef.nominationEnds).toISOString(),
          voting_starts_at: new Date(ef.votingStarts).toISOString(),
          voting_ends_at: new Date(ef.votingEnds).toISOString(),
          election_term_from: ef.termFrom || null,
          election_term_to: ef.termTo || null,
          open_posts: DEFAULT_OPEN_POSTS,
          winning_votes: DEFAULT_WINNING_VOTES,
        },
      ])
      .select()
      .single();

    if (pe || !poll) {
      toast.error(pe?.message ?? 'Could not create election');
      return;
    }

    const rows: { poll_id: string; option_text: string; election_post: string; votes_count: number }[] = [];
    for (const post of MANAGEMENT_COMMITTEE_POSTS) {
      const names = ef[post as SeedPost].map((s) => s.trim()).filter(Boolean);
      for (const t of names) {
        rows.push({ poll_id: poll.id, option_text: t, election_post: post, votes_count: 0 });
      }
    }
    if (rows.length > 0) await supabase.from('poll_options').insert(rows);

    const title = ef.question.trim();
    resetCreateForm();
    setShowElectionForm(false);
    toast.success('Election created — nomination phase');
    onReload();
    await notifyElectionEvent({
      event: 'nomination_open',
      societyId,
      createdBy: adminName,
      electionTitle: title,
    });
  };

  const openScheduleEditor = (poll: any) => {
    setScheduleEditId(poll.id);
    setScheduleForm({
      nominationStarts: toDatetimeLocalValue(poll.nomination_starts_at),
      nominationEnds: toDatetimeLocalValue(poll.nomination_ends_at),
      votingStarts: toDatetimeLocalValue(poll.voting_starts_at),
      votingEnds: toDatetimeLocalValue(poll.voting_ends_at),
    });
  };

  const saveSchedule = async (poll: any) => {
    const { nominationStarts, nominationEnds, votingStarts, votingEnds } = scheduleForm;
    if (!nominationStarts || !nominationEnds || !votingStarts || !votingEnds) {
      toast.error('All four dates are required.');
      return;
    }
    if (new Date(nominationEnds) < new Date(nominationStarts) || new Date(votingEnds) < new Date(votingStarts)) {
      toast.error('Each close date must be after its open date.');
      return;
    }
    const { error } = await supabase
      .from('polls')
      .update({
        nomination_starts_at: new Date(nominationStarts).toISOString(),
        nomination_ends_at: new Date(nominationEnds).toISOString(),
        voting_starts_at: new Date(votingStarts).toISOString(),
        voting_ends_at: new Date(votingEnds).toISOString(),
      })
      .eq('id', poll.id);
    if (error) toast.error(error.message);
    else {
      toast.success('Schedule updated');
      setScheduleEditId(null);
      onReload();
    }
  };

  const beginNominate = (pollId: string, post: ElectionPost) => {
    setNominatePollId(pollId);
    setNominatePost(post);
    setNominateStatement('');
  };

  const selfNominate = async () => {
    const poll = electionPolls.find((p) => p.id === nominatePollId);
    if (!poll || !nominatePost) return;
    if (!memberId || !memberName || !flatId) {
      toast.error('Your member profile is required to self-nominate.');
      return;
    }
    if (!isPostOpenForNomination(poll, nominatePost)) {
      toast.error('Self-nomination is not open for this post right now.');
      return;
    }
    const statement = nominateStatement.trim();
    if (statement.length < 20) {
      toast.error('Please write at least a short statement (20+ characters) explaining why you should be chosen.');
      return;
    }
    const existing = options.filter(
      (o) => o.poll_id === poll.id && o.election_post === nominatePost && o.member_id === memberId,
    );
    if (existing.length > 0) {
      toast.error('You have already nominated yourself for this post.');
      return;
    }
    if (societyId) {
      const { data: elig, error: eligErr } = await fetchMemberElectionEligibility({
        memberId,
        societyId,
      });
      if (eligErr) {
        toast.error(eligErr);
        return;
      }
      if (elig && !elig.eligible) {
        toast.error(
          elig.reasons.map(eligibilityReasonLabel).join('; ') ||
            'You are not eligible to contest under the bye-laws.',
        );
        return;
      }
    }
    const { error } = await supabase.from('poll_options').insert([
      {
        poll_id: poll.id,
        option_text: memberName.trim(),
        election_post: nominatePost,
        votes_count: 0,
        member_id: memberId,
        flat_id: flatId,
        flat_number: flatNumber || null,
        nominated_by: voterId || memberId,
        nomination_statement: statement,
      },
    ]);
    if (error) toast.error(error.message);
    else {
      if (societyId) {
        await logElectionAudit({
          societyId,
          pollId: poll.id,
          eventType: 'nomination_submitted',
          actorType: 'resident',
          actorId: memberId,
          actorName: memberName,
          payload: { post: nominatePost },
        });
      }
      toast.success(`Nominated for ${POST_DISPLAY[nominatePost]}`);
      setNominatePost(null);
      setNominatePollId(null);
      setNominateStatement('');
      onReload();
    }
  };

  const submitElectionBallot = async (poll: any) => {
    if (!voterId || !flatId) {
      toast.error('Missing member or flat context.');
      return;
    }
    if (!isVotingWindowOpen(poll)) {
      toast.error('Voting is not open in the current time window.');
      return;
    }
    if (!poll.voting_method) {
      toast.error('Voting method has not been recorded yet (Secret Ballot or Show of Hands).');
      return;
    }

    const existingBallot = ballots.find((b) => b.poll_id === poll.id && b.voter_id === voterId);
    if (existingBallot) {
      toast.error('Your ballot is already submitted and cannot be edited.');
      return;
    }

    if (societyId && memberId) {
      const { data: elig, error: eligErr } = await fetchMemberElectionEligibility({
        memberId,
        societyId,
      });
      if (eligErr) {
        toast.error(eligErr);
        return;
      }
      if (elig && !elig.eligible) {
        const detail = elig.reasons.map(eligibilityReasonLabel).join('; ');
        toast.error(detail || 'You are not eligible to vote under the bye-laws.');
        await logElectionAudit({
          societyId,
          pollId: poll.id,
          eventType: 'eligibility_checked',
          actorType: 'resident',
          actorId: memberId,
          actorName: memberName || null,
          payload: { eligible: false, reasons: elig.reasons, action: 'ballot' },
        });
        return;
      }
    }

    const pollOpts = options.filter((o) => o.poll_id === poll.id) as PollOptionRow[];
    const separate = Boolean(poll.separate_office_votes);
    const choices = ballotDraft[poll.id] ?? {};
    const err = validateElectionChoices(pollOpts, choices, separate, {
      committeeSeats: BYE_LAW.executiveMembers,
      maxMarks: BYE_LAW.committeeSize,
    });
    if (err) {
      toast.error(err);
      return;
    }

    const phone = (voterPhone || '').replace(/\D/g, '');
    if (phone) {
      const phoneVote = ballots.find(
        (b) => b.poll_id === poll.id && String(b.voter_phone || '').replace(/\D/g, '') === phone,
      );
      if (phoneVote) {
        toast.error('You have already voted (one vote per member, even across multiple flats).');
        return;
      }
    }

    const { error } = await supabase.from('poll_election_ballots').insert([
      {
        poll_id: poll.id,
        voter_id: voterId,
        flat_id: flatId,
        flat_number: flatNumber || null,
        voter_phone: phone || null,
        rankings: {},
        choices,
        ballot_method: poll.voting_method,
        is_proxy_vote: false,
        submitted_at: new Date().toISOString(),
      },
    ]);
    if (error) {
      const msg = error.message || '';
      if (/duplicate|unique/i.test(msg)) toast.error('Duplicate vote blocked — one ballot per member.');
      else if (/immutable/i.test(msg)) toast.error('Ballots cannot be changed after submission.');
      else toast.error(msg);
      return;
    }

    if (societyId) {
      await logElectionAudit({
        societyId,
        pollId: poll.id,
        eventType: 'ballot_cast',
        actorType: 'resident',
        actorId: memberId || voterId,
        actorName: memberName || null,
        payload: {
          ballot_method: poll.voting_method,
          separate_office_votes: separate,
          voter_id: voterId,
        },
      });
    }
    toast.success('Ballot submitted (final — cannot be edited)');
    onReload();
  };

  const startVoting = async (poll: any) => {
    if (!poll.voting_method) {
      toast.error('Record the voting method (Secret Ballot or Show of Hands) before opening the poll.');
      return;
    }
    const ok = await confirmAction(
      'Open voting?',
      `Method: ${poll.voting_method === 'show_of_hands' ? 'Show of Hands' : 'Secret Ballot'}. Residents cast one vote each during the scheduled window. Quorum is 3/4 of members.`,
      'Open voting',
      'Cancel',
    );
    if (!ok) return;

    let memberCount: number | null = null;
    let quorum: number | null = null;
    if (societyId) {
      const { count } = await supabase
        .from('members')
        .select('id, flats!inner(society_id)', { count: 'exact', head: true })
        .eq('flats.society_id', societyId)
        .is('date_leave', null);
      memberCount = count ?? null;
      if (memberCount != null) quorum = electionQuorumRequired(memberCount);
    }

    await supabase
      .from('polls')
      .update({
        election_phase: 'voting',
        is_active: true,
        ...(memberCount != null
          ? { member_count_at_election: memberCount, election_quorum_required: quorum }
          : {}),
      })
      .eq('id', poll.id);

    if (societyId) {
      await logElectionAudit({
        societyId,
        pollId: poll.id,
        eventType: 'phase_changed',
        actorType: 'admin',
        actorName: adminName,
        payload: {
          to: 'voting',
          voting_method: poll.voting_method,
          member_count_at_election: memberCount,
          election_quorum_required: quorum,
          bye_law_quorum_example_30: BYE_LAW.electionQuorumFor30,
        },
      });
    }

    toast.success(
      quorum != null
        ? `Voting open — quorum ${quorum} of ${memberCount} members (3/4)`
        : 'Voting phase started',
    );
    onReload();
    if (societyId) {
      await notifyElectionEvent({
        event: 'voting_open',
        societyId,
        createdBy: adminName,
        electionTitle: poll.question,
      });
    }
  };

  const closeElection = async (poll: any) => {
    const pollBallots = ballots.filter((b) => b.poll_id === poll.id);
    const quorum = poll.election_quorum_required as number | null | undefined;
    const memberCount = poll.member_count_at_election as number | null | undefined;
    const quorumNote =
      quorum != null
        ? ` Ballots cast: ${pollBallots.length}${memberCount != null ? ` · quorum ${quorum} of ${memberCount}` : ''}.`
        : '';
    if (quorum != null && pollBallots.length < quorum) {
      const proceed = await confirmAction(
        'Quorum not met',
        `Only ${pollBallots.length} ballot(s) vs required quorum ${quorum}. Close and tally anyway? Election may be invalid under bye-laws.`,
        'Close anyway',
        'Cancel',
      );
      if (!proceed) return;
    } else {
      const ok = await confirmAction(
        'Close election?',
        `Voting stops. Results stay in the admin portal until you publish the seven-member Management Committee.${quorumNote} Second- or third-place candidates are not automatically seated.`,
        'Close & tally',
        'Cancel',
      );
      if (!ok) return;
    }
    const pollOpts = options.filter((o) => o.poll_id === poll.id) as PollOptionRow[];
    const bRows = pollBallots.map((b) => ({
      choices: (b.choices ?? {}) as BallotChoices,
      rankings: b.rankings as Record<string, Record<string, number>> | null,
    }));
    const results = tallyElection(pollOpts, bRows, {
      separateOfficeVotes: Boolean(poll.separate_office_votes),
      committeeSeats: Number(poll.election_committee_seats) || BYE_LAW.executiveMembers,
    });
    await supabase
      .from('polls')
      .update({
        is_active: false,
        election_phase: 'closed',
        election_results: results as unknown as Record<string, unknown>,
        first_mc_meeting_deadline: new Date(Date.now() + BYE_LAW.firstMeetingWithinDays * 86400000)
          .toISOString()
          .slice(0, 10),
      })
      .eq('id', poll.id);
    if (societyId) {
      await logElectionAudit({
        societyId,
        pollId: poll.id,
        eventType: 'election_tallied',
        actorType: 'admin',
        actorName: adminName,
        payload: {
          ballot_count: bRows.length,
          quorum_required: quorum ?? null,
          quorum_met: quorum == null ? null : pollBallots.length >= quorum,
          ballot_mode: results.ballot_mode,
        },
      });
    }
    showSuccess('Election closed', 'Results are available here in the admin portal.');
    onReload();
    if (societyId) {
      await notifyElectionEvent({
        event: 'election_closed',
        societyId,
        createdBy: adminName,
        electionTitle: poll.question,
      });
    }
  };

  const publishToCommittee = async (poll: any) => {
    if (!societyId || !poll.election_results) return;
    const results = poll.election_results as ElectionResultsPayload;
    const formed = countFormedCommittee(results);
    const target = Number(poll.target_committee_size) || DEFAULT_TARGET_COMMITTEE_SIZE;
    if (formed < MIN_COMMITTEE_SIZE) {
      toast.error(
        `Bye-laws require ${MIN_COMMITTEE_SIZE} Management Committee members before publishing (currently ${formed}). Fill vacant seats per the vacancy procedure — do not auto-seat runners-up.`,
      );
      return;
    }
    const shortOfTarget = formed < target;
    const ok = await confirmAction(
      'Publish Management Committee?',
      shortOfTarget
        ? `Roster has ${formed} members (required ${target}). Publish the elected seven-member Management Committee to the Committee tab?`
        : `Publish ${formed} members of the Management Committee to the Committee tab? All members will be notified.`,
      'Publish',
      'Cancel',
    );
    if (!ok) return;
    const pollOpts = options.filter((o) => o.poll_id === poll.id) as PollOptionRow[];
    const res = await applyElectionToCommittee({
      societyId,
      pollId: poll.id,
      results,
      options: pollOpts,
      termFrom: poll.election_term_from,
      termTo: poll.election_term_to,
    });
    if (!res.ok) toast.error(res.error);
    else {
      await logElectionAudit({
        societyId,
        pollId: poll.id,
        eventType: 'committee_published',
        actorType: 'admin',
        actorName: adminName,
        payload: { formed, target },
      });
      showSuccess('Published', 'Committee roster updated for residents.');
      onReload();
      await notifyElectionEvent({
        event: 'winners_published',
        societyId,
        createdBy: adminName,
        electionTitle: poll.question,
      });
    }
  };

  const renderResults = (poll: any, adminView: boolean) => {
    const raw = poll.election_results;
    if (!raw || typeof raw !== 'object') return null;
    const r = raw as ElectionResultsPayload;
    const optById = new Map(options.filter((o) => o.poll_id === poll.id).map((o) => [o.id as string, o]));
    const winnerRow = (label: string, optionId: string | undefined, name: string, scoreNote: string) => {
      const opt = optionId ? optById.get(optionId) : undefined;
      const photo = opt ? photoForOption(opt, photoByMemberId) : undefined;
      return (
        <PersonPhotoSide key={optionId || label} name={name} photo={photo} size="sm" className="py-0.5">
          <p className="text-sm leading-snug">
            <span className="text-muted-foreground">{label}:</span>{' '}
            <strong>{name}</strong>
            <span className="text-[10px] text-muted-foreground ml-1">{scoreNote}</span>
          </p>
        </PersonPhotoSide>
      );
    };
    return (
      <div className="mt-3 rounded-lg border border-primary/30 bg-primary/5 p-3 space-y-1.5 text-sm">
        <p className="text-xs font-semibold text-primary uppercase tracking-wide flex items-center gap-1">
          <Award className="w-3.5 h-3.5" /> {adminView ? 'Tallied results (admin only)' : 'Results'}
        </p>
        {MANAGEMENT_COMMITTEE_POSTS.filter((p) => p !== 'committee').map((post) => {
          const w = r[post];
          if (!w) return null;
          return winnerRow(POST_DISPLAY[post], w.option_id, w.name, `(${w.score} votes)`);
        })}
        {r.committee?.length > 0 && (
          <div className="space-y-1.5 pt-1">
            <p className="text-muted-foreground text-xs">Executive Members ({r.committee.length})</p>
            {r.committee.map((c) => {
              const opt = optById.get(c.option_id);
              const photo = opt ? photoForOption(opt, photoByMemberId) : undefined;
              return (
                <PersonPhotoSide key={c.option_id} name={c.name} photo={photo} size="sm">
                  <p className="text-sm font-medium leading-snug">
                    {c.name}
                    <span className="text-[10px] text-muted-foreground font-normal ml-1">({c.score} votes)</span>
                  </p>
                </PersonPhotoSide>
              );
            })}
          </div>
        )}
      </div>
    );
  };

  const renderCandidateList = (poll: any, post: ElectionPost) => {
    const postOpts = options.filter((o) => o.poll_id === poll.id && o.election_post === post);
    if (postOpts.length === 0) return null;
    return (
      <div className="mb-3 space-y-2">
        <p className="text-xs font-semibold text-muted-foreground">{POST_DISPLAY[post]} — nominees</p>
        {postOpts.map((opt) => (
          <div key={opt.id} className="rounded-md border border-border/60 bg-muted/30 px-2.5 py-2 text-sm">
            <PersonPhotoSide name={opt.option_text} photo={photoForOption(opt, photoByMemberId)}>
              <p className="font-medium leading-snug">
                {opt.option_text}
                {opt.flat_number ? (
                  <span className="text-[10px] text-muted-foreground font-normal ml-1">· Flat {opt.flat_number}</span>
                ) : null}
              </p>
              {opt.nomination_statement && (
                <p className="text-xs text-muted-foreground mt-1 whitespace-pre-wrap">{opt.nomination_statement}</p>
              )}
            </PersonPhotoSide>
          </div>
        ))}
      </div>
    );
  };

  const renderBallotControls = (poll: any) => {
    const pollOpts = options.filter((o) => o.poll_id === poll.id) as PollOptionRow[];
    const separate = Boolean(poll.separate_office_votes);
    const draft = ballotDraft[poll.id] ?? {};
    const selected = new Set(Array.isArray(draft.selected) ? draft.selected : []);

    if (!separate) {
      return (
        <div className="space-y-2 mb-3">
          <p className="text-xs font-semibold text-muted-foreground">
            Mark up to {BYE_LAW.committeeSize} nominees (one ballot per member — not ranked)
          </p>
          <p className="text-[11px] text-muted-foreground">
            Selected {selected.size} / {BYE_LAW.committeeSize}. Highest marks fill each nominated post.
          </p>
          {MANAGEMENT_COMMITTEE_POSTS.map((post) => {
            const postOpts = pollOpts.filter((o) => o.election_post === post);
            if (postOpts.length === 0) return null;
            return (
              <div key={post} className="space-y-1.5">
                <p className="text-[11px] font-medium text-foreground">{POST_DISPLAY[post]}</p>
                {postOpts.map((opt) => {
                  const checked = selected.has(opt.id);
                  return (
                    <label
                      key={opt.id}
                      className={`flex items-start gap-2 rounded-md border px-2.5 py-2 text-sm cursor-pointer ${
                        checked ? 'border-primary bg-primary/5' : 'border-border/60'
                      }`}
                    >
                      <input
                        type="checkbox"
                        className="mt-1"
                        checked={checked}
                        onChange={() => toggleCombinedPick(poll.id, opt.id, BYE_LAW.committeeSize)}
                      />
                      <PersonPhotoSide name={opt.option_text} photo={photoForOption(opt, photoByMemberId)} className="flex-1">
                        <span className="font-medium">
                          {opt.option_text}
                          {opt.flat_number ? (
                            <span className="text-[10px] text-muted-foreground font-normal ml-1">· Flat {opt.flat_number}</span>
                          ) : null}
                        </span>
                        {opt.nomination_statement && (
                          <p className="text-[11px] text-muted-foreground whitespace-pre-wrap mt-0.5">
                            {opt.nomination_statement}
                          </p>
                        )}
                      </PersonPhotoSide>
                    </label>
                  );
                })}
              </div>
            );
          })}
        </div>
      );
    }

    return (
      <div className="space-y-3 mb-3">
        <p className="text-xs font-semibold text-muted-foreground">
          Separate office votes (expressly approved) — pick one per post (not ranked)
        </p>
        {MANAGEMENT_COMMITTEE_POSTS.map((post) => {
          const postOpts = pollOpts.filter((o) => o.election_post === post);
          if (postOpts.length === 0) return null;
          const committeePicks = new Set(
            Array.isArray(draft.committee)
              ? draft.committee
              : typeof draft.committee === 'string'
                ? [draft.committee]
                : [],
          );
          return (
            <div key={post} className="space-y-1.5">
              <p className="text-[11px] font-medium text-foreground">
                {POST_DISPLAY[post]}
                {post === 'committee' ? ` (up to ${BYE_LAW.executiveMembers})` : ''}
              </p>
              {postOpts.map((opt) => {
                const checked =
                  post === 'committee' ? committeePicks.has(opt.id) : draft[post] === opt.id;
                return (
                  <label
                    key={opt.id}
                    className={`flex items-start gap-2 rounded-md border px-2.5 py-2 text-sm cursor-pointer ${
                      checked ? 'border-primary bg-primary/5' : 'border-border/60'
                    }`}
                  >
                    <input
                      type={post === 'committee' ? 'checkbox' : 'radio'}
                      name={post === 'committee' ? undefined : `office-${poll.id}-${post}`}
                      className="mt-1"
                      checked={checked}
                      onChange={() => setOfficePick(poll.id, post, opt.id)}
                    />
                    <PersonPhotoSide name={opt.option_text} photo={photoForOption(opt, photoByMemberId)} className="flex-1">
                      <span className="font-medium">
                        {opt.option_text}
                        {opt.flat_number ? (
                          <span className="text-[10px] text-muted-foreground font-normal ml-1">· Flat {opt.flat_number}</span>
                        ) : null}
                      </span>
                    </PersonPhotoSide>
                  </label>
                );
              })}
            </div>
          );
        })}
      </div>
    );
  };

  const seedFields = (post: SeedPost) => (
    <div key={post} className="space-y-2">
      <p className="text-xs font-semibold">{POST_DISPLAY[post]} — seed candidates (optional)</p>
      {ef[post].map((line, i) => (
        <div key={`${post}-${i}`} className="flex gap-2">
          <input
            className="input-field flex-1 text-sm"
            placeholder={`Name ${i + 1}`}
            value={line}
            onChange={(e) => {
              const next = [...ef[post]];
              next[i] = e.target.value;
              setEf({ ...ef, [post]: next });
            }}
          />
          {ef[post].length > 1 && (
            <button
              type="button"
              onClick={() => setEf({ ...ef, [post]: ef[post].filter((_, j) => j !== i) })}
              className="text-destructive"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          )}
        </div>
      ))}
      <button
        type="button"
        className="text-xs text-primary underline"
        onClick={() => setEf({ ...ef, [post]: [...ef[post], ''] })}
      >
        + Add {POST_DISPLAY[post]} candidate
      </button>
    </div>
  );

  const renderElectionCard = (poll: any) => {
    const phase = electionPhase(poll);
    const pollBallots = ballots.filter((b) => b.poll_id === poll.id);
    const myBallot = pollBallots.find((b) => b.voter_id === voterId);
    const votingOpen = isVotingWindowOpen(poll);
    const nominationOpen = isNominationWindowOpen(poll);
    const pollOpts = options.filter((o) => o.poll_id === poll.id);
    const posts = postsForPoll(poll, pollOpts);
    const editingSchedule = scheduleEditId === poll.id;

    return (
      <div key={poll.id} className="card-section p-4 mb-3 border-l-4 border-l-primary">
        <div className="flex justify-between items-start gap-2 mb-2">
          <div className="min-w-0">
            <span className="text-[10px] uppercase font-semibold text-primary">
              Election · {BYE_LAW.committeeSize}-member MC
            </span>
            <p className="font-semibold">{poll.question}</p>
            {poll.description && <p className="text-xs text-muted-foreground mt-1">{poll.description}</p>}
            <p className="text-[11px] text-muted-foreground mt-1">Nomination: {nominationWindowLabel(poll)}</p>
            <p className="text-[11px] text-muted-foreground">Voting: {votingWindowLabel(poll)}</p>
            {!isResident && poll.election_quorum_required != null && (
              <p className="text-[11px] text-muted-foreground mt-0.5">
                Quorum {poll.election_quorum_required}
                {poll.member_count_at_election != null ? ` of ${poll.member_count_at_election}` : ''} (3/4)
              </p>
            )}
          </div>
          <span className="text-[10px] px-2 py-0.5 rounded-full shrink-0 bg-muted text-muted-foreground">
            {phaseBadgeLabel(phase)}
          </span>
        </div>
        <p className="text-xs text-muted-foreground mb-2">{pollBallots.length} ballot(s) cast</p>

        {!isResident && (phase === 'closed' || phase === 'applied') && poll.election_results && renderResults(poll, true)}
        {isResident && (phase === 'closed' || phase === 'applied') && poll.election_results && renderResults(poll, false)}
        {phase === 'closed' && poll.election_results && (
          <CommitteeFormationPanel
            poll={poll}
            isResident={!!isResident}
            memberName={memberName}
            flatNumber={flatNumber}
            flatId={flatId}
            memberId={memberId}
            optionMemberIds={Object.fromEntries(
              options
                .filter((o) => o.poll_id === poll.id && o.member_id)
                .map((o) => [o.id as string, o.member_id as string]),
            )}
            photoByMemberId={photoByMemberId}
            onReload={onReload}
          />
        )}

        {(phase === 'nomination' || phase === 'voting') &&
          MANAGEMENT_COMMITTEE_POSTS.filter((p) => posts.includes(p)).map((post) => (
            <div key={`list-${post}`}>{renderCandidateList(poll, post)}</div>
          ))}

        {isResident && phase === 'nomination' && (
          <div className="mt-3 border-t border-border pt-3 space-y-2">
            {!nominationOpen && (
              <p className="text-xs text-amber-600">
                Nomination opens in the scheduled window: {nominationWindowLabel(poll)}
              </p>
            )}
            {nominationOpen && (
              <>
                <p className="text-xs font-medium text-foreground">Propose yourself for a post</p>
                <div className="flex flex-wrap gap-2">
                  {MANAGEMENT_COMMITTEE_POSTS.map((post) =>
                    isPostOpenForNomination(poll, post) ? (
                      <button
                        key={post}
                        type="button"
                        onClick={() => beginNominate(poll.id, post)}
                        className="text-xs px-3 py-1.5 rounded-lg border border-primary/40 text-primary hover:bg-primary/10 flex items-center gap-1"
                      >
                        <UserPlus className="w-3 h-3" /> {POST_DISPLAY[post]}
                      </button>
                    ) : null,
                  )}
                </div>
                {nominatePollId === poll.id && nominatePost && (
                  <div className="rounded-lg border border-primary/30 bg-primary/5 p-3 space-y-2">
                    <p className="text-xs font-semibold">
                      Nominate for {POST_DISPLAY[nominatePost]} — why should members prefer you?
                    </p>
                    <textarea
                      className="input-field text-sm min-h-[100px]"
                      placeholder="Write why you should be chosen…"
                      value={nominateStatement}
                      onChange={(e) => setNominateStatement(e.target.value)}
                      maxLength={2000}
                    />
                    <p className="text-[10px] text-muted-foreground">{nominateStatement.trim().length}/2000</p>
                    <div className="flex gap-2">
                      <button type="button" onClick={() => void selfNominate()} className="btn-primary text-xs">
                        Submit nomination
                      </button>
                      <button
                        type="button"
                        className="text-xs text-muted-foreground underline"
                        onClick={() => {
                          setNominatePost(null);
                          setNominatePollId(null);
                        }}
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                )}
              </>
            )}
          </div>
        )}

        {isResident && phase === 'voting' && (
          <div className="mt-3 space-y-1 border-t border-border pt-3">
            {!votingOpen && (
              <p className="text-xs text-amber-600">Voting opens in the scheduled window: {votingWindowLabel(poll)}</p>
            )}
            {myBallot && votingOpen && (
              <p className="text-xs text-green-600 font-medium mb-2">
                Ballot submitted — final (cannot be edited).
              </p>
            )}
            {votingOpen && !myBallot && (
              <>
                <p className="text-xs text-muted-foreground mb-2">
                  One vote per eligible member. Votes are final after submission.
                  {poll.voting_method
                    ? ` Method: ${poll.voting_method === 'show_of_hands' ? 'Show of Hands' : 'Secret Ballot'}.`
                    : ' Voting method not yet recorded by admin.'}
                </p>
                {renderBallotControls(poll)}
                <button
                  type="button"
                  disabled={!flatId || !voterId || !poll.voting_method}
                  onClick={() => void submitElectionBallot(poll)}
                  className="btn-primary w-full text-sm mt-2"
                >
                  Submit ballot (final)
                </button>
              </>
            )}
          </div>
        )}

        <PollDocumentsPanel
          pollId={poll.id}
          societyId={societyId}
          isAdmin={!isResident}
          documents={documents}
          createdBy={adminName}
          onChanged={onReload}
        />

        {!isResident && (
          <div className="mt-2 text-xs text-muted-foreground space-y-1">
            {pollBallots.slice(0, 6).map((b) => {
              const prof = voterProfiles[b.voter_id];
              return (
                <div key={b.id} className="flex justify-between gap-2">
                  <span>{prof?.name ?? b.voter_id.slice(0, 8)}</span>
                  <span>Flat {prof?.flatNumber ?? b.flat_number ?? '—'}</span>
                </div>
              );
            })}
          </div>
        )}

        <VotingMethodConsentPanel
          poll={poll}
          societyId={societyId}
          isResident={isResident}
          adminName={adminName}
          memberId={memberId}
          memberName={memberName}
          flatNumber={flatNumber}
          onReload={onReload}
        />

        {!isResident && (
          <div className="mt-3 flex flex-wrap gap-2">
            {(phase === 'nomination' || phase === 'voting') && (
              <button
                type="button"
                onClick={() => (editingSchedule ? setScheduleEditId(null) : openScheduleEditor(poll))}
                className="text-xs px-3 py-1.5 rounded-lg border border-border inline-flex items-center gap-1"
              >
                <CalendarClock className="w-3.5 h-3.5" />
                {editingSchedule ? 'Hide schedule' : 'Edit dates'}
              </button>
            )}
            {phase === 'nomination' && (
              <button
                type="button"
                onClick={() => void startVoting(poll)}
                className="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-foreground"
              >
                Start voting window
              </button>
            )}
            {phase === 'voting' && poll.is_active && (
              <button type="button" onClick={() => void closeElection(poll)} className="text-xs text-destructive underline">
                Close election &amp; tally
              </button>
            )}
            {phase === 'closed' && (
              <button
                type="button"
                onClick={() => void publishToCommittee(poll)}
                className="text-xs px-3 py-1.5 rounded-lg bg-emerald-600 text-white"
              >
                Publish formed Committee to roster
              </button>
            )}
            {phase === 'applied' && (
              <span className="text-xs text-green-600 font-medium">✓ Published to committee roster</span>
            )}
          </div>
        )}

        {!isResident && editingSchedule && (
          <div className="mt-3 rounded-lg border border-border p-3 space-y-2">
            <p className="text-xs font-semibold text-muted-foreground uppercase">Schedule</p>
            <div className="grid grid-cols-2 gap-2">
              <div>
                <label className="text-[10px] text-muted-foreground">Nomination opens</label>
                <input
                  type="datetime-local"
                  className="input-field mt-0.5"
                  value={scheduleForm.nominationStarts}
                  onChange={(e) => setScheduleForm({ ...scheduleForm, nominationStarts: e.target.value })}
                />
              </div>
              <div>
                <label className="text-[10px] text-muted-foreground">Nomination closes</label>
                <input
                  type="datetime-local"
                  className="input-field mt-0.5"
                  value={scheduleForm.nominationEnds}
                  onChange={(e) => setScheduleForm({ ...scheduleForm, nominationEnds: e.target.value })}
                />
              </div>
              <div>
                <label className="text-[10px] text-muted-foreground">Voting opens</label>
                <input
                  type="datetime-local"
                  className="input-field mt-0.5"
                  value={scheduleForm.votingStarts}
                  onChange={(e) => setScheduleForm({ ...scheduleForm, votingStarts: e.target.value })}
                />
              </div>
              <div>
                <label className="text-[10px] text-muted-foreground">Voting closes</label>
                <input
                  type="datetime-local"
                  className="input-field mt-0.5"
                  value={scheduleForm.votingEnds}
                  onChange={(e) => setScheduleForm({ ...scheduleForm, votingEnds: e.target.value })}
                />
              </div>
            </div>
            <button type="button" onClick={() => void saveSchedule(poll)} className="btn-primary text-xs">
              Save schedule
            </button>
          </div>
        )}
      </div>
    );
  };

  return (
    <div className={embedded ? 'space-y-3' : ''}>
      <VotingCharterPanel isAdmin={!isResident} societyId={societyId} />

      {!embedded && (
        <div className="mb-3 rounded-lg border border-primary/20 bg-primary/5 px-3 py-2">
          <p className="text-[11px] text-muted-foreground">
            <strong className="text-foreground">Society Elections</strong> — elect the seven-member
            Management Committee (President, Vice-President, Secretary, Treasurer, 3 Executive Members) under
            the registered bye-laws: one vote per eligible member, Secret Ballot or Show of Hands, election
            quorum 3/4, 2-year term.
            {!isResident && ' Download the Election Charter to circulate to members.'}
          </p>
        </div>
      )}

      {!isResident && (
        <>
          <button
            type="button"
            onClick={() => setShowElectionForm(!showElectionForm)}
            className="btn-primary flex items-center justify-center gap-2 w-full sm:w-auto"
          >
            <Landmark className="w-4 h-4" /> New society election
          </button>

          {showElectionForm && (
            <div className="card-section p-4 mb-4 flex flex-col gap-3">
              <p className="text-xs font-semibold text-muted-foreground uppercase">
                Society election — 7-member Management Committee (nomination first)
              </p>
              <input
                className="input-field"
                placeholder="Election title (e.g. Managing Committee 2026)"
                value={ef.question}
                onChange={capsFieldChange(setEf, 'question')}
              />
              <textarea
                className="input-field"
                placeholder="Description (optional)"
                value={ef.description}
                onChange={capsFieldChange(setEf, 'description')}
              />

              <p className="text-[11px] font-medium text-foreground">Nomination window</p>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-[10px] text-muted-foreground">Opens</label>
                  <input
                    type="datetime-local"
                    className="input-field mt-0.5"
                    value={ef.nominationStarts}
                    onChange={(e) => setEf({ ...ef, nominationStarts: e.target.value })}
                  />
                </div>
                <div>
                  <label className="text-[10px] text-muted-foreground">Closes</label>
                  <input
                    type="datetime-local"
                    className="input-field mt-0.5"
                    value={ef.nominationEnds}
                    onChange={(e) => setEf({ ...ef, nominationEnds: e.target.value })}
                  />
                </div>
              </div>

              <p className="text-[11px] font-medium text-foreground">Voting window</p>
              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-[10px] text-muted-foreground">Opens</label>
                  <input
                    type="datetime-local"
                    className="input-field mt-0.5"
                    value={ef.votingStarts}
                    onChange={(e) => setEf({ ...ef, votingStarts: e.target.value })}
                  />
                </div>
                <div>
                  <label className="text-[10px] text-muted-foreground">Closes</label>
                  <input
                    type="datetime-local"
                    className="input-field mt-0.5"
                    value={ef.votingEnds}
                    onChange={(e) => setEf({ ...ef, votingEnds: e.target.value })}
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="text-[10px] text-muted-foreground">Tenure from</label>
                  <DateInput
                    className="input-field mt-0.5"
                    value={ef.termFrom}
                    onChange={(e) => setEf({ ...ef, termFrom: e.target.value })}
                  />
                </div>
                <div>
                  <label className="text-[10px] text-muted-foreground">Tenure to (optional)</label>
                  <DateInput
                    className="input-field mt-0.5"
                    value={ef.termTo}
                    onChange={(e) => setEf({ ...ef, termTo: e.target.value })}
                  />
                </div>
              </div>

              {MANAGEMENT_COMMITTEE_POSTS.map((post) => seedFields(post as SeedPost))}

              <button type="button" onClick={() => void addElection()} className="btn-primary">
                Create election (nomination phase)
              </button>
            </div>
          )}
        </>
      )}

      {electionPolls.length > 0 ? (
        <div className="space-y-3">{electionPolls.map(renderElectionCard)}</div>
      ) : (
        <div className="card-section p-6 text-center">
          <Landmark className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-50" />
          <p className="text-sm text-muted-foreground">No society elections yet.</p>
          {!isResident && (
            <p className="text-xs text-muted-foreground mt-1">
              Create an election to open nomination for the seven-member Management Committee.
            </p>
          )}
          {isResident && (
            <p className="text-xs text-muted-foreground mt-1">
              When the admin opens an election, you can self-nominate and vote here.
            </p>
          )}
        </div>
      )}
    </div>
  );
};

export default ElectionModule;
