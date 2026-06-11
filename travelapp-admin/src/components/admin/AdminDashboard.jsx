/**
 * AdminDashboard.jsx
 * Dashboard analytique avancé — Agence de voyage algérienne.
 * Sections : KPI · Revenus mensuels · Statuts réservations · Top destinations
 *            · Vols · Performance hôtels · Activité récente
 */

import React, { useState, useEffect, useMemo, useCallback } from 'react';
import {
  RefreshCw, TrendingUp, TrendingDown, Plane, Users,
  Hotel, Compass, BadgeDollarSign, BarChart2, Clock,
} from 'lucide-react';
import adminAPI from '../../services/adminAPI.js';
import { useAdmin } from '../../AdminContext.jsx';
import { SkeletonCard, SkeletonChart, RelativeTime } from './shared.jsx';

// ── Constantes ────────────────────────────────────────────────────────────────

// Capacité estimée par classe de cabine
const CAPACITY = { economique: 186, affaires: 42, premiere: 12 };

const STATUT_RES_CFG = {
  en_attente: { label: 'En attente', color: '#f59e0b', tw: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400' },
  confirmee:  { label: 'Confirmée',  color: '#3b82f6', tw: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' },
  payee:      { label: 'Payée',      color: '#10b981', tw: 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400' },
  annulee:    { label: 'Annulée',    color: '#ef4444', tw: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400' },
};

const STATUT_VOL_CFG = {
  programme:  { label: 'Programmé', color: '#3b82f6' },
  en_vol:     { label: 'En vol',    color: '#10b981' },
  atterri:    { label: 'Atterri',   color: '#64748b' },
  annule:     { label: 'Annulé',    color: '#ef4444' },
};

const CLASSE_CFG = {
  economique: { label: 'Économique', tw: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300' },
  affaires:   { label: 'Affaires',   tw: 'bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400' },
  premiere:   { label: 'Première',   tw: 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400' },
};

// ── Helpers ───────────────────────────────────────────────────────────────────

const fmt = (n) => Number(n || 0).toLocaleString('fr-DZ');
const fmtDZD = (n) => `${fmt(n)} DZD`;
const fmtDate = (d) => new Date(d).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });

// Arrondi "propre" pour l'axe Y des graphiques
const niceMax = (val) => {
  if (!val || val <= 0) return 1_000_000;
  const mag = Math.pow(10, Math.floor(Math.log10(val)));
  return Math.ceil(val / mag) * mag;
};

// Filtre par mois relatif (0 = mois courant, -1 = mois précédent)
const inRelativeMonth = (dateStr, delta) => {
  if (!dateStr) return false;
  const d = new Date(dateStr);
  const ref = new Date();
  ref.setMonth(ref.getMonth() + delta);
  return d.getFullYear() === ref.getFullYear() && d.getMonth() === ref.getMonth();
};

// Variation en % entre deux valeurs
const variation = (curr, prev) =>
  prev > 0 ? ((curr - prev) / prev) * 100 : null;

// ── Composants utilitaires ────────────────────────────────────────────────────

const SectionError = ({ msg }) =>
  msg ? (
    <div className="text-xs text-red-500 dark:text-red-400 bg-red-50 dark:bg-red-900/20 rounded-xl px-3 py-2">
      ⚠ {msg}
    </div>
  ) : null;

const SectionHeader = ({ title, subtitle }) => (
  <div className="mb-4">
    <h2 className="font-semibold text-slate-800 dark:text-white text-sm">{title}</h2>
    {subtitle && <p className="text-xs text-slate-400 mt-0.5">{subtitle}</p>}
  </div>
);

const StatusBadge = ({ statut, map = STATUT_RES_CFG }) => {
  const cfg = map[statut] ?? { label: statut, tw: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300' };
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${cfg.tw}`}>
      {cfg.label}
    </span>
  );
};

// ── Section A — KPI Card ──────────────────────────────────────────────────────

const KPICard = ({ label, value, sub, icon: Icon, gradient, delta, loading }) => {
  const isUp = delta !== null && delta >= 0;
  return (
    <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-5 flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${gradient}`}>
          <Icon className="w-5 h-5 text-white" />
        </div>
        {delta !== null && !loading && (
          <span className={`flex items-center gap-1 text-xs font-medium ${isUp ? 'text-emerald-500' : 'text-red-500'}`}>
            {isUp ? <TrendingUp className="w-3 h-3" /> : <TrendingDown className="w-3 h-3" />}
            {Math.abs(delta).toFixed(1)}%
          </span>
        )}
      </div>
      {loading ? (
        <div className="space-y-2">
          <div className="h-7 w-28 bg-slate-200 dark:bg-slate-700 rounded-lg animate-pulse" />
          <div className="h-3 w-20 bg-slate-200 dark:bg-slate-700 rounded animate-pulse" />
        </div>
      ) : (
        <div>
          <p className="text-2xl font-bold text-slate-800 dark:text-white leading-tight">{value}</p>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">{sub}</p>
        </div>
      )}
      <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">{label}</p>
    </div>
  );
};

// ── Section B — Graphique revenus mensuels (SVG natif) ───────────────────────

const RevenueChart = ({ months, loading }) => {
  const [tooltip, setTooltip] = useState(null);

  // Dimensions SVG
  const W = 860, H = 260;
  const PAD = { l: 72, r: 16, t: 16, b: 44 };
  const cW = W - PAD.l - PAD.r;   // largeur de la zone graphique
  const cH = H - PAD.t - PAD.b;   // hauteur de la zone graphique
  const groupW = cW / 12;
  const barW = Math.max(10, Math.min(20, groupW * 0.32));

  const maxVal = niceMax(Math.max(...months.flatMap((m) => [m.confirmed, m.cancelled]), 1));
  const scaleY = (v) => (v / maxVal) * cH;

  // 5 graduations axe Y
  const yTicks = Array.from({ length: 6 }, (_, i) => (maxVal / 5) * i);

  const fmtTick = (v) =>
    v >= 1_000_000 ? `${(v / 1_000_000).toFixed(0)}M` : v >= 1_000 ? `${(v / 1_000).toFixed(0)}k` : String(v);

  if (loading) return <SkeletonChart />;

  return (
    <div className="relative select-none">
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full" style={{ fontFamily: 'inherit' }}>
        {/* Fond zone graphique */}
        <rect x={PAD.l} y={PAD.t} width={cW} height={cH} fill="#0f172a" rx={4} />

        {/* Grille horizontale + labels axe Y */}
        {yTicks.map((tick, i) => {
          const y = PAD.t + cH - scaleY(tick);
          return (
            <g key={i}>
              <line
                x1={PAD.l} y1={y} x2={PAD.l + cW} y2={y}
                stroke={i === 0 ? '#334155' : '#1e2d3d'}
                strokeWidth={i === 0 ? 1 : 0.5}
                strokeDasharray={i === 0 ? undefined : '4 4'}
              />
              <text x={PAD.l - 6} y={y + 4} textAnchor="end" fontSize={9} fill="#475569">
                {fmtTick(tick)}
              </text>
            </g>
          );
        })}

        {/* Barres + labels axe X */}
        {months.map((m, i) => {
          const gx = PAD.l + i * groupW;
          const center = gx + groupW / 2;
          const b1x = center - barW - 2;
          const b2x = center + 2;
          const h1 = Math.max(scaleY(m.confirmed), 1);
          const h2 = Math.max(scaleY(m.cancelled), 1);
          const y1 = PAD.t + cH - h1;
          const y2 = PAD.t + cH - h2;

          return (
            <g key={i}>
              {/* Confirmés + payés — bleu */}
              <rect
                x={b1x} y={y1} width={barW} height={h1} rx={2}
                fill="#3b82f6"
                className="cursor-pointer"
                style={{ transition: 'filter 0.15s' }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.filter = 'drop-shadow(0 0 6px #3b82f6)';
                  setTooltip({ x: center, y: Math.min(y1, y2) - 8, m, series: 'confirmed' });
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.filter = '';
                  setTooltip(null);
                }}
              />
              {/* Annulés — rouge pâle */}
              <rect
                x={b2x} y={y2} width={barW} height={h2} rx={2}
                fill="#f87171" opacity={0.65}
                className="cursor-pointer"
                style={{ transition: 'filter 0.15s' }}
                onMouseEnter={(e) => {
                  e.currentTarget.style.filter = 'drop-shadow(0 0 6px #f87171)';
                  setTooltip({ x: center, y: Math.min(y1, y2) - 8, m, series: 'cancelled' });
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.filter = '';
                  setTooltip(null);
                }}
              />
              {/* Label mois */}
              <text x={center} y={H - 10} textAnchor="middle" fontSize={9} fill="#64748b">
                {m.label}
              </text>
            </g>
          );
        })}

        {/* Tooltip SVG */}
        {tooltip && (() => {
          const tx = Math.min(Math.max(tooltip.x - 72, PAD.l + 4), W - 150);
          const ty = Math.max(tooltip.y - 46, PAD.t + 4);
          const val = tooltip.series === 'confirmed' ? tooltip.m.confirmed : tooltip.m.cancelled;
          const color = tooltip.series === 'confirmed' ? '#60a5fa' : '#f87171';
          return (
            <g>
              <rect x={tx} y={ty} width={144} height={42} rx={6} fill="#0f172a" stroke="#334155" strokeWidth={1} />
              <text x={tx + 72} y={ty + 15} textAnchor="middle" fontSize={9} fill="#94a3b8">
                {tooltip.m.label} — {tooltip.series === 'confirmed' ? 'Confirmés/Payés' : 'Annulés'}
              </text>
              <text x={tx + 72} y={ty + 30} textAnchor="middle" fontSize={11} fontWeight="bold" fill={color}>
                {fmtDZD(val)}
              </text>
            </g>
          );
        })()}
      </svg>

      {/* Légende */}
      <div className="flex items-center gap-5 mt-2 px-1">
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 rounded-sm bg-blue-500" />
          <span className="text-xs text-slate-500 dark:text-slate-400">Confirmés / Payés</span>
        </div>
        <div className="flex items-center gap-2">
          <div className="w-3 h-3 rounded-sm bg-red-400 opacity-65" />
          <span className="text-xs text-slate-500 dark:text-slate-400">Annulés</span>
        </div>
      </div>
    </div>
  );
};

// ── Section C — Donut réservations par statut (SVG natif, animation CSS) ─────

const StatusDonut = ({ dist, loading, animated }) => {
  const r = 68, cx = 90, cy = 90, sw = 26;
  const circumference = 2 * Math.PI * r;

  // Calcul des segments avec offset cumulé
  const total = dist.reduce((s, d) => s + d.count, 0);
  let cumulative = 0;
  const segments = dist.map((d) => {
    const segLen = total > 0 ? (d.count / total) * circumference : 0;
    const dashoffset = circumference - cumulative;
    cumulative += segLen;
    return { ...d, segLen: animated ? segLen : 0, dashoffset };
  });

  if (loading) return <SkeletonChart className="h-48" />;

  return (
    <div className="flex flex-col sm:flex-row items-center gap-6">
      <svg viewBox="0 0 180 180" className="w-44 h-44 flex-shrink-0">
        {/* Anneau de fond */}
        <circle cx={cx} cy={cy} r={r} fill="none" stroke="#1e293b" strokeWidth={sw} />
        {/* Segments — transition sur stroke-dasharray au montage */}
        {segments.map((seg, i) => (
          <circle
            key={seg.status}
            cx={cx} cy={cy} r={r}
            fill="none"
            stroke={(STATUT_RES_CFG[seg.status] ?? {}).color ?? '#64748b'}
            strokeWidth={sw}
            strokeDasharray={`${seg.segLen} ${circumference}`}
            strokeDashoffset={seg.dashoffset}
            transform={`rotate(-90, ${cx}, ${cy})`}
            style={{ transition: `stroke-dasharray 0.9s ease-out ${i * 0.12}s` }}
          />
        ))}
        {/* Total centré */}
        <text x={cx} y={cy - 7} textAnchor="middle" fontSize={22} fontWeight="bold" fill="white">{total}</text>
        <text x={cx} y={cy + 12} textAnchor="middle" fontSize={8.5} fill="#64748b">réservations</text>
      </svg>

      {/* Légende */}
      <div className="flex-1 space-y-3 w-full">
        {dist.map((d) => {
          const cfg = STATUT_RES_CFG[d.status] ?? {};
          return (
            <div key={d.status} className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-2 min-w-0">
                <div className="w-2.5 h-2.5 rounded-full flex-shrink-0" style={{ backgroundColor: cfg.color }} />
                <span className="text-sm text-slate-600 dark:text-slate-300 truncate">{cfg.label ?? d.status}</span>
              </div>
              <div className="flex items-center gap-2 flex-shrink-0">
                <span className="text-sm font-semibold text-slate-800 dark:text-white">{d.count}</span>
                <span className="text-xs text-slate-400 w-12 text-right">{d.pct.toFixed(1)}%</span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ── Section D — Top 5 destinations ───────────────────────────────────────────

const TopDestinations = ({ dests, maxCount, loading }) => {
  if (loading) return (
    <div className="space-y-3">
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="h-12 bg-slate-200 dark:bg-slate-800 rounded-xl animate-pulse" />
      ))}
    </div>
  );

  if (!dests.length) return <p className="text-sm text-slate-400">Aucune donnée disponible.</p>;

  return (
    <div className="space-y-3">
      {dests.map((d, i) => (
        <div key={d.id ?? i} className="flex items-center gap-3">
          {/* Rang */}
          <span className="w-5 text-xs font-bold text-slate-400 flex-shrink-0">{i + 1}</span>
          {/* Infos + barre */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 mb-1">
              <span className="text-sm font-semibold text-slate-800 dark:text-white truncate">{d.name}</span>
              <span className="text-xs text-slate-400 flex-shrink-0">{d.country}</span>
              {d.isPopular && (
                <span className="text-xs bg-orange-100 text-orange-600 dark:bg-orange-900/30 dark:text-orange-400 px-1.5 py-0.5 rounded-full flex-shrink-0">
                  🔥 Populaire
                </span>
              )}
            </div>
            {/* Barre de progression */}
            <div className="h-1.5 bg-slate-100 dark:bg-slate-800 rounded-full overflow-hidden">
              <div
                className="h-full bg-gradient-to-r from-blue-500 to-blue-400 rounded-full transition-all duration-700"
                style={{ width: `${maxCount > 0 ? (d.count / maxCount) * 100 : 0}%` }}
              />
            </div>
          </div>
          {/* Stats */}
          <div className="text-right flex-shrink-0">
            <p className="text-sm font-semibold text-slate-800 dark:text-white">{d.count}</p>
            <p className="text-xs text-slate-400">{fmtDZD(d.ca)}</p>
          </div>
        </div>
      ))}
    </div>
  );
};

// ── Section E — Vols ──────────────────────────────────────────────────────────

const VolsSection = ({ volsStatut, upcoming, loading }) => {
  if (loading) return <SkeletonChart className="h-56" />;

  const total = volsStatut.reduce((s, v) => s + v.count, 0);

  return (
    <div className="space-y-5">
      {/* Répartition statuts — barre horizontale empilée */}
      <div>
        <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">Statuts des vols</p>
        <div className="flex h-3 rounded-full overflow-hidden gap-px">
          {volsStatut.map((seg) => (
            <div
              key={seg.statut}
              title={`${seg.label} : ${seg.count}`}
              style={{
                width: `${total > 0 ? (seg.count / total) * 100 : 0}%`,
                backgroundColor: seg.color,
              }}
            />
          ))}
        </div>
        <div className="flex flex-wrap gap-x-4 gap-y-1 mt-2">
          {volsStatut.map((seg) => (
            <div key={seg.statut} className="flex items-center gap-1.5">
              <div className="w-2 h-2 rounded-full" style={{ backgroundColor: seg.color }} />
              <span className="text-xs text-slate-500 dark:text-slate-400">{seg.label} ({seg.count})</span>
            </div>
          ))}
        </div>
      </div>

      {/* Prochains départs */}
      <div>
        <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider mb-3">Prochains départs</p>
        {upcoming.length === 0 ? (
          <p className="text-sm text-slate-400">Aucun vol à venir.</p>
        ) : (
          <div className="space-y-2">
            {upcoming.map((vol) => {
              const classeCfg = CLASSE_CFG[vol.classe] ?? CLASSE_CFG.economique;
              return (
                <div
                  key={vol.id}
                  className="flex items-center gap-3 p-3 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-700"
                >
                  <Plane className="w-4 h-4 text-blue-500 flex-shrink-0" />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="text-sm font-mono font-semibold text-slate-800 dark:text-white">{vol.numero_vol}</span>
                      <span className={`text-xs px-1.5 py-0.5 rounded-full ${classeCfg.tw}`}>{classeCfg.label}</span>
                    </div>
                    <p className="text-xs text-slate-500 dark:text-slate-400 truncate">
                      {vol.ville_depart} → {vol.destination?.name ?? '—'} · {fmtDate(vol.date_depart)}
                    </p>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <p className="text-sm font-semibold text-slate-800 dark:text-white">{vol.places_disponibles}</p>
                    <p className="text-xs text-slate-400">places</p>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

// ── Section F — Performance hôtels ───────────────────────────────────────────

const HotelsPerf = ({ hotels, loading }) => {
  if (loading) return (
    <div className="space-y-3">
      {Array.from({ length: 5 }).map((_, i) => (
        <div key={i} className="h-16 bg-slate-200 dark:bg-slate-800 rounded-xl animate-pulse" />
      ))}
    </div>
  );
  if (!hotels.length) return <p className="text-sm text-slate-400">Aucune donnée.</p>;

  return (
    <div className="space-y-2">
      {hotels.map((h) => {
        const stars = Math.round(h.etoiles ?? 0);
        const destName = typeof h.destination === 'object'
          ? (h.destination?.name ?? '—')
          : (h.destination ?? '—');
        return (
          <div
            key={h.id}
            className="flex items-center gap-4 p-3 rounded-xl bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-700"
          >
            <Hotel className="w-4 h-4 text-violet-500 flex-shrink-0" />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="text-sm font-semibold text-slate-800 dark:text-white truncate">{h.nom}</span>
                <span className="text-xs text-amber-500 flex-shrink-0">{'★'.repeat(stars)}</span>
              </div>
              <p className="text-xs text-slate-400 truncate">{destName}</p>
            </div>
            <div className="text-right flex-shrink-0 space-y-0.5">
              <div className="flex items-center gap-1 justify-end">
                <span className="text-sm font-bold text-emerald-500">{h.note}</span>
                <span className="text-xs text-slate-400">/10</span>
              </div>
              <p className="text-xs text-slate-400">{h.nb_avis} avis</p>
              <p className="text-xs text-blue-500 font-medium">{fmtDZD(h.prix_nuit)}/nuit</p>
            </div>
          </div>
        );
      })}
    </div>
  );
};

// ── Section G — Activité récente ──────────────────────────────────────────────

const ActivityTimeline = ({ items, loading }) => {
  if (loading) return (
    <div className="space-y-3">
      {Array.from({ length: 8 }).map((_, i) => (
        <div key={i} className="h-14 bg-slate-200 dark:bg-slate-800 rounded-xl animate-pulse" />
      ))}
    </div>
  );
  if (!items.length) return <p className="text-sm text-slate-400">Aucune réservation récente.</p>;

  return (
    <div className="space-y-2">
      {items.map((r) => {
        const dest = r.vol?.destination?.name ?? r.hotel?.nom ?? '—';
        return (
          <div
            key={r.id}
            className="flex items-center gap-3 p-3 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors"
          >
            {/* Dot timeline */}
            <div className="w-2 h-2 rounded-full flex-shrink-0" style={{ backgroundColor: (STATUT_RES_CFG[r.statut] ?? {}).color ?? '#64748b' }} />
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <span className="font-mono text-xs font-semibold text-blue-500 dark:text-blue-400">{r.reference}</span>
                <StatusBadge statut={r.statut} />
              </div>
              <p className="text-xs text-slate-500 dark:text-slate-400 truncate mt-0.5">{dest}</p>
            </div>
            <div className="text-right flex-shrink-0">
              <p className="text-sm font-semibold text-slate-800 dark:text-white">{fmtDZD(r.prix_total)}</p>
              <p className="text-xs text-slate-400">{RelativeTime(r.created_at)}</p>
            </div>
          </div>
        );
      })}
    </div>
  );
};

// ── AdminDashboard — composant principal ──────────────────────────────────────

const AdminDashboard = () => {
  const { admin } = useAdmin();
  const [rawData, setRawData] = useState({ reservations: [], vols: [], hotels: [], destinations: [], guides: [] });
  const [sectionErrors, setSectionErrors] = useState({});
  const [loading, setLoading] = useState(true);
  const [refreshKey, setRefreshKey] = useState(0);
  const [animated, setAnimated] = useState(false); // déclenche animations au chargement

  const fetchAll = useCallback(async () => {
    setLoading(true);
    setAnimated(false);
    const [resR, volsR, hotelsR, destsR, guidesR] = await Promise.allSettled([
      adminAPI.getReservationsAll(),
      adminAPI.getVolsAll(),
      adminAPI.getHotels({ per_page: 200 }),
      adminAPI.getDestinations({ per_page: 100 }),
      adminAPI.getGuides({ per_page: 100 }),
    ]);

    const extract = (r) => r.status === 'fulfilled' ? (r.value?.data ?? []) : [];
    const err = (r) => r.status === 'rejected' ? (r.reason?.message ?? 'Erreur inconnue') : null;

    setRawData({
      reservations: extract(resR),
      vols: extract(volsR),
      hotels: extract(hotelsR),
      destinations: extract(destsR),
      guides: extract(guidesR),
    });
    setSectionErrors({
      reservations: err(resR),
      vols: err(volsR),
      hotels: err(hotelsR),
      destinations: err(destsR),
      guides: err(guidesR),
    });
    setLoading(false);
    // Léger délai pour que le SVG soit rendu avant de déclencher les animations
    setTimeout(() => setAnimated(true), 80);
  }, []);

  useEffect(() => { fetchAll(); }, [fetchAll, refreshKey]);

  // ── Tous les calculs dans un seul useMemo ─────────────────────────────────
  const computed = useMemo(() => {
    const { reservations, vols, hotels, destinations, guides } = rawData;
    const now = new Date();

    // ── KPI 1 : Chiffre d'affaires (réservations payées + confirmées)
    const paidStatuts = ['payee', 'confirmee'];
    const caTotal = reservations
      .filter((r) => paidStatuts.includes(r.statut))
      .reduce((s, r) => s + parseFloat(r.prix_total || 0), 0);
    const caThisMonth = reservations
      .filter((r) => paidStatuts.includes(r.statut) && inRelativeMonth(r.created_at, 0))
      .reduce((s, r) => s + parseFloat(r.prix_total || 0), 0);
    const caLastMonth = reservations
      .filter((r) => paidStatuts.includes(r.statut) && inRelativeMonth(r.created_at, -1))
      .reduce((s, r) => s + parseFloat(r.prix_total || 0), 0);

    // ── KPI 2 : Réservations ce mois
    const resThisMonth = reservations.filter((r) => inRelativeMonth(r.created_at, 0)).length;
    const resLastMonth = reservations.filter((r) => inRelativeMonth(r.created_at, -1)).length;

    // ── KPI 3 : Taux d'occupation moyen des vols
    const occupancies = vols.map((v) => {
      const cap = CAPACITY[v.classe] ?? 150;
      return 1 - Math.min(v.places_disponibles, cap) / cap;
    });
    const avgOccupancy = occupancies.length
      ? (occupancies.reduce((s, o) => s + o, 0) / occupancies.length) * 100
      : 0;

    // ── KPI 4 : Revenu moyen par réservation non annulée
    const nonCancelled = reservations.filter((r) => r.statut !== 'annulee').length;
    const avgRevenue = nonCancelled > 0 ? caTotal / nonCancelled : 0;
    const avgRevThisMonth = (() => {
      const nc = reservations.filter((r) => r.statut !== 'annulee' && inRelativeMonth(r.created_at, 0)).length;
      const ca = reservations
        .filter((r) => paidStatuts.includes(r.statut) && inRelativeMonth(r.created_at, 0))
        .reduce((s, r) => s + parseFloat(r.prix_total || 0), 0);
      return nc > 0 ? ca / nc : 0;
    })();
    const avgRevLastMonth = (() => {
      const nc = reservations.filter((r) => r.statut !== 'annulee' && inRelativeMonth(r.created_at, -1)).length;
      const ca = reservations
        .filter((r) => paidStatuts.includes(r.statut) && inRelativeMonth(r.created_at, -1))
        .reduce((s, r) => s + parseFloat(r.prix_total || 0), 0);
      return nc > 0 ? ca / nc : 0;
    })();

    // ── KPI 5 : Guides actifs
    const activeGuides = guides.filter((g) => g.disponible).length;

    // ── Section B : Revenus 12 derniers mois
    const monthlyRevenue = Array.from({ length: 12 }, (_, idx) => {
      const ref = new Date(now.getFullYear(), now.getMonth() - (11 - idx), 1);
      const label = ref.toLocaleDateString('fr-FR', { month: 'short' });
      const monthRes = reservations.filter((r) => {
        const d = new Date(r.created_at);
        return d.getFullYear() === ref.getFullYear() && d.getMonth() === ref.getMonth();
      });
      return {
        label,
        confirmed: monthRes.filter((r) => paidStatuts.includes(r.statut)).reduce((s, r) => s + parseFloat(r.prix_total || 0), 0),
        cancelled: monthRes.filter((r) => r.statut === 'annulee').reduce((s, r) => s + parseFloat(r.prix_total || 0), 0),
      };
    });

    // ── Section C : Répartition par statut
    const countByStatus = { en_attente: 0, confirmee: 0, payee: 0, annulee: 0 };
    reservations.forEach((r) => { if (r.statut in countByStatus) countByStatus[r.statut]++; });
    const total = reservations.length;
    const statusDist = Object.entries(countByStatus).map(([status, count]) => ({
      status, count, pct: total > 0 ? (count / total) * 100 : 0,
    }));

    // ── Section D : Top 5 destinations (par nb réservations)
    const destPopular = new Map(destinations.map((d) => [d.id, d.is_popular]));
    const destMap = {};
    reservations.forEach((r) => {
      const destId = r.vol?.destination_id ?? r.vol?.destination?.id;
      if (!destId) return;
      const name = r.vol?.destination?.name ?? `Destination ${destId}`;
      const country = r.vol?.destination?.country ?? '';
      if (!destMap[destId]) destMap[destId] = { id: destId, name, country, count: 0, ca: 0 };
      destMap[destId].count++;
      destMap[destId].ca += parseFloat(r.prix_total || 0);
    });
    const topDests = Object.values(destMap)
      .map((d) => ({ ...d, isPopular: destPopular.get(d.id) ?? false }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);
    const topDestsMax = topDests[0]?.count ?? 1;

    // ── Section E : Vols par statut + prochains départs
    const volsStatut = Object.entries(STATUT_VOL_CFG).map(([statut, cfg]) => ({
      statut, label: cfg.label, color: cfg.color,
      count: vols.filter((v) => v.statut === statut).length,
    }));
    const upcomingFlights = [...vols]
      .filter((v) => new Date(v.date_depart) > now)
      .sort((a, b) => new Date(a.date_depart) - new Date(b.date_depart))
      .slice(0, 5);

    // ── Section F : Top 5 hôtels (score = nb_avis * note)
    const topHotels = [...hotels]
      .sort((a, b) => (b.nb_avis * parseFloat(b.note || 0)) - (a.nb_avis * parseFloat(a.note || 0)))
      .slice(0, 5);

    // ── Section G : 8 dernières réservations (par created_at desc)
    const recentActivity = [...reservations]
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
      .slice(0, 8);

    return {
      kpis: [
        {
          label: 'Chiffre d\'affaires',
          value: fmtDZD(caTotal),
          sub: `Ce mois : ${fmtDZD(caThisMonth)}`,
          icon: BadgeDollarSign,
          gradient: 'bg-gradient-to-br from-blue-500 to-blue-700',
          delta: variation(caThisMonth, caLastMonth),
        },
        {
          label: 'Réservations ce mois',
          value: resThisMonth.toLocaleString('fr-DZ'),
          sub: `Mois précédent : ${resLastMonth}`,
          icon: BarChart2,
          gradient: 'bg-gradient-to-br from-violet-500 to-violet-700',
          delta: variation(resThisMonth, resLastMonth),
        },
        {
          label: 'Taux d\'occupation',
          value: `${avgOccupancy.toFixed(1)} %`,
          sub: `Sur ${vols.length} vols`,
          icon: Plane,
          gradient: 'bg-gradient-to-br from-sky-500 to-sky-700',
          delta: null,
        },
        {
          label: 'Revenu moy./réservation',
          value: fmtDZD(avgRevenue),
          sub: 'Hors annulations',
          icon: TrendingUp,
          gradient: 'bg-gradient-to-br from-emerald-500 to-emerald-700',
          delta: variation(avgRevThisMonth, avgRevLastMonth),
        },
        {
          label: 'Guides actifs',
          value: activeGuides.toLocaleString('fr-DZ'),
          sub: `Sur ${guides.length} guides`,
          icon: Compass,
          gradient: 'bg-gradient-to-br from-amber-500 to-amber-700',
          delta: null,
        },
      ],
      monthlyRevenue,
      statusDist,
      topDests,
      topDestsMax,
      volsStatut,
      upcomingFlights,
      topHotels,
      recentActivity,
    };
  }, [rawData]);

  const today = new Date().toLocaleDateString('fr-FR', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });

  return (
    <div className="p-6 md:p-8 space-y-8 max-w-7xl mx-auto">

      {/* ── En-tête ── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-800 dark:text-white">
            Tableau de bord analytique
          </h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1 capitalize">{today}</p>
        </div>
        <button
          onClick={() => setRefreshKey((k) => k + 1)}
          disabled={loading}
          className="self-start flex items-center gap-2 px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl hover:bg-slate-50 dark:hover:bg-slate-800 transition disabled:opacity-50"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          Actualiser
        </button>
      </div>

      {/* ── Section A — KPIs ── */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
        {computed.kpis.map((kpi) => (
          <KPICard key={kpi.label} {...kpi} loading={loading} />
        ))}
      </div>

      {/* ── Section B — Revenus mensuels ── */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6">
        <SectionHeader
          title="Revenus mensuels"
          subtitle="12 derniers mois — confirmés/payés vs annulés"
        />
        <SectionError msg={sectionErrors.reservations} />
        <RevenueChart months={computed.monthlyRevenue} loading={loading} />
      </div>

      {/* ── Sections C + D ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

        {/* Section C — Donut statuts */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6">
          <SectionHeader title="Réservations par statut" />
          <SectionError msg={sectionErrors.reservations} />
          <StatusDonut dist={computed.statusDist} loading={loading} animated={animated} />
        </div>

        {/* Section D — Top destinations */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6">
          <SectionHeader
            title="Top 5 destinations"
            subtitle="Classées par nombre de réservations"
          />
          <SectionError msg={sectionErrors.reservations} />
          <TopDestinations dests={computed.topDests} maxCount={computed.topDestsMax} loading={loading} />
        </div>
      </div>

      {/* ── Sections E + F ── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">

        {/* Section E — Vols */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6">
          <SectionHeader title="Vols" subtitle="Statuts & prochains départs" />
          <SectionError msg={sectionErrors.vols} />
          <VolsSection
            volsStatut={computed.volsStatut}
            upcoming={computed.upcomingFlights}
            loading={loading}
          />
        </div>

        {/* Section F — Hôtels */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6">
          <SectionHeader
            title="Performance hôtels"
            subtitle="Top 5 par score (note × avis)"
          />
          <SectionError msg={sectionErrors.hotels} />
          <HotelsPerf hotels={computed.topHotels} loading={loading} />
        </div>
      </div>

      {/* ── Section G — Activité récente ── */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-800 p-6">
        <SectionHeader title="Activité récente" subtitle="8 dernières réservations" />
        <SectionError msg={sectionErrors.reservations} />
        <ActivityTimeline items={computed.recentActivity} loading={loading} />
      </div>

    </div>
  );
};

export default AdminDashboard;
