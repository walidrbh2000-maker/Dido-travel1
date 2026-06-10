<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

/**
 * Stocke les tokens FCM par utilisateur et par appareil.
 * Plusieurs appareils par utilisateur sont supportés.
 */
class DeviceToken extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'token',
        'platform',   // 'android' | 'ios' | 'web'
        'device_id',  // identifiant unique de l'appareil (facultatif)
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Enregistre ou met à jour un token pour un utilisateur donné.
     * Évite les doublons en utilisant (user_id, token) comme clé unique.
     */
    public static function upsertToken(int $userId, string $token, string $platform = 'android', ?string $deviceId = null): static
    {
        return static::updateOrCreate(
            ['user_id' => $userId, 'token' => $token],
            ['platform' => $platform, 'device_id' => $deviceId, 'updated_at' => now()]
        );
    }

    /**
     * Supprime un token (déconnexion / désinscription).
     */
    public static function removeToken(int $userId, string $token): int
    {
        return static::where('user_id', $userId)
            ->where('token', $token)
            ->delete();
    }

    /**
     * Retourne tous les tokens valides d'un utilisateur.
     */
    public static function tokensForUser(int $userId): array
    {
        return static::where('user_id', $userId)
            ->pluck('token')
            ->toArray();
    }
}
