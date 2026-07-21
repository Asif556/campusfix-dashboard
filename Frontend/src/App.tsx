import { Toaster } from "@/components/ui/toaster";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import StudentDashboard from "./pages/StudentDashboard";
import ReportComplaint from "./pages/ReportComplaint";
import TrackComplaints from "./pages/TrackComplaints";
import ComplaintDetails from "./pages/ComplaintDetails";
import AdminDashboard from "./pages/AdminDashboard";
import WelcomePage from "./pages/WelcomePage";
import StudentLogin from "./pages/StudentLogin";
import StudentRegister from "./pages/StudentRegister";
import ManagerLogin from "./pages/ManagerLogin";
import AuthorityLogin from "./pages/AuthorityLogin";
import AuthorityDashboard from "./pages/AuthorityDashboard";
import AppLayout from "./layout/AppLayout";
import NotFound from "./pages/NotFound";

const queryClient = new QueryClient();

const ADMIN_SESSION_KEY = 'admin_session';
const AUTHORITY_SESSION_KEY = 'authority_session';

// A role session is a localStorage key holding an expiry timestamp (ms).
const hasActiveSession = (key: string) => {
  const session = localStorage.getItem(key);
  if (!session) return false;
  const expiry = Number(session);
  if (Number.isNaN(expiry) || Date.now() >= expiry) {
    localStorage.removeItem(key);
    return false;
  }
  return true;
};

const hasActiveAdminSession = () => hasActiveSession(ADMIN_SESSION_KEY);
const hasActiveAuthoritySession = () => hasActiveSession(AUTHORITY_SESSION_KEY);

// Student-only routes: other roles get redirected to their home
const RequireStudent = ({ children }: { children: React.ReactNode }) => {
  if (hasActiveAdminSession()) return <Navigate to="/admin" replace />;
  if (hasActiveAuthoritySession()) return <Navigate to="/authority" replace />;
  if (!localStorage.getItem('student_user')) return <Navigate to="/welcome" replace />;
  return <>{children}</>;
};

// Admin-only routes: non-admins get redirected to /manager-login
const RequireAdmin = ({ children }: { children: React.ReactNode }) => {
  if (!hasActiveAdminSession()) return <Navigate to="/manager-login" replace />;
  return <>{children}</>;
};

// Authority-only routes: non-authorities get redirected to /authority-login
const RequireAuthority = ({ children }: { children: React.ReactNode }) => {
  if (!hasActiveAuthoritySession()) return <Navigate to="/authority-login" replace />;
  return <>{children}</>;
};

// Shared routes accessible by any signed-in role (e.g. complaint detail)
const RequireAnyAuth = ({ children }: { children: React.ReactNode }) => {
  if (!hasActiveAdminSession() && !hasActiveAuthoritySession() && !localStorage.getItem('student_user'))
    return <Navigate to="/welcome" replace />;
  return <>{children}</>;
};

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Toaster />
      <Sonner />
      <BrowserRouter>
        <Routes>
          {/* Public auth routes (no navbar) */}
          <Route path="/welcome" element={<WelcomePage />} />
          <Route path="/student-login" element={<StudentLogin />} />
          <Route path="/student-register" element={<StudentRegister />} />
          <Route path="/manager-login" element={<ManagerLogin />} />
          <Route path="/authority-login" element={<AuthorityLogin />} />

          {/* App routes (with navbar) */}
          <Route element={<AppLayout />}>
            {/* Student-only routes */}
            <Route path="/" element={<RequireStudent><StudentDashboard /></RequireStudent>} />
            <Route path="/report" element={<RequireStudent><ReportComplaint /></RequireStudent>} />
            <Route path="/track" element={<RequireStudent><TrackComplaints /></RequireStudent>} />
            <Route path="/complaints/:id" element={<RequireAnyAuth><ComplaintDetails /></RequireAnyAuth>} />

            {/* Admin-only route */}
            <Route path="/admin" element={<RequireAdmin><AdminDashboard /></RequireAdmin>} />

            {/* Authority-only route */}
            <Route path="/authority" element={<RequireAuthority><AuthorityDashboard /></RequireAuthority>} />
          </Route>

          <Route path="*" element={<NotFound />} />
        </Routes>
      </BrowserRouter>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
