import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { useStore } from '@/store/useStore';
import {
  Calendar,
  FileText,
  Gavel,
  Mic,
  PenLine,
  Plus,
  Trash2,
  Users,
  CheckCircle2,
  Circle,
  Megaphone,
} from 'lucide-react';
import { toast } from 'sonner';
import { confirmAction } from '@/lib/swal';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

type MeetingRow = {
  id: string;
  society_id: string;
  title: string;
  description: string | null;
  meeting_at: string;
  location: string | null;
  status: string;
  published: boolean;
  discussion_notes: string | null;
  minutes_summary: string | null;
  audio_recording_url: string | null;
  created_by: string | null;
};

type AttendeeRow = {
  id: string;
  meeting_id: string;
  member_id: string | null;
  flat_number: string | null;
  display_name: string;
  guest_name: string | null;
  attendee_role: string;
  is_present: boolean;
};

type DecisionRow = { id: string; meeting_id: string; decision_text: string; sort_order: number };
type DocRow = {
  id: string;
  meeting_id: string;
  title: string;
  file_url: string;
  file_name: string | null;
  mime_type: string | null;
};
type SigRow = {
  id: string;
  meeting_document_id: string;
  meeting_attendee_id: string;
  signature_image_url: string;
  signed_at: string;
  signer_label: string | null;
};

type MemberPick = { id: string; name: string; flat_id: string; flat_number: string };

interface Props {
  adminName?: string;
  /** When true, only published meetings are listed (read-only). */
  isResident?: boolean;
}

async function uploadMeetingFile(
  societyId: string,
  meetingId: string,
  kind: 'docs' | 'audio' | 'signatures',
  file: Blob,
  filename: string,
): Promise<string | null> {
  const safe = filename.replace(/[^\w.-]/g, '_').slice(0, 120);
  const path = `meetings/${societyId}/${meetingId}/${kind}/${crypto.randomUUID()}_${safe}`;
  const { error } = await supabase.storage.from('notification-media').upload(path, file, {
    cacheControl: '3600',
    upsert: false,
    contentType: file.type || undefined,
  });
  if (error) {
    console.error(error);
    return null;
  }
  const { data } = supabase.storage.from('notification-media').getPublicUrl(path);
  return data.publicUrl;
}

function SignaturePad({ canvasRef }: { canvasRef: React.RefObject<HTMLCanvasElement> }) {
  const drawing = useRef(false);

  const pos = (e: React.PointerEvent<HTMLCanvasElement>) => {
    const c = canvasRef.current;
    if (!c) return { x: 0, y: 0 };
    const r = c.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };

  return (
    <canvas
      ref={canvasRef}
      width={320}
      height={140}
      className="touch-none w-full max-w-[320px] rounded-md border border-border bg-white cursor-crosshair"
      onPointerDown={(e) => {
        e.currentTarget.setPointerCapture(e.pointerId);
        drawing.current = true;
        const ctx = e.currentTarget.getContext('2d');
        if (!ctx) return;
        const { x, y } = pos(e);
        ctx.strokeStyle = '#111';
        ctx.lineWidth = 2;
        ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(x, y);
      }}
      onPointerMove={(e) => {
        if (!drawing.current) return;
        const ctx = e.currentTarget.getContext('2d');
        if (!ctx) return;
        const { x, y } = pos(e);
        ctx.lineTo(x, y);
        ctx.stroke();
      }}
      onPointerUp={(e) => {
        drawing.current = false;
        try {
          e.currentTarget.releasePointerCapture(e.pointerId);
        } catch {
          /* ignore */
        }
      }}
      onPointerLeave={() => {
        drawing.current = false;
      }}
    />
  );
}

