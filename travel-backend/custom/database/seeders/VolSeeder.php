<?php

namespace Database\Seeders;

use App\Models\Destination;
use App\Models\Vol;
use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

/**
 * ⚠️  PRÉREQUIS MIGRATION — avant d'exécuter ce seeder, la colonne `escale`
 *     doit exister dans la table `vols` :
 *
 *     Schema::table('vols', function (Blueprint $table) {
 *         $table->json('escale')->nullable()->after('ville_depart');
 *     });
 *
 * Génère trois catégories de vols :
 *   1. Domestiques  Alger → Ville  (DOMESTIC_ROUTES)
 *   2. Domestiques  Ville → Alger  (routes inverses, ville_depart = ville)
 *   3. Internationaux Alger → Destination (INTERNATIONAL_ROUTES)
 *
 * Les vols long-courriers définis dans ESCALE_MAP reçoivent automatiquement
 * un objet JSON `escale` contenant : ville, arrivee_escale, depart_escale,
 * duree_transit_min.
 */
class VolSeeder extends Seeder
{
    private const TOTAL_DAYS = 60;
    private const CHUNK_SIZE = 500;

    /** Compagnie → préfixe IATA */
    private const AIRLINES = [
        'Air Algérie'      => 'AH',
        'Tassili Airlines' => 'SF',
        'Air France'       => 'AF',
        'Royal Air Maroc'  => 'AT',
        'Emirates'         => 'EK',
        'Turkish Airlines' => 'TK',
        'Lufthansa'        => 'LH',
        'Transavia'        => 'TO',
        'Vueling'          => 'VY',
    ];

    /**
     * Routes domestiques — direction Alger → ville.
     * Format : [destination_name, durée_h, prix_min_DZD, prix_max_DZD, vols/jour]
     *
     * Les mêmes données sont réutilisées pour générer les routes inverses
     * (ville → Alger) avec ville_depart = destination_name.
     */
    private const DOMESTIC_ROUTES = [
        ['Oran',        1.0, 4_500,  12_000, 3],
        ['Constantine', 1.2, 5_000,  13_000, 3],
        ['Annaba',      1.5, 5_500,  14_000, 2],
        ['Tlemcen',     1.5, 5_000,  13_000, 2],
        ['Béjaïa',      1.0, 4_500,  11_000, 2],
        ['Sétif',       1.0, 4_500,  11_000, 2],
        ['Ghardaïa',    1.5, 6_000,  14_000, 2],
        ['Tamanrasset', 2.5, 9_000,  20_000, 1],
    ];

    /**
     * Routes internationales — toutes au départ d'Alger (ALG).
     * Format : [destination_name, durée_h, prix_min_DZD, prix_max_DZD, vols/jour]
     */
    private const INTERNATIONAL_ROUTES = [
        ['Paris',      3.5,  25_000,  65_000, 2],
        ['Marseille',  2.75, 20_000,  55_000, 2],
        ['Lyon',       3.0,  22_000,  58_000, 1],
        ['Londres',    4.0,  35_000,  85_000, 1],
        ['Madrid',     3.5,  28_000,  70_000, 1],
        ['Rome',       3.0,  25_000,  65_000, 1],
        ['Dubaï',      6.5,  45_000, 110_000, 1],
        ['Istanbul',   4.5,  32_000,  78_000, 1],
        ['Le Caire',   3.5,  28_000,  68_000, 1],
        ['Tunis',      1.5,  15_000,  40_000, 2],
        ['Casablanca', 2.5,  18_000,  48_000, 1],
        ['New York',  10.5,  85_000, 180_000, 1],
    ];

