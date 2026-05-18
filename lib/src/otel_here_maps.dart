// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_here_maps_suppression.dart';

const _tracerName = 'dartastic_otel_libs_here_maps';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class HereMapsResult {
  const HereMapsResult({
    this.itemCount,
    this.transportMode,
    this.tier,
    this.requestId,
    this.statusCode,
  });

  final int? itemCount;

  /// `car`, `truck`, `pedestrian`, `bicycle`, `taxi`, `scooter`,
  /// `privateBus`. Truck routing has its own SKU with restrictions.
  final String? transportMode;

  /// HERE pricing tier — `essentials` / `pro` / `enterprise`. Affects
  /// per-request rate and matrix-routing scope.
  final String? tier;

  /// `X-Request-Id` from response headers.
  final String? requestId;
  final int? statusCode;
}

class HereMapsCallResult<T> {
  const HereMapsCallResult({required this.value, this.result});
  final T value;
  final HereMapsResult? result;
}

/// Wraps a HERE Location Services REST call in a CLIENT span. [service]
/// is one of `routing`, `geocoding`, `search`, `tour_planning`,
/// `matrix_routing`, `isoline_routing`, `map_tile`, `traffic`.
Future<T> tracedHereMaps<T>({
  required String service,
  required Future<HereMapsCallResult<T>> Function() invoke,
  String? apiVersion,
}) async {
  if (hereMapsInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'here_maps',
    'rpc.method': service,
    'here_maps.service': service,
  };
  if (apiVersion != null) m['here_maps.api_version'] = apiVersion;

  final span = _tracer().startSpan(
    'here_maps $service',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'here_maps.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.transportMode != null) {
        extras.add(OTel.attributeString(
          'here_maps.transport_mode',
          r.result!.transportMode!,
        ));
      }
      if (r.result!.tier != null) {
        extras.add(OTel.attributeString(
          'here_maps.tier',
          r.result!.tier!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'here_maps.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'HERE HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
