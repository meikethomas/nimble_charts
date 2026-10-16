// Copyright 2026 the Charts project authors. Please see the AUTHORS file
// for details.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:convert';
import 'dart:io';
import 'dart:math' show Rectangle;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimble_charts/flutter.dart' as charts;
import 'package:nimble_charts/src/behaviors/legend/legend.dart'
    show TappableLegend;
import 'package:nimble_charts/src/behaviors/legend/legend_entry_layout.dart'
    show SimpleLegendEntryLayout;
import 'package:nimble_charts/src/graphics_factory.dart' show GraphicsFactory;
import 'package:nimble_charts/src/symbol_renderer.dart'
    show SymbolRendererCanvas;
import 'package:nimble_charts/src/text_element.dart' as chart_text;
import 'package:nimble_charts/src/text_style.dart' as chart_text_style;
import 'package:nimble_charts/src/util/color.dart' show ColorUtil;
import 'package:nimble_charts_common/common.dart' as common;

const _expectedRepositoryUrl =
    'https://github.com/meikethomas/nimble_charts.git';

void main() {
  group('MMB0014_source_cleanup_regression', () {
    testWidgets('MMB0011_text_scaler_reaches_real_painter', (tester) async {
      const linear = TextScaler.linear(1.5);
      const nonlinear = _NonlinearTextScaler();

      for (final scaler in [linear, nonlinear]) {
        final elements = await _pumpScaledElements(tester, scaler);
        final expectedSmall = TextPainter(
          text: const TextSpan(
            text: 'Scale me',
            style: TextStyle(fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();
        final expectedLarge = TextPainter(
          text: const TextSpan(
            text: 'Scale me',
            style: TextStyle(fontSize: 30),
          ),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
        )..layout();

        expect(elements.small.textScaler, same(scaler));
        expect(elements.large.textScaler, same(scaler));
        expect(
          elements.small.measurement.horizontalSliceWidth,
          closeTo(expectedSmall.width, 0.001),
        );
        expect(
          elements.large.measurement.horizontalSliceWidth,
          closeTo(expectedLarge.width, 0.001),
        );

        if (scaler is _NonlinearTextScaler) {
          final flattenedLarge = TextPainter(
            text: const TextSpan(
              text: 'Scale me',
              style: TextStyle(fontSize: 30),
            ),
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.linear(scaler.scale(1)),
          )..layout();
          expect(
            elements.large.measurement.horizontalSliceWidth,
            isNot(closeTo(flattenedLarge.width, 0.001)),
          );
        }
      }
    });

    test('MMB0011_legacy_linear_scale_and_relayout', () {
      final element = chart_text.TextElement(
        'A deliberately long label for relayout',
        style: chart_text_style.TextStyle()..fontSize = 12,
        textScaleFactor: 1.5,
      );
      final initialPainter = element.textPainter;
      final initialHeight = element.measurement.verticalSliceWidth;

      expect(initialPainter!.textScaler.scale(12), equals(18));

      element.textStyle = chart_text_style.TextStyle()..fontSize = 24;
      final stylePainter = element.textPainter;
      expect(stylePainter, isNot(same(initialPainter)));
      expect(
        element.measurement.verticalSliceWidth,
        greaterThan(initialHeight),
      );

      element
        ..maxWidth = 40
        ..maxWidthStrategy = common.MaxWidthStrategy.ellipsize;
      final widthPainter = element.textPainter;
      expect(widthPainter, isNot(same(stylePainter)));
      expect(element.measurement.horizontalSliceWidth, lessThanOrEqualTo(40));

      const nonlinear = _NonlinearTextScaler();
      final modernWins = chart_text.TextElement(
        'precedence',
        textScaleFactor: 9,
        textScaler: nonlinear,
      );
      expect(modernWins.textScaler, same(nonlinear));
      expect(modernWins.textPainter!.textScaler.scale(30), equals(52.5));
    });

    testWidgets('MMB0011_symbol_color_bytes_and_legend_opacity', (
      tester,
    ) async {
      final renderer = _RecordingSymbolRenderer();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: SymbolRendererCanvas(renderer, null).build(
                context,
                size: const Size(20, 20),
                color: const common.Color(r: 1, g: 128, b: 255, a: 129),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        renderer.fillColor,
        const common.Color(r: 1, g: 128, b: 255, a: 129),
      );
      expect(renderer.strokeColor, renderer.fillColor);

      final rounded = ColorUtil.fromDartColor(
        const ui.Color.from(alpha: 0.5, red: 0.1, green: 0.5, blue: 1),
      );
      expect(rounded, const common.Color(r: 26, g: 128, b: 255, a: 128));

      final series = common.MutableSeries<DateTime>(
        common.Series<_TimePoint, DateTime>(
          id: 'legend',
          data: [_TimePoint(DateTime.utc(2024), 1)],
          domainFn: (datum, _) => datum.date,
          measureFn: (datum, _) => datum.measure,
        ),
      );
      final entry = common.LegendEntry<DateTime>(
        series,
        'Hidden series',
        textStyle: const common.TextStyleSpec(
          color: common.Color(r: 40, g: 80, b: 120),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => const SimpleLegendEntryLayout().createLabel(
              context,
              entry,
              const _NoopLegend(),
              true,
            ),
          ),
        ),
      );

      final label = tester.widget<Text>(find.text('Hidden series'));
      expect(label.style!.color!.a, closeTo(0.26, 0.000001));
    });

    testWidgets('MMB0011_timeseries_render_and_selection', (tester) async {
      final data = [
        _TimePoint(DateTime.utc(2024), 10),
        _TimePoint(DateTime.utc(2024, 2), 30),
        _TimePoint(DateTime.utc(2024, 3), 20),
      ];
      final series = charts.Series<_TimePoint, DateTime>(
        id: 'balance',
        data: data,
        domainFn: (datum, _) => datum.date,
        measureFn: (datum, _) => datum.measure,
      );
      charts.SelectionModel<DateTime>? selectionModel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: charts.TimeSeriesChart(
                [series],
                animate: false,
                selectionModels: [
                  charts.SelectionModelConfig<DateTime>(
                    changedListener: (model) => selectionModel = model,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(charts.TimeSeriesChart));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(selectionModel, isNotNull);
      expect(selectionModel!.selectedDatum, isNotEmpty);
      final selected = selectionModel!.selectedDatum.first;
      expect(data, contains(selected.datum));
      expect(
        selected.series.measureFn(selected.index),
        equals((selected.datum as _TimePoint).measure),
      );
    });

    test('MMB0014_cleaned_common_source_is_exercised', () async {
      final flutterPackageRoot = Directory.current.absolute;
      final forkRoot = flutterPackageRoot.parent;
      final appRoot = forkRoot.parent.parent;
      final expectedForkRoot = _childDirectory(
        appRoot,
        'subrepos/nimble_charts',
      );
      final expectedFlutterPackage = _childDirectory(
        expectedForkRoot,
        'charts_flutter',
      );
      final expectedCommonPackage = _childDirectory(
        expectedForkRoot,
        'charts_common',
      );

      expect(
        File.fromUri(appRoot.uri.resolve('.fvmrc')).existsSync(),
        isTrue,
        reason: 'The test must run inside the bound App workspace.',
      );
      expect(expectedForkRoot.existsSync(), isTrue);
      expect(expectedFlutterPackage.existsSync(), isTrue);
      expect(expectedCommonPackage.existsSync(), isTrue);
      expect(
        _canonicalDirectory(flutterPackageRoot),
        _canonicalDirectory(expectedFlutterPackage),
        reason: 'The package test must run from the bound Charts checkout.',
      );

      final forkTopLevel = Directory(
        await _runGit(forkRoot, const ['rev-parse', '--show-toplevel']),
      );
      expect(
        _canonicalDirectory(forkTopLevel),
        _canonicalDirectory(expectedForkRoot),
        reason: 'The expected Charts directory must be its Git root.',
      );
      expect(
        _normalizeRepositoryUrl(
          await _runGit(forkRoot, const ['remote', 'get-url', 'origin']),
        ),
        _normalizeRepositoryUrl(_expectedRepositoryUrl),
        reason: 'The bound Charts checkout has the wrong origin.',
      );
      final expectedCommonTree = await _runGit(forkRoot, const [
        'rev-parse',
        'HEAD:charts_common',
      ]);

      final packageConfig = File.fromUri(
        flutterPackageRoot.uri.resolve('.dart_tool/package_config.json'),
      );
      expect(
        packageConfig.existsSync(),
        isTrue,
        reason: 'Prepare charts_flutter with Flutter 3.44.9 before testing.',
      );
      final decoded = jsonDecode(packageConfig.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      final packages = (decoded as Map<String, dynamic>)['packages'];
      expect(packages, isA<List<dynamic>>());
      final commonEntries = (packages as List<dynamic>).where(
        (entry) =>
            entry is Map<String, dynamic> &&
            entry['name'] == 'nimble_charts_common',
      );
      expect(
        commonEntries,
        hasLength(1),
        reason: 'package_config must contain nimble_charts_common once.',
      );
      final commonEntry = commonEntries.single as Map<String, dynamic>;
      final rootUri = commonEntry['rootUri'];
      expect(rootUri, isA<String>());
      final resolvedCommonPackage = Directory.fromUri(
        packageConfig.parent.uri.resolve(rootUri as String),
      );
      expect(
        resolvedCommonPackage.existsSync(),
        isTrue,
        reason: 'The resolved Common package root does not exist.',
      );

      final resolvedCommonPath = _canonicalDirectory(resolvedCommonPackage);
      if (resolvedCommonPath == _canonicalDirectory(expectedCommonPackage)) {
        return;
      }

      expect(
        await _runGit(forkRoot, const [
          'status',
          '--porcelain',
          '--untracked-files=all',
          '--',
          'charts_common',
        ]),
        isEmpty,
        reason:
            'Unpublished Common changes require the canonical local sibling; '
            'a Git-cache checkout would exercise the pre-cleanup tree.',
      );

      final resolvedRepository = Directory(
        await _runGit(resolvedCommonPackage, const [
          'rev-parse',
          '--show-toplevel',
        ]),
      );
      final expectedResolvedCommon = _childDirectory(
        resolvedRepository,
        'charts_common',
      );
      expect(expectedResolvedCommon.existsSync(), isTrue);
      expect(
        resolvedCommonPath,
        _canonicalDirectory(expectedResolvedCommon),
        reason: 'Common must use the charts_common path in its repository.',
      );

      final checkoutOrigin = await _runGit(resolvedRepository, const [
        'config',
        '--get',
        'remote.origin.url',
      ]);
      expect(
        _normalizeRepositoryUrl(checkoutOrigin),
        isNot(_normalizeRepositoryUrl(_expectedRepositoryUrl)),
        reason: 'A development checkout outside the bound fork is invalid.',
      );
      final cacheRepository = _localOriginDirectory(
        resolvedRepository,
        checkoutOrigin,
      );
      expect(
        cacheRepository,
        isNotNull,
        reason: 'A final non-local source must be a Pub Git-cache checkout.',
      );
      final verifiedCacheRepository = cacheRepository!;
      expect(verifiedCacheRepository.existsSync(), isTrue);
      expect(
        await _runGit(verifiedCacheRepository, const [
          'rev-parse',
          '--is-bare-repository',
        ]),
        'true',
        reason: 'The Pub cache origin must be a bare Git repository.',
      );
      expect(
        _normalizeRepositoryUrl(
          await _runGit(verifiedCacheRepository, const [
            'config',
            '--get',
            'remote.origin.url',
          ]),
        ),
        _normalizeRepositoryUrl(_expectedRepositoryUrl),
        reason: 'The Pub cache belongs to a different repository.',
      );
      expect(
        await _runGit(resolvedRepository, const [
          'status',
          '--porcelain',
          '--untracked-files=no',
        ]),
        isEmpty,
        reason: 'The resolved Git-cache checkout contains tracked changes.',
      );
      expect(
        await _runGit(resolvedRepository, const [
          'rev-parse',
          'HEAD:charts_common',
        ]),
        expectedCommonTree,
        reason: 'The resolved Common package tree predates the cleanup.',
      );
    });
  });
}

Directory _childDirectory(Directory parent, String relativePath) =>
    Directory.fromUri(parent.uri.resolve('$relativePath/'));

String _canonicalDirectory(Directory directory) =>
    directory.resolveSymbolicLinksSync();

Directory? _localOriginDirectory(Directory repository, String origin) {
  final originUri = Uri.tryParse(origin.trim());
  if (originUri != null && originUri.scheme == 'file') {
    return Directory.fromUri(originUri);
  }
  if (originUri != null && originUri.hasScheme) {
    return null;
  }
  return Directory.fromUri(repository.uri.resolve(origin.trim()));
}

String _normalizeRepositoryUrl(String value) {
  var normalized = value.trim().replaceAll(r'\', '/');
  if (normalized.startsWith('git@github.com:')) {
    normalized = 'https://github.com/${normalized.substring(15)}';
  }
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.endsWith('.git')) {
    normalized = normalized.substring(0, normalized.length - 4);
  }
  return normalized;
}

Future<String> _runGit(
  Directory workingDirectory,
  List<String> arguments,
) async {
  final result = await Process.run('git', [
    '-C',
    workingDirectory.path,
    ...arguments,
  ]);
  expect(
    result.exitCode,
    0,
    reason:
        'git ${arguments.join(' ')} failed in ${workingDirectory.path}: '
        '${result.stderr}',
  );
  return (result.stdout as String).trim();
}

Future<({chart_text.TextElement small, chart_text.TextElement large})>
_pumpScaledElements(WidgetTester tester, TextScaler scaler) async {
  chart_text.TextElement? smallElement;
  chart_text.TextElement? largeElement;

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: scaler),
        child: Builder(
          builder: (context) {
            final factory = GraphicsFactory(context);
            smallElement =
                factory.createTextElement('Scale me') as chart_text.TextElement
                  ..textStyle = (chart_text_style.TextStyle()..fontSize = 12);
            largeElement =
                factory.createTextElement('Scale me') as chart_text.TextElement
                  ..textStyle = (chart_text_style.TextStyle()..fontSize = 30);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  return (small: smallElement!, large: largeElement!);
}

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) {
    if (fontSize <= 1) {
      return fontSize;
    }
    return fontSize * (fontSize < 20 ? 1.25 : 1.75);
  }

  @override
  double get textScaleFactor => 1;
}

class _RecordingSymbolRenderer extends common.SymbolRenderer {
  _RecordingSymbolRenderer() : super(isSolid: true);

  common.Color? fillColor;
  common.Color? strokeColor;

  @override
  void paint(
    common.ChartCanvas canvas,
    Rectangle<num> bounds, {
    List<int>? dashPattern,
    common.Color? fillColor,
    common.FillPatternType? fillPattern,
    common.Color? strokeColor,
    double? strokeWidthPx,
  }) {
    this.fillColor = fillColor;
    this.strokeColor = strokeColor;
  }

  @override
  bool shouldRepaint(_RecordingSymbolRenderer oldRenderer) => false;
}

class _NoopLegend implements TappableLegend<Object?, DateTime> {
  const _NoopLegend();

  @override
  void onLegendEntryTapUp(common.LegendEntry<dynamic> detail) {}
}

class _TimePoint {
  const _TimePoint(this.date, this.measure);

  final DateTime date;
  final int measure;
}
