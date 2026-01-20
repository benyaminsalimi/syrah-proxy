import 'package:test/test.dart';
import 'package:syrah_core/models/filter.dart';
import 'package:syrah_core/models/http_request.dart';
import 'package:syrah_core/services/filter_service.dart';

void main() {
  group('FilterService', () {
    late FilterService service;

    setUp(() {
      service = FilterService();
    });

    tearDown(() {
      service.dispose();
    });

    group('initialization', () {
      test('initializes with built-in presets', () {
        expect(service.presets, isNotEmpty);
        expect(service.presets.every((p) => p.isBuiltIn), isTrue);
      });

      test('initializes with empty filter state', () {
        expect(service.filterState.hasActiveFilter, isFalse);
      });
    });

    group('filter state updates', () {
      test('setSearchText updates search text', () {
        service.setSearchText('test query');

        expect(service.filterState.searchText, 'test query');
      });

      test('clearSearch clears search text', () {
        service.setSearchText('test query');
        service.clearSearch();

        expect(service.filterState.searchText, isEmpty);
      });

      test('addFilter adds filter to state', () {
        final filter = Filter.simple(
          id: 'test-filter',
          field: FilterField.method,
          operator: FilterOperator.equals,
          value: 'GET',
        );

        service.addFilter(filter);

        expect(service.filterState.filters, contains(filter));
      });

      test('removeFilter removes filter by id', () {
        final filter = Filter.simple(
          id: 'test-filter',
          field: FilterField.method,
          operator: FilterOperator.equals,
          value: 'GET',
        );

        service.addFilter(filter);
        service.removeFilter('test-filter');

        expect(service.filterState.filters, isEmpty);
      });

      test('clearFilters resets filter state', () {
        service.setSearchText('test');
        service.addFilter(Filter.simple(
          id: 'f1',
          field: FilterField.method,
          operator: FilterOperator.equals,
          value: 'GET',
        ));

        service.clearFilters();

        expect(service.filterState.searchText, isEmpty);
        expect(service.filterState.filters, isEmpty);
      });
    });

    group('preset management', () {
      test('applyPreset sets active preset', () {
        service.applyPreset('errors');

        expect(service.filterState.activePreset, isNotNull);
        expect(service.filterState.activePreset!.id, 'errors');
      });

      test('applyPreset updates lastUsedAt', () {
        service.applyPreset('errors');

        final preset = service.getPreset('errors');
        expect(preset?.lastUsedAt, isNotNull);
      });

      test('clearPreset removes active preset', () {
        service.applyPreset('errors');
        service.clearPreset();

        expect(service.filterState.activePreset, isNull);
      });

      test('addPreset adds custom preset', () {
        final preset = FilterPreset(
          id: 'custom',
          name: 'Custom Filter',
          filter: Filter.simple(
            id: 'custom-filter',
            field: FilterField.host,
            operator: FilterOperator.contains,
            value: 'api',
          ),
          createdAt: DateTime.now(),
        );

        service.addPreset(preset);

        expect(service.presets.any((p) => p.id == 'custom'), isTrue);
        expect(service.getPreset('custom'), isNotNull);
      });

      test('updatePreset updates custom preset', () {
        final preset = FilterPreset(
          id: 'custom',
          name: 'Custom Filter',
          filter: Filter.simple(
            id: 'custom-filter',
            field: FilterField.host,
            operator: FilterOperator.contains,
            value: 'api',
          ),
          createdAt: DateTime.now(),
        );

        service.addPreset(preset);

        final updated = preset.copyWith(name: 'Updated Name');
        service.updatePreset(updated);

        expect(service.getPreset('custom')?.name, 'Updated Name');
      });

      test('updatePreset does not update built-in preset', () {
        final errorPreset = service.getPreset('errors');
        final updated = errorPreset!.copyWith(name: 'Modified');

        service.updatePreset(updated);

        expect(service.getPreset('errors')?.name, 'Errors Only');
      });

      test('removePreset removes custom preset', () {
        final preset = FilterPreset(
          id: 'custom',
          name: 'Custom Filter',
          filter: Filter.simple(
            id: 'custom-filter',
            field: FilterField.host,
            operator: FilterOperator.contains,
            value: 'api',
          ),
          createdAt: DateTime.now(),
        );

        service.addPreset(preset);
        service.removePreset('custom');

        expect(service.getPreset('custom'), isNull);
      });

      test('removePreset does not remove built-in preset', () {
        service.removePreset('errors');

        expect(service.getPreset('errors'), isNotNull);
      });

      test('removePreset clears active preset if it was removed', () {
        final preset = FilterPreset(
          id: 'custom',
          name: 'Custom Filter',
          filter: Filter.simple(
            id: 'custom-filter',
            field: FilterField.host,
            operator: FilterOperator.contains,
            value: 'api',
          ),
          createdAt: DateTime.now(),
        );

        service.addPreset(preset);
        service.applyPreset('custom');
        service.removePreset('custom');

        expect(service.filterState.activePreset, isNull);
      });

      test('customPresets returns only non-built-in presets', () {
        final preset = FilterPreset(
          id: 'custom',
          name: 'Custom Filter',
          filter: Filter.simple(
            id: 'custom-filter',
            field: FilterField.host,
            operator: FilterOperator.contains,
            value: 'api',
          ),
          createdAt: DateTime.now(),
        );

        service.addPreset(preset);

        expect(service.customPresets.length, 1);
        expect(service.customPresets.first.id, 'custom');
      });
    });

    group('toggle methods', () {
      test('toggleShowMarkedOnly toggles flag', () {
        expect(service.filterState.showMarkedOnly, isFalse);

        service.toggleShowMarkedOnly();
        expect(service.filterState.showMarkedOnly, isTrue);

        service.toggleShowMarkedOnly();
        expect(service.filterState.showMarkedOnly, isFalse);
      });

      test('toggleShowErrorsOnly toggles flag', () {
        expect(service.filterState.showErrorsOnly, isFalse);

        service.toggleShowErrorsOnly();
        expect(service.filterState.showErrorsOnly, isTrue);

        service.toggleShowErrorsOnly();
        expect(service.filterState.showErrorsOnly, isFalse);
      });

      test('toggleMethodFilter adds and removes methods', () {
        service.toggleMethodFilter(HttpMethod.get);
        expect(service.filterState.selectedMethods, contains(HttpMethod.get));

        service.toggleMethodFilter(HttpMethod.post);
        expect(service.filterState.selectedMethods, contains(HttpMethod.post));

        service.toggleMethodFilter(HttpMethod.get);
        expect(service.filterState.selectedMethods, isNot(contains(HttpMethod.get)));
        expect(service.filterState.selectedMethods, contains(HttpMethod.post));
      });
    });

    group('hidden patterns', () {
      test('addHiddenPattern adds pattern', () {
        service.addHiddenPattern('google-analytics.com');

        expect(service.filterState.hiddenPatterns, contains('google-analytics.com'));
      });

      test('addHiddenPattern does not add duplicate', () {
        service.addHiddenPattern('google-analytics.com');
        service.addHiddenPattern('google-analytics.com');

        expect(
          service.filterState.hiddenPatterns.where((p) => p == 'google-analytics.com').length,
          1,
        );
      });

      test('removeHiddenPattern removes pattern', () {
        service.addHiddenPattern('google-analytics.com');
        service.removeHiddenPattern('google-analytics.com');

        expect(service.filterState.hiddenPatterns, isEmpty);
      });
    });

    group('filter setters', () {
      test('setStatusCodeFilter sets status codes', () {
        service.setStatusCodeFilter([200, 201, 204]);

        expect(service.filterState.selectedStatusCodes, [200, 201, 204]);
      });

      test('setContentTypeFilter sets content types', () {
        service.setContentTypeFilter(['json', 'xml']);

        expect(service.filterState.selectedContentTypes, ['json', 'xml']);
      });

      test('setDateRange sets date range', () {
        final from = DateTime(2024, 1, 1);
        final to = DateTime(2024, 12, 31);

        service.setDateRange(from, to);

        expect(service.filterState.fromDate, from);
        expect(service.filterState.toDate, to);
      });
    });

    group('saveAsPreset', () {
      test('saves current filter state as preset', () {
        service.setSearchText('api');
        service.addFilter(Filter.simple(
          id: 'f1',
          field: FilterField.method,
          operator: FilterOperator.equals,
          value: 'GET',
        ));

        service.saveAsPreset('my-preset', 'My Preset', description: 'Test preset');

        final preset = service.getPreset('my-preset');
        expect(preset, isNotNull);
        expect(preset!.name, 'My Preset');
        expect(preset.description, 'Test preset');
        expect(preset.isBuiltIn, isFalse);
      });
    });

    group('buildFilter', () {
      test('builds filter from parameters', () {
        final filter = FilterService.buildFilter(
          field: FilterField.url,
          operator: FilterOperator.contains,
          value: 'example.com',
        );

        expect(filter, isA<SimpleFilter>());
        final simple = filter as SimpleFilter;
        expect(simple.field, FilterField.url);
        expect(simple.operator, FilterOperator.contains);
        expect(simple.value, 'example.com');
      });

      test('builds filter with header name', () {
        final filter = FilterService.buildFilter(
          field: FilterField.requestHeader,
          operator: FilterOperator.equals,
          value: 'application/json',
          headerName: 'Content-Type',
        );

        final simple = filter as SimpleFilter;
        expect(simple.headerName, 'Content-Type');
      });

      test('throws for missing parameters', () {
        expect(
          () => FilterService.buildFilter(
            field: FilterField.url,
            operator: null,
            value: 'test',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('streams', () {
      test('filterStateStream emits on state changes', () async {
        final states = <FilterState>[];
        final subscription = service.filterStateStream.listen(states.add);

        service.setSearchText('test');
        service.toggleShowMarkedOnly();

        await Future.delayed(const Duration(milliseconds: 10));

        expect(states.length, 2);
        expect(states[0].searchText, 'test');
        expect(states[1].showMarkedOnly, isTrue);

        await subscription.cancel();
      });

      test('presetStream emits on preset changes', () async {
        final updates = <List<FilterPreset>>[];
        final subscription = service.presetStream.listen(updates.add);

        final preset = FilterPreset(
          id: 'custom',
          name: 'Custom',
          filter: Filter.quickSearch(id: 'qs', searchText: ''),
          createdAt: DateTime.now(),
        );

        service.addPreset(preset);

        await Future.delayed(const Duration(milliseconds: 10));

        expect(updates.length, 1);
        expect(updates[0].any((p) => p.id == 'custom'), isTrue);

        await subscription.cancel();
      });
    });
  });

  group('NoisePatterns', () {
    test('commonNoise contains expected patterns', () {
      expect(NoisePatterns.commonNoise, contains('google-analytics.com'));
      expect(NoisePatterns.commonNoise, contains('fonts.googleapis.com'));
    });

    test('commonFileExtensions contains expected extensions', () {
      expect(NoisePatterns.commonFileExtensions, contains('.woff'));
      expect(NoisePatterns.commonFileExtensions, contains('.woff2'));
      expect(NoisePatterns.commonFileExtensions, contains('.ttf'));
    });
  });
}
