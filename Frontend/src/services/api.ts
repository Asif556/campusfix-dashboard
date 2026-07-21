import axios from 'axios';

export const API_BASE_URL = 'http://127.0.0.1:5000/campusfix/api';
//export const API_BASE_URL = 'https://server.uemcseaiml.org/campusfix/api';

// Origin of the API server (strip the "/campusfix/api" suffix) — used to build
// absolute URLs for static assets like uploaded photos.
export const API_ORIGIN = API_BASE_URL.replace(/\/campusfix\/api\/?$/, '');

/**
 * Resolve a stored complaint photo path to an absolute, loadable URL.
 * The backend stores paths like "/uploads/<name>" but serves them at
 * "<origin>/campusfix/uploads/<name>". Rendering the raw value as-is resolves
 * it against the frontend origin (404). This normalises both.
 */
export const resolvePhotoUrl = (photo?: string | null): string | null => {
  if (!photo) return null;
  if (/^https?:\/\//i.test(photo)) return photo; // already absolute
  const filename = photo.split('/').filter(Boolean).pop();
  if (!filename) return null;
  return `${API_ORIGIN}/campusfix/uploads/${filename}`;
};

const API = axios.create({
  //baseURL: '/api',
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// ── Auth ─────────────────────────────────────────────────────────────────
export const studentRegister = async (name: string, email: string, password: string) => {
  try {
    const res = await API.post('/auth/student-register', { name, email, password });
    return res.data;
  } catch (err) {
    if (axios.isAxiosError(err) && err.response?.data?.error) {
      throw new Error(err.response.data.error);
    }
    throw err;
  }
};

export const studentLogin = async (email: string, password: string) => {
  try {
    const res = await API.post('/auth/student-login', { email, password });
    return res.data;
  } catch (err) {
    if (axios.isAxiosError(err) && err.response?.data?.error) {
      throw new Error(err.response.data.error);
    }
    throw err;
  }
};

export const sendOtp = async (email: string) => {
  const res = await API.post('/auth/send-otp', { email });
  return res.data;
};

export const verifyOtp = async (email: string, otp: string) => {
  const res = await API.post('/auth/verify-otp', { email, otp });
  return res.data;
};

export const adminLogin = async (email: string, password: string) => {
  const res = await API.post('/auth/admin-login', { email, password });
  return res.data;
};

export const getDashboardStats = async (studentEmail?: string) => {
  const res = await API.get('/dashboard', { params: studentEmail ? { student_email: studentEmail } : {} });
  return res.data;
};

export const getComplaints = async (studentEmail?: string) => {
  const res = await API.get('/complaints', { params: studentEmail ? { student_email: studentEmail } : {} });
  return res.data;
};

export const getComplaintById = async (id: string) => {
  const res = await API.get(`/complaints/${id}`);
  return res.data;
};

export const createComplaint = async (data: FormData) => {
  const res = await API.post('/complaints', data, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return res.data;
};

export const getAdminComplaints = async () => {
  const res = await API.get('/admin/complaints');
  return res.data;
};

export const updateComplaintStatus = async (id: string, status: string, adminName?: string, adminEmail?: string) => {
  const res = await API.put(`/complaints/${id}/status`, {
    status,
    ...(adminName ? { admin_name: adminName } : {}),
    ...(adminEmail ? { admin_email: adminEmail } : {}),
  });
  return res.data;
};


export const getRecurringComplaints = async () => {
  const res = await API.get('/complaints/recurring');
  return res.data;
};

export const getAuthorities = async (category?: string) => {
  const res = await API.get('/authorities', { params: category ? { category } : {} });
  return res.data;
};

export const addAuthority = async (data: { name: string; email: string; phone: string; category: string }) => {
  const res = await API.post('/authorities', data);
  return res.data;
};

export const deleteAuthority = async (id: string) => {
  const res = await API.delete(`/authorities/${id}`);
  return res.data;
};

export const assignComplaint = async (complaintId: string, authorityId: string, adminName: string) => {
  const res = await API.post(`/complaints/${complaintId}/assign`, { authority_id: authorityId, admin_name: adminName });
  return res.data;
};

export const acceptFix = async (complaintId: string, feedback: string, studentName: string, studentEmail: string) => {
  const res = await API.post(`/complaints/${complaintId}/accept`, { feedback, student_name: studentName, student_email: studentEmail });
  return res.data;
};

export const reopenComplaint = async (complaintId: string, reason: string, studentName: string, studentEmail: string) => {
  const res = await API.post(`/complaints/${complaintId}/reopen`, { reason, student_name: studentName, student_email: studentEmail });
  return res.data;
};

export default API;
