import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyageur/core/error/app_error.dart';
import 'package:voyageur/data/datasources/remote/payment_remote_datasource.dart';
import 'package:voyageur/data/repositories/payment_repository.dart';
import 'package:voyageur/domain/entities/payment_entity.dart';
import 'package:voyageur/domain/usecases/payment/process_payment_usecase.dart';
import 'package:voyageur/providers/auth/auth_provider.dart';
import 'package:voyageur/providers/reservation/reservation_provider.dart';

// ── Infrastructure providers ───────────────────────────────────────────────

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(
    remoteDatasource: PaymentRemoteDatasource(
      apiClient: ref.watch(apiClientProvider),
    ),
  );
});

final processPaymentUseCaseProvider = Provider<ProcessPaymentUsecase>((ref) {
  return ProcessPaymentUsecase(
    repository: ref.watch(paymentRepositoryProvider),
  );
});

// ── Payment notifier ───────────────────────────────────────────────────────

final paymentProvider =
    AsyncNotifierProvider<PaymentNotifier, PaymentEntity?>(
  PaymentNotifier.new,
);

class PaymentNotifier extends AsyncNotifier<PaymentEntity?> {
  @override
  FutureOr<PaymentEntity?> build() => null; // حالة أولية: لا يوجد دفع

  /// معالجة الدفع — النقطة الرئيسية للـ FIX Issue 3.
  ///
  /// الخطوات:
  ///   1. استدعاء API الدفع.
  ///   2. عند النجاح → تحديث حالة الحجز محلياً (optimistic).
  ///   3. ثم refresh من الخادم للتأكيد النهائي.
  ///   4. إرجاع [true] عند النجاح، [false] عند الفشل.
  Future<bool> processPayment({
    required int reservationId,
    required String methode,
    required String token,
  }) async {
    state = const AsyncLoading();

    final usecase = ref.read(processPaymentUseCaseProvider);
    final result = await usecase(
      reservationId: reservationId,
      methode: methode,
      token: token,
    );

    return result.fold(
      // ── Échec ──────────────────────────────────────────────────────────
      (AppError error) {
        state = AsyncError(
          Exception(_messageFromError(error)),
          StackTrace.current,
        );
        return false;
      },
      // ── Succès ─────────────────────────────────────────────────────────
      (PaymentEntity payment) {
        state = AsyncData(payment);

        // FIX Issue 3: Notify the reservations provider to update immediately.
        // This triggers both an optimistic local update AND a server refresh.
        ref
            .read(reservationsProvider.notifier)
            .afterPaymentSuccess(reservationId);

        return true;
      },
    );
  }

  /// Réinitialise l'état du provider (utile après navigation).
  void reset() => state = const AsyncData(null);

  static String _messageFromError(AppError error) => error.when(
        network: (m) => m,
        unauthorized: () => 'Non autorisé',
        notFound: (r) => 'Ressource introuvable : $r',
        serverError: (m) => m,
        validation: (e) => e.values.isNotEmpty
            ? e.values.first.first
            : 'Erreur de validation',
        unknown: (e) => e.toString(),
      );
}
