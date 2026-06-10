import 'package:dio/dio.dart';
import 'package:voyageur/core/network/api_client.dart';
import 'package:voyageur/core/network/api_endpoints.dart';

/// Remote datasource for guides.
///
/// All server-side filtering is expressed via [queryParameters] so that the
/// datasource stays thin and the caller (repository / use-case) owns the
/// query semantics.
class GuideRemoteDatasource {
  final ApiClient _apiClient;

  const GuideRemoteDatasource({required ApiClient apiClient})
      : _apiClient = apiClient;

  /// Fetch the paginated list of available guides.
  ///
  /// Supported [queryParameters]:
  ///   - `destination_id` (int)   — server-side filter; pass this whenever
  ///     the caller needs guides for a specific destination.
  ///   - `langue`         (String) — JSON-contains filter.
  ///   - `per_page`       (int)   — page size, default 15 on the server.
  Future<Response> getGuides({Map<String, dynamic>? queryParameters}) {
    return _apiClient.get(
      ApiEndpoints.guides,
      queryParameters: queryParameters,
    );
  }

  /// Fetch the detail of a single guide by [id].
  Future<Response> getGuideDetail(int id) {
    return _apiClient.get(ApiEndpoints.guideDetail(id));
  }
}
