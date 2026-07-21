import { useState, useEffect } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { LayoutDashboard, FileWarning, ListChecks, Shield, Menu, X, Sun, Moon, LogOut } from 'lucide-react';
import { cn } from '@/lib/utils';
import { getStoredJSON } from '@/lib/storage';

const studentNavItems = [
  { label: 'Dashboard', path: '/', icon: LayoutDashboard },
  { label: 'Report Issue', path: '/report', icon: FileWarning },
  { label: 'Track', path: '/track', icon: ListChecks },
];

const adminNavItems = [
  { label: 'Admin', path: '/admin', icon: Shield },
];

const ADMIN_SESSION_KEY = 'admin_session';

const Navbar = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const [mobileOpen, setMobileOpen] = useState(false);
  const [dark, setDark] = useState(() => localStorage.getItem('theme') === 'dark');

  const studentUser = getStoredJSON<{ name?: string }>('student_user');
  const isAdminLoggedIn = (() => {
    const session = localStorage.getItem(ADMIN_SESSION_KEY);
    if (!session) return false;
    const expiry = Number(session);
    if (Number.isNaN(expiry) || Date.now() >= expiry) {
      localStorage.removeItem(ADMIN_SESSION_KEY);
      return false;
    }
    return true;
  })();

  // Admin takes full precedence — student tabs are completely hidden for admins
  const visibleNavItems = isAdminLoggedIn ? adminNavItems : studentNavItems;

  const handleLogout = () => {
    if (isAdminLoggedIn) {
      localStorage.removeItem(ADMIN_SESSION_KEY);
      localStorage.removeItem('admin_user');
    } else {
      localStorage.removeItem('student_user');
    }
    navigate('/welcome');
  };

  const adminUser = getStoredJSON<{ name?: string }>('admin_user');
  const displayName = isAdminLoggedIn ? (adminUser?.name ?? 'Admin') : studentUser?.name ?? '';

  useEffect(() => {
    document.documentElement.classList.toggle('dark', dark);
    localStorage.setItem('theme', dark ? 'dark' : 'light');
  }, [dark]);

  return (
    <header className="sticky top-0 z-50 glass border-b border-border/30">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link to={isAdminLoggedIn ? '/admin' : '/'} className="flex items-center gap-3 group">
            <div className="flex items-center gap-2">
              <img src="/assets/IEM.png" alt="IEM Logo" className="h-10 w-10 object-contain drop-shadow-sm" />
              <img src="/assets/UEM_LOGO.png" alt="UEM Logo" className="h-10 w-10 object-contain drop-shadow-sm" />
            </div>
            <div className="hidden sm:block">
              <span className="text-lg font-bold font-display text-gradient">CampusFix</span>
              <p className="text-[10px] text-muted-foreground leading-none -mt-0.5">Smart Complaint System</p>
            </div>
          </Link>

          {/* Desktop Nav */}
          <nav className="hidden md:flex items-center gap-1 bg-muted/50 rounded-2xl p-1">
            {visibleNavItems.map((item) => {
              const active = location.pathname === item.path;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  className={cn(
                    'flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all duration-200',
                    active
                      ? 'gradient-primary text-primary-foreground shadow-button'
                      : 'text-muted-foreground hover:text-foreground hover:bg-card'
                  )}
                >
                  <item.icon className="h-4 w-4" />
                  {item.label}
                </Link>
              );
            })}
          </nav>

          {/* Right side */}
          <div className="flex items-center gap-1">
            {displayName && (
              <div className="hidden sm:flex items-center gap-2 mr-1">
                <span className="text-xs font-medium text-muted-foreground">
                  Hi, {displayName}
                </span>
                <button
                  onClick={handleLogout}
                  className="p-2.5 rounded-xl text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
                  title="Logout"
                >
                  <LogOut className="h-4 w-4" />
                </button>
              </div>
            )}

            <button
              onClick={() => setDark(!dark)}
              className="p-2.5 rounded-xl text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
              title={dark ? 'Switch to light mode' : 'Switch to dark mode'}
            >
              {dark ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
            </button>

            <button
              onClick={() => setMobileOpen(!mobileOpen)}
              className="md:hidden p-2.5 rounded-xl text-muted-foreground hover:bg-muted transition-colors"
            >
              {mobileOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Nav */}
      {mobileOpen && (
        <div className="md:hidden border-t border-border/30 glass animate-slide-up">
          <div className="px-4 py-3 space-y-1">
            {visibleNavItems.map((item) => {
              const active = location.pathname === item.path;
              return (
                <Link
                  key={item.path}
                  to={item.path}
                  onClick={() => setMobileOpen(false)}
                  className={cn(
                    'flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all',
                    active
                      ? 'gradient-primary text-primary-foreground shadow-button'
                      : 'text-muted-foreground hover:bg-muted'
                  )}
                >
                  <item.icon className="h-4 w-4" />
                  {item.label}
                </Link>
              );
            })}
            {displayName && (
              <button
                onClick={handleLogout}
                className="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-destructive hover:bg-destructive/10 w-full transition-all"
              >
                <LogOut className="h-4 w-4" />
                Logout
              </button>
            )}
          </div>
        </div>
      )}
    </header>
  );
};

export default Navbar;
