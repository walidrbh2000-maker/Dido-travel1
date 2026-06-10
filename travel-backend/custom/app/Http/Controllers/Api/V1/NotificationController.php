<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AppNotification;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    // ─────────────────────────────────────────────────────────────────────────
    // Token FCM
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * POST /notifications/token
     * Enregistre ou met à jour le token FCM de l'appareil courant.
     */
    public function registerToken(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token'     => 'required|string|max:512',
            'platform'  => 'sometimes|in:android,ios,web',
            'device_id' => 'sometimes|nullable|string|max:255',
        ]);

        DeviceToken::upsertToken(
            userId:   auth()->id(),
            token:    $data['token'],
            platform: $data['platform'] ?? 'android',
            deviceId: $data['device_id'] ?? null,
        );

        return response()->json(['message' => 'Token enregistré']);
    }

    /**
     * DELETE /notifications/token
     * Supprime le token FCM (déconnexion / opt-out notifications).
     */
    public function removeToken(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => 'required|string|max:512',
        ]);

        DeviceToken::removeToken(auth()->id(), $data['token']);

        return response()->json(['message' => 'Token supprimé']);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Notifications in-app
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * GET /notifications
     * Liste paginée des notifications de l'utilisateur courant.
     */
    public function index(Request $request): JsonResponse
    {
        $notifications = AppNotification::forUser(auth()->id())
            ->orderBy('created_at', 'desc')
            ->paginate($request->integer('per_page', 20));

        return response()->json($notifications);
    }

    /**
     * GET /notifications/unread-count
     * Compte les notifications non lues (pour le badge Flutter).
     */
    public function unreadCount(): JsonResponse
    {
        $count = AppNotification::forUser(auth()->id())
            ->unread()
            ->count();

        return response()->json(['count' => $count]);
    }

    /**
     * PATCH /notifications/{notification}/read
     * Marque une notification comme lue.
     */
    public function markRead(AppNotification $notification): JsonResponse
    {
        $this->authorizeNotification($notification);
        $notification->markAsRead();

        return response()->json(['message' => 'Notification marquée comme lue']);
    }

    /**
     * POST /notifications/read-all
     * Marque toutes les notifications de l'utilisateur comme lues.
     */
    public function markAllRead(): JsonResponse
    {
        AppNotification::forUser(auth()->id())
            ->unread()
            ->update(['read_at' => now()]);

        return response()->json(['message' => 'Toutes les notifications marquées comme lues']);
    }

    /**
     * DELETE /notifications/{notification}
     * Supprime une notification.
     */
    public function destroy(AppNotification $notification): JsonResponse
    {
        $this->authorizeNotification($notification);
        $notification->delete();

        return response()->json(['message' => 'Notification supprimée']);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private function authorizeNotification(AppNotification $notification): void
    {
        if ($notification->user_id !== auth()->id()) {
            abort(403, 'Accès non autorisé');
        }
    }
}
