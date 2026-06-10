<?php

namespace Database\Seeders;

use App\Models\Destination;
use App\Models\Guide;
use Illuminate\Database\Seeder;

class GuideSeeder extends Seeder
{
    // ── Langues proposées par destination ────────────────────────────
    // Format : 'NomDestination' => ['Langue1', 'Langue2', ...]
    // FIX: tableaux PHP au lieu de chaînes — langues est une colonne JSON
    private const LANGUAGES_BY_DESTINATION = [
        'Oran'        => ['Arabe', 'Français', 'Tamazight'],
        'Constantine' => ['Arabe', 'Français'],
        'Annaba'      => ['Arabe', 'Français'],
        'Tlemcen'     => ['Arabe', 'Français', 'Espagnol'],
        'Béjaïa'      => ['Arabe', 'Français', 'Tamazight'],
        'Sétif'       => ['Arabe', 'Français'],
        'Ghardaïa'    => ['Arabe', 'Français', 'Mozabite'],
        'Tamanrasset' => ['Arabe', 'Français', 'Tamasheq'],
        'Paris'       => ['Français', 'Arabe', 'Anglais', 'Espagnol'],
        'Marseille'   => ['Français', 'Arabe', 'Anglais'],
        'Lyon'        => ['Français', 'Arabe', 'Anglais'],
        'Londres'     => ['Anglais', 'Français', 'Arabe'],
        'Madrid'      => ['Espagnol', 'Français', 'Arabe', 'Anglais'],
        'Rome'        => ['Italien', 'Français', 'Arabe', 'Anglais'],
        'Dubaï'       => ['Arabe', 'Anglais', 'Français'],
        'Istanbul'    => ['Turc', 'Arabe', 'Français', 'Anglais'],
        'Le Caire'    => ['Arabe', 'Français', 'Anglais'],
        'Tunis'       => ['Arabe', 'Français', 'Anglais'],
        'Casablanca'  => ['Arabe', 'Français', 'Espagnol', 'Anglais'],
        'New York'    => ['Anglais', 'Français', 'Arabe', 'Espagnol'],
    ];

