// ─────────────────────────────────────────────────────────────────────────────
// AJOUTS À shared.jsx — coller à la fin du fichier existant
// ─────────────────────────────────────────────────────────────────────────────

// ── Skeleton card (h-32, animate-pulse) ──────────────────────────────────────
export const SkeletonCard = ({ className = '' }) => (
  <div
    className={`animate-pulse h-32 rounded-2xl bg-slate-200 dark:bg-slate-800 ${className}`}
  />
);

// ── Skeleton chart (h-64, animate-pulse) ─────────────────────────────────────
export const SkeletonChart = ({ className = '' }) => (
  <div
    className={`animate-pulse h-64 rounded-2xl bg-slate-200 dark:bg-slate-800 ${className}`}
  />
);

// ── RelativeTime — fonction pure, retourne "il y a Xmin/h/j" en français ─────
// Exemple : RelativeTime('2024-06-01T10:00:00Z') → "il y a 2h"
export const RelativeTime = (dateString) => {
  if (!dateString) return '—';
  const diff = Date.now() - new Date(dateString).getTime();
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60)  return 'à l\'instant';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60)  return `il y a ${minutes}min`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24)    return `il y a ${hours}h`;
  const days = Math.floor(hours / 24);
  if (days === 1)    return 'hier';
  if (days < 7)      return `il y a ${days}j`;
  return new Date(dateString).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' });
};
