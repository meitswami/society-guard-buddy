import { supabase } from '@/integrations/supabase/client';
import { invokePushNotification } from '@/lib/pushNotification';

export type ElectionNotifyEvent =
  | 'nomination_open'
  | 'voting_open'
  | 'election_closed'
  | 'winners_published';

const TITLES: Record<ElectionNotifyEvent, string> = {
  nomination_open: 'Society election — nomination open',
  voting_open: 'Society election — voting open',
  election_closed: 'Society election closed',
  winners_published: 'New committee published',
};

function defaultMessage(event: ElectionNotifyEvent, electionTitle: string): string {
  switch (event) {
    case 'nomination_open':
      return `Propose yourself for President, Secretary or Treasurer: ${electionTitle}`;
    case 'voting_open':
      return `Cast your ranked ballot: ${electionTitle}`;
    case 'election_closed':
      return `Voting has closed for: ${electionTitle}`;
    case 'winners_published':
      return `Elected office-bearers are now on the Committee roster: ${electionTitle}`;
  }
}

/** In-app notification + push to all members for an election lifecycle event. */
export async function notifyElectionEvent(params: {
  event: ElectionNotifyEvent;
  societyId: string;
  createdBy: string;
  electionTitle: string;
  message?: string;
}): Promise<void> {
  const title = TITLES[params.event];
  const message = params.message ?? defaultMessage(params.event, params.electionTitle);
  await supabase.from('notifications').insert([
    {
      title,
      message,
      type: 'poll',
      target_type: 'all',
      created_by: params.createdBy,
      society_id: params.societyId,
    },
  ]);
  await invokePushNotification({
    title,
    message,
    target_type: 'all',
    society_id: params.societyId,
  });
}
