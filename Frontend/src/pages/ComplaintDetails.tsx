import { useEffect, useState, useCallback } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  ArrowLeft, MapPin, Tag, Calendar, CheckCircle2, Clock, UserCheck,
  Loader2, Info, Ticket, Mail, Expand, X, ZoomIn, ZoomOut, Download,
  RotateCcw, AlertTriangle, Star, XCircle,
} from 'lucide-react';
import StatusBadge from '@/components/StatusBadge';
import { getComplaintById, resolvePhotoUrl } from '@/services/api';
import { getStoredJSON } from '@/lib/storage';
import { CATEGORY_META, DEFAULT_CATEGORY } from '@/lib/constants';
import { AcceptFeedbackModal, ReopenModal } from '@/components/AcceptReopenModals';
import { toast } from 'sonner';

const timelineSteps = [
  { label: 'Submitted',          desc: 'Complaint registered',          icon: Clock },
  { label: 'Assigned',           desc: 'Department assigned',            icon: UserCheck },
  { label: 'In Progress',        desc: 'Being worked on',               icon: Loader2 },
  { label: 'Pending Acceptance', desc: 'Fix ready — awaiting student',   icon: AlertTriangle },
  { label: 'Completed',          desc: 'Issue resolved & accepted',      icon: CheckCircle2 },
];

const fmtTimestamp = (iso: string) => {
  if (!iso) return null;
  return new Date(iso).toLocaleString('en-IN', {
    timeZone: 'Asia/Calcutta',
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', hour12: true,
  });
};

/** Rough "time left until <iso>" phrase, e.g. "in ~20h 30m". */
const fmtRemaining = (iso: string): string | null => {
  if (!iso) return null;
  const ms = new Date(iso).getTime() - Date.now();
  if (Number.isNaN(ms)) return null;
  if (ms <= 0) return 'any moment now';
  const totalMins = Math.floor(ms / 60000);
  const h = Math.floor(totalMins / 60);
  const m = totalMins % 60;
  if (h >= 1) return `in ~${h}h${m ? ` ${m}m` : ''}`;
  return `in ~${m}m`;
};

/* ── Image Lightbox ─────────────────────────────────────────────────────── */
const ZOOM_STEP = 0.25;
const ZOOM_MIN  = 0.5;
const ZOOM_MAX  = 4;

const ImageLightbox = ({ src, alt, onClose }: { src: string; alt: string; onClose: () => void }) => {
  const [zoom, setZoom] = useState(1);

  const zoomIn  = () => setZoom(z => Math.min(ZOOM_MAX, +(z + ZOOM_STEP).toFixed(2)));
  const zoomOut = () => setZoom(z => Math.max(ZOOM_MIN, +(z - ZOOM_STEP).toFixed(2)));

  const handleDownload = async () => {
    try {
      const res  = await fetch(src);
      const blob = await res.blob();
      const url  = URL.createObjectURL(blob);
      const a    = document.createElement('a');
      a.href     = url;
      a.download = src.split('/').pop() || 'image';
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      toast.error('Download failed');
    }
  };

  // Close on Escape
  const onKey = useCallback((e: KeyboardEvent) => {
    if (e.key === 'Escape') onClose();
  }, [onClose]);

  useEffect(() => {
    window.addEventListener('keydown', onKey);
    document.body.style.overflow = 'hidden';
    return () => {
      window.removeEventListener('keydown', onKey);
      document.body.style.overflow = '';
    };
  }, [onKey]);

  return (
    <div
      className="fixed inset-0 z-50 flex flex-col bg-black/90 backdrop-blur-sm"
      onClick={onClose}
    >
      {/* Toolbar */}
      <div
        className="flex items-center justify-between px-4 py-3 shrink-0"
        onClick={e => e.stopPropagation()}
      >
        <span className="text-white/60 text-xs font-medium">{Math.round(zoom * 100)}%</span>
        <div className="flex items-center gap-2">
          <button
            onClick={zoomOut}
            disabled={zoom <= ZOOM_MIN}
            className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white disabled:opacity-30 transition-all"
            title="Zoom out"
          >
            <ZoomOut className="h-4 w-4" />
          </button>
          <button
            onClick={zoomIn}
            disabled={zoom >= ZOOM_MAX}
            className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white disabled:opacity-30 transition-all"
            title="Zoom in"
          >
            <ZoomIn className="h-4 w-4" />
          </button>
          <button
            onClick={handleDownload}
            className="p-2 rounded-xl bg-white/10 hover:bg-white/20 text-white transition-all"
            title="Download"
          >
            <Download className="h-4 w-4" />
          </button>
          <button
            onClick={onClose}
            className="p-2 rounded-xl bg-white/10 hover:bg-destructive/70 text-white transition-all"
            title="Close (Esc)"
          >
            <X className="h-4 w-4" />
          </button>
        </div>
      </div>

      {/* Image area */}
      <div
        className="flex-1 overflow-auto flex items-center justify-center p-6"
        onClick={e => e.stopPropagation()}
      >
        <div
          style={{ transform: `scale(${zoom})`, transformOrigin: 'center center', transition: 'transform 0.2s ease' }}
          className="inline-flex shrink-0"
        >
          <img
            src={src}
            alt={alt}
            style={{ maxHeight: '72vh', maxWidth: '88vw' }}
            className="rounded-xl shadow-2xl object-contain"
            draggable={false}
          />
        </div>
      </div>

      {/* Zoom hint */}
      <p className="text-center text-white/30 text-xs pb-3 shrink-0">Click outside or press Esc to close</p>
    </div>
  );
};
/* ───────────────────────────────────────────────────────────────────────── */

