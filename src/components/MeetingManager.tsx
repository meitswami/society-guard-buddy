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
  MapPin,
  Building2,
  Radio,
  Square,
  Send,
  MicOff,
  ChevronUp,
  ChevronDown,
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
  executives_present: string | null;
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
  sort_order?: number;
  created_at?: string;
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

type FlatWithMembers = {
  id: string;
  flat_number: string;
  owner_name: string | null;
  members: { id: string; name: string }[];
};

interface Props {
  adminName?: string;
  isResident?: boolean;
}

function toDateInput(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function toTimeInput(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const h = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${h}:${min}`;
}

function combineDateAndTimeToIso(dateStr: string, timeStr: string): string {
  const d = dateStr || toDateInput(new Date().toISOString());
  const t = timeStr || '09:00';
  const dt = new Date(`${d}T${t}:00`);
  return dt.toISOString();
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

/** File picker `accept` — images + PDFs (multiple selection in file manager). */
const MEETING_DOC_ACCEPT =
  'image/*,application/pdf,.pdf,.jpg,.jpeg,.png,.webp,.gif,.bmp,.heic,.heif,.tif,.tiff';

function isAllowedMeetingAttachment(file: File): boolean {
  const t = (file.type || '').toLowerCase();
  if (t.startsWith('image/')) return true;
  if (t === 'application/pdf' || t === 'application/x-pdf') return true;
  const n = file.name.toLowerCase();
  return n.endsWith('.pdf');
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
  const [flatsWithMembers, setFlatsWithMembers] = useState<FlatWithMembers[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [attendees, setAttendees] = useState<AttendeeRow[]>([]);
  const [decisions, setDecisions] = useState<DecisionRow[]>([]);
  const [documents, setDocuments] = useState<DocRow[]>([]);
  const [signatures, setSignatures] = useState<SigRow[]>([]);
  const [showNew, setShowNew] = useState(false);
  const [newForm, setNewForm] = useState({ title: '', meetingDate: '', meetingTime: '', location: '' });
  const [memberToAdd, setMemberToAdd] = useState('');
  const [guestName, setGuestName] = useState('');
  const [sigCtx, setSigCtx] = useState<{ doc: DocRow; attendee: AttendeeRow } | null>(null);
  const [signerLabel, setSignerLabel] = useState('');
  const [attendeeSelection, setAttendeeSelection] = useState<Set<string>>(() => new Set());
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const selected = useMemo(() => meetings.find((m) => m.id === selectedId) ?? null, [meetings, selectedId]);
  const [notesDraft, setNotesDraft] = useState({ discussion: '', minutes: '' });
  const [executivesDraft, setExecutivesDraft] = useState('');
  const [metaDraft, setMetaDraft] = useState({ title: '', meetingDate: '', meetingTime: '', location: '' });
  const [isRecording, setIsRecording] = useState(false);
  const [dictationOn, setDictationOn] = useState(false);
  const mediaRecRef = useRef<MediaRecorder | null>(null);
  const chunksRef = useRef<Blob[]>([]);
  const speechRef = useRef<{ stop: () => void } | null>(null);

  useEffect(() => {
    if (!selected) {
      setNotesDraft({ discussion: '', minutes: '' });
      setExecutivesDraft('');
      setMetaDraft({ title: '', meetingDate: '', meetingTime: '', location: '' });
      return;
    }
    setNotesDraft({
      discussion: selected.discussion_notes ?? '',
      minutes: selected.minutes_summary ?? '',
    });
    setExecutivesDraft(selected.executives_present ?? '');
    setMetaDraft({
      title: selected.title,
      meetingDate: toDateInput(selected.meeting_at),
      meetingTime: toTimeInput(selected.meeting_at),
      location: selected.location ?? '',
    });
  }, [selected?.id, selected?.discussion_notes, selected?.minutes_summary, selected?.executives_present, selected?.title, selected?.meeting_at, selected?.location]);

  useEffect(() => {
    return () => {
      try {
        mediaRecRef.current?.stop();
      } catch {
        /* ignore */
      }
      speechRef.current?.stop();
    };
  }, []);

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

  const loadFlatsWithMembers = useCallback(async () => {
    if (!societyId || isResident) {
      setFlatsWithMembers([]);
      return;
    }
    const { data: flats } = await supabase
      .from('flats')
      .select('id, flat_number, owner_name')
      .eq('society_id', societyId)
      .order('flat_number');
    const flatIds = (flats ?? []).map((f) => f.id);
    if (flatIds.length === 0) {
      setFlatsWithMembers([]);
      return;
    }
    const { data: mems } = await supabase.from('members').select('id, name, flat_id').in('flat_id', flatIds);
    const byFlat = new Map<string, { id: string; name: string }[]>();
    for (const m of mems ?? []) {
      const list = byFlat.get(m.flat_id) ?? [];
      list.push({ id: m.id, name: m.name });
      byFlat.set(m.flat_id, list);
    }
    setFlatsWithMembers(
      (flats ?? []).map((f) => ({
        id: f.id,
        flat_number: f.flat_number,
        owner_name: f.owner_name,
        members: byFlat.get(f.id) ?? [],
      })),
    );
  }, [societyId, isResident]);

  const loadDetail = useCallback(async (meetingId: string) => {
    const [a, d, doc] = await Promise.all([
      supabase.from('meeting_attendees').select('*').eq('meeting_id', meetingId).order('display_name'),
      supabase.from('meeting_decisions').select('*').eq('meeting_id', meetingId).order('sort_order'),
      supabase
        .from('meeting_documents')
        .select('*')
        .eq('meeting_id', meetingId)
        .order('sort_order', { ascending: true })
        .order('created_at', { ascending: true }),
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
    void loadFlatsWithMembers();
  }, [loadMembers, loadFlatsWithMembers]);

  useEffect(() => {
    if (selectedId) void loadDetail(selectedId);
    else {
      setAttendees([]);
      setDecisions([]);
      setDocuments([]);
      setSignatures([]);
    }
    setAttendeeSelection(new Set());
  }, [selectedId, loadDetail]);

  useEffect(() => {
    setAttendeeSelection((prev) => {
      const valid = new Set(attendees.map((a) => a.id));
      const next = new Set<string>();
      for (const id of prev) if (valid.has(id)) next.add(id);
      return next;
    });
  }, [attendees]);

  const persistMeetingPatch = async (patch: Partial<MeetingRow>) => {
    if (!selectedId) return;
    const { error } = await supabase.from('meetings').update(patch).eq('id', selectedId);
    if (error) toast.error(error.message);
    else void loadMeetings();
  };

  const saveNotesDraft = async (opts?: { skipConfirm?: boolean; silent?: boolean }) => {
    if (!selectedId) return;
    if (!opts?.skipConfirm) {
      const ok = await confirmAction(
        'Save discussion & minutes?',
        'This updates the saved text on the server for this meeting.',
        'Save',
        'Cancel',
      );
      if (!ok) return;
    }
    await persistMeetingPatch({
      discussion_notes: notesDraft.discussion.trim() || null,
      minutes_summary: notesDraft.minutes.trim() || null,
    } as Partial<MeetingRow>);
    if (!opts?.silent) toast.success('Notes saved');
  };

  const saveExecutives = async (opts?: { skipConfirm?: boolean; silent?: boolean }) => {
    if (!selectedId) return;
    if (!opts?.skipConfirm) {
      const ok = await confirmAction(
        'Save executive list?',
        'Updates who was recorded as present from the managing committee.',
        'Save',
        'Cancel',
      );
      if (!ok) return;
    }
    await persistMeetingPatch({ executives_present: executivesDraft.trim() || null } as Partial<MeetingRow>);
    if (!opts?.silent) toast.success('Executive list saved');
  };

  const saveMeetingMeta = async () => {
    if (!selectedId) return;
    const ok = await confirmAction(
      'Save meeting details?',
      'Updates title, date, time, and venue for this meeting.',
      'Save',
      'Cancel',
    );
    if (!ok) return;
    const meeting_at = combineDateAndTimeToIso(metaDraft.meetingDate, metaDraft.meetingTime);
    await persistMeetingPatch({
      title: metaDraft.title.trim() || 'Meeting',
      meeting_at,
      location: metaDraft.location.trim() || null,
    } as Partial<MeetingRow>);
    toast.success('Meeting details saved');
  };

  const createMeeting = async () => {
    if (!societyId || !newForm.title.trim()) return;
    const meeting_at = combineDateAndTimeToIso(
      newForm.meetingDate || toDateInput(new Date().toISOString()),
      newForm.meetingTime || toTimeInput(new Date().toISOString()),
    );
    const { data, error } = await supabase
      .from('meetings')
      .insert([
        {
          society_id: societyId,
          title: newForm.title.trim(),
          location: newForm.location.trim() || null,
          meeting_at,
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
    setNewForm({ title: '', meetingDate: '', meetingTime: '', location: '' });
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

  const isFlatMarkedPresent = (flat: FlatWithMembers) => {
    if (flat.members.length === 0) return false;
    return flat.members.every((m) => {
      const row = attendees.find((a) => a.member_id === m.id);
      return row?.is_present;
    });
  };

  const setFlatPresence = async (flat: FlatWithMembers, present: boolean) => {
    if (!selectedId) return;
    if (flat.members.length === 0) {
      toast.message('No members on this flat yet — add residents first.');
      return;
    }
    const ok = await confirmAction(
      present ? 'Mark flat present?' : 'Remove flat from attendance?',
      present
        ? `Add everyone in flat ${flat.flat_number} to the attendance list as present.`
        : `Remove all members of flat ${flat.flat_number} from this meeting’s attendance list.`,
      present ? 'Mark present' : 'Remove',
      'Cancel',
    );
    if (!ok) return;
    if (present) {
      for (const m of flat.members) {
        const existing = attendees.find((a) => a.member_id === m.id);
        if (existing) {
          await supabase.from('meeting_attendees').update({ is_present: true, flat_number: flat.flat_number }).eq('id', existing.id);
        } else {
          await supabase.from('meeting_attendees').insert([
            {
              meeting_id: selectedId,
              member_id: m.id,
              display_name: m.name,
              flat_number: flat.flat_number,
              attendee_role: 'member',
              is_present: true,
            },
          ]);
        }
      }
      toast.success(`Marked ${flat.flat_number} present`);
    } else {
      for (const m of flat.members) {
        const existing = attendees.find((a) => a.member_id === m.id);
        if (existing) await supabase.from('meeting_attendees').delete().eq('id', existing.id);
      }
      toast.message(`Cleared ${flat.flat_number} from attendance`);
    }
    void loadDetail(selectedId);
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
    const row = attendees.find((a) => a.id === id);
    const ok = await confirmAction(
      'Remove attendee?',
      row
        ? `Remove “${row.display_name}” from this meeting’s attendance list.`
        : 'Remove this person from the attendance list.',
      'Remove',
      'Cancel',
    );
    if (!ok) return;
    const { error } = await supabase.from('meeting_attendees').delete().eq('id', id);
    if (error) toast.error(error.message);
    else {
      setAttendeeSelection((prev) => {
        const n = new Set(prev);
        n.delete(id);
        return n;
      });
      if (selectedId) void loadDetail(selectedId);
    }
  };

  const toggleAttendeeSelected = (id: string) => {
    setAttendeeSelection((prev) => {
      const n = new Set(prev);
      if (n.has(id)) n.delete(id);
      else n.add(id);
      return n;
    });
  };

  const selectAllAttendeeIds = () => {
    setAttendeeSelection(new Set(attendees.map((a) => a.id)));
  };

  const clearAttendeeSelection = () => setAttendeeSelection(new Set());

  const bulkMarkAttendeesPresent = async () => {
    if (!selectedId || attendeeSelection.size === 0) {
      toast.message('Select at least one attendee');
      return;
    }
    const ok = await confirmAction(
      'Mark selected present?',
      `Set ${attendeeSelection.size} attendee(s) as present.`,
      'Update',
      'Cancel',
    );
    if (!ok) return;
    for (const id of attendeeSelection) {
      await supabase.from('meeting_attendees').update({ is_present: true }).eq('id', id);
    }
    toast.success('Attendance updated');
    clearAttendeeSelection();
    void loadDetail(selectedId);
  };

  const bulkMarkAttendeesAbsent = async () => {
    if (!selectedId || attendeeSelection.size === 0) {
      toast.message('Select at least one attendee');
      return;
    }
    const ok = await confirmAction(
      'Mark selected absent?',
      `Set ${attendeeSelection.size} attendee(s) as absent (they stay on the list).`,
      'Update',
      'Cancel',
    );
    if (!ok) return;
    for (const id of attendeeSelection) {
      await supabase.from('meeting_attendees').update({ is_present: false }).eq('id', id);
    }
    toast.success('Attendance updated');
    clearAttendeeSelection();
    void loadDetail(selectedId);
  };

  const bulkRemoveAttendees = async () => {
    if (!selectedId || attendeeSelection.size === 0) {
      toast.message('Select at least one attendee');
      return;
    }
    const ok = await confirmAction(
      'Remove selected attendees?',
      `Permanently remove ${attendeeSelection.size} row(s) from this meeting. Signatures on documents may become orphaned.`,
      'Remove',
      'Cancel',
    );
    if (!ok) return;
    for (const id of attendeeSelection) {
      await supabase.from('meeting_attendees').delete().eq('id', id);
    }
    clearAttendeeSelection();
    toast.success('Removed');
    void loadDetail(selectedId);
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
    const ok = await confirmAction('Delete decision?', 'This removes one decision line from the meeting record.', 'Delete', 'Cancel');
    if (!ok) return;
    const { error } = await supabase.from('meeting_decisions').delete().eq('id', id);
    if (error) toast.error(error.message);
    else if (selectedId) void loadDetail(selectedId);
  };

  const uploadDocuments = async (files: FileList | File[] | null) => {
    if (!selectedId || !societyId || !files?.length) return;
    const arr = Array.from(files as FileList | File[]);
    const allowed = arr.filter(isAllowedMeetingAttachment);
    if (allowed.length === 0) {
      toast.error('Only images and PDF files are supported.');
      return;
    }
    if (allowed.length < arr.length) {
      toast.message(`${arr.length - allowed.length} file(s) skipped (not image or PDF).`);
    }
    const maxSo = documents.reduce((m, d) => Math.max(m, typeof d.sort_order === 'number' ? d.sort_order : 0), -1);
    let nextOrder = maxSo + 1;
    let uploaded = 0;
    for (const file of allowed) {
      const url = await uploadMeetingFile(societyId, selectedId, 'docs', file, file.name);
      if (!url) {
        toast.error(`Upload failed: ${file.name}`);
        continue;
      }
      const { error } = await supabase.from('meeting_documents').insert([
        {
          meeting_id: selectedId,
          title: file.name.replace(/\.[^.]+$/, '') || 'Attachment',
          file_url: url,
          file_name: file.name,
          mime_type: file.type || null,
          sort_order: nextOrder++,
        },
      ]);
      if (error) toast.error(`${file.name}: ${error.message}`);
      else uploaded += 1;
    }
    if (uploaded > 0) {
      toast.success(uploaded === 1 ? 'File attached' : `${uploaded} files attached`);
      void loadDetail(selectedId);
    }
  };

  const moveMeetingDocument = async (docId: string, dir: 'up' | 'down') => {
    if (!selectedId) return;
    const sorted = [...documents].sort((a, b) => {
      const sa = a.sort_order ?? 0;
      const sb = b.sort_order ?? 0;
      if (sa !== sb) return sa - sb;
      const ta = a.created_at ?? '';
      const tb = b.created_at ?? '';
      return ta < tb ? -1 : ta > tb ? 1 : 0;
    });
    const i = sorted.findIndex((d) => d.id === docId);
    if (i < 0) return;
    const j = dir === 'up' ? i - 1 : i + 1;
    if (j < 0 || j >= sorted.length) return;
    const reordered = [...sorted];
    [reordered[i], reordered[j]] = [reordered[j], reordered[i]];
    const results = await Promise.all(
      reordered.map((d, idx) => supabase.from('meeting_documents').update({ sort_order: idx }).eq('id', d.id)),
    );
    const firstErr = results.find((r) => r.error)?.error;
    if (firstErr) toast.error(firstErr.message);
    else void loadDetail(selectedId);
  };

  const uploadAudio = async (file: File) => {
    if (!selectedId || !societyId) return;
    if (selected?.audio_recording_url) {
      const ok = await confirmAction(
        'Replace session audio?',
        'This meeting already has a recording. Uploading will replace it with the new file.',
        'Replace',
        'Cancel',
      );
      if (!ok) return;
    }
    const url = await uploadMeetingFile(societyId, selectedId, 'audio', file, file.name);
    if (!url) {
      toast.error('Upload failed');
      return;
    }
    await persistMeetingPatch({ audio_recording_url: url } as Partial<MeetingRow>);
    toast.success('Recording saved to this meeting');
  };

  const startLiveRecording = async () => {
    if (!selectedId || !societyId || isResident) return;
    if (!navigator.mediaDevices?.getUserMedia) {
      toast.error('Microphone not supported in this browser');
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      chunksRef.current = [];
      const mr = new MediaRecorder(stream, { mimeType: MediaRecorder.isTypeSupported('audio/webm') ? 'audio/webm' : undefined });
      mediaRecRef.current = mr;
      mr.ondataavailable = (ev) => {
        if (ev.data.size) chunksRef.current.push(ev.data);
      };
      mr.onstop = async () => {
        stream.getTracks().forEach((t) => t.stop());
        const blob = new Blob(chunksRef.current, { type: mr.mimeType || 'audio/webm' });
        chunksRef.current = [];
        mediaRecRef.current = null;
        setIsRecording(false);
        if (blob.size < 200) {
          toast.message('Recording too short');
          return;
        }
        const url = await uploadMeetingFile(societyId, selectedId, 'audio', blob, `session-${Date.now()}.webm`);
        if (!url) {
          toast.error('Upload failed');
          return;
        }
        await persistMeetingPatch({ audio_recording_url: url } as Partial<MeetingRow>);
        toast.success('Session recording saved');
      };
      mr.start(400);
      setIsRecording(true);
      toast.message('Recording… tap Stop when the meeting ends.');
    } catch {
      toast.error('Could not access microphone');
    }
  };

  const stopLiveRecording = () => {
    mediaRecRef.current?.stop();
  };

  const toggleDictation = () => {
    if (isResident) return;
    const W = window as unknown as {
      SpeechRecognition?: new () => {
        lang: string;
        continuous: boolean;
        interimResults: boolean;
        start: () => void;
        stop: () => void;
        onresult: ((ev: { resultIndex: number; results: { length: number; [i: number]: { [0]: { transcript: string } } } }) => void) | null;
        onerror: (() => void) | null;
        onend: (() => void) | null;
      };
      webkitSpeechRecognition?: new () => {
        lang: string;
        continuous: boolean;
        interimResults: boolean;
        start: () => void;
        stop: () => void;
        onresult: ((ev: { resultIndex: number; results: { length: number; [i: number]: { [0]: { transcript: string } } } }) => void) | null;
        onerror: (() => void) | null;
        onend: (() => void) | null;
      };
    };
    const SR = typeof window !== 'undefined' ? W.SpeechRecognition ?? W.webkitSpeechRecognition : undefined;
    if (!SR) {
      toast.error('Speech recognition not supported in this browser (try Chrome).');
      return;
    }
    if (dictationOn) {
      speechRef.current?.stop();
      setDictationOn(false);
      return;
    }
    const rec = new SR();
    rec.lang = document.documentElement.lang?.startsWith('hi') ? 'hi-IN' : 'en-IN';
    rec.continuous = true;
    rec.interimResults = true;
    rec.onresult = (ev) => {
      let chunk = '';
      for (let i = ev.resultIndex; i < ev.results.length; i++) {
        chunk += ev.results[i]?.[0]?.transcript ?? '';
      }
      if (chunk) setNotesDraft((p) => ({ ...p, minutes: `${p.minutes}${chunk} ` }));
    };
    rec.onerror = () => setDictationOn(false);
    rec.onend = () => setDictationOn(false);
    speechRef.current = rec;
    rec.start();
    setDictationOn(true);
    toast.message('Dictating into minutes… tap again to stop.');
  };

  const publishAndNotifyAll = async () => {
    if (!selectedId || !societyId || isResident) return;
    const ok = await confirmAction(
      'Publish minutes to all residents?',
      'Saves discussion & minutes, marks the meeting published, sends an in-app notification, and triggers push where configured.',
      'Publish',
      'Cancel',
    );
    if (!ok) return;
    await saveNotesDraft({ skipConfirm: true, silent: true });
    await saveExecutives({ skipConfirm: true, silent: true });
    await persistMeetingPatch({ published: true } as Partial<MeetingRow>);
    const title = `Minutes: ${metaDraft.title || selected?.title || 'Meeting'}`;
    const body =
      (notesDraft.minutes || 'Published minutes are available.').slice(0, 900) +
      (notesDraft.minutes.length > 900 ? '…' : '') +
      ' Open the Meetings tab in the app.';
    await supabase.from('notifications').insert([
      {
        title,
        message: body,
        type: 'general',
        target_type: 'all',
        target_id: 'all',
        created_by: adminName,
        society_id: societyId,
        sound_key: 'digital',
        sound_custom_url: null,
      },
    ]);
    try {
      await supabase.functions.invoke('send-push-notification', {
        body: {
          title,
          message: body,
          target_type: 'all',
          society_id: societyId,
          sound_key: 'digital',
          sound_custom_url: '',
        },
      });
    } catch (e) {
      console.warn('Push failed', e);
    }
    toast.success('Published and sent to all residents (in-app + push where configured).');
    void loadMeetings();
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
    const existingSig = signatures.find(
      (s) => s.meeting_document_id === sigCtx.doc.id && s.meeting_attendee_id === sigCtx.attendee.id,
    );
    const ok = await confirmAction(
      existingSig ? 'Overwrite signature?' : 'Save signature?',
      existingSig
        ? 'This attendee already signed this document. Saving replaces the previous image.'
        : 'Store this signature on the document for the selected attendee.',
      'Save',
      'Cancel',
    );
    if (!ok) return;
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
    if (existingSig) {
      const { error } = await supabase
        .from('meeting_document_signatures')
        .update({ signature_image_url: url, signer_label: signerLabel.trim() || null, signed_at: new Date().toISOString() })
        .eq('id', existingSig.id);
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
              ? 'Published minutes and materials from your managing committee.'
              : 'Date, place, time, executive & flat attendance, photos, session audio, minutes (type or dictate), then publish and notify everyone.'}
          </p>
        </div>
        {!isResident && (
          <Button
            type="button"
            size="sm"
            className="shrink-0"
            onClick={() => {
              const now = new Date().toISOString();
              setNewForm((p) => ({
                ...p,
                meetingDate: p.meetingDate || toDateInput(now),
                meetingTime: p.meetingTime || toTimeInput(now),
              }));
              setShowNew(true);
            }}
          >
            <Plus className="w-4 h-4 mr-1" /> New meeting
          </Button>
        )}
      </div>

      <Dialog open={showNew} onOpenChange={setShowNew}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>New meeting</DialogTitle>
            <DialogDescription>Set title, date, time, and venue. You can add attendance and minutes after.</DialogDescription>
          </DialogHeader>
          <div className="space-y-3">
            <div>
              <Label>Title</Label>
              <Input
                value={newForm.title}
                onChange={(e) => setNewForm((p) => ({ ...p, title: e.target.value }))}
                placeholder="AGM / maintenance review"
              />
            </div>
            <div className="grid grid-cols-2 gap-2">
              <div>
                <Label>Date</Label>
                <Input
                  type="date"
                  value={newForm.meetingDate}
                  onChange={(e) => setNewForm((p) => ({ ...p, meetingDate: e.target.value }))}
                />
              </div>
              <div>
                <Label>Time</Label>
                <Input
                  type="time"
                  value={newForm.meetingTime}
                  onChange={(e) => setNewForm((p) => ({ ...p, meetingTime: e.target.value }))}
                />
              </div>
            </div>
            <div>
              <Label>Place / venue</Label>
              <Input
                value={newForm.location}
                onChange={(e) => setNewForm((p) => ({ ...p, location: e.target.value }))}
                placeholder="Club house hall"
              />
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

      <div className="grid gap-3 lg:grid-cols-2">
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
                {m.location ? (
                  <>
                    <MapPin className="w-3 h-3 shrink-0" /> {m.location}
                  </>
                ) : null}
              </p>
              <p className="text-[10px] text-muted-foreground mt-0.5 capitalize">Status: {m.status}</p>
            </button>
          ))}
        </div>

        {selected && (
          <div className="card-section p-4 space-y-4 border border-border max-h-[calc(100vh-8rem)] overflow-y-auto">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <h3 className="font-semibold text-sm">Meeting record</h3>
                <p className="text-[11px] text-muted-foreground">ID {selected.id.slice(0, 8)}…</p>
              </div>
              {!isResident && (
                <Button variant="destructive" size="sm" className="shrink-0" type="button" onClick={() => void deleteMeeting(selected.id)}>
                  <Trash2 className="w-4 h-4" />
                </Button>
              )}
            </div>

            {!isResident && (
              <>
                <div className="border border-border rounded-lg p-3 space-y-2 bg-muted/20">
                  <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">Date, time & place</p>
                  <Input value={metaDraft.title} onChange={(e) => setMetaDraft((p) => ({ ...p, title: e.target.value }))} placeholder="Title" />
                  <div className="grid grid-cols-2 gap-2">
                    <Input type="date" value={metaDraft.meetingDate} onChange={(e) => setMetaDraft((p) => ({ ...p, meetingDate: e.target.value }))} />
                    <Input type="time" value={metaDraft.meetingTime} onChange={(e) => setMetaDraft((p) => ({ ...p, meetingTime: e.target.value }))} />
                  </div>
                  <Input
                    value={metaDraft.location}
                    onChange={(e) => setMetaDraft((p) => ({ ...p, location: e.target.value }))}
                    placeholder="Place / venue"
                  />
                  <Button type="button" size="sm" variant="secondary" onClick={() => void saveMeetingMeta()}>
                    Save date, time & place
                  </Button>
                </div>

                <div className="border border-border rounded-lg p-3 space-y-2">
                  <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">Executive members present</p>
                  <textarea
                    className="input-field min-h-[88px] text-sm"
                    value={executivesDraft}
                    onChange={(e) => setExecutivesDraft(e.target.value)}
                    placeholder={'One name & role per line, e.g.\nPresident — R. Mehta\nTreasurer — S. Khan'}
                  />
                  <Button type="button" size="sm" variant="secondary" onClick={() => void saveExecutives()}>
                    Save executive list
                  </Button>
                </div>

                <div className="border border-border rounded-lg p-3 space-y-2">
                  <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground flex items-center gap-1">
                    <Building2 className="w-3 h-3" /> Flats — tap Present to record everyone in that flat
                  </p>
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 max-h-56 overflow-y-auto pr-1">
                    {flatsWithMembers.map((flat) => {
                      const on = isFlatMarkedPresent(flat);
                      const disabled = flat.members.length === 0;
                      return (
                        <div
                          key={flat.id}
                          className={`rounded-lg border p-2 text-[11px] ${on ? 'border-green-600/50 bg-green-500/5' : 'border-border bg-card'}`}
                        >
                          <div className="flex items-center justify-between gap-1 mb-1">
                            <span className="font-semibold">{flat.flat_number}</span>
                            <Button
                              type="button"
                              size="sm"
                              variant={on ? 'default' : 'outline'}
                              className="h-7 text-[10px] px-2"
                              disabled={disabled}
                              onClick={() => void setFlatPresence(flat, !on)}
                            >
                              {on ? 'Present ✓' : 'Present'}
                            </Button>
                          </div>
                          {flat.owner_name ? <p className="text-muted-foreground truncate">Owner: {flat.owner_name}</p> : null}
                          <ul className="mt-1 space-y-0.5 text-muted-foreground">
                            {flat.members.map((m) => (
                              <li key={m.id} className="truncate">
                                · {m.name}
                              </li>
                            ))}
                            {flat.members.length === 0 && <li className="italic">No members</li>}
                          </ul>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </>
            )}

            {isResident && selected.executives_present && (
              <div>
                <Label className="text-xs">Executive members recorded</Label>
                <p className="text-sm whitespace-pre-wrap mt-1 bg-muted/40 rounded-md p-2">{selected.executives_present}</p>
              </div>
            )}

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
                  Published (residents can open)
                </label>
              </div>
            )}

            <div>
              <Label className="text-xs flex items-center gap-1">
                <Megaphone className="w-3 h-3" /> Discussion & conversation
              </Label>
              {isResident ? (
                <p className="text-sm whitespace-pre-wrap mt-1 min-h-[4rem] bg-muted/40 rounded-md p-2">{selected.discussion_notes || '—'}</p>
              ) : (
                <textarea
                  className="input-field min-h-[100px] mt-1 text-sm"
                  value={notesDraft.discussion}
                  onChange={(e) => setNotesDraft((p) => ({ ...p, discussion: e.target.value }))}
                  placeholder="Notes from the floor, questions, debate…"
                />
              )}
            </div>

            <div>
              <Label className="text-xs flex items-center gap-1">
                <FileText className="w-3 h-3" /> Minutes & summary
              </Label>
              {isResident ? (
                <p className="text-sm whitespace-pre-wrap mt-1 min-h-[4rem] bg-muted/40 rounded-md p-2">{selected.minutes_summary || '—'}</p>
              ) : (
                <>
                  <textarea
                    className="input-field min-h-[120px] mt-1 text-sm"
                    value={notesDraft.minutes}
                    onChange={(e) => setNotesDraft((p) => ({ ...p, minutes: e.target.value }))}
                    placeholder="Type conclusions here, or use Dictate (mic) below."
                  />
                  <div className="flex flex-wrap gap-2 mt-2">
                    <Button type="button" variant={dictationOn ? 'default' : 'outline'} size="sm" onClick={() => toggleDictation()}>
                      {dictationOn ? <MicOff className="w-4 h-4 mr-1" /> : <Mic className="w-4 h-4 mr-1" />}
                      {dictationOn ? 'Stop dictation' : 'Dictate into minutes'}
                    </Button>
                    <Button type="button" variant="secondary" size="sm" onClick={() => void saveNotesDraft()}>
                      Save discussion & minutes
                    </Button>
                  </div>
                </>
              )}
            </div>

            <div>
              <Label className="text-xs flex items-center gap-1">
                <Mic className="w-3 h-3" /> Session audio
              </Label>
              {selected.audio_recording_url ? (
                <audio controls className="w-full mt-1 h-10" src={selected.audio_recording_url}>
                  <track kind="captions" />
                </audio>
              ) : (
                <p className="text-xs text-muted-foreground mt-1">No recording yet.</p>
              )}
              {!isResident && (
                <div className="mt-2 flex flex-col gap-2">
                  <div className="flex flex-wrap gap-2 items-center">
                    {!isRecording ? (
                      <Button type="button" size="sm" variant="default" onClick={() => void startLiveRecording()}>
                        <Radio className="w-4 h-4 mr-1" /> Record session (mic)
                      </Button>
                    ) : (
                      <Button type="button" size="sm" variant="destructive" onClick={() => stopLiveRecording()}>
                        <Square className="w-4 h-4 mr-1" /> Stop & upload
                      </Button>
                    )}
                  </div>
                  <label className="block">
                    <span className="text-[10px] text-muted-foreground">Or upload audio file</span>
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
                </div>
              )}
            </div>

            {!isResident && (
              <div className="border border-dashed border-border rounded-lg p-3 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">
                  Photos & documents (images + PDF)
                </p>
                <p className="text-[10px] text-muted-foreground leading-snug">
                  <strong>Browse files</strong> opens the system file picker — select <strong>multiple</strong> images and/or PDFs at once. Use the arrows on each attachment below to change display order.
                </p>
                <div className="flex flex-wrap gap-2">
                  <label className="btn-primary text-xs px-3 py-2 cursor-pointer">
                    Browse files
                    <input
                      type="file"
                      multiple
                      accept={MEETING_DOC_ACCEPT}
                      className="hidden"
                      onChange={(e) => {
                        void uploadDocuments(e.target.files);
                        e.target.value = '';
                      }}
                    />
                  </label>
                  <label className="btn-secondary text-xs px-3 py-2 cursor-pointer">
                    Take photo
                    <input
                      type="file"
                      accept="image/*"
                      capture="environment"
                      className="hidden"
                      onChange={(e) => {
                        const f = e.target.files?.[0];
                        e.target.value = '';
                        if (f) void uploadDocuments([f]);
                      }}
                    />
                  </label>
                </div>
              </div>
            )}

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
                  <Users className="w-3 h-3" /> Attendance list (flat + guests)
                </Label>
              </div>
              {!isResident && (
                <div className="flex flex-col gap-2 mt-2">
                  <div className="flex flex-wrap gap-2 items-end">
                    <div className="flex-1 min-w-[140px]">
                      <Select value={memberToAdd || undefined} onValueChange={setMemberToAdd}>
                        <SelectTrigger className="h-9">
                          <SelectValue placeholder="Add one member…" />
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
                      Add
                    </Button>
                  </div>
                  <div className="flex flex-wrap gap-2 items-end">
                    <Input placeholder="Guest name" value={guestName} onChange={(e) => setGuestName(e.target.value)} className="max-w-[200px]" />
                    <Button type="button" size="sm" variant="secondary" onClick={() => void addGuestAttendee()}>
                      Guest
                    </Button>
                    <Button type="button" size="sm" variant="outline" onClick={() => void addAdminAttendee()}>
                      Add {adminName}
                    </Button>
                  </div>
                </div>
              )}
              <ul className="mt-2 space-y-1 max-h-40 overflow-y-auto">
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
              <div className="flex items-center justify-between gap-2 flex-wrap">
                <Label className="text-xs flex items-center gap-1">
                  <FileText className="w-3 h-3" /> Documents & signatures
                </Label>
              </div>
              {documents.length === 0 && <p className="text-xs text-muted-foreground mt-2">No attachments.</p>}
              <ul className="mt-2 space-y-3">
                {documents.map((doc, docIndex) => (
                  <li key={doc.id} className="border border-border rounded-lg p-2 space-y-2">
                    <div className="flex items-start justify-between gap-2">
                      <a
                        href={doc.file_url}
                        target="_blank"
                        rel="noreferrer"
                        className="text-sm font-medium text-primary underline min-w-0 break-words"
                      >
                        {doc.title}
                        {doc.file_name?.toLowerCase().endsWith('.pdf') ? (
                          <span className="text-[10px] text-muted-foreground font-normal ml-1">(PDF)</span>
                        ) : null}
                      </a>
                      {!isResident && (
                        <div className="flex flex-col gap-0.5 shrink-0">
                          <Button
                            type="button"
                            variant="outline"
                            size="icon"
                            className="h-7 w-7"
                            title="Move up"
                            disabled={docIndex === 0}
                            onClick={() => void moveMeetingDocument(doc.id, 'up')}
                          >
                            <ChevronUp className="w-4 h-4" />
                          </Button>
                          <Button
                            type="button"
                            variant="outline"
                            size="icon"
                            className="h-7 w-7"
                            title="Move down"
                            disabled={docIndex === documents.length - 1}
                            onClick={() => void moveMeetingDocument(doc.id, 'down')}
                          >
                            <ChevronDown className="w-4 h-4" />
                          </Button>
                        </div>
                      )}
                    </div>
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

            {!isResident && (
              <div className="border border-primary/30 rounded-lg p-3 bg-primary/5">
                <p className="text-sm font-medium mb-1">Publish report to all members</p>
                <p className="text-[11px] text-muted-foreground mb-2">
                  Saves notes, marks published, sends in-app notification and push (FCM / OneSignal) to every resident device where configured.
                </p>
                <Button type="button" className="w-full sm:w-auto" onClick={() => void publishAndNotifyAll()}>
                  <Send className="w-4 h-4 mr-2" /> Publish minutes & notify all
                </Button>
              </div>
            )}
          </div>
        )}
      </div>

      <Dialog open={!!sigCtx} onOpenChange={(o) => !o && setSigCtx(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Signature — {sigCtx?.doc.title}</DialogTitle>
            <DialogDescription>
              For <strong>{sigCtx?.attendee.display_name}</strong>. Collect on one device at the table if needed.
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
