import { useEffect, useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Loader2, Wrench, Mail, KeyRound, LogIn } from 'lucide-react';
import { authoritySendOtp, authorityVerifyOtp, clearSession } from '@/services/api';
import { toast } from 'sonner';
import axios from 'axios';

const AUTHORITY_SESSION_KEY = 'authority_session';
const SESSION_DURATION = 8 * 60 * 60 * 1000; // 8 hours

const AuthorityLogin = () => {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [otp, setOtp] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [sendingOtp, setSendingOtp] = useState(false);
  const [verifying, setVerifying] = useState(false);
  const [resendCooldown, setResendCooldown] = useState(0);
  const otpInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (otpSent) otpInputRef.current?.focus();
  }, [otpSent]);

  useEffect(() => {
    if (resendCooldown <= 0) return;
    const id = setTimeout(() => setResendCooldown(c => c - 1), 1000);
    return () => clearTimeout(id);
  }, [resendCooldown]);

  const handleChangeEmail = () => {
    setOtpSent(false);
    setOtp('');
    setResendCooldown(0);
  };

  const handleSendOtp = async () => {
    if (!email.trim()) {
      toast.error('Please enter your registered authority email');
      return;
    }
    setSendingOtp(true);
    try {
      const res = await authoritySendOtp(email.trim().toLowerCase());
      setOtp('');
      setOtpSent(true);
      setResendCooldown(res?.resend_after ?? 30);
      toast.success('OTP sent to your email');
    } catch (err: unknown) {
      let message = 'Failed to send OTP';
      if (axios.isAxiosError(err)) {
        message = err.response?.data?.error ?? message;
        const retry = err.response?.data?.retry_after;
        if (typeof retry === 'number') setResendCooldown(retry);
      } else if (err instanceof Error) {
        message = err.message;
      }
      toast.error(message);
    } finally {
      setSendingOtp(false);
    }
  };

  const handleOtpLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    if (otp.trim().length !== 6) {
      toast.error('Please enter the 6-digit OTP sent to your email');
      return;
    }
    setVerifying(true);
    try {
      const res = await authorityVerifyOtp(email.trim().toLowerCase(), otp.trim());
      if (!res?.user) {
        toast.error('Login failed — unexpected server response');
        return;
      }
      clearSession(); // drop any prior student/admin session before switching role
      if (res.token) localStorage.setItem('auth_token', res.token);
      localStorage.setItem('authority_user', JSON.stringify(res.user));
      localStorage.setItem(AUTHORITY_SESSION_KEY, String(Date.now() + SESSION_DURATION));
      toast.success(`Welcome, ${res.user.name || res.user.email}!`);
      navigate('/authority');
    } catch (err: unknown) {
      let message = 'Login failed';
      if (axios.isAxiosError(err)) message = err.response?.data?.error ?? message;
      else if (err instanceof Error) message = err.message;
      toast.error(message);
    } finally {
      setVerifying(false);
    }
  };

  const handleOtpChange = (value: string) => {
    setOtp(value.replace(/\D/g, '').slice(0, 6));
  };

  return (
    <div className="min-h-screen bg-background flex items-center justify-center px-4 relative overflow-hidden">
      <div className="absolute top-[-80px] left-[-80px] w-80 h-80 rounded-full bg-primary/10 blur-3xl pointer-events-none" />
      <div className="absolute bottom-[-80px] right-[-80px] w-72 h-72 rounded-full bg-amber-500/10 blur-3xl pointer-events-none" />

      <div className="relative z-10 w-full max-w-md animate-slide-up">
        <button
          onClick={() => navigate('/welcome')}
          className="flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground mb-6 transition-colors group"
        >
          <ArrowLeft className="h-4 w-4 group-hover:-translate-x-0.5 transition-transform" />
          Back to home
        </button>

        <div className="bg-card rounded-3xl shadow-card-hover border border-border/40 overflow-hidden">
          <div className="gradient-hero p-8 text-center relative overflow-hidden">
            <div className="absolute top-0 right-0 w-40 h-40 bg-white/5 rounded-full -translate-y-1/2 translate-x-1/2" />
            <div className="absolute bottom-0 left-12 w-24 h-24 bg-white/5 rounded-full translate-y-1/2" />
            <div className="relative">
              <div className="w-16 h-16 rounded-2xl bg-white/15 backdrop-blur-sm flex items-center justify-center mx-auto mb-4 border border-white/20">
                <Wrench className="h-8 w-8 text-white" />
              </div>
              <h1 className="text-xl font-bold font-display text-white">Authority Login</h1>
              <p className="text-sm text-white/60 mt-1">Sign in to manage your assigned complaints</p>
            </div>
          </div>

          <form onSubmit={handleOtpLogin} className="p-8 space-y-4">
            <div className="relative">
              <Mail className="absolute left-4 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <input
                type="email"
                placeholder="Your registered authority email"
                value={email}
                onChange={e => setEmail(e.target.value)}
                disabled={otpSent}
                className="w-full pl-11 pr-4 py-3.5 rounded-xl border border-input bg-background text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary text-sm transition-all disabled:opacity-60 disabled:cursor-not-allowed"
                required
              />
            </div>

            {otpSent && (
              <div className="flex items-center justify-between -mt-1 px-1">
                <span className="text-[11px] text-muted-foreground">🔒 OTP sent to this email — locked</span>
                <button type="button" onClick={handleChangeEmail} className="text-[11px] font-semibold text-primary hover:underline">
                  Change email
                </button>
              </div>
            )}

            {otpSent && (
              <div className="space-y-3 animate-slide-up">
                <div className="flex items-center justify-center gap-2 text-xs font-semibold text-muted-foreground">
                  <KeyRound className="h-3.5 w-3.5 text-primary" />
                  Enter the 6-digit OTP
                </div>
                <div className="relative" onClick={() => otpInputRef.current?.focus()}>
                  <input
                    ref={otpInputRef}
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    maxLength={6}
                    value={otp}
                    onChange={e => handleOtpChange(e.target.value)}
                    className="absolute inset-0 opacity-0 pointer-events-none"
                    aria-label="Enter 6-digit OTP"
                  />
                  <div className="absolute inset-0 rounded-2xl bg-gradient-to-r from-primary/20 via-secondary/20 to-cyan-400/20 blur-xl animate-pulse-slow pointer-events-none" />
                  <div className="relative grid grid-cols-6 gap-2 sm:gap-3">
                    {Array.from({ length: 6 }).map((_, index) => {
                      const digit = otp[index] ?? '';
                      const isFilled = Boolean(digit);
                      const isCurrent = index === otp.length;
                      return (
                        <div
                          key={index}
                          className={`h-12 sm:h-14 rounded-xl border-2 flex items-center justify-center text-lg sm:text-xl font-extrabold font-display tracking-tight transition-all duration-300 select-none ${
                            isFilled
                              ? 'border-primary/70 bg-gradient-to-br from-primary/90 to-secondary text-primary-foreground shadow-lg shadow-primary/30 scale-[1.03]'
                              : isCurrent
                                ? 'border-primary/60 bg-primary/5 text-primary ring-4 ring-primary/15'
                                : 'border-border/60 bg-muted/40 text-muted-foreground'
                          }`}
                        >
                          {digit || (isCurrent ? '|' : '')}
                        </div>
                      );
                    })}
                  </div>
                </div>
                <p className="text-[11px] text-center text-muted-foreground">Tip: You can paste the full OTP directly.</p>
              </div>
            )}

            {!otpSent ? (
              <button
                type="button"
                onClick={handleSendOtp}
                disabled={sendingOtp}
                className="w-full gradient-primary text-primary-foreground py-3.5 rounded-xl font-bold text-sm shadow-button hover:opacity-90 transition-all flex items-center justify-center gap-2 disabled:opacity-40"
              >
                {sendingOtp ? <Loader2 className="h-4 w-4 animate-spin" /> : <Mail className="h-4 w-4" />}
                {sendingOtp ? 'Sending OTP...' : 'Send OTP'}
              </button>
            ) : (
              <>
                <button
                  type="submit"
                  disabled={verifying}
                  className="w-full gradient-primary text-primary-foreground py-3.5 rounded-xl font-bold text-sm shadow-button hover:opacity-90 transition-all flex items-center justify-center gap-2 disabled:opacity-40"
                >
                  {verifying ? <Loader2 className="h-4 w-4 animate-spin" /> : <LogIn className="h-4 w-4" />}
                  {verifying ? 'Verifying...' : 'Verify OTP & Login'}
                </button>
                <button
                  type="button"
                  onClick={handleSendOtp}
                  disabled={sendingOtp || verifying || resendCooldown > 0}
                  className="w-full py-2.5 rounded-xl text-sm font-semibold text-muted-foreground hover:text-primary hover:bg-primary/5 transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  {resendCooldown > 0 ? `Resend OTP in ${resendCooldown}s` : sendingOtp ? 'Resending OTP...' : 'Resend OTP'}
                </button>
              </>
            )}
          </form>

          <div className="px-8 pb-8">
            <div className="bg-muted/50 rounded-xl p-4 border border-border/30">
              <p className="text-xs text-muted-foreground text-center">
                Only emails registered as an authority by the admin can sign in. Login is via OTP — no password needed.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default AuthorityLogin;