    /**
     * Escales pour les vols long-courriers (uniquement depuis Alger).
     *
     * Clé    : nom de la destination finale (= $route[0] dans INTERNATIONAL_ROUTES)
     * ville  : ville d'escale
     * transit_min : durée de l'escale en minutes
     * leg1_fraction : fraction du temps de vol pur avant l'escale
     *                 (ex. 0.333 → Alger→Paris ≈ 3.5h sur 10.5h de vol)
     *
     * La colonne `date_arrivee` enregistre l'arrivée FINALE (vol + escale).
     * Le JSON `escale` contient les horaires exacts de passage.
     */
    private const ESCALE_MAP = [
        // New York (10.5h de vol) → escale à Paris-CDG, transit 2h
        // Alger → Paris ≈ 3.5h (33 %), Paris → New York ≈ 7h
        'New York' => [
            'ville'         => 'Paris',
            'transit_min'   => 120,
            'leg1_fraction' => 0.333,
        ],
        // Dubaï (6.5h) → escale au Caire, transit 1h30
        // Alger → Le Caire ≈ 3h (46 %), Le Caire → Dubaï ≈ 3.5h
        'Dubaï' => [
            'ville'         => 'Le Caire',
            'transit_min'   => 90,
            'leg1_fraction' => 0.462,
        ],
    ];

    private const DEPARTURE_SLOTS = [
        '06:15', '07:30', '09:00', '10:45',
        '12:30', '14:15', '16:00', '17:45',
        '19:30', '21:00',
    ];

    // ── Point d'entrée ────────────────────────────────────────────────────────

