<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('token', 512);
            $table->string('platform', 20)->default('android'); // android | ios | web
            $table->string('device_id', 255)->nullable();
            $table->timestamps();

            // Un utilisateur ne peut avoir le même token qu'une seule fois
            $table->unique(['user_id', 'token']);
            // Index pour les lookups par user_id
            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
    }
};
