import { useNavigate } from 'react-router-dom';
import { GraduationCap, Shield, ArrowRight, Wrench, CheckCircle2, Clock, TrendingUp, Bell, MapPin, Zap } from 'lucide-react';

const features = [
  {
    icon: Wrench,
    color: 'text-blue-500',
    bg: 'bg-blue-500/10',
    title: 'Report Issues',
    desc: 'Submit infrastructure complaints with photos in seconds.',
  },
  {
    icon: Clock,
    color: 'text-amber-500',
    bg: 'bg-amber-500/10',
    title: 'Track Progress',
    desc: 'Real-time status updates on every complaint you raise.',
  },
  {
    icon: CheckCircle2,
    color: 'text-emerald-500',
    bg: 'bg-emerald-500/10',
    title: 'Get Resolved',
    desc: 'Issues are assigned and resolved by campus management.',
  },
  {
    icon: Bell,
    color: 'text-purple-500',
    bg: 'bg-purple-500/10',
    title: 'Stay Updated',
    desc: 'Know when your complaint moves through each stage.',
  },
  {
    icon: MapPin,
    color: 'text-red-500',
    bg: 'bg-red-500/10',
    title: 'Pin Locations',
    desc: 'Specify building, floor and room for precise resolution.',
  },
  {
    icon: TrendingUp,
    color: 'text-cyan-500',
    bg: 'bg-cyan-500/10',
    title: 'View Analytics',
    desc: 'See resolution rates and recurring issues at a glance.',
  },
];

const WelcomePage = () => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-background relative overflow-hidden">
      {/* Background blobs */}
      <div className="absolute top-[-160px] left-[-160px] w-[500px] h-[500px] rounded-full bg-primary/8 blur-3xl pointer-events-none" />
      <div className="absolute bottom-[-120px] right-[-120px] w-[440px] h-[440px] rounded-full bg-secondary/8 blur-3xl pointer-events-none" />
      <div className="absolute top-1/3 right-1/4 w-[300px] h-[300px] rounded-full bg-cyan-500/5 blur-[80px] pointer-events-none" />

      {/* Top bar — admin link lives here, very minimal */}
      <div className="relative z-20 flex items-center justify-between px-6 sm:px-10 pt-5">
        <div className="flex items-center gap-3">
          <img src="/assets/UEM_LOGO.png" alt="UEM" className="h-9 w-9 object-contain drop-shadow-sm" />
          <img src="/assets/IEM.png" alt="IEM" className="h-9 w-9 object-contain drop-shadow-sm" />
          <span className="text-sm font-bold font-display text-gradient hidden sm:block">CampusFix</span>
        </div>
        <div className="flex items-center gap-1">
          <button
            onClick={() => navigate('/authority-login')}
            className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5 rounded-lg hover:bg-muted/60"
          >
            <Wrench className="h-3.5 w-3.5" />
            Authority Login
          </button>
          <button
            onClick={() => navigate('/manager-login')}
            className="flex items-center gap-1.5 text-xs font-medium text-muted-foreground hover:text-foreground transition-colors px-3 py-1.5 rounded-lg hover:bg-muted/60"
          >
            <Shield className="h-3.5 w-3.5" />
            Admin Login
          </button>
        </div>
      </div>

      {/* Hero */}
      <div className="relative z-10 flex flex-col items-center text-center px-4 pt-16 pb-10 max-w-4xl mx-auto">
        <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full bg-primary/10 text-primary text-xs font-bold tracking-widest uppercase mb-6 border border-primary/20">
          <Zap className="h-3.5 w-3.5" />
          Smart Campus Platform
        </div>

        <h1 className="text-4xl sm:text-5xl md:text-6xl font-extrabold font-display text-gradient leading-tight mb-5">
          Campus Infrastructure
          <br />
          Made&nbsp;Accountable
        </h1>

        <p className="text-muted-foreground text-base sm:text-lg max-w-xl mx-auto mb-10 leading-relaxed">
          Report broken lights, leaky taps, faulty furniture and more — right from your phone.
          The right team gets notified instantly.
        </p>

        {/* Primary CTA */}
        <button
          onClick={() => navigate('/student-login')}
          className="group relative inline-flex items-center gap-3 gradient-primary text-primary-foreground px-10 py-4 rounded-2xl text-base font-bold shadow-button hover:opacity-90 hover:shadow-lg hover:-translate-y-0.5 transition-all duration-300 mb-4"
        >
          <GraduationCap className="h-5 w-5" />
          Student Login
          <ArrowRight className="h-5 w-5 group-hover:translate-x-1 transition-transform" />
        </button>

        <p className="text-xs text-muted-foreground">
          Use your <span className="font-semibold text-foreground/70">@uem.edu.in</span> or <span className="font-semibold text-foreground/70">@iem.edu.in</span> email · OTP verification
        </p>
      </div>

      {/* Feature grid */}
      <div className="relative z-10 max-w-5xl mx-auto px-4 pb-16">
        <p className="text-center text-xs font-bold tracking-widest uppercase text-muted-foreground mb-8">
          Everything you need
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {features.map((f, i) => (
            <div
              key={f.title}
              className="group bg-card/70 backdrop-blur-sm border border-border/40 rounded-2xl p-5 shadow-card hover:shadow-card-hover hover:-translate-y-0.5 transition-all duration-300 animate-slide-up"
              style={{ animationDelay: `${i * 60}ms` }}
            >
              <div className={`w-10 h-10 rounded-xl ${f.bg} flex items-center justify-center mb-3 group-hover:scale-110 transition-transform duration-300`}>
                <f.icon className={`h-5 w-5 ${f.color}`} />
              </div>
              <h3 className="text-sm font-bold text-foreground mb-1">{f.title}</h3>
              <p className="text-xs text-muted-foreground leading-relaxed">{f.desc}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Footer */}
      <div className="relative z-10 text-center pb-8 px-4 space-y-1">
        <p className="text-xs text-muted-foreground/50">
          © 2026 University of Engineering &amp; Management · CampusFix
        </p>
        <p className="text-xs text-muted-foreground/40">
          Developed at CSE AI IEDC Lab by{' '}
          <a href="https://www.linkedin.com/in/mdasif2003/" target="_blank" rel="noopener noreferrer" className="underline underline-offset-2 hover:text-muted-foreground transition-colors">MD Asif</a>,{' '}
          <a href="https://www.linkedin.com/in/pratyaychatterjee/" target="_blank" rel="noopener noreferrer" className="underline underline-offset-2 hover:text-muted-foreground transition-colors">Pratyay Chatterjee</a> and{' '}
          <a href="https://www.linkedin.com/in/prakash-metla-921050253" target="_blank" rel="noopener noreferrer" className="underline underline-offset-2 hover:text-muted-foreground transition-colors">Prakash Metla</a>{' '}
          under the guidance of{' '}
          <a href="https://www.linkedin.com/in/sudipta-sahana-3843321a/" target="_blank" rel="noopener noreferrer" className="underline underline-offset-2 hover:text-muted-foreground transition-colors">Dr. Sudipta Sahana</a> and{' '}
          <a href="https://www.linkedin.com/in/susmitamukherjee-environmentalist/" target="_blank" rel="noopener noreferrer" className="underline underline-offset-2 hover:text-muted-foreground transition-colors">Dr. Susmita Mukherjee</a>
        </p>
      </div>
    </div>
  );
};

export default WelcomePage;
