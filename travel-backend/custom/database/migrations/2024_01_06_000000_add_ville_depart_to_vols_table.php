<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('vols', function (Blueprint $table) {
            // Ville (ou aéroport) de départ — 'Alger' par défaut
            // car toutes les routes existantes partent de la capitale.
            $table->string('ville_depart', 100)
                  ->default('Alger')
                  ->after('destination_id');
        });
    }

    public function down(): void
    {
        Schema::table('vols', function (Blueprint $table) {
            $table->dropColumn('ville_depart');
        });
    }
};
