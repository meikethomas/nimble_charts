// Copyright 2019 the Charts project authors. Please see the AUTHORS file
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

import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;
import 'package:intl/intl.dart' show DateFormat, Intl;
import 'package:nimble_charts_common/src/chart/cartesian/axis/time/simple_time_tick_formatter.dart';
import 'package:test/test.dart';

void main() {
  const tickLabel = '-tick-';
  final testDate1 = DateTime.utc(1984, 11, 11);
  final testDate2 = DateTime.utc(1984, 11, 12);

  late SimpleTimeTickFormatter simpleTimeFormatter;
  late SimpleTimeTickFormatter simpleTimeFormatterWithDateFormat;
  late DateFormat dateFormat;
  String? previousLocale;

  String testFormatter(DateTime dateTime) => tickLabel;

  setUpAll(() async {
    await initializeDateFormatting('en_US');
    await initializeDateFormatting('de');
  });

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    dateFormat = DateFormat.yMMMd();
    simpleTimeFormatter = SimpleTimeTickFormatter(formatter: testFormatter);
    simpleTimeFormatterWithDateFormat = SimpleTimeTickFormatter(
      formatter: dateFormat.format,
    );
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
  });

  group('MMB0014_source_cleanup_regression', () {
    group('MMB0011_intl_formatter_regression', () {
      test('formatter with custom formatting function input', () {
        final actualLabelFirstTick = simpleTimeFormatter.formatFirstTick(
          testDate1,
        );
        final actualLabelSimpleTick = simpleTimeFormatter.formatSimpleTick(
          testDate1,
        );
        final actualLabelTransitionTick = simpleTimeFormatter
            .formatTransitionTick(testDate1);
        final actualBoolIsTransition = simpleTimeFormatter.isTransition(
          testDate2,
          testDate1,
        );

        expect(actualLabelFirstTick, equals(tickLabel));
        expect(actualLabelSimpleTick, equals(tickLabel));
        expect(actualLabelTransitionTick, equals(tickLabel));
        expect(actualBoolIsTransition, isFalse);
      });

      test('formatter with DateFormat formatting function', () {
        const expectedLabel = 'Nov 11, 1984';

        final actualLabelFirstTick = simpleTimeFormatterWithDateFormat
            .formatFirstTick(testDate1);
        final actualLabelSimpleTick = simpleTimeFormatterWithDateFormat
            .formatSimpleTick(testDate1);
        final actualLabelTransitionTick = simpleTimeFormatterWithDateFormat
            .formatTransitionTick(testDate1);
        final actualBoolIsTransition = simpleTimeFormatterWithDateFormat
            .isTransition(testDate2, testDate1);

        expect(actualLabelFirstTick, equals(expectedLabel));
        expect(actualLabelSimpleTick, equals(expectedLabel));
        expect(actualLabelTransitionTick, equals(expectedLabel));
        expect(actualBoolIsTransition, isFalse);
      });

      test('MMB0011_date_labels_en_de_preserve_boundaries', () {
        final beforeBoundary = DateTime.utc(2024, 1, 31, 23, 59, 59);
        final afterBoundary = DateTime.utc(2024, 2);

        Intl.defaultLocale = 'en_US';
        final englishFormatter = SimpleTimeTickFormatter(
          formatter: DateFormat.yMMMd().format,
        );
        expect(
          englishFormatter.formatFirstTick(beforeBoundary),
          equals('Jan 31, 2024'),
        );
        expect(
          englishFormatter.formatTransitionTick(afterBoundary),
          equals('Feb 1, 2024'),
        );

        Intl.defaultLocale = 'de';
        final germanFormatter = SimpleTimeTickFormatter(
          formatter: DateFormat.yMMMd().format,
        );
        expect(
          germanFormatter.formatFirstTick(beforeBoundary),
          equals('31. Jan. 2024'),
        );
        expect(
          germanFormatter.formatTransitionTick(afterBoundary),
          equals('1. Feb. 2024'),
        );
      });
    });
  });
}
