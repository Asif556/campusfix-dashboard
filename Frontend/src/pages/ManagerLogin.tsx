import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Shield, Mail, Lock, ArrowLeft, Loader2 } from 'lucide-react';
import { adminLogin, clearSession } from '@/services/api';
import { toast } from 'sonner';

const SESSION_KEY = 'admin_session';
const SESSION_DURATION = 2 * 60 * 60 * 1000; // 2 hours

const ManagerLogin = () => {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const res = await adminLogin(email, password);
      if (!res?.user) {
        toast.error('Login failed — unexpected server response');
        return;
      }
      clearSession(); // drop any prior student/authority session before switching role
      if (res.token) localStorage.setItem('auth_token', res.token);
      localStorage.setItem(SESSION_KEY, String(Date.now() + SESSION_DURATION));
      localStorage.setItem('admin_user', JSON.stringify(res.user));
      toast.success('Welcome, Admin!');
      navigate('/admin');
    } catch (err: any) {
      toast.error(err?.response?.data?.error || 'Invalid credentials');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4 relative overflow-hidden">
      {/* Background blobs */}
      <div className="absolute top-[-80px] left-[-80px] w-80 h-80 rounded-full bg-primary/10 blur-3xl pointer-events-none" />
      <div className="absolute bottom-[-80px] right-[-80px] w-72 h-72 rounded-full bg-indigo-500/10 blur-3xl pointer-events-none" />

      <div className="relative z-10 w-full max-w-md animate-slide-up">
        {/* Back */}
        <button
          onClick={() => navigate('/')}
          className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground mb-6 transition-colors group"
        >
          <ArrowLeft className="h-4 w-4 group-hover:-translate-x-0.5 transition-transform" />
          Back to home
        </button>

        <div className="bg-card rounded-3xl shadow-card-hover border border-border/40 overflow-hidden">
          {/* Header */}
          <div className="gradient-hero p-8 text-center relative overflow-hidden">
            <div className="absolute top-0 right-0 w-40 h-40 bg-white/5 rounded-full -translate-y-1/2 translate-x-1/2" />
            <div className="absolute bottom-0 left-12 w-24 h-24 bg-white/5 rounded-full translate-y-1/2" />
            <div className="relative">
              <div className="w-16 h-16 rounded-2xl bg-white/15 backdrop-blur-sm flex items-center justify-center mx-auto mb-4 border border-white/20">
                <Shield className="h-8 w-8 text-white" />
              </div>
              <h1 className="text-xl font-bold font-display text-white">Manager Login</h1>
              <p className="text-sm text-white/60 mt-1">Admin &amp; facility management access</p>
            </div>
          </div>

          {/* Form */}
          <form onSubmit={handleLogin} className="p-8 space-y-4">
            <div className="relative">
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <input
                type="email"
                placeholder="Admin email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                className="w-full pl-11 pr-4 py-3.5 rounded-xl border border-input bg-background text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary text-sm transition-all"
                required
              />
            </div>
            <div className="relative">
              <Lock className="absolute left-4 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <input
                type="password"
                placeholder="Password"
                value={password}
                onChange={e => setPassword(e.target.value)}
                className="w-full pl-11 pr-4 py-3.5 rounded-xl border border-input bg-background text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary text-sm transition-all"
                required
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full gradient-primary text-primary-foreground py-3.5 rounded-xl font-bold text-sm shadow-button hover:opacity-90 transition-all flex items-center justify-center gap-2 disabled:opacity-40"
            >
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <Shield className="h-4 w-4" />}
              {loading ? 'Signing in...' : 'Sign In as Manager'}
            </button>
          </form>

          <div className="px-8 pb-8">
            <div className="bg-muted/50 rounded-xl p-4 border border-border/30">
              <p className="text-xs text-muted-foreground text-center">
                Use the admin credentials provided by your system administrator.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default ManagerLogin;