    public function run(): void
    {
        if (Vol::count() > 0) {
            $this->command->warn('⚠️  Vols déjà présents — VolSeeder ignoré.');
            return;
        }

        $destinations  = Destination::all()->keyBy('name');
        $algerDest     = $destinations->get('Alger');

        if (! $algerDest) {
            $this->command->error('❌  Destination "Alger" introuvable — lancez d\'abord DestinationSeeder.');
            return;
        }

        $totalRoutes = count(self::DOMESTIC_ROUTES) * 2 // aller + retour
                     + count(self::INTERNATIONAL_ROUTES);

        $this->command->info(sprintf(
            '✈️  Génération des vols pour %d jours (%d routes)…',
            self::TOTAL_DAYS,
            $totalRoutes
        ));

        $now           = Carbon::now()->startOfDay();
        $chunk         = [];
        $totalInserted = 0;

        for ($day = 0; $day < self::TOTAL_DAYS; $day++) {
            $date = $now->copy()->addDays($day);

            // ── 1. Domestiques : Alger → ville ────────────────────────────
            foreach (self::DOMESTIC_ROUTES as $route) {
                $dest = $destinations->get($route[0]);
                if (! $dest) continue;

                for ($f = 0; $f < $route[4]; $f++) {
                    $chunk[] = $this->buildRow($dest->id, $date, $route, $f, 'Alger');
                }
            }

            // ── 2. Domestiques : ville → Alger (routes inverses) ──────────
            foreach (self::DOMESTIC_ROUTES as $route) {
                // Destination = Alger ; ville_depart = $route[0]
                for ($f = 0; $f < $route[4]; $f++) {
                    $chunk[] = $this->buildRow(
                        $algerDest->id,
                        $date,
                        $route,
                        $f,
                        $route[0] // ex. 'Oran'
                    );
                }
            }

            // ── 3. Internationaux : Alger → destination ───────────────────
            foreach (self::INTERNATIONAL_ROUTES as $route) {
                $dest = $destinations->get($route[0]);
                if (! $dest) continue;

                for ($f = 0; $f < $route[4]; $f++) {
                    $chunk[] = $this->buildRow($dest->id, $date, $route, $f, 'Alger');
                }
            }

            if (count($chunk) >= self::CHUNK_SIZE) {
                DB::table('vols')->insert($chunk);
                $totalInserted += count($chunk);
                $chunk = [];
                $this->command->line("   → {$totalInserted} vols insérés…");
            }
        }

        if (! empty($chunk)) {
            DB::table('vols')->insert($chunk);
            $totalInserted += count($chunk);
        }

        $this->command->info("✅  {$totalInserted} vols générés avec succès.");
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /**
     * Construit un enregistrement vol prêt pour l'insertion en masse.
     *
     * @param  int    $destId      ID de la destination finale
     * @param  Carbon $date        Jour de départ
     * @param  array  $route       [dest_name, durée_h, prix_min, prix_max, vols/j]
     * @param  int    $slotIdx     Index du créneau horaire
     * @param  string $villeDepart Ville d'embarquement (ex. 'Alger', 'Oran')
     */
    private function buildRow(
        int    $destId,
        Carbon $date,
        array  $route,
        int    $slotIdx,
        string $villeDepart = 'Alger'
    ): array {
        [, $durationHours, $minPrice, $maxPrice] = $route;

        // ── Calcul de l'escale (uniquement pour les vols au départ d'Alger) ──
        $routeDestName = $route[0];
        $escaleConfig  = ($villeDepart === 'Alger')
            ? (self::ESCALE_MAP[$routeDestName] ?? null)
            : null;

        $transitMin  = $escaleConfig ? $escaleConfig['transit_min'] : 0;
        $flightMin   = (int) round($durationHours * 60);
        $totalMin    = $flightMin + $transitMin; // vol pur + temps d'escale

        // ── Horaires ─────────────────────────────────────────────────────────
        $slot        = self::DEPARTURE_SLOTS[$slotIdx % count(self::DEPARTURE_SLOTS)];
        $departureAt = Carbon::parse($date->toDateString() . ' ' . $slot);
        $arrivalAt   = $departureAt->copy()->addMinutes($totalMin);

        // ── JSON escale ───────────────────────────────────────────────────────
        // arrivee_escale = départ + (fraction du vol pur avant l'escale)
        // depart_escale  = arrivee_escale + transit
        // Les deux timestamps sont en UTC (comme toutes les autres dates).
        $escaleJson = null;
        if ($escaleConfig !== null) {
            $leg1Min    = (int) round($flightMin * $escaleConfig['leg1_fraction']);
            $escArrivee = $departureAt->copy()->addMinutes($leg1Min);
            $escDepart  = $escArrivee->copy()->addMinutes($transitMin);

            $escaleJson = json_encode([
                'ville'             => $escaleConfig['ville'],
                'arrivee_escale'    => $escArrivee->format('Y-m-d H:i:s'),
                'depart_escale'     => $escDepart->format('Y-m-d H:i:s'),
                'duree_transit_min' => $transitMin,
            ], JSON_UNESCAPED_UNICODE);
        }

        // ── Compagnie & numéro de vol ─────────────────────────────────────────
        $airlineNames = array_keys(self::AIRLINES);
        $airlineName  = $airlineNames[array_rand($airlineNames)];
        $iata         = self::AIRLINES[$airlineName];

        // ── Tarif (modulé selon la classe) ────────────────────────────────────
        $classe    = $this->drawClasse();
        $basePrice = random_int($minPrice, $maxPrice);
        $prix      = round(match ($classe) {
            'affaires' => $basePrice * 2.2,
            'premiere' => $basePrice * 4.0,
            default    => (float) $basePrice,
        }, 2);

        $ts = now()->format('Y-m-d H:i:s');

        return [
            'compagnie'          => $airlineName,
            'numero_vol'         => $iata . random_int(100, 9999),
            'destination_id'     => $destId,
            'ville_depart'       => $villeDepart,
            'escale'             => $escaleJson,          // null ou JSON string
            'date_depart'        => $departureAt->format('Y-m-d H:i:s'),
            'date_arrivee'       => $arrivalAt->format('Y-m-d H:i:s'),
            'prix'               => $prix,
            'places_disponibles' => random_int(20, 220),
            'classe'             => $classe,
            'statut'             => 'programme',
            'created_at'         => $ts,
            'updated_at'         => $ts,
        ];
    }

    /** Tire aléatoirement une classe selon la distribution réelle du marché. */
    private function drawClasse(): string
    {
        $n = random_int(1, 100);
        return match (true) {
            $n <= 70 => 'economique',
            $n <= 92 => 'affaires',
            default  => 'premiere',
        };
    }
}