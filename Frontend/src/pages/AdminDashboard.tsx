import { useEffect, useRef, useState } from 'react';
import {
  AlertCircle, Clock, CheckCircle2, Eye, Shield, RefreshCw,
  ChevronLeft, ChevronRight, ChevronUp, ChevronDown, Ticket, Mail, Download, FileSpreadsheet,
  X, UserCheck, UserPlus, Users, Plus, Pencil, Save, Trash2, Loader2, Wrench, Search, ScrollText,
  Bell, Zap,
} from 'lucide-react';
import {
  ResponsiveContainer, PieChart, Pie, Cell, Tooltip as ReTooltip,
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  AreaChart, Area,
} from 'recharts';
import DashboardCard from '@/components/DashboardCard';
import StatusBadge from '@/components/StatusBadge';
import {
  getAdminComplaints, updateComplaintStatus, getRecurringComplaints,
  getAuthorities, addAuthority, updateAuthority, deleteAuthority, assignComplaint,
  getCategorySettings, updateCategorySettings,
  getNotificationEmails, addNotificationEmail, deleteNotificationEmail,
  type CategorySettings,
} from '@/services/api';
import { toast } from 'sonner';
import { useNavigate } from 'react-router-dom';
import { getStoredJSON } from '@/lib/storage';
import { CATEGORIES, categoryEmoji } from '@/lib/constants';
import * as XLSX from 'xlsx';

const SESSION_KEY = 'admin_session';
const PAGE_SIZE   = 10;

const fmtTimestamp = (iso: string) => {
  if (!iso) return '—';
  return new Date(iso).toLocaleString('en-IN', {
    timeZone: 'Asia/Calcutta',
    day: '2-digit', month: 'short', year: 'numeric',
    hour: '2-digit', minute: '2-digit', hour12: true,
  });
};

// ── Types ─────────────────────────────────────────────────────────────────────
interface Authority {
  _id: string;
  name: string;
  email: string;
  phone: string;
  category: string;
}

