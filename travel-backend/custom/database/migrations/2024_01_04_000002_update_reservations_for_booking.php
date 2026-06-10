<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            if (! Schema::hasColumn('reservations', 'type_trajet')) {
                $table->enum('type_trajet', ['aller_simple', 'aller_retour'])
                      ->default('aller_simple')
                      ->after('vol_id');
            }

            if (! Schema::hasColumn('reservations', 'vol_retour_id')) {
                $table->foreignId('vol_retour_id')
                      ->nullable()
                      ->after('type_trajet')
                      ->constrained('vols')
                      ->onDelete('set null');
            }

            if (! Schema::hasColumn('reservations', 'guide_id')) {
                $table->foreignId('guide_id')
                      ->nullable()
                      ->after('hotel_id')
                      ->constrained('guides')
                      ->onDelete('set null');
            }
        });
    }

    public function down(): void
    {
        Schema::table('reservations', function (Blueprint $table) {
            if (Schema::hasColumn('reservations', 'vol_retour_id')) {
                $table->dropForeign(['vol_retour_id']);
                $table->dropColumn('vol_retour_id');
            }

            if (Schema::hasColumn('reservations', 'guide_id')) {
                $table->dropForeign(['guide_id']);
                $table->dropColumn('guide_id');
            }

            if (Schema::hasColumn('reservations', 'type_trajet')) {
                $table->dropColumn('type_trajet');
            }
        });
    }
};