const ComplaintDetails = () => {
  const { id } = useParams();
  const navigate = useNavigate();
  const [complaint, setComplaint] = useState<any>(null);
  const [loadError, setLoadError] = useState(false);
  const [lightbox, setLightbox]   = useState(false);
  const [accepting, setAccepting] = useState(false);
  const [reopening, setReopening] = useState(false);

  const currentUser  = getStoredJSON<{ name?: string; email?: string }>('student_user') ?? {};
  const studentName  = currentUser.name || currentUser.email?.split('@')[0] || 'Student';
  const isOwner      = complaint && currentUser.email && complaint.student_email === currentUser.email;

  // The detailed activity log (incl. internal reject reasons / cascade hops) is for
  // staff only. Students keep the higher-level stepper and never see rejections.
  const sessionActive = (k: string) => {
    const s = localStorage.getItem(k);
    if (!s) return false;
    const exp = Number(s);
    return !Number.isNaN(exp) && Date.now() < exp;
  };
  const isStaff = sessionActive('admin_session') || sessionActive('authority_session');

  useEffect(() => {
    if (!id) return;
    let active = true;
    setLoadError(false);
    getComplaintById(id)
      .then(data => { if (active) setComplaint(data); })
      .catch(() => { if (active) setLoadError(true); });
    return () => { active = false; };
  }, [id]);

  if (loadError) return (
    <div className="flex flex-col items-center justify-center h-64 gap-4 text-center">
      <AlertTriangle className="h-8 w-8 text-destructive" />
      <div>
        <p className="text-sm font-semibold text-foreground">Couldn't load this complaint</p>
        <p className="text-xs text-muted-foreground mt-1">It may have been removed, or the server is unreachable.</p>
      </div>
      <button onClick={() => navigate(-1)} className="text-sm font-medium text-primary hover:underline">
        Go back
      </button>
    </div>
  );

  if (!complaint) return (
    <div className="flex items-center justify-center h-64">
      <div className="w-8 h-8 border-2 border-primary border-t-transparent rounded-full animate-spin" />
    </div>
  );

  const meta = CATEGORY_META[complaint.category] || CATEGORY_META[DEFAULT_CATEGORY];

  // Map Reopened / Rejected to their visual position in the timeline (shown as a
  // terminal node in the happy-path stepper; the full history lives in the Activity Log).
  const displaySteps = complaint.status === 'Reopened'
    ? [
        ...timelineSteps.slice(0, 4),
        { label: 'Reopened', desc: 'Student reopened the complaint', icon: RotateCcw },
      ]
    : complaint.status === 'Rejected'
    ? [
        ...timelineSteps.slice(0, 2),
        { label: 'Rejected', desc: 'Authority rejected — awaiting re-assignment', icon: XCircle },
      ]
    : timelineSteps;

  const statusIndex = displaySteps.findIndex(s => s.label === complaint.status);

  const statusTimestamps: Record<string, string> = {};
  const statusMeta: Record<string, { admin_name: string; authority_name: string; student_name: string; reason: string; auto_accepted: boolean }> = {};
  (complaint.status_history || []).forEach((h: any) => {
    if (h.status && h.timestamp && !statusTimestamps[h.status]) {
      statusTimestamps[h.status] = h.timestamp;
    }
    if (h.status && !statusMeta[h.status]) {
      statusMeta[h.status] = {
        admin_name: h.admin_name || '',
        authority_name: h.authority_name || '',
        student_name: h.student_name || '',
        reason: h.reason || '',
        auto_accepted: !!h.auto_accepted,
      };
    }
  });
  if (!statusTimestamps['Submitted'] && complaint.timestamp) {
    statusTimestamps['Submitted'] = complaint.timestamp;
  }

  // Per-step actor line (who performed each action)
  const getActor = (label: string): string | null => {
    switch (label) {
      case 'Submitted':
        return complaint.student_email ? `Registered by ${complaint.student_email}` : null;
      case 'Assigned': {
        const authorityName = statusMeta['Assigned']?.authority_name || complaint.assignedTo?.name || '';
        const adminBy       = statusMeta['Assigned']?.admin_name     || complaint.assignedTo?.assigned_by || '';
        const auto          = adminBy === 'Auto-assign';
        if (authorityName && auto)    return `Auto-assigned to ${authorityName}`;
        if (authorityName && adminBy) return `Assigned to ${authorityName} by Admin — ${adminBy}`;
        if (authorityName)            return `Assigned to ${authorityName}`;
        if (adminBy && !auto)         return `Assigned by Admin — ${adminBy}`;
        return null;
      }
      case 'In Progress': {
        const name = statusMeta['In Progress']?.authority_name || complaint.assignedTo?.name || statusMeta['Assigned']?.authority_name || '';
        return name ? `Accepted — being handled by ${name}` : 'Accepted by the authority';
      }
      case 'Pending Acceptance': {
        const authorityBy = statusMeta['Pending Acceptance']?.authority_name || '';
        const adminBy     = statusMeta['Pending Acceptance']?.admin_name || '';
        if (authorityBy) return `Marked resolved by ${authorityBy}`;
        return adminBy ? `Resolved by Admin — ${adminBy}` : 'Awaiting student confirmation';
      }
      case 'Completed': {
        if (statusMeta['Completed']?.auto_accepted) return 'Auto-accepted — no response in time';
        const studentBy = statusMeta['Completed']?.student_name || '';
        return studentBy ? `Fix accepted by ${studentBy}` : null;
      }
      case 'Reopened': {
        const studentBy = statusMeta['Reopened']?.student_name || '';
        return studentBy ? `Reopened by ${studentBy}` : null;
      }
      case 'Rejected':
        // Kept neutral in the shared stepper — the who/why lives in the staff-only
        // Activity Log, never surfaced to the student.
        return 'Awaiting re-assignment by admin';
      default:
        return null;
    }
  };

  // Full, un-deduped chronological history — the reject cascade can produce several
  // Assigned/Rejected entries that the linear stepper above can't represent.
  const activityIcon = (status: string) => ({
    'Submitted': Clock,
    'Assigned': UserCheck,
    'In Progress': Loader2,
    'Rejected': XCircle,
    'Pending Acceptance': AlertTriangle,
    'Completed': CheckCircle2,
    'Reopened': RotateCcw,
  }[status] ?? Info);

  const activityText = (h: any): { title: string; detail?: string; reason?: string } => {
    switch (h.status) {
      case 'Submitted':
        return { title: 'Complaint registered', detail: complaint.student_email ? `by ${complaint.student_email}` : undefined };
      case 'Assigned': {
        const auto = h.admin_name === 'Auto-assign';
        return {
          title: `Assigned to ${h.authority_name || 'an authority'}`,
          detail: auto ? 'auto-assigned by priority' : h.admin_name ? `by Admin — ${h.admin_name}` : undefined,
        };
      }
      case 'In Progress':
        return { title: 'Assignment accepted', detail: h.authority_name ? `by ${h.authority_name}` : undefined };
      case 'Rejected':
        return { title: 'Assignment rejected', detail: h.authority_name ? `by ${h.authority_name}` : undefined, reason: h.reason };
      case 'Pending Acceptance':
        return { title: 'Marked as resolved', detail: h.authority_name ? `by ${h.authority_name}` : h.admin_name ? `by Admin — ${h.admin_name}` : undefined };
      case 'Completed':
        if (h.auto_accepted) return { title: 'Fix auto-accepted', detail: 'no student response in time' };
        return { title: 'Fix accepted', detail: h.student_name ? `by ${h.student_name}` : undefined };
      case 'Reopened':
        return { title: 'Complaint reopened', detail: h.student_name ? `by ${h.student_name}` : undefined, reason: h.reason };
      default:
        return { title: h.status };
    }
  };

  const history = complaint.status_history || [];

  return (
    <>
      {lightbox && complaint.photo && (
        <ImageLightbox
          src={resolvePhotoUrl(complaint.photo) ?? ''}
          alt={complaint.category}
          onClose={() => setLightbox(false)}
        />
      )}
      {accepting && (
        <AcceptFeedbackModal
          complaint={complaint}
          studentName={studentName}
          onClose={() => setAccepting(false)}
          onDone={() => setComplaint((prev: any) => ({ ...prev, status: 'Completed' }))}
        />
      )}
      {reopening && (
        <ReopenModal
          complaint={complaint}
          studentName={studentName}
          onClose={() => setReopening(false)}
          onDone={() => setComplaint((prev: any) => ({ ...prev, status: 'Reopened' }))}
        />
      )}

      <div className="max-w-3xl mx-auto">
        <button onClick={() => navigate(-1)} className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground mb-6 transition-colors group">
          <ArrowLeft className="h-4 w-4 group-hover:-translate-x-0.5 transition-transform" /> Back to complaints
        </button>

        <div className="bg-card rounded-3xl shadow-card-hover border border-border/40 overflow-hidden animate-slide-up">
          {/* Hero banner */}
          {complaint.photo ? (
            <div className="relative h-56 overflow-hidden group cursor-pointer" onClick={() => setLightbox(true)}>
              <img src={resolvePhotoUrl(complaint.photo) ?? undefined} alt={complaint.category} className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105" />
              <div className="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent" />
              {/* Expand hint overlay */}
              <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                <div className="flex items-center gap-2 px-4 py-2 rounded-2xl bg-black/60 backdrop-blur-sm text-white text-sm font-medium">
                  <Expand className="h-4 w-4" />
                  View full image
                </div>
              </div>
              {/* Always-visible expand icon */}
              <button
                className="absolute top-3 right-3 p-2 rounded-xl bg-black/50 backdrop-blur-sm text-white hover:bg-black/70 transition-all"
                title="Open full image"
                onClick={e => { e.stopPropagation(); setLightbox(true); }}
              >
                <Expand className="h-4 w-4" />
              </button>
            </div>
          ) : (
            <div className={`relative h-40 bg-gradient-to-r ${meta.solidGradient} flex items-center justify-center overflow-hidden`}>
              <div className="absolute inset-0 bg-black/10" />
              <div className="absolute top-4 right-4 w-32 h-32 bg-white/10 rounded-full" />
              <div className="absolute bottom-4 left-8 w-20 h-20 bg-white/5 rounded-full" />
              <span className="text-6xl relative z-10 drop-shadow-lg">{meta.emoji}</span>
            </div>
          )}

          <div className="p-6 md:p-8 space-y-8">
            {/* Ticket + status row */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="flex items-center gap-2 px-3 py-1.5 rounded-xl bg-primary/8 border border-primary/20 w-fit">
                <Ticket className="h-4 w-4 text-primary" />
                <span className="text-sm font-bold font-mono text-primary tracking-wide">{complaint.ticket_number}</span>
              </div>
              <StatusBadge status={complaint.status} />
            </div>

            {/* Header */}
            <div>
              <h1 className="text-2xl font-bold font-display text-foreground">{complaint.category} Issue</h1>
              <div className="flex flex-wrap gap-4 mt-3 text-sm text-muted-foreground">
                <span className="flex items-center gap-1.5">
                  <MapPin className="h-4 w-4 text-primary/60" />
                  {complaint.location?.building}, {complaint.location?.floor}, {complaint.location?.room}
                </span>
                <span className="flex items-center gap-1.5">
                  <Calendar className="h-4 w-4 text-primary/60" />
                  {fmtTimestamp(complaint.timestamp) || complaint.date}
                </span>
                <span className="flex items-center gap-1.5">
                  <Tag className="h-4 w-4 text-primary/60" />
                  {complaint.category}
                </span>
              </div>
              <div className="flex items-center gap-1.5 mt-2 text-sm text-muted-foreground">
                <Mail className="h-4 w-4 text-primary/60" />
                <span>Raised by{' '}
                  {complaint.student_email
                    ? <span className="font-medium text-foreground">{complaint.student_email}</span>
                    : <span className="italic text-muted-foreground/50">not recorded</span>
                  }
                </span>
              </div>
            </div>

            {/* Action Required Banner */}
            {complaint.status === 'Pending Acceptance' && isOwner && (
              <div className="bg-amber-500/10 border border-amber-500/30 rounded-2xl p-5">
                <div className="flex items-start gap-3 mb-4">
                  <AlertTriangle className="h-5 w-5 text-amber-600 shrink-0 mt-0.5" />
                  <div>
                    <p className="text-sm font-bold text-amber-700 dark:text-amber-400">Action Required</p>
                    <p className="text-xs text-amber-600/80 dark:text-amber-500/80 mt-0.5">
                      The admin has marked this issue as resolved. Please verify and either accept the fix or reopen if the problem persists.
                    </p>
                    {complaint.auto_accept_at && (
                      <p className="text-xs text-amber-700/90 dark:text-amber-400/90 mt-2 font-medium">
                        ⏳ If you don't respond, the fix is <strong>auto-accepted {fmtRemaining(complaint.auto_accept_at)}</strong>
                        {fmtTimestamp(complaint.auto_accept_at) ? ` (by ${fmtTimestamp(complaint.auto_accept_at)})` : ''}.
                      </p>
                    )}
                  </div>
                </div>
                <div className="flex gap-3">
                  <button
                    onClick={() => setAccepting(true)}
                    className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20 text-sm font-semibold transition-all border border-emerald-500/20"
                  >
                    <CheckCircle2 className="h-4 w-4" /> Accept Fix
                  </button>
                  <button
                    onClick={() => setReopening(true)}
                    className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl bg-amber-500/10 text-amber-600 hover:bg-amber-500/20 text-sm font-semibold transition-all border border-amber-500/20"
                  >
                    <RotateCcw className="h-4 w-4" /> Reopen Issue
                  </button>
                </div>
              </div>
            )}

            {/* Description */}
            <div className="bg-muted/30 rounded-2xl p-5 border border-border/30">
              <div className="flex items-center gap-2 mb-3">
                <Info className="h-4 w-4 text-primary" />
                <h2 className="text-sm font-bold font-display text-foreground">Description</h2>
              </div>
              <p className="text-sm text-muted-foreground leading-relaxed">{complaint.description}</p>
            </div>

            {/* Student feedback (shown after acceptance) */}
            {complaint.student_feedback && (
              <div className="bg-emerald-500/5 border border-emerald-500/20 rounded-2xl p-5">
                <div className="flex items-center gap-2 mb-2">
                  <Star className="h-4 w-4 text-emerald-500" />
                  <h2 className="text-sm font-bold font-display text-foreground">Student Feedback</h2>
                </div>
                <p className="text-sm text-muted-foreground leading-relaxed italic">"{complaint.student_feedback}"</p>
              </div>
            )}

            {/* Reopen reason */}
            {complaint.reopen_reason && (
              <div className="bg-red-500/5 border border-red-500/20 rounded-2xl p-5">
                <div className="flex items-center gap-2 mb-2">
                  <RotateCcw className="h-4 w-4 text-red-500" />
                  <h2 className="text-sm font-bold font-display text-foreground">Reopen Reason</h2>
                </div>
                <p className="text-sm text-muted-foreground leading-relaxed italic">"{complaint.reopen_reason}"</p>
              </div>
            )}

            {/* Timeline */}
            <div>
              <h2 className="text-sm font-bold font-display text-foreground mb-6">Status Timeline</h2>
              <div className="space-y-0">
                {displaySteps.map((step, i) => {
                  const isActive  = i <= statusIndex;
                  const isCurrent = i === statusIndex;
                  const ts        = statusTimestamps[step.label];
                  const actor = isActive ? getActor(step.label) : null;
                  return (
                    <div key={step.label} className="flex items-start gap-4">
                      <div className="flex flex-col items-center">
                        <div className={`w-10 h-10 rounded-2xl flex items-center justify-center transition-all duration-500 ${
                          isActive
                            ? 'gradient-primary text-primary-foreground shadow-button'
                            : 'bg-muted text-muted-foreground'
                        } ${isCurrent ? 'ring-4 ring-secondary/20 scale-110' : ''}`}>
                          <step.icon className="h-4 w-4" />
                        </div>
                        {i < displaySteps.length - 1 && (
                          <div className={`w-0.5 h-16 transition-colors ${isActive ? 'bg-primary/40' : 'bg-border'}`} />
                        )}
                      </div>
                      <div className="pt-1.5 pb-2">
                        <p className={`text-sm font-semibold ${isActive ? 'text-foreground' : 'text-muted-foreground'}`}>
                          {step.label}
                        </p>
                        <p className="text-xs text-muted-foreground mt-0.5">{step.desc}</p>
                        {actor && (
                          <p className="text-xs text-foreground/70 font-medium mt-1">{actor}</p>
                        )}
                        {ts ? (
                          <p className="text-xs text-primary/70 font-medium mt-1">{fmtTimestamp(ts)}</p>
                        ) : isActive ? (
                          <p className="text-xs text-muted-foreground/50 mt-1 italic">Time not recorded</p>
                        ) : null}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>

            {/* Activity Log — full chronological history (staff only; students see the stepper) */}
            {isStaff && history.length > 0 && (
              <div>
                <h2 className="text-sm font-bold font-display text-foreground mb-4">Activity Log</h2>
                <div className="space-y-3">
                  {history.map((h: any, i: number) => {
                    const Icon = activityIcon(h.status);
                    const t = activityText(h);
                    return (
                      <div key={i} className="flex items-start gap-3">
                        <div className="w-8 h-8 rounded-lg bg-muted flex items-center justify-center shrink-0 mt-0.5">
                          <Icon className="h-3.5 w-3.5 text-muted-foreground" />
                        </div>
                        <div className="flex-1 min-w-0">
                          <p className="text-sm font-medium text-foreground">
                            {t.title}
                            {t.detail && <span className="text-muted-foreground font-normal"> {t.detail}</span>}
                          </p>
                          {t.reason && <p className="text-xs text-rose-600 mt-0.5 italic">"{t.reason}"</p>}
                          {h.timestamp && <p className="text-[11px] text-muted-foreground/70 mt-0.5">{fmtTimestamp(h.timestamp)}</p>}
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
};

export default ComplaintDetails;
