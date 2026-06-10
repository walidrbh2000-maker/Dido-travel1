<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('vols', function (Blueprint $table) {
            // Escale (correspondance) — null = vol direct
            // Structure JSON :
            //   {
            //     "ville":              "Paris",
            //     "arrivee_escale":     "2025-06-10 10:45:00",
            //     "depart_escale":      "2025-06-10 12:45:00",
            //     "duree_transit_min":  120
            //   }
            $table->json('escale')
                  ->nullable()
                  ->after('ville_depart');
        });
    }

    public function down(): void
    {
        Schema::table('vols', function (Blueprint $table) {
            $table->dropColumn('escale');
        });
    }
};
