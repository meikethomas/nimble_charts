import 'dart:convert';
import 'dart:io';

import 'package:example/gallery_app.dart';
import 'package:example/main.dart';
import 'package:example/original.dart';
import 'package:example/picker/full_screen_sample.dart';
import 'package:example/picker/tag_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nimble_charts/flutter.dart' as charts;

const _simpleBarChartTitle = 'Simple Bar Chart';
const _simpleLineChartTitle = 'Simple Line Chart';
const _simpleTimeSeriesChartTitle = 'Simple Time Series Chart';
const _simplePieChartTitle = 'Simple Pie Chart';
const _galleryPumpDuration = Duration(milliseconds: 600);

void main() {
  group('MMB0014_source_cleanup_regression', () {
    testWidgets(
      'MMB0013_gallery_starts_and_filters_at_phone_and_tablet_widths',
      (tester) async {
        _configureGalleryTest(tester, const Size(390, 900), const (
          themeMode: ThemeMode.light,
          isOriginal: false,
          useRandomData: true,
        ));

        for (final width in const <double>[390, 800]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          tester.view.physicalSize = Size(width, 900);
          appState.value = const (
            themeMode: ThemeMode.light,
            isOriginal: false,
            useRandomData: true,
          );

          await tester.pumpWidget(const GalleryApp());
          await _pumpGallery(tester);

          expect(find.byType(TagSelectionScreen), findsOneWidget);
          expect(find.text(_simpleBarChartTitle), findsOneWidget);
          expect(find.byType(charts.BarChart), findsWidgets);
          _expectNoFlutterException(tester, 'initial gallery at ${width}px');

          await tester.tap(find.widgetWithText(FilterChip, 'Bar'));
          await _pumpGallery(tester);
          expect(find.text(_simpleBarChartTitle), findsNothing);
          expect(find.byType(charts.BarChart), findsNothing);

          await tester.tap(find.widgetWithText(FilterChip, 'Line'));
          await _pumpGallery(tester);
          expect(find.text(_simpleLineChartTitle), findsOneWidget);
          expect(find.byType(charts.LineChart), findsWidgets);
          expect(find.text(_simpleBarChartTitle), findsNothing);
          _expectNoFlutterException(tester, 'filtered gallery at ${width}px');
        }
      },
    );

    testWidgets('MMB0013_gallery_opens_chart_returns_and_switches_theme', (
      tester,
    ) async {
      _configureGalleryTest(tester, const Size(800, 1000), const (
        themeMode: ThemeMode.light,
        isOriginal: false,
        useRandomData: true,
      ));

      await tester.pumpWidget(const GalleryApp());
      await _pumpGallery(tester);

      final sampleTitle = find.text(_simpleBarChartTitle);
      expect(sampleTitle, findsOneWidget);
      await tester.ensureVisible(sampleTitle);
      await tester.pump();
      expect(
        find.ancestor(of: sampleTitle, matching: find.byType(InkWell)),
        findsOneWidget,
      );
      await tester.tap(sampleTitle);
      await _pumpGallery(tester);

      expect(find.byType(FullScreenSample), findsOneWidget);
      expect(find.byType(charts.BarChart), findsOneWidget);
      expect(find.text(_simpleBarChartTitle), findsOneWidget);
      _expectNoFlutterException(tester, 'full-screen chart');

      await tester.pageBack();
      await _pumpGallery(tester);
      expect(find.byType(TagSelectionScreen), findsOneWidget);
      expect(find.byType(FullScreenSample), findsNothing);

      await tester.tap(find.byIcon(Icons.dark_mode));
      await _pumpGallery(tester);

      expect(appState.value.themeMode, ThemeMode.dark);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      final screenContext = tester.element(find.byType(TagSelectionScreen));
      expect(Theme.of(screenContext).brightness, Brightness.dark);
      _expectNoFlutterException(tester, 'dark gallery after navigation');
    });

    testWidgets('MMB0013_original_gallery_bar_line_timeseries_pie_smoke', (
      tester,
    ) async {
      _configureGalleryTest(tester, const Size(1000, 1200), const (
        themeMode: ThemeMode.light,
        isOriginal: true,
        useRandomData: false,
      ));

      await tester.pumpWidget(const GalleryApp());
      await _pumpGallery(tester);

      expect(find.byType(Original), findsOneWidget);
      expect(appState.value.useRandomData, isFalse);

      await _openOriginalSample(
        tester,
        title: _simpleBarChartTitle,
        chart: find.byType(charts.BarChart),
      );
      await _openOriginalSample(
        tester,
        title: _simpleTimeSeriesChartTitle,
        chart: find.byType(charts.TimeSeriesChart),
      );
      await _openOriginalSample(
        tester,
        title: _simpleLineChartTitle,
        chart: find.byType(charts.LineChart),
      );
      await _openOriginalSample(
        tester,
        title: _simplePieChartTitle,
        chart: find.byType(charts.PieChart<num>),
      );

      expect(appState.value.useRandomData, isFalse);
      _expectNoFlutterException(tester, 'deterministic original gallery');
    });

    test('MMB0013_example_uses_local_fork_packages', () {
      final packageConfig = File('.dart_tool/package_config.json').absolute;
      expect(
        packageConfig.existsSync(),
        isTrue,
        reason: 'Run Flutter 3.44.9 pub get in the example before testing.',
      );

      final decoded = jsonDecode(packageConfig.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      final packages = (decoded as Map<String, dynamic>)['packages'];
      expect(packages, isA<List<dynamic>>());
      final packageEntries = packages as List<dynamic>;

      const expectedRoots = <String, String>{
        'nimble_charts': '..',
        'nimble_charts_common': '../../charts_common',
      };
      for (final expected in expectedRoots.entries) {
        final entries = packageEntries.where(
          (entry) =>
              entry is Map<String, dynamic> && entry['name'] == expected.key,
        );
        expect(
          entries,
          hasLength(1),
          reason: 'package_config must contain ${expected.key} exactly once.',
        );

        final entry = entries.single as Map<String, dynamic>;
        final rootUri = entry['rootUri'];
        expect(rootUri, isA<String>());
        final resolvedRoot = Directory.fromUri(
          packageConfig.parent.uri.resolve(rootUri as String),
        );
        expect(
          resolvedRoot.existsSync(),
          isTrue,
          reason: '${expected.key} rootUri does not resolve to a directory.',
        );

        final expectedRoot = Directory(expected.value);
        expect(expectedRoot.existsSync(), isTrue);
        expect(
          resolvedRoot.resolveSymbolicLinksSync(),
          expectedRoot.resolveSymbolicLinksSync(),
          reason: '${expected.key} must resolve to the local Charts checkout.',
        );
      }
    });

    test('MMB0013_native_toolchain_pins_match_target', () {
      final settings = _readFile('android/settings.gradle');
      final rootBuild = _readFile('android/build.gradle');
      final appBuild = _readFile('android/app/build.gradle');
      final wrapper = _readProperties(
        File('android/gradle/wrapper/gradle-wrapper.properties'),
      );
      final manifest = _readFile('android/app/src/main/AndroidManifest.xml');

      expect(
        settings,
        contains(
          r'includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")',
        ),
      );
      _expectPluginVersion(
        settings,
        'dev.flutter.flutter-plugin-loader',
        '1.0.0',
      );
      _expectPluginVersion(
        settings,
        'com.android.application',
        '8.10.1',
        applyFalse: true,
      );
      _expectPluginVersion(
        settings,
        'org.jetbrains.kotlin.android',
        '2.1.21',
        applyFalse: true,
      );

      for (final pluginId in const <String>[
        'com.android.application',
        'kotlin-android',
        'dev.flutter.flutter-gradle-plugin',
      ]) {
        _expectPluginDeclaration(appBuild, pluginId);
      }

      expect(settings, isNot(contains('app_plugin_loader.gradle')));
      expect(appBuild, isNot(contains('apply from:')));
      expect(appBuild, isNot(contains('flutter.gradle')));
      expect(appBuild, isNot(contains('kotlin-stdlib-jdk7')));
      expect(rootBuild, isNot(contains('classpath')));
      expect(rootBuild, isNot(contains('jcenter()')));
      expect(rootBuild, contains('mavenCentral()'));

      expect(wrapper['distributionUrl'], contains('gradle-8.11.1-all.zip'));
      expect(
        appBuild,
        matches(RegExp(r'''namespace\s*=\s*["']com\.example\.example["']''')),
      );
      expect(
        appBuild,
        matches(
          RegExp(r'''applicationId\s*=\s*["']com\.example\.example["']'''),
        ),
      );
      expect(
        appBuild,
        matches(RegExp(r'compileSdk\s*=\s*flutter\.compileSdkVersion')),
      );
      expect(appBuild, matches(RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion')));
      expect(appBuild, matches(RegExp(r'targetSdk\s*=\s*36\b')));
      expect(
        appBuild,
        matches(RegExp(r'sourceCompatibility\s*=\s*JavaVersion\.VERSION_17')),
      );
      expect(
        appBuild,
        matches(RegExp(r'targetCompatibility\s*=\s*JavaVersion\.VERSION_17')),
      );
      expect(
        appBuild,
        matches(
          RegExp(r'jvmTarget\s*=\s*JavaVersion\.VERSION_17\.toString\(\)'),
        ),
      );
      expect(
        RegExp(r'<manifest[^>]*\spackage\s*=').hasMatch(manifest),
        isFalse,
        reason: 'Android package identity belongs in namespace/applicationId.',
      );
    });
  });
}

void _configureGalleryTest(WidgetTester tester, Size size, AppState state) {
  final previousState = appState.value;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  appState.value = state;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    appState.value = previousState;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpGallery(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_galleryPumpDuration);
}

Future<void> _openOriginalSample(
  WidgetTester tester, {
  required String title,
  required Finder chart,
}) async {
  final tile = find.text(title);
  await tester.scrollUntilVisible(
    tile,
    500,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
  expect(tile, findsOneWidget);
  await tester.tap(tile);
  await _pumpGallery(tester);

  expect(chart, findsOneWidget, reason: '$title must render its real chart.');
  _expectNoFlutterException(tester, title);

  await tester.pageBack();
  await _pumpGallery(tester);
  expect(find.byType(Original), findsOneWidget);
}

void _expectNoFlutterException(WidgetTester tester, String phase) {
  expect(tester.takeException(), isNull, reason: phase);
}

String _readFile(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'Missing file: $path');
  return file.readAsStringSync();
}

Map<String, String> _readProperties(File file) {
  expect(file.existsSync(), isTrue, reason: 'Missing file: ${file.path}');
  final properties = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final separator = line.indexOf('=');
    if (separator <= 0 || line.trimLeft().startsWith('#')) {
      continue;
    }
    properties[line.substring(0, separator).trim()] = line
        .substring(separator + 1)
        .trim();
  }
  return properties;
}

void _expectPluginDeclaration(String source, String pluginId) {
  final pattern = RegExp('''id\\s+["']${RegExp.escape(pluginId)}["']''');
  expect(source, matches(pattern), reason: 'Missing app plugin: $pluginId');
}

void _expectPluginVersion(
  String source,
  String pluginId,
  String version, {
  bool applyFalse = false,
}) {
  final applyClause = applyFalse ? r'\s+apply\s+false' : '';
  final pattern = RegExp(
    '''id\\s+["']${RegExp.escape(pluginId)}["']'''
    '''\\s+version\\s+["']${RegExp.escape(version)}["']$applyClause''',
  );
  expect(
    source,
    matches(pattern),
    reason: '$pluginId must be pinned to $version.',
  );
}
