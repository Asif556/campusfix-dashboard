import { useState, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Send, Upload, QrCode, MapPin, FileText, ChevronDown, X } from 'lucide-react';
import { createComplaint } from '@/services/api';
import { getStoredJSON } from '@/lib/storage';
import { toast } from 'sonner';

const categories = [
  { label: 'Electricity', emoji: '⚡' },
  { label: 'Furniture', emoji: '🪑' },
  { label: 'Water', emoji: '💧' },
  { label: 'Internet', emoji: '📡' },
  { label: 'Cleanliness', emoji: '🧹' },
  { label: 'Infrastructure', emoji: '🏗️' },
];

const ReportComplaint = () => {
  const navigate = useNavigate();
  const [form, setForm] = useState({ category: '', building: '', floor: '', room: '', description: '' });
  const [photo, setPhoto] = useState<File | null>(null);
  const [photoPreview, setPhotoPreview] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      const fd = new FormData();
      Object.entries(form).forEach(([k, v]) => fd.append(k, v));
      if (photo) fd.append('photo', photo);
      const user = getStoredJSON<{ email?: string }>('student_user') ?? {};
      if (user.email) fd.append('student_email', user.email);
      await createComplaint(fd);
      toast.success('Complaint submitted successfully!');
      navigate('/track');
    } catch {
      toast.error('Failed to submit complaint.');
    } finally {
      setLoading(false);
    }
  };

  const update = (field: string, value: string) => setForm(prev => ({ ...prev, [field]: value }));

  return (
    <div className="max-w-2xl mx-auto">
      {/* Header */}
      <div className="mb-8 animate-slide-up">
        <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-primary/10 text-primary text-xs font-semibold mb-3">
          <FileText className="h-3 w-3" />
          New Complaint
        </div>
        <h1 className="text-2xl font-bold font-display text-foreground">Report an Issue</h1>
        <p className="text-sm text-muted-foreground mt-1">Help us improve campus infrastructure by reporting problems</p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6 animate-slide-up" style={{ animationDelay: '100ms' }}>
        {/* Category Selection */}
        <div className="bg-card rounded-2xl shadow-card border border-border/40 p-6">
          <label className="block text-sm font-semibold text-foreground mb-3">Select Category</label>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
            {categories.map(c => (
              <button
                key={c.label}
                type="button"
                onClick={() => update('category', c.label)}
                className={`flex items-center gap-2.5 px-4 py-3 rounded-xl border-2 text-sm font-medium transition-all duration-200 ${
                  form.category === c.label
                    ? 'border-primary bg-primary/5 text-primary shadow-sm'
                    : 'border-border/40 text-muted-foreground hover:border-primary/30 hover:bg-muted/50'
                }`}
              >
                <span className="text-lg">{c.emoji}</span>
                {c.label}
              </button>
            ))}
          </div>
        </div>

        {/* Location */}
        <div className="bg-card rounded-2xl shadow-card border border-border/40 p-6">
          <div className="flex items-center gap-2 mb-4">
            <MapPin className="h-4 w-4 text-primary" />
            <label className="text-sm font-semibold text-foreground">Location Details</label>
          </div>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {[
              { field: 'building', label: 'Building', placeholder: 'e.g. B1,B2,B3' },
              { field: 'floor', label: 'Floor', placeholder: 'e.g. 2nd Floor' },
              { field: 'room', label: 'Room', placeholder: 'e.g. 2.1,2.2' },
            ].map(input => (
              <div key={input.field}>
                <label className="block text-xs font-medium text-muted-foreground mb-1.5">{input.label}</label>
                <input
                  type="text"
                  placeholder={input.placeholder}
                  value={form[input.field as keyof typeof form]}
                  onChange={(e) => update(input.field, e.target.value)}
                  className="w-full px-4 py-3 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary transition-all"
                  required
                />
              </div>
            ))}
          </div>
        </div>

        {/* Description */}
        <div className="bg-card rounded-2xl shadow-card border border-border/40 p-6">
          <label className="block text-sm font-semibold text-foreground mb-3">Describe the Issue</label>
          <textarea
            rows={4}
            placeholder="Please describe the issue in detail — what's broken, where exactly, and how it affects you..."
            value={form.description}
            onChange={(e) => update('description', e.target.value)}
            className="w-full px-4 py-3 rounded-xl border border-input bg-background text-foreground text-sm focus:outline-none focus:ring-2 focus:ring-ring/50 focus:border-primary resize-none transition-all leading-relaxed"
            required
          />
        </div>

        {/* Attachments */}
        <div className="space-y-3">
          <div className="flex flex-wrap gap-3">
            <input
              ref={fileInputRef}
              type="file"
              accept="image/png,image/jpeg,image/jpg,image/gif,image/webp"
              className="hidden"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) {
                  setPhoto(file);
                  setPhotoPreview(URL.createObjectURL(file));
                }
              }}
            />
            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              className="flex items-center gap-2 px-5 py-3 rounded-xl border-2 border-dashed border-border bg-card text-sm font-medium text-muted-foreground hover:border-primary/40 hover:text-primary hover:bg-primary/5 transition-all duration-200"
            >
              <Upload className="h-4 w-4" />
              {photo ? 'Change Photo' : 'Upload Photo'}
            </button>
            {/* <button
              type="button"
              className="flex items-center gap-2 px-5 py-3 rounded-xl border-2 border-dashed border-border bg-card text-sm font-medium text-muted-foreground hover:border-primary/40 hover:text-primary hover:bg-primary/5 transition-all duration-200"
            >
              <QrCode className="h-4 w-4" />
              Scan QR Code
            </button> */}
          </div>
          {photoPreview && (
            <div className="relative inline-block">
              <img src={photoPreview} alt="Preview" className="h-32 rounded-xl border border-border/40 object-cover" />
              <button
                type="button"
                onClick={() => { setPhoto(null); setPhotoPreview(null); if (fileInputRef.current) fileInputRef.current.value = ''; }}
                className="absolute -top-2 -right-2 p-1 rounded-full bg-destructive text-destructive-foreground shadow-sm hover:opacity-90 transition-opacity"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            </div>
          )}
        </div>

        {/* Submit */}
        <button
          type="submit"
          disabled={loading || !form.category}
          className="w-full gradient-primary text-primary-foreground py-4 rounded-2xl font-bold text-sm shadow-button hover:opacity-90 transition-all duration-200 flex items-center justify-center gap-2 disabled:opacity-40 disabled:cursor-not-allowed"
        >
          <Send className="h-4 w-4" />
          {loading ? 'Submitting...' : 'Submit Complaint'}
        </button>
      </form>
    </div>
  );
};

export default ReportComplaint;
