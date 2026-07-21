import { cn } from '@/lib/utils';

interface StatusBadgeProps {
  status: string;
  className?: string;
}

const statusConfig: Record<string, { bg: string; text: string; dot: string; ring: string }> = {
  'Submitted': { bg: 'bg-status-submitted/10', text: 'text-status-submitted', dot: 'bg-status-submitted', ring: 'ring-status-submitted/20' },
  'Assigned': { bg: 'bg-status-assigned/10', text: 'text-status-assigned', dot: 'bg-status-assigned', ring: 'ring-status-assigned/20' },
  'In Progress': { bg: 'bg-status-progress/10', text: 'text-status-progress', dot: 'bg-status-progress animate-pulse', ring: 'ring-status-progress/20' },
  'Completed': { bg: 'bg-status-completed/10', text: 'text-status-completed', dot: 'bg-status-completed', ring: 'ring-status-completed/20' },
  'Pending Acceptance': { bg: 'bg-amber-500/10', text: 'text-amber-600', dot: 'bg-amber-500 animate-pulse', ring: 'ring-amber-500/20' },
  'Reopened': { bg: 'bg-red-500/10', text: 'text-red-600', dot: 'bg-red-500', ring: 'ring-red-500/20' },
  'Rejected': { bg: 'bg-rose-500/10', text: 'text-rose-600', dot: 'bg-rose-500', ring: 'ring-rose-500/20' },
};

const StatusBadge = ({ status, className }: StatusBadgeProps) => {
  const config = statusConfig[status] || statusConfig['Submitted'];

  return (
    <span className={cn(
      'inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-bold ring-1',
      config.bg, config.text, config.ring, className
    )}>
      <span className={cn('w-2 h-2 rounded-full', config.dot)} />
      {status}
    </span>
  );
};

export default StatusBadge;