// ── AssignModal ───────────────────────────────────────────────────────────────
const AssignModal = ({
  complaint,
  adminName,
  onClose,
  onAssigned,
}: {
  complaint: any;
  adminName: string;
  onClose: () => void;
  onAssigned: (id: string, assignedTo: any) => void;
}) => {
  const [authorities, setAuthorities] = useState<Authority[]>([]);
  const [selected, setSelected]       = useState<string | null>(null);
  const [loading, setLoading]         = useState(false);
  const [confirmed, setConfirmed]     = useState<any>(null);

  useEffect(() => {
    getAuthorities(complaint.category).then(setAuthorities).catch(() => setAuthorities([]));
  }, [complaint.category]);

  const handleAssign = async () => {
    if (!selected) return;
    setLoading(true);
    try {
      const res = await assignComplaint(complaint._id, selected, adminName);
      setConfirmed(res.assigned_to);
      onAssigned(complaint._id, res.assigned_to);
    } catch {
      toast.error('Failed to assign authority');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="bg-card rounded-3xl shadow-card-hover border border-border/40 w-full max-w-md animate-slide-up">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-border/30">
          <div>
            <h2 className="text-base font-bold font-display text-foreground">Assign Concerned Authority</h2>
            <p className="text-xs text-muted-foreground mt-0.5">{complaint.category} · {complaint.ticket_number}</p>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-muted text-muted-foreground transition-colors">
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="p-6">
          {!confirmed ? (
            <>
              {authorities.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground text-sm">
                  <p>No authorities found for <strong>{complaint.category}</strong>.</p>
                  <p className="text-xs mt-1 text-muted-foreground/70">
                    Add them via <span className="text-primary font-medium">Manage Authority</span>.
                  </p>
                </div>
              ) : (
                <div className="space-y-2 mb-5 max-h-64 overflow-y-auto pr-1">
                  {authorities.map(a => (
                    <label
                      key={a._id}
                      className={`flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-all ${
                        selected === a._id
                          ? 'border-primary bg-primary/5'
                          : 'border-border/40 hover:border-primary/30 hover:bg-muted/30'
                      }`}
                    >
                      <input
                        type="radio"
                        name="authority"
                        value={a._id}
                        checked={selected === a._id}
                        onChange={() => setSelected(a._id)}
                        className="accent-primary"
                      />
                      <div>
                        <p className="text-sm font-semibold text-foreground">{a.name}</p>
                        <p className="text-xs text-muted-foreground">
                          {a.email}{a.phone ? ` · ${a.phone}` : ''}
                        </p>
                      </div>
                    </label>
                  ))}
                </div>
              )}
              <button
                onClick={handleAssign}
                disabled={!selected || loading}
                className="w-full gradient-primary text-primary-foreground py-3 rounded-xl font-bold text-sm shadow-button hover:opacity-90 transition-all flex items-center justify-center gap-2 disabled:opacity-40"
              >
                {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <UserCheck className="h-4 w-4" />}
                Assign Issue
              </button>
            </>
          ) : (
            <>
              <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-2xl p-5 mb-5 text-center">
                <CheckCircle2 className="h-9 w-9 text-emerald-500 mx-auto mb-3" />
                <p className="text-sm font-bold text-foreground">Issue Assigned!</p>
                <p className="text-xs text-muted-foreground mt-2 leading-relaxed">
                  Assigned to{' '}
                  <span className="font-semibold text-foreground">{confirmed.name}</span>{' '}
                  at {fmtTimestamp(confirmed.assigned_at)}{' '}
                  by Admin —{' '}
                  <span className="font-semibold text-foreground">{adminName}</span>
                </p>
              </div>
              <div className="flex gap-3">
                <button
                  onClick={() => { setConfirmed(null); setSelected(null); }}
                  className="flex-1 py-2.5 rounded-xl border border-border/40 text-sm font-medium text-muted-foreground hover:text-foreground hover:bg-muted transition-all"
                >
                  Change Personnel
                </button>
                <button
                  onClick={onClose}
                  className="flex-1 py-2.5 rounded-xl gradient-primary text-primary-foreground text-sm font-bold shadow-button hover:opacity-90 transition-all"
                >
                  Close
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};

// ── ManageAuthorityPanel ──────────────────────────────────────────────────────
const ManageAuthorityPanel = ({ onClose }: { onClose: () => void }) => {
  const [authorities, setAuthorities] = useState<Authority[]>([]);
  const [settings, setSettings] = useState<CategorySettings[]>([]);
  const [form, setForm] = useState<{ name: string; email: string; phone: string; category: string }>(
    { name: '', email: '', phone: '', category: CATEGORIES[0] },
  );
  const [saving, setSaving] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const formRef = useRef<HTMLDivElement>(null);

  const load = () => {
    getAuthorities().then(setAuthorities).catch(() => {});
    getCategorySettings().then(setSettings).catch(() => {});
  };
  useEffect(() => { load(); }, []);

  const settingsFor = (cat: string) => settings.find(s => s.category === cat);

  const applySettings = (partial: { category: string } & Partial<CategorySettings>) => {
    setSettings(prev => {
      const idx = prev.findIndex(s => s.category === partial.category);
      if (idx === -1) {
        return [...prev, {
          category: partial.category,
          auto_assign: partial.auto_assign ?? false,
          priority_order: partial.priority_order ?? [],
        }];
      }
      const next = [...prev];
      next[idx] = { ...next[idx], ...partial };
      return next;
    });
  };

  // Authorities of a category ordered by the saved priority_order; unranked appended by name.
  const orderedForCategory = (cat: string): Authority[] => {
    const items = authorities.filter(a => a.category === cat);
    const byId = new Map(items.map(a => [a._id, a]));
    const seen = new Set<string>();
    const ranked: Authority[] = [];
    for (const id of settingsFor(cat)?.priority_order ?? []) {
      const a = byId.get(id);
      if (a && !seen.has(id)) { ranked.push(a); seen.add(id); }
    }
    const rest = items.filter(a => !seen.has(a._id)).sort((a, b) => a.name.localeCompare(b.name));
    return [...ranked, ...rest];
  };

  const handleToggleAuto = async (cat: string) => {
    const next = !(settingsFor(cat)?.auto_assign ?? false);
    applySettings({ category: cat, auto_assign: next });   // optimistic
    try {
      await updateCategorySettings({ category: cat, auto_assign: next });
      toast.success(`Auto-assign ${next ? 'ON' : 'OFF'} for ${cat}`);
    } catch {
      toast.error('Failed to update auto-assign');
      load();
    }
  };

  const handleReorder = async (cat: string, index: number, dir: -1 | 1) => {
    const ordered = orderedForCategory(cat);
    const target = index + dir;
    if (target < 0 || target >= ordered.length) return;
    const arr = [...ordered];
    [arr[index], arr[target]] = [arr[target], arr[index]];
    const ids = arr.map(a => a._id);
    applySettings({ category: cat, priority_order: ids });  // optimistic
    try {
      await updateCategorySettings({ category: cat, priority_order: ids });
    } catch {
      toast.error('Failed to save priority order');
      load();
    }
  };

  const resetForm = () => {
    setEditingId(null);
    setForm({ name: '', email: '', phone: '', category: CATEGORIES[0] });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      if (editingId) {
        await updateAuthority(editingId, form);
        toast.success('Authority updated');
      } else {
        await addAuthority(form);
        toast.success('Authority added');
      }
      resetForm();
      load();
    } catch {
      toast.error(editingId ? 'Failed to update authority' : 'Failed to add authority');
    } finally {
      setSaving(false);
    }
  };

  const startEdit = (a: Authority) => {
    setEditingId(a._id);
    setForm({ name: a.name, email: a.email, phone: a.phone, category: a.category });
    formRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  const handleDelete = async (id: string) => {
    try {
      await deleteAuthority(id);
      setAuthorities(prev => prev.filter(a => a._id !== id));
      if (editingId === id) resetForm();
      toast.success('Authority removed');
    } catch {
      toast.error('Failed to remove authority');
    }
  };

  const activeCategories = CATEGORIES.filter(cat => authorities.some(a => a.category === cat));

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="bg-card rounded-3xl shadow-card-hover border border-border/40 w-full max-w-2xl max-h-[90vh] flex flex-col animate-slide-up">
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-border/30 shrink-0">
          <div className="flex items-center gap-2">
            <Users className="h-5 w-5 text-primary" />
            <h2 className="text-base font-bold font-display text-foreground">Manage Authority</h2>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-muted text-muted-foreground transition-colors">
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {/* Add / Edit form */}
          <div ref={formRef} className="bg-muted/30 rounded-2xl p-5 border border-border/30">
            <h3 className="text-sm font-bold text-foreground mb-4">{editingId ? 'Edit Authority' : 'Add New Authority'}</h3>
            <form onSubmit={handleSubmit} className="space-y-3">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <input
                  placeholder="Full Name *"
                  value={form.name}
                  onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                  className="px-3 py-2.5 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all"
                  required
                />
                <input
                  placeholder="Email *"
                  type="email"
                  value={form.email}
                  onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
                  className="px-3 py-2.5 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all"
                  required
                />
                <input
                  placeholder="Phone (optional)"
                  value={form.phone}
                  onChange={e => setForm(f => ({ ...f, phone: e.target.value }))}
                  className="px-3 py-2.5 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all"
                />
                <select
                  value={form.category}
                  onChange={e => setForm(f => ({ ...f, category: e.target.value }))}
                  className="px-3 py-2.5 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all cursor-pointer"
                >
                  {CATEGORIES.map(c => <option key={c} value={c}>{c}</option>)}
                </select>
              </div>
              <div className="flex items-center gap-2">
                <button
                  type="submit"
                  disabled={saving}
                  className="flex items-center gap-2 px-5 py-2.5 rounded-xl gradient-primary text-primary-foreground text-sm font-bold shadow-button hover:opacity-90 transition-all disabled:opacity-40"
                >
                  {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : editingId ? <Save className="h-4 w-4" /> : <Plus className="h-4 w-4" />}
                  {editingId ? 'Save Changes' : 'Add Authority'}
                </button>
                {editingId && (
                  <button
                    type="button"
                    onClick={resetForm}
                    className="px-5 py-2.5 rounded-xl border border-border/40 text-sm font-semibold text-muted-foreground hover:text-foreground hover:bg-muted transition-all"
                  >
                    Cancel
                  </button>
                )}
              </div>
            </form>
          </div>

          {/* Authority list — grouped by category, with auto-assign toggle + priority order */}
          {activeCategories.length === 0 ? (
            <p className="text-center text-muted-foreground text-sm py-6">No authorities added yet.</p>
          ) : (
            activeCategories.map(cat => {
              const items = orderedForCategory(cat);
              const auto = settingsFor(cat)?.auto_assign ?? false;
              return (
                <div key={cat}>
                  {/* Category header: name + per-category auto-assign toggle */}
                  <div className="flex items-center justify-between mb-2">
                    <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider">{cat}</p>
                    <div className="flex items-center gap-2">
                      <Zap className={`h-3.5 w-3.5 ${auto ? 'text-primary' : 'text-muted-foreground/40'}`} />
                      <span className="text-[11px] font-medium text-muted-foreground">Auto-assign</span>
                      <button
                        onClick={() => handleToggleAuto(cat)}
                        role="switch"
                        aria-checked={auto}
                        className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${auto ? 'bg-primary' : 'bg-muted-foreground/30'}`}
                        title={`Turn auto-assign ${auto ? 'off' : 'on'} for ${cat}`}
                      >
                        <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${auto ? 'translate-x-4' : 'translate-x-1'}`} />
                      </button>
                    </div>
                  </div>
                  {auto && (
                    <p className="text-[11px] text-muted-foreground/70 mb-2">
                      New {cat} issues auto-assign to <span className="font-semibold text-foreground">{items[0]?.name}</span>, cascading down this list on rejection.
                    </p>
                  )}
                  <div className="space-y-2">
                    {items.map((a, idx) => (
                      <div
                        key={a._id}
                        className={`flex items-center justify-between p-3 rounded-xl border transition-colors ${
                          editingId === a._id
                            ? 'bg-primary/5 border-primary/50'
                            : 'bg-muted/20 border-border/30 hover:bg-muted/40'
                        }`}
                      >
                        <div className="flex items-center gap-3 min-w-0">
                          {/* Priority index + reorder controls */}
                          <div className="flex flex-col items-center shrink-0">
                            <button
                              onClick={() => handleReorder(cat, idx, -1)}
                              disabled={idx === 0}
                              className="p-0.5 rounded text-muted-foreground hover:text-primary disabled:opacity-20 disabled:cursor-not-allowed transition-colors"
                              title="Move up (higher priority)"
                            >
                              <ChevronUp className="h-3.5 w-3.5" />
                            </button>
                            <span className="text-[10px] font-bold text-muted-foreground tabular-nums">{idx + 1}</span>
                            <button
                              onClick={() => handleReorder(cat, idx, 1)}
                              disabled={idx === items.length - 1}
                              className="p-0.5 rounded text-muted-foreground hover:text-primary disabled:opacity-20 disabled:cursor-not-allowed transition-colors"
                              title="Move down (lower priority)"
                            >
                              <ChevronDown className="h-3.5 w-3.5" />
                            </button>
                          </div>
                          <div className="min-w-0">
                            <p className="text-sm font-semibold text-foreground truncate">{a.name}</p>
                            <p className="text-xs text-muted-foreground truncate">
                              {a.email}{a.phone ? ` · ${a.phone}` : ''}
                            </p>
                          </div>
                        </div>
                        <div className="flex items-center gap-1 shrink-0">
                          <button
                            onClick={() => startEdit(a)}
                            className="p-2 rounded-xl text-muted-foreground hover:text-primary hover:bg-primary/10 transition-all"
                            title="Edit authority"
                          >
                            <Pencil className="h-4 w-4" />
                          </button>
                          <button
                            onClick={() => handleDelete(a._id)}
                            className="p-2 rounded-xl text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-all"
                            title="Remove authority"
                          >
                            <Trash2 className="h-4 w-4" />
                          </button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>
    </div>
  );
};

// ── NotificationEmailsPanel ───────────────────────────────────────────────────
const NotificationEmailsPanel = ({ onClose }: { onClose: () => void }) => {
  const [emails, setEmails] = useState<{ _id: string; email: string }[]>([]);
  const [newEmail, setNewEmail] = useState('');
  const [saving, setSaving] = useState(false);

  const load = () => getNotificationEmails().then(setEmails).catch(() => {});
  useEffect(() => { load(); }, []);

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newEmail.trim()) return;
    setSaving(true);
    try {
      await addNotificationEmail(newEmail.trim());
      setNewEmail('');
      load();
      toast.success('Notification email added');
    } catch (err: any) {
      toast.error(err?.message || 'Failed to add email');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await deleteNotificationEmail(id);
      setEmails(prev => prev.filter(e => e._id !== id));
      toast.success('Removed');
    } catch {
      toast.error('Failed to remove');
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4">
      <div className="bg-card rounded-3xl shadow-card-hover border border-border/40 w-full max-w-lg max-h-[90vh] flex flex-col animate-slide-up">
        <div className="flex items-center justify-between p-6 border-b border-border/30 shrink-0">
          <div className="flex items-center gap-2">
            <Bell className="h-5 w-5 text-primary" />
            <h2 className="text-base font-bold font-display text-foreground">Notification Emails</h2>
          </div>
          <button onClick={onClose} className="p-2 rounded-xl hover:bg-muted text-muted-foreground transition-colors">
            <X className="h-4 w-4" />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-6 space-y-5">
          <div className="bg-amber-500/10 border border-amber-500/20 rounded-2xl p-4 flex items-start gap-3">
            <AlertCircle className="h-5 w-5 text-amber-600 shrink-0 mt-0.5" />
            <p className="text-xs text-foreground leading-relaxed">
              These addresses are emailed <strong>only when an authority rejects</strong> an assignment, so an admin can step in and re-assign. Separate from your admin login accounts.
            </p>
          </div>

          <form onSubmit={handleAdd} className="flex gap-2">
            <input
              type="email"
              placeholder="admin@uem.edu.in"
              value={newEmail}
              onChange={e => setNewEmail(e.target.value)}
              className="flex-1 px-3 py-2.5 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all"
              required
            />
            <button
              type="submit"
              disabled={saving}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl gradient-primary text-primary-foreground text-sm font-bold shadow-button hover:opacity-90 transition-all disabled:opacity-40"
            >
              {saving ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
              Add
            </button>
          </form>

          {emails.length === 0 ? (
            <p className="text-center text-muted-foreground text-sm py-6">No notification emails yet.</p>
          ) : (
            <div className="space-y-2">
              {emails.map(e => (
                <div key={e._id} className="flex items-center justify-between p-3 rounded-xl border bg-muted/20 border-border/30">
                  <div className="flex items-center gap-2 min-w-0">
                    <Mail className="h-4 w-4 text-muted-foreground shrink-0" />
                    <span className="text-sm text-foreground truncate">{e.email}</span>
                  </div>
                  <button
                    onClick={() => handleDelete(e._id)}
                    className="p-2 rounded-xl text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-all shrink-0"
                    title="Remove"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

// ── AdminDashboard ────────────────────────────────────────────────────────────
const AdminDashboard = () => {
  const [complaints, setComplaints] = useState<any[]>([]);
  const [recurring, setRecurring]   = useState<any[]>([]);
  const [page, setPage]             = useState(1);
  const [search, setSearch]         = useState('');
  const [showExport, setShowExport] = useState(false);
  const [exportFrom, setExportFrom] = useState('');
  const [exportTo, setExportTo]     = useState('');
  const [assigning, setAssigning]   = useState<any | null>(null);
  const [showManage, setShowManage] = useState(false);
  const [showNotify, setShowNotify] = useState(false);
  const [loading, setLoading]       = useState(true);
  const navigate = useNavigate();

  const adminUser  = getStoredJSON<{ name?: string; email?: string }>('admin_user');
  const adminName  = adminUser?.name ?? 'Admin';

  const handleExport = () => {
    const from = exportFrom ? new Date(exportFrom + 'T00:00:00') : null;
    const to   = exportTo   ? new Date(exportTo   + 'T23:59:59') : null;

    const filtered = complaints.filter(c => {
      if (!c.timestamp) return true;
      const d = new Date(c.timestamp);
      if (from && d < from) return false;
      if (to   && d > to)   return false;
      return true;
    });

    if (filtered.length === 0) {
      toast.error('No complaints found in the selected date range.');
      return;
    }

    const rows = filtered.map(c => ({
      'Ticket No.'  : c.ticket_number || '',
      'Category'    : c.category,
      'Building'    : c.location?.building || '',
      'Floor'       : c.location?.floor || '',
      'Room'        : c.location?.room || '',
      'Description' : c.description,
      'Status'      : c.status,
      'Raised By'   : c.student_email || '',
      'Timestamp'   : c.timestamp ? fmtTimestamp(c.timestamp) : '',
    }));

    const ws = XLSX.utils.json_to_sheet(rows);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Complaints');

    const fromLabel = exportFrom || 'all';
    const toLabel   = exportTo   || 'all';
    XLSX.writeFile(wb, `campusfix_complaints_${fromLabel}_to_${toLabel}.xlsx`);
    toast.success(`Exported ${filtered.length} complaint${filtered.length !== 1 ? 's' : ''}`);
    setShowExport(false);
  };

  const handleResolve = async (id: string) => {
    try {
      await updateComplaintStatus(id, 'Pending Acceptance', adminName, adminUser?.email);
      setComplaints(prev => prev.map(x => x._id === id ? { ...x, status: 'Pending Acceptance' } : x));
      toast.success('Marked as resolved — student notified to accept the fix');
    } catch {
      toast.error('Failed to update status');
    }
  };

  const handleAssigned = (complaintId: string, assignedTo: any) => {
    setComplaints(prev =>
      prev.map(x => x._id === complaintId ? { ...x, status: 'Assigned', assignedTo } : x),
    );
  };

  useEffect(() => {
    setLoading(true);
    getAdminComplaints()
      .then(setComplaints)
      .catch(() => toast.error('Failed to load complaints'))
      .finally(() => setLoading(false));
    getRecurringComplaints().then(setRecurring).catch(() => {});
  }, []);

  const total       = complaints.length;
  const pending     = complaints.filter(c => ['Submitted', 'Reopened', 'Rejected'].includes(c.status)).length;
  const underFixing = complaints.filter(c => ['Assigned', 'In Progress', 'Pending Acceptance'].includes(c.status)).length;
  const resolved    = complaints.filter(c => c.status === 'Completed').length;

  // ── Chart data ───────────────────────────────────────────────────────────
  const statusChartData = [
    { name: 'Unattended',        value: pending,     color: '#f59e0b' },
    { name: 'Under Fixing',      value: underFixing, color: '#6366f1' },
    { name: 'Resolved',          value: resolved,    color: '#10b981' },
  ].filter(d => d.value > 0);

  const categoryChartData = CATEGORIES.map(cat => ({
    name: cat,
    count: complaints.filter(c => c.category === cat).length,
  })).filter(d => d.count > 0).sort((a, b) => b.count - a.count);

  const monthlyData = (() => {
    const now = new Date();
    const entries = Array.from({ length: 6 }, (_, i) => {
      const d = new Date(now.getFullYear(), now.getMonth() - (5 - i), 1);
      return { month: d.toLocaleString('en-IN', { month: 'short' }), monthIndex: d.getMonth(), year: d.getFullYear(), count: 0 };
    });
    complaints.forEach(c => {
      if (!c.timestamp) return;
      const d  = new Date(c.timestamp);
      const entry = entries.find(e => e.monthIndex === d.getMonth() && e.year === d.getFullYear());
      if (entry) entry.count++;
    });
    return entries.map(({ month, count }) => ({ month, count }));
  })();

  // Audit-log search: match ticket number or raised-by email (case-insensitive).
  const q = search.trim().toLowerCase();
  const filteredComplaints = q
    ? complaints.filter(c =>
        (c.ticket_number || '').toLowerCase().includes(q) ||
        (c.student_email || '').toLowerCase().includes(q))
    : complaints;

  const filteredTotal = filteredComplaints.length;
  const totalPages = Math.max(1, Math.ceil(filteredTotal / PAGE_SIZE));
  const paginated  = filteredComplaints.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  return (
    <div className="space-y-8">
      {/* Modals */}
      {assigning && (
        <AssignModal
          complaint={assigning}
          adminName={adminName}
          onClose={() => setAssigning(null)}
          onAssigned={handleAssigned}
        />
      )}
      {showManage && <ManageAuthorityPanel onClose={() => setShowManage(false)} />}
      {showNotify && <NotificationEmailsPanel onClose={() => setShowNotify(false)} />}

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 animate-slide-up">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-primary/10 text-primary text-xs font-semibold mb-3">
            <Shield className="h-3 w-3" />
            Admin Panel
          </div>
          <h1 className="text-2xl font-bold font-display text-foreground">Admin Dashboard</h1>
          <p className="text-sm text-muted-foreground mt-1">Manage and assign campus complaints</p>
        </div>
        <div className="flex items-center gap-3 flex-wrap">
          <button
            onClick={() => setShowManage(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-muted hover:bg-muted/80 text-foreground text-sm font-semibold transition-all border border-border/40"
          >
            <Users className="h-4 w-4" />
            Manage Authority
          </button>
          <button
            onClick={() => setShowNotify(true)}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-muted hover:bg-muted/80 text-foreground text-sm font-semibold transition-all border border-border/40"
          >
            <Bell className="h-4 w-4" />
            Notification Emails
          </button>
          <button
            onClick={() => setShowExport(v => !v)}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-primary/10 hover:bg-primary/20 text-primary text-sm font-semibold transition-all border border-primary/20"
          >
            <FileSpreadsheet className="h-4 w-4" />
            Export XLSX
          </button>
          <button
            onClick={() => { localStorage.removeItem('auth_token'); localStorage.removeItem(SESSION_KEY); localStorage.removeItem('admin_user'); navigate('/welcome'); }}
            className="text-sm text-muted-foreground hover:text-destructive transition-colors font-medium"
          >
            Sign out
          </button>
        </div>
      </div>

      {/* Export panel */}
      {showExport && (
        <div className="bg-card border border-border/40 rounded-2xl p-5 shadow-card animate-slide-up">
          <div className="flex items-center justify-between mb-4">
            <div className="flex items-center gap-2">
              <Download className="h-4 w-4 text-primary" />
              <h3 className="text-sm font-bold text-foreground">Export Complaints as XLSX</h3>
            </div>
            <button onClick={() => setShowExport(false)} className="p-1.5 rounded-lg hover:bg-muted text-muted-foreground transition-colors">
              <X className="h-4 w-4" />
            </button>
          </div>
          <p className="text-xs text-muted-foreground mb-4">
            Filter by issue raised date. Leave both blank to export all complaints.
          </p>
          <div className="flex flex-col sm:flex-row gap-3 items-end">
            <div className="flex-1">
              <label className="block text-xs font-medium text-muted-foreground mb-1.5">From date</label>
              <input
                type="date"
                value={exportFrom}
                onChange={e => setExportFrom(e.target.value)}
                className="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all"
              />
            </div>
            <div className="flex-1">
              <label className="block text-xs font-medium text-muted-foreground mb-1.5">To date</label>
              <input
                type="date"
                value={exportTo}
                onChange={e => setExportTo(e.target.value)}
                min={exportFrom || undefined}
                className="w-full px-3 py-2.5 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all"
              />
            </div>
            <button
              onClick={handleExport}
              className="flex items-center gap-2 px-5 py-2.5 rounded-xl gradient-primary text-primary-foreground text-sm font-bold shadow-button hover:opacity-90 transition-all whitespace-nowrap"
            >
              <Download className="h-4 w-4" />
              Download
            </button>
          </div>
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 animate-slide-up" style={{ animationDelay: '100ms' }}>
        <DashboardCard title="Total Complaints Raised"       value={total}       icon={AlertCircle}  iconBg="bg-primary/10" />
        <DashboardCard title="Total Complaints Unattended"   value={pending}     icon={Clock}        iconBg="bg-status-submitted/10" />
        <DashboardCard title="Total Complaints Under Fixing" value={underFixing} icon={Wrench}       iconBg="bg-violet-500/10" />
        <DashboardCard title="Total Complaints Resolved"     value={resolved}    icon={CheckCircle2} iconBg="bg-status-completed/10" />
      </div>

      {/* Charts */}
      {total > 0 && (
        <div className="space-y-4 animate-slide-up" style={{ animationDelay: '150ms' }}>
          {/* Row 1: Status donut + Category bar */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {/* Status Breakdown */}
            <div className="bg-card rounded-2xl border border-border/40 shadow-card p-5">
              <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-4">Status Breakdown</p>
              {statusChartData.length > 0 ? (
                <div className="flex items-center gap-4">
                  <ResponsiveContainer width={160} height={160}>
                    <PieChart>
                      <Pie data={statusChartData} cx="50%" cy="50%" innerRadius={45} outerRadius={70} paddingAngle={3} dataKey="value" strokeWidth={0}>
                        {statusChartData.map((entry, i) => <Cell key={i} fill={entry.color} />)}
                      </Pie>
                      <ReTooltip
                        contentStyle={{ background: 'hsl(var(--card))', border: '1px solid hsl(var(--border))', borderRadius: '12px', fontSize: '12px' }}
                        itemStyle={{ color: 'hsl(var(--foreground))' }}
                      />
                    </PieChart>
                  </ResponsiveContainer>
                  <div className="space-y-2 flex-1">
                    {statusChartData.map(d => (
                      <div key={d.name} className="flex items-center justify-between text-xs">
                        <div className="flex items-center gap-2">
                          <span className="w-2.5 h-2.5 rounded-full shrink-0" style={{ background: d.color }} />
                          <span className="text-muted-foreground">{d.name}</span>
                        </div>
                        <span className="font-bold text-foreground">{d.value}</span>
                      </div>
                    ))}
                    <div className="pt-1 border-t border-border/30 flex items-center justify-between text-xs">
                      <span className="text-muted-foreground">Total</span>
                      <span className="font-bold text-foreground">{total}</span>
                    </div>
                  </div>
                </div>
              ) : (
                <p className="text-sm text-muted-foreground text-center py-8">No data</p>
              )}
            </div>

            {/* Category Breakdown */}
            <div className="bg-card rounded-2xl border border-border/40 shadow-card p-5">
              <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-4">Complaints by Category</p>
              {categoryChartData.length > 0 ? (
                <ResponsiveContainer width="100%" height={160}>
                  <BarChart data={categoryChartData} layout="vertical" margin={{ left: 0, right: 16, top: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" horizontal={false} stroke="hsl(var(--border))" />
                    <XAxis type="number" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} allowDecimals={false} />
                    <YAxis type="category" dataKey="name" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} width={82} />
                    <ReTooltip
                      contentStyle={{ background: 'hsl(var(--card))', border: '1px solid hsl(var(--border))', borderRadius: '12px', fontSize: '12px' }}
                      itemStyle={{ color: 'hsl(var(--foreground))' }}
                      cursor={{ fill: 'hsl(var(--muted))', opacity: 0.4 }}
                    />
                    <Bar dataKey="count" fill="#6366f1" radius={[0, 6, 6, 0]} maxBarSize={20} />
                  </BarChart>
                </ResponsiveContainer>
              ) : (
                <p className="text-sm text-muted-foreground text-center py-8">No data</p>
              )}
            </div>
          </div>

          {/* Row 2: Monthly Trend */}
          <div className="bg-card rounded-2xl border border-border/40 shadow-card p-5">
            <p className="text-xs font-bold text-muted-foreground uppercase tracking-wider mb-4">Monthly Complaint Trend (last 6 months)</p>
            <ResponsiveContainer width="100%" height={160}>
              <AreaChart data={monthlyData} margin={{ left: 0, right: 16, top: 4, bottom: 0 }}>
                <defs>
                  <linearGradient id="trendGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%"  stopColor="#6366f1" stopOpacity={0.25} />
                    <stop offset="95%" stopColor="#6366f1" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                <XAxis dataKey="month" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} axisLine={false} tickLine={false} allowDecimals={false} width={28} />
                <ReTooltip
                  contentStyle={{ background: 'hsl(var(--card))', border: '1px solid hsl(var(--border))', borderRadius: '12px', fontSize: '12px' }}
                  itemStyle={{ color: 'hsl(var(--foreground))' }}
                  cursor={{ stroke: '#6366f1', strokeWidth: 1 }}
                />
                <Area type="monotone" dataKey="count" stroke="#6366f1" strokeWidth={2.5} fill="url(#trendGradient)" dot={{ fill: '#6366f1', r: 4, strokeWidth: 0 }} activeDot={{ r: 6 }} name="Complaints" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}

      {/* Audit Logs */}
      <div className="bg-card rounded-2xl shadow-card border border-border/40 overflow-hidden animate-slide-up" style={{ animationDelay: '200ms' }}>
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 px-5 py-4 border-b border-border/40 bg-muted/30">
          <div className="flex items-center gap-2">
            <ScrollText className="h-4 w-4 text-primary" />
            <h2 className="text-sm font-bold font-display text-foreground uppercase tracking-wider">Audit Logs</h2>
            <span className="text-xs text-muted-foreground">({filteredTotal})</span>
          </div>
          <div className="relative w-full sm:w-80">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <input
              type="text"
              value={search}
              onChange={e => { setSearch(e.target.value); setPage(1); }}
              placeholder="Search by ticket ID or email…"
              className="w-full pl-9 pr-3 py-2 rounded-xl border border-border/40 bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all"
            />
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-border/40 bg-muted/30">
                <th className="text-left px-5 py-4 font-bold font-display text-foreground text-xs uppercase tracking-wider">Ticket ID</th>
                <th className="text-left px-5 py-4 font-bold font-display text-foreground text-xs uppercase tracking-wider">Category</th>
                <th className="text-left px-5 py-4 font-bold font-display text-foreground text-xs uppercase tracking-wider hidden sm:table-cell">Location</th>
                <th className="text-left px-5 py-4 font-bold font-display text-foreground text-xs uppercase tracking-wider hidden lg:table-cell">Raised By</th>
                <th className="text-left px-5 py-4 font-bold font-display text-foreground text-xs uppercase tracking-wider">Status</th>
                <th className="text-left px-5 py-4 font-bold font-display text-foreground text-xs uppercase tracking-wider hidden md:table-cell">Raised At</th>
                <th className="text-right px-5 py-4 font-bold font-display text-foreground text-xs uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody>
              {paginated.map((c, i) => (
                <tr
                  key={c._id}
                  className="border-b border-border/20 hover:bg-muted/20 transition-colors animate-slide-in-right"
                  style={{ animationDelay: `${300 + i * 50}ms` }}
                >
                  {/* Ticket */}
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-1.5">
                      <Ticket className="h-3.5 w-3.5 text-primary/50 shrink-0" />
                      <span className="font-mono text-xs font-semibold text-primary">{c.ticket_number || '—'}</span>
                    </div>
                  </td>

                  {/* Category */}
                  <td className="px-5 py-4">
                    <div className="flex items-center gap-2">
                      <span className="text-lg leading-none">{categoryEmoji(c.category)}</span>
                      <span className="font-medium text-foreground">{c.category}</span>
                    </div>
                  </td>

                  {/* Location */}
                  <td className="px-5 py-4 text-muted-foreground hidden sm:table-cell">
                    {c.location?.building}, {c.location?.room}
                  </td>

                  {/* Raised By */}
                  <td className="px-5 py-4 hidden lg:table-cell">
                    <div className="flex items-center gap-1.5 text-muted-foreground">
                      <Mail className="h-3.5 w-3.5 shrink-0" />
                      <span className="text-xs truncate max-w-[160px]">{c.student_email || '—'}</span>
                    </div>
                  </td>

                  {/* Status */}
                  <td className="px-5 py-4">
                    <div className="space-y-1">
                      <StatusBadge status={c.status} />
                      {['Assigned', 'In Progress', 'Pending Acceptance'].includes(c.status) && c.assignedTo?.name && (
                        <p className="text-[10px] text-muted-foreground">
                          → {c.assignedTo.name}
                        </p>
                      )}
                    </div>
                  </td>

                  {/* Raised At */}
                  <td className="px-5 py-4 text-muted-foreground text-xs hidden md:table-cell whitespace-nowrap">
                    {fmtTimestamp(c.timestamp)}
                  </td>

                  {/* Actions */}
                  <td className="px-5 py-4 text-right">
                    <div className="flex items-center justify-end gap-1.5">
                      <button
                        onClick={() => navigate(`/complaints/${c._id}`)}
                        className="p-2.5 rounded-xl text-muted-foreground hover:text-primary hover:bg-primary/10 transition-all"
                        title="View details"
                      >
                        <Eye className="h-4 w-4" />
                      </button>

                      {['Submitted', 'Reopened', 'Rejected'].includes(c.status) && (
                        <button
                          onClick={() => setAssigning(c)}
                          className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-primary/10 text-primary hover:bg-primary/20 text-xs font-semibold transition-all border border-primary/20 whitespace-nowrap"
                        >
                          <UserPlus className="h-3.5 w-3.5" />
                          {c.status === 'Submitted' ? 'Assign' : 'Re-Assign'}
                        </button>
                      )}

                      {(c.status === 'Assigned' || c.status === 'In Progress') && (
                        <button
                          onClick={() => handleResolve(c._id)}
                          className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20 text-xs font-semibold transition-all border border-emerald-500/20 whitespace-nowrap"
                        >
                          <CheckCircle2 className="h-3.5 w-3.5" />
                          Mark Resolved
                        </button>
                      )}

                      {c.status === 'Pending Acceptance' && (
                        <span className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-amber-500/10 text-amber-600 text-xs font-semibold border border-amber-500/20 whitespace-nowrap">
                          <Clock className="h-3.5 w-3.5" />
                          Awaiting Student
                        </span>
                      )}

                      {c.status === 'Completed' && (
                        <span className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-emerald-500/10 text-emerald-600 text-xs font-semibold border border-emerald-500/20">
                          <CheckCircle2 className="h-3.5 w-3.5" />
                          Closed
                        </span>
                      )}
                    </div>
                  </td>
                </tr>
              ))}

              {paginated.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-5 py-12 text-center text-muted-foreground text-sm">
                    {loading ? 'Loading complaints…' : q ? 'No matching complaints.' : 'No complaints found.'}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>

        {/* Pagination */}
        <div className="flex items-center justify-between px-5 py-4 border-t border-border/30 bg-muted/20">
          <p className="text-xs text-muted-foreground">
            Showing{' '}
            <span className="font-semibold text-foreground">{Math.min((page - 1) * PAGE_SIZE + 1, filteredTotal)}–{Math.min(page * PAGE_SIZE, filteredTotal)}</span>{' '}
            of <span className="font-semibold text-foreground">{filteredTotal}</span> complaints
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setPage(p => Math.max(1, p - 1))}
              disabled={page === 1}
              className="p-2 rounded-xl border border-border/40 text-muted-foreground hover:text-foreground hover:bg-card disabled:opacity-40 disabled:cursor-not-allowed transition-all"
              title="Previous page"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
            <span className="text-xs font-medium text-foreground px-2">
              Page {page} of {totalPages}
            </span>
            <button
              onClick={() => setPage(p => Math.min(totalPages, p + 1))}
              disabled={page === totalPages}
              className="p-2 rounded-xl border border-border/40 text-muted-foreground hover:text-foreground hover:bg-card disabled:opacity-40 disabled:cursor-not-allowed transition-all"
              title="Next page"
            >
              <ChevronRight className="h-4 w-4" />
            </button>
          </div>
        </div>
      </div>

      {/* Recurring Complaints */}
      {recurring.length > 0 && (
        <div className="bg-card rounded-2xl shadow-card border border-border/40 overflow-hidden animate-slide-up" style={{ animationDelay: '300ms' }}>
          <div className="px-6 py-4 border-b border-border/40 bg-muted/30 flex items-center gap-2">
            <RefreshCw className="h-4 w-4 text-destructive" />
            <h2 className="text-sm font-bold font-display text-foreground uppercase tracking-wider">Recurring Issues</h2>
            <span className="ml-auto text-xs text-muted-foreground">{recurring.length} patterns detected</span>
          </div>
          <div className="divide-y divide-border/20">
            {recurring.map((r, i) => (
              <div key={i} className="px-6 py-4 flex items-center justify-between hover:bg-muted/20 transition-colors">
                <div>
                  <p className="text-sm font-semibold text-foreground">{r.category} — {r.building}, Room {r.room}</p>
                  <p className="text-xs text-muted-foreground mt-0.5">Reported {r.count} times</p>
                </div>
                <span className="text-xs font-medium px-2.5 py-1 rounded-full bg-destructive/10 text-destructive">Recurring</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default AdminDashboard;