const MeetingManager = ({ adminName = 'Admin', isResident = false }: Props) => {
  const societyId = useStore((s) => s.societyId);
  const [meetings, setMeetings] = useState<MeetingRow[]>([]);
  const [members, setMembers] = useState<MemberPick[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [attendees, setAttendees] = useState<AttendeeRow[]>([]);
  const [decisions, setDecisions] = useState<DecisionRow[]>([]);
  const [documents, setDocuments] = useState<DocRow[]>([]);
  const [signatures, setSignatures] = useState<SigRow[]>([]);
  const [showNew, setShowNew] = useState(false);
  const [newForm, setNewForm] = useState({ title: '', meeting_at: '', location: '' });
  const [memberToAdd, setMemberToAdd] = useState('');
  const [guestName, setGuestName] = useState('');
  const [sigCtx, setSigCtx] = useState<{ doc: DocRow; attendee: AttendeeRow } | null>(null);
  const [signerLabel, setSignerLabel] = useState('');
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const selected = useMemo(() => meetings.find((m) => m.id === selectedId) ?? null, [meetings, selectedId]);
  const [notesDraft, setNotesDraft] = useState({ discussion: '', minutes: '' });

  useEffect(() => {
    if (!selected) {
      setNotesDraft({ discussion: '', minutes: '' });
      return;
    }
    setNotesDraft({
      discussion: selected.discussion_notes ?? '',
      minutes: selected.minutes_summary ?? '',
    });
  }, [selected?.id, selected?.discussion_notes, selected?.minutes_summary]);

  const loadMeetings = useCallback(async () => {
    if (!societyId) {
      setMeetings([]);
      return;
    }
    let q = supabase.from('meetings').select('*').eq('society_id', societyId).order('meeting_at', { ascending: false });
    if (isResident) q = q.eq('published', true);
    const { data, error } = await q;
    if (error) {
      toast.error(error.message);
      return;
    }
    setMeetings((data ?? []) as MeetingRow[]);
  }, [societyId, isResident]);

  const loadMembers = useCallback(async () => {
    if (!societyId || isResident) {
      setMembers([]);
      return;
    }
    const { data: flats } = await supabase.from('flats').select('id, flat_number').eq('society_id', societyId);
    const flatIds = (flats ?? []).map((f) => f.id);
    const flatNum = new Map((flats ?? []).map((f) => [f.id, f.flat_number]));
    if (flatIds.length === 0) {
      setMembers([]);
      return;
    }
    const { data: mems } = await supabase.from('members').select('id, name, flat_id').in('flat_id', flatIds);
    setMembers(
      (mems ?? []).map((m) => ({
        id: m.id,
        name: m.name,
        flat_id: m.flat_id,
        flat_number: flatNum.get(m.flat_id) ?? '',
      })),
    );
  }, [societyId, isResident]);

  const loadDetail = useCallback(async (meetingId: string) => {
    const [a, d, doc] = await Promise.all([
      supabase.from('meeting_attendees').select('*').eq('meeting_id', meetingId).order('display_name'),
      supabase.from('meeting_decisions').select('*').eq('meeting_id', meetingId).order('sort_order'),
      supabase.from('meeting_documents').select('*').eq('meeting_id', meetingId).order('created_at'),
    ]);
    setAttendees((a.data ?? []) as AttendeeRow[]);
    setDecisions((d.data ?? []) as DecisionRow[]);
    const docs = (doc.data ?? []) as DocRow[];
    setDocuments(docs);
    const docIds = docs.map((x) => x.id);
    if (docIds.length === 0) {
      setSignatures([]);
      return;
    }
    const { data: sig } = await supabase.from('meeting_document_signatures').select('*').in('meeting_document_id', docIds);
    setSignatures((sig ?? []) as SigRow[]);
  }, []);

  useEffect(() => {
    void loadMeetings();
  }, [loadMeetings]);

  useEffect(() => {
    void loadMembers();
  }, [loadMembers]);

  useEffect(() => {
    if (selectedId) void loadDetail(selectedId);
    else {
      setAttendees([]);
      setDecisions([]);
      setDocuments([]);
      setSignatures([]);
    }
  }, [selectedId, loadDetail]);

  const persistMeetingPatch = async (patch: Partial<MeetingRow>) => {
    if (!selectedId) return;
    const { error } = await supabase.from('meetings').update(patch).eq('id', selectedId);
    if (error) toast.error(error.message);
    else void loadMeetings();
  };

  const saveNotesDraft = async () => {
    if (!selectedId) return;
    await persistMeetingPatch({
      discussion_notes: notesDraft.discussion.trim() || null,
      minutes_summary: notesDraft.minutes.trim() || null,
    } as Partial<MeetingRow>);
    toast.success('Notes saved');
  };

  const createMeeting = async () => {
    if (!societyId || !newForm.title.trim()) return;
    const at = newForm.meeting_at ? new Date(newForm.meeting_at).toISOString() : new Date().toISOString();
    const { data, error } = await supabase
      .from('meetings')
      .insert([
        {
          society_id: societyId,
          title: newForm.title.trim(),
          location: newForm.location.trim() || null,
          meeting_at: at,
          status: 'scheduled',
          created_by: adminName,
        },
      ])
      .select()
      .single();
    if (error) {
      toast.error(error.message);
      return;
    }
    toast.success('Meeting created');
    setShowNew(false);
    setNewForm({ title: '', meeting_at: '', location: '' });
    await loadMeetings();
    setSelectedId(data.id);
  };

  const deleteMeeting = async (id: string) => {
    const ok = await confirmAction('Delete meeting?', 'Removes attendees, decisions, documents, and signatures.', 'Delete', 'Cancel');
    if (!ok) return;
    const { error } = await supabase.from('meetings').delete().eq('id', id);
    if (error) toast.error(error.message);
    else {
      toast.success('Deleted');
      if (selectedId === id) setSelectedId(null);
      void loadMeetings();
    }
  };

  const addMemberAttendee = async () => {
    if (!selectedId || !memberToAdd) return;
    const m = members.find((x) => x.id === memberToAdd);
    if (!m) return;
    const exists = attendees.some((a) => a.member_id === m.id);
    if (exists) {
      toast.message('Already on the list');
      return;
    }
    const { error } = await supabase.from('meeting_attendees').insert([
      {
        meeting_id: selectedId,
        member_id: m.id,
        display_name: m.name,
        flat_number: m.flat_number,
        attendee_role: 'member',
        is_present: true,
      },
    ]);
    if (error) toast.error(error.message);
    else {
      setMemberToAdd('');
      void loadDetail(selectedId);
    }
  };

  const addGuestAttendee = async () => {
    if (!selectedId || !guestName.trim()) return;
    const { error } = await supabase.from('meeting_attendees').insert([
      {
        meeting_id: selectedId,
        member_id: null,
        display_name: guestName.trim(),
        guest_name: guestName.trim(),
        flat_number: null,
        attendee_role: 'guest',
        is_present: true,
      },
    ]);
    if (error) toast.error(error.message);
    else {
      setGuestName('');
      void loadDetail(selectedId);
    }
  };

  const addAdminAttendee = async () => {
    if (!selectedId) return;
    const { error } = await supabase.from('meeting_attendees').insert([
      {
        meeting_id: selectedId,
        member_id: null,
        display_name: adminName,
        attendee_role: 'admin',
        is_present: true,
      },
    ]);
    if (error) toast.error(error.message);
    else void loadDetail(selectedId);
  };

  const removeAttendee = async (id: string) => {
    const { error } = await supabase.from('meeting_attendees').delete().eq('id', id);
    if (error) toast.error(error.message);
    else if (selectedId) void loadDetail(selectedId);
  };

  const addDecision = async () => {
    if (!selectedId) return;
    const next = decisions.length;
    const { error } = await supabase.from('meeting_decisions').insert([
      { meeting_id: selectedId, decision_text: 'Decision (edit below, then tap away)', sort_order: next },
    ]);
    if (error) toast.error(error.message);
    else void loadDetail(selectedId);
  };

  const updateDecisionText = async (id: string, text: string) => {
    const { error } = await supabase.from('meeting_decisions').update({ decision_text: text }).eq('id', id);
    if (error) toast.error(error.message);
  };

  const removeDecision = async (id: string) => {
    const { error } = await supabase.from('meeting_decisions').delete().eq('id', id);
    if (error) toast.error(error.message);
    else if (selectedId) void loadDetail(selectedId);
  };

  const uploadDocument = async (file: File) => {
    if (!selectedId || !societyId) return;
    const url = await uploadMeetingFile(societyId, selectedId, 'docs', file, file.name);
    if (!url) {
      toast.error('Upload failed');
      return;
    }
    const { error } = await supabase.from('meeting_documents').insert([
      {
        meeting_id: selectedId,
        title: file.name.replace(/\.[^.]+$/, '') || 'Document',
        file_url: url,
        file_name: file.name,
        mime_type: file.type || null,
      },
    ]);
    if (error) toast.error(error.message);
    else {
      toast.success('Document attached');
      void loadDetail(selectedId);
    }
  };

  const uploadAudio = async (file: File) => {
    if (!selectedId || !societyId) return;
    const url = await uploadMeetingFile(societyId, selectedId, 'audio', file, file.name);
    if (!url) {
      toast.error('Upload failed');
      return;
    }
    await persistMeetingPatch({ audio_recording_url: url } as Partial<MeetingRow>);
    toast.success('Recording linked to this meeting');
  };

  const clearCanvas = () => {
    const c = canvasRef.current;
    if (!c) return;
    const ctx = c.getContext('2d');
    if (!ctx) return;
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, c.width, c.height);
  };

  useEffect(() => {
    if (sigCtx) {
      clearCanvas();
      setSignerLabel(sigCtx.attendee.display_name);
    }
  }, [sigCtx]);

  const saveSignature = async () => {
    if (!sigCtx || !selectedId || !societyId) return;
    const c = canvasRef.current;
    if (!c) return;
    const blob = await new Promise<Blob | null>((res) => c.toBlob((b) => res(b), 'image/png'));
    if (!blob) {
      toast.error('Could not read signature');
      return;
    }
    const url = await uploadMeetingFile(societyId, selectedId, 'signatures', blob, `${sigCtx.attendee.id}.png`);
    if (!url) {
      toast.error('Upload failed');
      return;
    }
    const existing = signatures.find(
      (s) => s.meeting_document_id === sigCtx.doc.id && s.meeting_attendee_id === sigCtx.attendee.id,
    );
    if (existing) {
      const { error } = await supabase
        .from('meeting_document_signatures')
        .update({ signature_image_url: url, signer_label: signerLabel.trim() || null, signed_at: new Date().toISOString() })
        .eq('id', existing.id);
      if (error) toast.error(error.message);
    } else {
      const { error } = await supabase.from('meeting_document_signatures').insert([
        {
          meeting_document_id: sigCtx.doc.id,
          meeting_attendee_id: sigCtx.attendee.id,
          signature_image_url: url,
          signer_label: signerLabel.trim() || null,
        },
      ]);
      if (error) toast.error(error.message);
    }
    toast.success('Signature saved');
    setSigCtx(null);
    void loadDetail(selectedId);
  };

  const presentAttendees = attendees.filter((a) => a.is_present);

  if (!societyId) {
    return <p className="text-sm text-muted-foreground p-4">Select a society context.</p>;
  }

  return (
    <div className="page-container pb-24 space-y-4">
      <div className="flex items-start justify-between gap-2">
        <div>
          <h2 className="text-lg font-semibold flex items-center gap-2">
            <Users className="w-5 h-5 text-primary" />
            {isResident ? 'Society meetings' : 'Meetings'}
          </h2>
          <p className="text-xs text-muted-foreground mt-1">
            {isResident
              ? 'Published minutes, decisions, and documents your committee chose to share.'
              : 'Record attendees, discussion, decisions, documents, and capture signatures on the record.'}
          </p>
        </div>
        {!isResident && (
          <Button type="button" size="sm" className="shrink-0" onClick={() => setShowNew(true)}>
            <Plus className="w-4 h-4 mr-1" /> New
          </Button>
        )}
      </div>

      <Dialog open={showNew} onOpenChange={setShowNew}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>New meeting</DialogTitle>
            <DialogDescription>Creates a scheduled entry you can fill in with notes and attendees.</DialogDescription>
          </DialogHeader>
          <div className="space-y-3">
            <div>
              <Label>Title</Label>
              <Input value={newForm.title} onChange={(e) => setNewForm((p) => ({ ...p, title: e.target.value }))} placeholder="AGM / water tank discussion" />
            </div>
            <div>
              <Label>When</Label>
              <Input
                type="datetime-local"
                value={newForm.meeting_at}
                onChange={(e) => setNewForm((p) => ({ ...p, meeting_at: e.target.value }))}
              />
            </div>
            <div>
              <Label>Location</Label>
              <Input value={newForm.location} onChange={(e) => setNewForm((p) => ({ ...p, location: e.target.value }))} placeholder="Club house" />
            </div>
          </div>
          <DialogFooter>
            <Button variant="secondary" type="button" onClick={() => setShowNew(false)}>
              Cancel
            </Button>
            <Button type="button" onClick={() => void createMeeting()}>
              Create
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      <div className="grid gap-3 md:grid-cols-2">
        <div className="space-y-2">
          {meetings.length === 0 && <p className="text-sm text-muted-foreground">No meetings yet.</p>}
          {meetings.map((m) => (
            <button
              key={m.id}
              type="button"
              onClick={() => setSelectedId(m.id)}
              className={`w-full text-left card-section p-3 border transition ${selectedId === m.id ? 'border-primary ring-1 ring-primary/30' : 'border-border'}`}
            >
              <div className="flex items-center justify-between gap-2">
                <p className="font-medium text-sm">{m.title}</p>
                {m.published && (
                  <span className="text-[10px] uppercase bg-primary/15 text-primary px-1.5 py-0.5 rounded">Published</span>
                )}
              </div>
              <p className="text-[11px] text-muted-foreground mt-1 flex items-center gap-1">
                <Calendar className="w-3 h-3" />
                {new Date(m.meeting_at).toLocaleString()}
                {m.location ? ` · ${m.location}` : ''}
              </p>
              <p className="text-[10px] text-muted-foreground mt-0.5 capitalize">Status: {m.status}</p>
            </button>
          ))}
        </div>

        {selected && (
          <div className="card-section p-4 space-y-4 border border-border">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <h3 className="font-semibold text-sm truncate">{selected.title}</h3>
                <p className="text-[11px] text-muted-foreground">{new Date(selected.meeting_at).toLocaleString()}</p>
              </div>
              {!isResident && (
                <Button variant="destructive" size="sm" className="shrink-0" type="button" onClick={() => void deleteMeeting(selected.id)}>
                  <Trash2 className="w-4 h-4" />
                </Button>
              )}
            </div>

            {!isResident && (
              <div className="grid gap-2 sm:grid-cols-2">
                <div>
                  <Label className="text-xs">Status</Label>
                  <Select value={selected.status} onValueChange={(v) => void persistMeetingPatch({ status: v } as Partial<MeetingRow>)}>
                    <SelectTrigger className="h-9">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="draft">Draft</SelectItem>
                      <SelectItem value="scheduled">Scheduled</SelectItem>
                      <SelectItem value="completed">Completed</SelectItem>
                      <SelectItem value="cancelled">Cancelled</SelectItem>
                    </SelectContent>
                  </Select>
                </div>
                <label className="flex items-center gap-2 text-xs mt-5">
                  <input
                    type="checkbox"
                    checked={selected.published}
                    onChange={(e) => void persistMeetingPatch({ published: e.target.checked })}
                  />
                  Published (visible to residents)
                </label>
              </div>
            )}

            <div>
              <Label className="text-xs flex items-center gap-1">
                <Megaphone className="w-3 h-3" /> Discussion & conversation notes
              </Label>
              {isResident ? (
                <p className="text-sm whitespace-pre-wrap mt-1 min-h-[4rem] bg-muted/40 rounded-md p-2">
                  {selected.discussion_notes || '—'}
                </p>
              ) : (
                <>
                  <textarea
                    className="input-field min-h-[120px] mt-1 text-sm"
                    value={notesDraft.discussion}
                    onChange={(e) => setNotesDraft((p) => ({ ...p, discussion: e.target.value }))}
                    placeholder="Verbatim notes, who said what, resident concerns…"
                  />
                </>
              )}
            </div>

            <div>
              <Label className="text-xs flex items-center gap-1">
                <FileText className="w-3 h-3" /> Minutes & essence (conclusions)
              </Label>
              {isResident ? (
                <p className="text-sm whitespace-pre-wrap mt-1 min-h-[4rem] bg-muted/40 rounded-md p-2">
                  {selected.minutes_summary || '—'}
                </p>
              ) : (
                <>
                  <textarea
                    className="input-field min-h-[100px] mt-1 text-sm"
                    value={notesDraft.minutes}
                    onChange={(e) => setNotesDraft((p) => ({ ...p, minutes: e.target.value }))}
                    placeholder="Short summary of outcomes for residents who were not present."
                  />
                  <Button type="button" variant="secondary" size="sm" className="mt-2" onClick={() => void saveNotesDraft()}>
                    Save discussion & minutes
                  </Button>
                </>
              )}
            </div>

            <div>
              <Label className="text-xs flex items-center gap-1">
                <Mic className="w-3 h-3" /> Audio recording
              </Label>
              {selected.audio_recording_url ? (
                <audio controls className="w-full mt-1 h-9" src={selected.audio_recording_url}>
                  <track kind="captions" />
                </audio>
              ) : (
                <p className="text-xs text-muted-foreground mt-1">No audio attached.</p>
              )}
              {!isResident && (
                <label className="mt-2 block">
                  <span className="text-[10px] text-muted-foreground">Upload recording (mp3, webm, m4a…)</span>
                  <Input
                    type="file"
                    accept="audio/*,video/*"
                    className="mt-1"
                    onChange={(e) => {
                      const f = e.target.files?.[0];
                      e.target.value = '';
                      if (f) void uploadAudio(f);
                    }}
                  />
                </label>
              )}
            </div>

            <div>
              <div className="flex items-center justify-between">
                <Label className="text-xs flex items-center gap-1">
                  <Gavel className="w-3 h-3" /> Decisions
                </Label>
                {!isResident && (
                  <Button type="button" variant="outline" size="sm" onClick={() => void addDecision()}>
                    <Plus className="w-3 h-3 mr-1" /> Add
                  </Button>
                )}
              </div>
              <ul className="mt-2 space-y-2">
                {decisions.map((d, i) => (
                  <li key={d.id} className="flex gap-2 items-start">
                    <span className="text-[10px] text-muted-foreground w-5 shrink-0 pt-2">{i + 1}.</span>
                    {isResident ? (
                      <p className="text-sm flex-1">{d.decision_text}</p>
                    ) : (
                      <>
                        <textarea
                          className="input-field flex-1 min-h-[60px] text-sm"
                          defaultValue={d.decision_text}
                          onBlur={(e) => void updateDecisionText(d.id, e.target.value)}
                        />
                        <Button type="button" variant="ghost" size="icon" className="shrink-0" onClick={() => void removeDecision(d.id)}>
                          <Trash2 className="w-4 h-4 text-destructive" />
                        </Button>
                      </>
                    )}
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <div className="flex items-center justify-between">
                <Label className="text-xs flex items-center gap-1">
                  <Users className="w-3 h-3" /> Attendees
                </Label>
              </div>
              {!isResident && (
                <div className="flex flex-col gap-2 mt-2">
                  <div className="flex flex-wrap gap-2 items-end">
                    <div className="flex-1 min-w-[140px]">
                      <Select value={memberToAdd || undefined} onValueChange={setMemberToAdd}>
                        <SelectTrigger className="h-9">
                          <SelectValue placeholder="Add member…" />
                        </SelectTrigger>
                        <SelectContent className="max-h-60">
                          {members.map((m) => (
                            <SelectItem key={m.id} value={m.id}>
                              {m.name} · {m.flat_number}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>
                    <Button type="button" size="sm" variant="secondary" onClick={() => void addMemberAttendee()}>
                      Add member
                    </Button>
                  </div>
                  <div className="flex flex-wrap gap-2 items-end">
                    <Input placeholder="Guest name" value={guestName} onChange={(e) => setGuestName(e.target.value)} className="max-w-[200px]" />
                    <Button type="button" size="sm" variant="secondary" onClick={() => void addGuestAttendee()}>
                      Add guest
                    </Button>
                    <Button type="button" size="sm" variant="outline" onClick={() => void addAdminAttendee()}>
                      Add me ({adminName})
                    </Button>
                  </div>
                </div>
              )}
              <ul className="mt-2 space-y-1">
                {attendees.map((a) => (
                  <li key={a.id} className="flex items-center justify-between text-sm gap-2">
                    <span className="min-w-0 truncate">
                      {a.display_name}
                      {a.flat_number ? <span className="text-muted-foreground"> · {a.flat_number}</span> : null}
                      <span className="text-[10px] text-muted-foreground ml-1">({a.attendee_role})</span>
                    </span>
                    {!isResident && (
                      <div className="flex items-center gap-1 shrink-0">
                        <button
                          type="button"
                          className="p-1 rounded hover:bg-muted"
                          title="Present"
                          onClick={async () => {
                            await supabase.from('meeting_attendees').update({ is_present: !a.is_present }).eq('id', a.id);
                            void loadDetail(selected.id);
                          }}
                        >
                          {a.is_present ? <CheckCircle2 className="w-4 h-4 text-green-600" /> : <Circle className="w-4 h-4" />}
                        </button>
                        <Button type="button" variant="ghost" size="icon" onClick={() => void removeAttendee(a.id)}>
                          <Trash2 className="w-4 h-4 text-destructive" />
                        </Button>
                      </div>
                    )}
                  </li>
                ))}
              </ul>
            </div>

            <div>
              <div className="flex items-center justify-between">
                <Label className="text-xs flex items-center gap-1">
                  <FileText className="w-3 h-3" /> Documents & signatures
                </Label>
                {!isResident && (
                  <label>
                    <span className="sr-only">Upload</span>
                    <Input
                      type="file"
                      className="max-w-[180px] h-9 text-xs"
                      onChange={(e) => {
                        const f = e.target.files?.[0];
                        e.target.value = '';
                        if (f) void uploadDocument(f);
                      }}
                    />
                  </label>
                )}
              </div>
              {documents.length === 0 && <p className="text-xs text-muted-foreground mt-2">No documents.</p>}
              <ul className="mt-2 space-y-3">
                {documents.map((doc) => (
                  <li key={doc.id} className="border border-border rounded-lg p-2 space-y-2">
                    <a href={doc.file_url} target="_blank" rel="noreferrer" className="text-sm font-medium text-primary underline">
                      {doc.title}
                    </a>
                    <div className="grid gap-1 sm:grid-cols-2">
                      {presentAttendees.map((att) => {
                        const sig = signatures.find(
                          (s) => s.meeting_document_id === doc.id && s.meeting_attendee_id === att.id,
                        );
                        return (
                          <div key={att.id} className="flex items-center justify-between gap-2 text-xs bg-muted/40 rounded px-2 py-1">
                            <span className="truncate">{att.display_name}</span>
                            {sig ? (
                              <a href={sig.signature_image_url} target="_blank" rel="noreferrer" className="text-primary shrink-0">
                                Signed
                              </a>
                            ) : !isResident ? (
                              <Button type="button" variant="outline" size="sm" className="h-7 text-[10px] px-2" onClick={() => setSigCtx({ doc, attendee: att })}>
                                <PenLine className="w-3 h-3 mr-1" /> Sign
                              </Button>
                            ) : (
                              <span className="text-muted-foreground">—</span>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  </li>
                ))}
              </ul>
            </div>
          </div>
        )}
      </div>

      <Dialog open={!!sigCtx} onOpenChange={(o) => !o && setSigCtx(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Signature — {sigCtx?.doc.title}</DialogTitle>
            <DialogDescription>
              Capturing for <strong>{sigCtx?.attendee.display_name}</strong>. Draw in the box; usually the secretary collects these on one device at the meeting.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-2">
            <Label className="text-xs">Printed name (optional)</Label>
            <Input value={signerLabel} onChange={(e) => setSignerLabel(e.target.value)} />
            <SignaturePad canvasRef={canvasRef} />
            <div className="flex gap-2">
              <Button type="button" variant="secondary" onClick={clearCanvas}>
                Clear pad
              </Button>
            </div>
          </div>
          <DialogFooter>
            <Button type="button" variant="secondary" onClick={() => setSigCtx(null)}>
              Cancel
            </Button>
            <Button type="button" onClick={() => void saveSignature()}>
              Save signature
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
};

export default MeetingManager;
