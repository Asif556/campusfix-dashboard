import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { FileWarning, ListChecks, History, AlertCircle, Clock, CheckCircle2, TrendingUp, ArrowRight, Zap, Bell, CheckCircle, RotateCcw, Ticket } from 'lucide-react';
import DashboardCard from '@/components/DashboardCard';
import { getDashboardStats, getComplaints } from '@/services/api';
import { getStoredJSON } from '@/lib/storage';
import { AcceptFeedbackModal, ReopenModal } from '@/components/AcceptReopenModals';

const StudentDashboard = () => {
  const [stats, setStats] = useState({ totalComplaints: 0, pendingIssues: 0, resolvedIssues: 0, inProgress: 0, monthChange: 0, resolutionRate: 0 });
  const [pendingAcceptance, setPendingAcceptance] = useState<any[]>([]);
  const [accepting, setAccepting] = useState<any | null>(null);
  const [reopening, setReopening] = useState<any | null>(null);

  const user = getStoredJSON<{ name?: string; email?: string }>('student_user') ?? {};
  const studentName = user.name || user.email?.split('@')[0] || 'Student';

  useEffect(() => {
    if (!user.email) return;
    getDashboardStats(user.email).then(setStats).catch(() => {});
    getComplaints(user.email)
      .then(all => setPendingAcceptance(all.filter((c: any) => c.status === 'Pending Acceptance')))
      .catch(() => {});
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleActionDone = (id: string) => {
    setPendingAcceptance(prev => prev.filter(c => c._id !== id));
  };

  const quickActions = [
    { title: 'Report Issue', desc: 'Submit a new infrastructure complaint', icon: FileWarning, path: '/report', gradient: 'from-red-500/10 via-orange-500/5 to-transparent', iconColor: 'text-red-500', iconBg: 'bg-red-500/10' },
    { title: 'Track Complaints', desc: 'Monitor your complaint progress', icon: ListChecks, path: '/track', gradient: 'from-blue-500/10 via-cyan-500/5 to-transparent', iconColor: 'text-blue-500', iconBg: 'bg-blue-500/10' },
    { title: 'Complaint History', desc: 'View all past complaints', icon: History, path: '/track', gradient: 'from-emerald-500/10 via-green-500/5 to-transparent', iconColor: 'text-emerald-500', iconBg: 'bg-emerald-500/10' },
  ];

  return (
    <div className="space-y-8">
      {/* Modals */}
      {accepting && (
        <AcceptFeedbackModal
          complaint={accepting}
          studentName={studentName}
          onClose={() => setAccepting(null)}
          onDone={handleActionDone}
        />
      )}
      {reopening && (
        <ReopenModal
          complaint={reopening}
          studentName={studentName}
          onClose={() => setReopening(null)}
          onDone={handleActionDone}
        />
      )}

      {/* Hero Section */}
      <div className="relative overflow-hidden rounded-3xl gradient-hero p-8 md:p-10">
        <div className="absolute top-0 right-0 w-64 h-64 bg-white/5 rounded-full -translate-y-1/2 translate-x-1/2" />
        <div className="absolute bottom-0 left-20 w-32 h-32 bg-white/5 rounded-full translate-y-1/2" />
        <div className="absolute top-1/2 right-1/4 w-2 h-2 bg-white/30 rounded-full animate-pulse-slow" />
        <div className="absolute top-1/3 right-1/3 w-1.5 h-1.5 bg-white/20 rounded-full animate-pulse-slow" style={{ animationDelay: '1s' }} />
        <div className="relative flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div className="flex items-center gap-4">
            <div>
              <div className="flex items-center gap-2 mb-1">
                <Zap className="h-5 w-5 text-yellow-300" />
                <span className="text-sm font-medium text-white/70">Smart Campus Platform</span>
              </div>
              <h1 className="text-2xl md:text-3xl font-bold font-display text-white">Welcome back! 👋</h1>
              <p className="text-white/60 text-sm mt-1">Here's your campus infrastructure overview</p>
            </div>
          </div>
          <Link
            to="/report"
            className="flex items-center gap-2 px-6 py-3 bg-white/15 hover:bg-white/25 text-white rounded-2xl text-sm font-semibold backdrop-blur-sm transition-all duration-300 border border-white/20 hover:border-white/30 shadow-lg"
          >
            <FileWarning className="h-4 w-4" />
            Report New Issue
            <ArrowRight className="h-4 w-4" />
          </Link>
        </div>
      </div>

      {/* Notification Centre */}
      {pendingAcceptance.length > 0 && (
        <div className="bg-amber-500/5 border border-amber-500/30 rounded-2xl overflow-hidden animate-slide-up">
          <div className="flex items-center gap-3 px-5 py-4 border-b border-amber-500/20 bg-amber-500/10">
            <div className="relative">
              <Bell className="h-5 w-5 text-amber-600" />
              <span className="absolute -top-1 -right-1 w-4 h-4 rounded-full bg-amber-500 text-white text-[10px] font-bold flex items-center justify-center">
                {pendingAcceptance.length}
              </span>
            </div>
            <h2 className="text-sm font-bold text-amber-700 dark:text-amber-500">
              Action Required — {pendingAcceptance.length} fix{pendingAcceptance.length > 1 ? 'es' : ''} pending your review
            </h2>
          </div>
          <div className="divide-y divide-amber-500/10">
            {pendingAcceptance.map(c => (
              <div key={c._id} className="px-5 py-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 hover:bg-amber-500/5 transition-colors">
                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <Ticket className="h-3.5 w-3.5 text-amber-600/70" />
                    <span className="font-mono text-xs font-semibold text-amber-700 dark:text-amber-400">{c.ticket_number}</span>
                    <span className="text-xs text-muted-foreground">·</span>
                    <span className="text-xs font-medium text-foreground">{c.category}</span>
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {c.location?.building}, Room {c.location?.room} — Fix ready, please review and confirm
                  </p>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <button
                    onClick={() => setAccepting(c)}
                    className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20 text-xs font-semibold transition-all border border-emerald-500/20"
                  >
                    <CheckCircle className="h-3.5 w-3.5" />
                    Accept Fix
                  </button>
                  <button
                    onClick={() => setReopening(c)}
                    className="flex items-center gap-1.5 px-3 py-2 rounded-xl bg-amber-500/10 text-amber-600 hover:bg-amber-500/20 text-xs font-semibold transition-all border border-amber-500/20"
                  >
                    <RotateCcw className="h-3.5 w-3.5" />
                    Reopen
                  </button>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Stats */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="animate-slide-up" style={{ animationDelay: '0ms' }}>
          <DashboardCard
            title="Total"
            value={stats.totalComplaints}
            icon={AlertCircle}
            iconBg="bg-primary/10"
            trend={stats.totalComplaints > 0 ? (stats.monthChange > 0 ? `+${stats.monthChange}% this month` : stats.monthChange < 0 ? `${stats.monthChange}% this month` : 'No change this month') : undefined}
          />
        </div>
        <div className="animate-slide-up" style={{ animationDelay: '100ms' }}>
          <DashboardCard title="Pending" value={stats.pendingIssues} icon={Clock} iconBg="bg-status-submitted/10" />
        </div>
        <div className="animate-slide-up" style={{ animationDelay: '200ms' }}>
          <DashboardCard title="In Progress" value={stats.inProgress} icon={TrendingUp} iconBg="bg-status-progress/10" />
        </div>
        <div className="animate-slide-up" style={{ animationDelay: '300ms' }}>
          <DashboardCard
            title="Resolved"
            value={stats.resolvedIssues}
            icon={CheckCircle2}
            iconBg="bg-status-completed/10"
            trend={stats.totalComplaints > 0 ? `${stats.resolutionRate}% resolution rate` : undefined}
          />
        </div>
      </div>

      {/* Quick Actions */}
      <div>
        <h2 className="text-lg font-bold font-display text-foreground mb-4">Quick Actions</h2>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          {quickActions.map((action, i) => (
            <Link
              key={action.title}
              to={action.path}
              className="group relative bg-card rounded-2xl p-6 shadow-card hover:shadow-card-hover transition-all duration-500 border border-border/40 overflow-hidden hover:-translate-y-1 animate-slide-up"
              style={{ animationDelay: `${400 + i * 100}ms` }}
            >
              <div className={`absolute inset-0 bg-gradient-to-br ${action.gradient} opacity-0 group-hover:opacity-100 transition-opacity duration-500`} />
              <div className="relative">
                <div className={`p-3 rounded-2xl w-fit ${action.iconBg} mb-4 group-hover:scale-110 transition-transform duration-300`}>
                  <action.icon className={`h-6 w-6 ${action.iconColor}`} />
                </div>
                <h3 className="font-semibold font-display text-card-foreground group-hover:text-foreground transition-colors">{action.title}</h3>
                <p className="text-sm text-muted-foreground mt-1">{action.desc}</p>
                <ArrowRight className="h-4 w-4 text-muted-foreground/40 mt-3 group-hover:text-primary group-hover:translate-x-1 transition-all duration-300" />
              </div>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
};

export default StudentDashboard;
