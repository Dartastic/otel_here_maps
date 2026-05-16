// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_here_maps/otel_here_maps.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_here_maps-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('truck routing records transport_mode + tier', () async {
    await tracedHereMaps<String>(
      service: 'routing',
      apiVersion: 'v8',
      invoke: () async => const HereMapsCallResult(
        value: 'ok',
        result: HereMapsResult(
          itemCount: 1,
          transportMode: 'truck',
          tier: 'pro',
          requestId: 'req-1',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('here_maps routing')!);
    expect(a['here_maps.service'], 'routing');
    expect(a['here_maps.transport_mode'], 'truck');
    expect(a['here_maps.tier'], 'pro');
  });

  test('suppression skips spans', () async {
    await runWithoutHereMapsInstrumentationAsync(() async {
      await tracedHereMaps<String>(
        service: 'geocoding',
        invoke: () async => const HereMapsCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('here_maps '), isEmpty);
  });
}