    // ── Guides définis par destination ───────────────────────────────
    // FIX: format corrigé → [nom, tarif_jour, experience_annees, description]
    // Suppression de : specialite, note, nb_avis (colonnes inexistantes)
    private const GUIDES_BY_DESTINATION = [

        // ── Algérie ──────────────────────────────────────────────────
        'Oran' => [
            ['Karim Benali',    3800,  10, 'Guide certifié passionné par l\'histoire ottomane et espagnole d\'Oran, avec 10 ans d\'expérience.'],
            ['Yasmine Boudiaf', 3200,   7, 'Spécialiste de la culture oranaise, elle vous emmène à la découverte des saveurs et traditions locales.'],
            ['Mourad Fekhar',   4000,  12, 'Architecte de formation, il dévoile l\'âme méditerranéenne d\'Oran à travers ses bâtiments emblématiques.'],
        ],
        'Constantine' => [
            ['Nabil Laïb',      3500,  15, 'Expert des ponts et de l\'histoire numide de Constantine, auteur de plusieurs guides touristiques locaux.'],
            ['Sonia Mekideche', 3200,   9, 'Guide polyglotte spécialisée dans le patrimoine architectural et les traditions artisanales constantinoises.'],
            ['Hocine Amrani',   2800,   6, 'Connaisseur du plateau rocheux et des gorges du Rhummel, idéal pour les amateurs de paysages grandioses.'],
        ],
        'Annaba' => [
            ['Amel Daoudi',     3000,  12, 'Spécialiste des vestiges romains d\'Hippone et de la basilique Saint-Augustin, guide depuis 12 ans.'],
            ['Réda Bouchama',   2600,   5, 'Guide nature passionné par le littoral et le parc national d\'El Kala, il organise des circuits éco-touristiques.'],
        ],
        'Tlemcen' => [
            ['Fatima Bendjama', 3600,  18, 'Docteure en histoire islamique, spécialiste incontestée des mosquées et médersas de Tlemcen.'],
            ['Omar Medjber',    3400,  14, 'Passionné par l\'héritage andalou, il retrace l\'histoire des réfugiés maures à travers la ville.'],
            ['Hanane Bensaïd',  2900,   8, 'Guide et artisane, elle vous initie aux techniques traditionnelles du tapis tlemcénien et de la broderie.'],
        ],
        'Béjaïa' => [
            ['Djamel Aït Kaci', 3200,  11, 'Guide de montagne agréé, il connaît chaque sentier du Djurdjura et des gorges de la Soummam.'],
            ['Lydia Hamitouche',2800,   7, 'Guide francophone spécialisée dans l\'histoire berbère et phénicienne de la région de Béjaïa.'],
        ],
        'Sétif' => [
            ['Rachid Guerfi',   3000,  13, 'Archéologue passionné, guide attitré du musée et des ruines de Djemila, classées à l\'UNESCO.'],
            ['Amira Belloula',  2500,   4, 'Native des Hauts Plateaux, elle partage les traditions culinaires et festives de la région sétifienne.'],
        ],
        'Ghardaïa' => [
            ['Slimane Baba Ammi', 4200, 20, 'Guide mozabite de naissance, il vous plonge dans les secrets de l\'architecture et de la société ibadite.'],
            ['Naïma Benhaddou',   3600, 15, 'Spécialiste des souks et de l\'artisanat de la vallée du M\'Zab, classée au patrimoine mondial UNESCO.'],
            ['Youcef Athmani',    3900, 12, 'Guide saharien expérimenté, il organise des excursions dans les dunes et les palmeraies environnantes.'],
        ],
        'Tamanrasset' => [
            ['Ag Mahmoud',      5500,  25, 'Touareg de souche, guide inégalé pour les treks vers l\'Assekrem et les peintures rupestres du Hoggar.'],
            ['Moussa Kel Taher',5000,  18, 'Spécialiste des traversées sahariennes en 4×4, il connaît chaque piste du Tassili et de l\'Ahaggar.'],
            ['Fatouma Ag Alla', 4200,  10, 'Passionnée par la culture imohagh, elle partage chants, bijoux et traditions du peuple du désert.'],
        ],

        // ── France ───────────────────────────────────────────────────
        'Paris' => [
            ['Sophie Marchand', 18000,  12, 'Guide conférencière au Louvre et à Orsay, elle rend l\'art accessible à tous les voyageurs arabophones.'],
            ['Pierre Lefèvre',  16500,  20, 'Passionné de l\'histoire de Paris, il retrace 2000 ans de capitale à travers ses rues et monuments.'],
            ['Amira Chekroun',  15000,   8, 'Guide bilingue franco-arabophone, spécialisée dans les bonnes adresses parisiennes et le shopping de luxe.'],
        ],
        'Marseille' => [
            ['Jean-Claude Izzo',14500,  16, 'Guide passionné par Marseille et la Méditerranée, il vous fait découvrir les Calanques et le Vieux-Port.'],
            ['Samira Benali',   13000,   9, 'Franco-algérienne, elle vous guide à travers l\'histoire de la diaspora et les quartiers multiculturels.'],
        ],
        'Lyon' => [
            ['Marc Dupuis',     15500,  14, 'Expert en gastronomie lyonnaise, il vous emmène dans les bouchons authentiques et les marchés gourmands.'],
            ['Céline Faure',    14000,  11, 'Spécialiste des traboules et de la soierie lyonnaise, guide officielle de la vieille ville classée UNESCO.'],
        ],
        'Londres' => [
            ['James Thornton',  25000,  22, 'Historien de la famille royale britannique, guide attitré de Buckingham et de la Tour de Londres.'],
            ['Fatima Al-Hassan',22000,  10, 'Guide arabophone spécialisée, elle facilite le séjour des visiteurs du Golfe et du Maghreb à Londres.'],
        ],
        'Madrid' => [
            ['Carlos García',   18500,  17, 'Expert du Prado et du Reina Sofía, il dévoile les chefs-d\'œuvre espagnols en arabe et en français.'],
            ['Leila Benomar',   17000,   8, 'Guide franco-marocaine à Madrid depuis 8 ans, passionnée de flamenco et d\'architecture mudéjare.'],
        ],
        'Rome' => [
            ['Marco Ferretti',  19000,  20, 'Archéologue et guide, il ressuscite la Rome antique depuis le Forum jusqu\'aux Catacombes.'],
            ['Nadia Esposito',  17500,  13, 'Guide officiellement accréditée au Vatican, elle mène les visites en arabe et en français.'],
        ],
        'Dubaï' => [
            ['Ahmed Al-Rashidi',28000,  15, 'Guide local natif de Dubaï, il raconte la transformation du désert en mégapole en une génération.'],
            ['Sara Al-Mansoori',25000,  10, 'Spécialiste des souks d\'or, des centres commerciaux et des expériences VIP à Dubaï.'],
            ['Tariq Hussain',   30000,  12, 'Guide pour les safaris en 4×4, sandboarding et nuits sous les étoiles du désert de Dubaï.'],
        ],
        'Istanbul' => [
            ['Mehmet Yilmaz',   20000,  18, 'Historien turc et guide francophone, il retrace les splendeurs ottomanes de Topkapi à Sainte-Sophie.'],
            ['Nour Kaya',       18000,  11, 'Passionnée de cuisine et de négoce, elle guide à travers le Grand Bazar et les saveurs du Bosphore.'],
        ],
        'Le Caire' => [
            ['Hassan Ibrahim',  16000,  20, 'Égyptologue diplômé de l\'Université du Caire, guide officiel des pyramides et du Musée Égyptien.'],
            ['Mariam Saad',     14500,  13, 'Spécialiste du Caire fatimide, elle guide à travers les mosquées, les khans et les cimetières historiques.'],
        ],
        'Tunis' => [
            ['Amine Trabelsi',  12000,  16, 'Guide officiel de la médina de Tunis, classée UNESCO, passionné par l\'histoire aghlabide et hafside.'],
            ['Sarra Ben Amor',  11000,  10, 'Archéologue guide, spécialiste de Carthage et des musées nationaux tunisiens.'],
        ],
        'Casablanca' => [
            ['Youssef El Fassi',13500,  14, 'Architecte et guide, il décrypte le melting-pot architectural de Casablanca, de l\'art déco à Hassan II.'],
            ['Houda Alami',     12000,   9, 'Guide franco-marocaine, elle initie les visiteurs à la cuisine marocaine et aux artères historiques.'],
        ],
        'New York' => [
            ['Michael Carter',  38000,  18, 'New-Yorkais de naissance, il guide à travers Manhattan, Brooklyn et les grands monuments de la ville.'],
            ['Nadia Benkirane', 35000,  10, 'Guide arabophone à New York depuis 10 ans, spécialisée dans le shopping et les musées incontournables.'],
            ['James Rodriguez', 32000,  12, 'Passionné par les quartiers ethniques et la street-food new-yorkaise, il fait vivre la ville de l\'intérieur.'],
        ],
    ];

