import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Wrench, CheckCircle2, XCircle, Clock, Eye, Loader2, LogOut, X,
  Shield, ClipboardList, Hourglass,
} from 'lucide-react';
import StatusBadge from '@/components/StatusBadge';
import {
  getAuthorityComplaints, authorityAccept, authorityReject, authorityMarkDone, clearSession,
} from '@/services/api';
import { getStoredJSON } from '@/lib/storage';
import { categoryEmoji } from '@/lib/constants';
import { toast } from 'sonner';

const fmtTimestamp = (iso: string) => {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('en-IN', {
    timeZone: 'Asia/Calcutta',
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit', hour12: true,
  });
};

// ── Reject-reason modal (a reason is mandatory) ───────────────────────────────
const RejectReasonModal = ({
  complaint, onClose, onDone,
}: {
  complaint: any;
  onClose: () => void;
  onDone: (id: string, message: string) => void;
}) => {
  const [reason, setReason] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async () => {
    if (!reason.trim()) {
      toast.error('Please provide a reason for rejecting.');
      return;
    }
    setLoading(true);
    try {
      const res = await authorityReject(complaint._id, reason.trim());
      onDone(complaint._id, res?.message || 'Assignment rejected.');
      onClose();
    } catch (err: any) {
      toast.error(err?.response?.data?.error || 'Failed to reject. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="bg-card rounded-3xl shadow-card-hover border border-border/40 w-full max-w-md animate-slide-up">
        <div className="flex items-center justify-between p-6 border-b border-border/30">
          <div>
            <h2 className="text-base font-bold font-display text-foreground">Reject Assignment</h2>
            <p className="text-xs text-muted-foreground mt-0.5">{complaint.ticket_number} · {complaint.category}</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-muted text-muted-foreground transition-colors">
            <X className="h-4 w-4" />
          </button>
        </div>
        <div className="p-6 space-y-4">
          <div className="bg-red-500/10 border border-red-500/20 rounded-2xl p-4 flex items-start gap-3">
            <XCircle className="h-5 w-5 text-red-500 shrink-0 mt-0.5" />
            <p className="text-sm text-foreground">
              This task will be passed to the next authority in the priority order, or returned to the admin if none remain.
              The student is <strong>not</strong> notified.
            </p>
          </div>
          <div>
            <label className="block text-xs font-medium text-muted-foreground mb-1.5">
              Reason for rejecting <span className="text-red-500">*</span>
            </label>
            <textarea
              value={reason}
              onChange={e => setReason(e.target.value)}
              rows={3}
              placeholder="Why can't you take this on? (e.g. wrong department, no capacity...)"
              className="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all resize-none"
            />
          </div>
          <div className="flex gap-3">
            <button onClick={onClose} className="flex-1 py-2.5 rounded-xl border border-border/40 text-sm font-medium text-muted-foreground hover:text-foreground hover:bg-muted transition-all">
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              disabled={loading || !reason.trim()}
              className="flex-1 bg-red-500 text-white py-2.5 rounded-xl font-bold text-sm hover:opacity-90 transition-all flex items-center justify-center gap-2 disabled:opacity-40"
            >
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <XCircle className="h-4 w-4" />}
              Reject
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

// ── AuthorityDashboard ────────────────────────────────────────────────────────
const AuthorityDashboard = () => {
  const navigate = useNavigate();
  const [complaints, setComplaints] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [rejecting, setRejecting] = useState<any | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);

  const authority = getStoredJSON<{ name?: string; category?: string; email?: string }>('authority_user') ?? {};

  const load = () =>
    getAuthorityComplaints()
      .then(setComplaints)
      .catch(() => toast.error('Failed to load your complaints'))
      .finally(() => setLoading(false));

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleAccept = async (id: string) => {
    setBusyId(id);
    try {
      await authorityAccept(id);
      setComplaints(prev => prev.map(c => c._id === id ? { ...c, status: 'In Progress' } : c));
      toast.success('Accepted — the student has been notified.');
    } catch (err: any) {
      toast.error(err?.response?.data?.error || 'Failed to accept');
    } finally {
      setBusyId(null);
    }
  };

  const handleMarkDone = async (id: string) => {
    setBusyId(id);
    try {
      await authorityMarkDone(id);
      setComplaints(prev => prev.map(c => c._id === id ? { ...c, status: 'Pending Acceptance' } : c));
      toast.success('Marked as done — awaiting student confirmation.');
    } catch (err: any) {
      toast.error(err?.response?.data?.error || 'Failed to update');
    } finally {
      setBusyId(null);
    }
  };

  const handleRejected = (id: string, message: string) => {
    // Rejected tasks leave this authority's queue (reassigned or returned to admin).
    setComplaints(prev => prev.filter(c => c._id !== id));
    toast.success(message);
  };

  const handleSignOut = () => {
    clearSession();
    navigate('/welcome');
  };

  const awaiting  = complaints.filter(c => c.status === 'Assigned').length;
  const working   = complaints.filter(c => c.status === 'In Progress').length;
  const pending   = complaints.filter(c => c.status === 'Pending Acceptance').length;

  return (
    <div className="space-y-8">
      {rejecting && (
        <RejectReasonModal complaint={rejecting} onClose={() => setRejecting(null)} onDone={handleRejected} />
      )}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 animate-slide-up">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-primary/10 text-primary text-xs font-semibold mb-3">
            <Shield className="h-3 w-3" />
            Authority Panel
          </div>
          <h1 className="text-2xl font-bold font-display text-foreground">My Assigned Complaints</h1>
          <p className="text-sm text-muted-foreground mt-1">
            {authority.name ? <>Signed in as <span className="font-semibold text-foreground">{authority.name}</span></> : 'Authority'}
            {authority.category && <> · <span className="font-medium">{authority.category}</span> domain</>}
          </p>
        </div>
        <button onClick={handleSignOut} className="text-sm text-muted-foreground hover:text-destructive transition-colors font-medium self-start sm:self-auto">
          Sign out
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 animate-slide-up" style={{ animationDelay: '80ms' }}>
        {[
          { label: 'Awaiting your response', value: awaiting, icon: ClipboardList, tint: 'text-status-assigned', bg: 'bg-status-assigned/10' },
          { label: 'In progress', value: working, icon: Wrench, tint: 'text-violet-500', bg: 'bg-violet-500/10' },
          { label: 'Awaiting student', value: pending, icon: Hourglass, tint: 'text-amber-500', bg: 'bg-amber-500/10' },
        ].map(s => (
          <div key={s.label} className="bg-card rounded-2xl border border-border/40 shadow-card p-4 flex items-center gap-3">
            <div className={`w-10 h-10 rounded-xl ${s.bg} flex items-center justify-center shrink-0`}>
              <s.icon className={`h-5 w-5 ${s.tint}`} />
            </div>
            <div>
              <p className="text-xl font-bold text-foreground leading-none">{s.value}</p>
              <p className="text-[11px] text-muted-foreground mt-1 leading-tight">{s.label}</p>
            </div>
          </div>
        ))}
      </div>

      {/* Queue */}
      {loading ? (
        <div className="text-center py-20 text-sm text-muted-foreground">Loading your complaints…</div>
      ) : complaints.length === 0 ? (
        <div className="text-center py-20 animate-slide-up">
          <div className="w-16 h-16 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
            <CheckCircle2 className="h-6 w-6 text-muted-foreground" />
          </div>
          <p className="text-lg font-semibold font-display text-foreground">Nothing on your plate</p>
          <p className="text-sm text-muted-foreground mt-1">New assignments will appear here.</p>
        </div>
      ) : (
        <div className="space-y-4 animate-slide-up" style={{ animationDelay: '120ms' }}>
          {complaints.map(c => {
            const busy = busyId === c._id;
            return (
              <div key={c._id} className="bg-card rounded-2xl border border-border/40 shadow-card overflow-hidden">
                <div className="p-5 flex flex-col sm:flex-row sm:items-center gap-4">
                  <div className="flex items-start gap-3 flex-1 min-w-0">
                    <div className="w-11 h-11 rounded-xl bg-muted flex items-center justify-center text-xl shrink-0">
                      {categoryEmoji(c.category)}
                    </div>
                    <div className="min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-mono text-xs font-semibold text-primary">{c.ticket_number}</span>
                        <StatusBadge status={c.status} />
                      </div>
                      <p className="text-sm font-semibold text-foreground mt-1">{c.category} — {c.location?.building}, Room {c.location?.room}</p>
                      <p className="text-xs text-muted-foreground line-clamp-1 mt-0.5">{c.description}</p>
                      <p className="text-[11px] text-muted-foreground/70 mt-1">Raised {fmtTimestamp(c.timestamp)}</p>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-2 shrink-0 flex-wrap">
                    <button
                      onClick={() => navigate(`/complaints/${c._id}`)}
                      className="p-2.5 rounded-xl text-muted-foreground hover:text-primary hover:bg-primary/10 transition-all"
                      title="View details"
                    >
                      <Eye className="h-4 w-4" />
                    </button>

                    {c.status === 'Assigned' && (
                      <>
                        <button
                          onClick={() => handleAccept(c._id)}
                          disabled={busy}
                          className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20 text-xs font-semibold transition-all border border-emerald-500/20 disabled:opacity-40"
                        >
                          {busy ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <CheckCircle2 className="h-3.5 w-3.5" />}
                          Accept
                        </button>
                        <button
                          onClick={() => setRejecting(c)}
                          disabled={busy}
                          className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-red-500/10 text-red-600 hover:bg-red-500/20 text-xs font-semibold transition-all border border-red-500/20 disabled:opacity-40"
                        >
                          <XCircle className="h-3.5 w-3.5" />
                          Reject
                        </button>
                      </>
                    )}

                    {c.status === 'In Progress' && (
                      <button
                        onClick={() => handleMarkDone(c._id)}
                        disabled={busy}
                        className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20 text-xs font-semibold transition-all border border-emerald-500/20 disabled:opacity-40"
                      >
                        {busy ? <Loader2 className="h-3.5 w-3.5 animate-spin" /> : <CheckCircle2 className="h-3.5 w-3.5" />}
                        Mark Done
                      </button>
                    )}

                    {c.status === 'Pending Acceptance' && (
                      <span className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-amber-500/10 text-amber-600 text-xs font-semibold border border-amber-500/20">
                        <Clock className="h-3.5 w-3.5" />
                        Awaiting Student
                      </span>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

export default AuthorityDashboard;
