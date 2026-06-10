<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // BUG B FIX: élargir l'enum pour accepter les méthodes algériennes
        // locales (carte_doree, cib) et stripe en remplacement de 'carte'/'paypal'
        DB::statement(
            "ALTER TABLE payments 
             MODIFY COLUMN methode 
             ENUM('carte_doree','cib','virement','stripe','carte','paypal') 
             NOT NULL"
        );
    }

    public function down(): void
    {
        DB::statement(
            "ALTER TABLE payments 
             MODIFY COLUMN methode 
             ENUM('carte','paypal','virement') 
             NOT NULL"
        );
    }
};