    public function run(): void
    {
        if (Guide::count() > 0) {
            $this->command->warn('⚠️  Guides déjà présents — GuideSeeder ignoré.');
            return;
        }

        $destinations = Destination::all()->keyBy('name');
        $inserted     = 0;

        foreach (self::GUIDES_BY_DESTINATION as $destName => $guides) {
            $destination = $destinations->get($destName);

            if (! $destination) {
                $this->command->warn("⚠️  Destination introuvable : {$destName} — guides ignorés.");
                continue;
            }

            // FIX: langues est déjà un tableau PHP → Laravel le sérialisera en JSON
            $langues = self::LANGUAGES_BY_DESTINATION[$destName] ?? ['Arabe', 'Français'];

            foreach ($guides as [$nom, $tarifJour, $experienceAnnees, $description]) {
                Guide::create([
                    'nom'               => $nom,
                    'destination_id'    => $destination->id,
                    // FIX: 'tarif_jour' (non 'prix_jour') — correspondance avec migration/model
                    'tarif_jour'        => $tarifJour,
                    // FIX: champ présent dans la migration, absent de l'ancien seeder
                    'experience_annees' => $experienceAnnees,
                    // FIX: tableau PHP — le cast 'array' du model gère la sérialisation JSON
                    'langues'           => $langues,
                    'description'       => $description,
                    'disponible'        => true,
                    'image'             => null,
                    // FIX: 'specialite', 'note', 'nb_avis' supprimés — colonnes inexistantes
                ]);

                $inserted++;
            }
        }

        $this->command->info("✅  {$inserted} guides générés avec succès.");
    }
}
