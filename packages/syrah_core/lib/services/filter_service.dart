import 'dart:async';

import '../models/models.dart';

/// Service for managing filters and filter presets
class FilterService {
  final _filterStateController = StreamController<FilterState>.broadcast();
  final _presetController = StreamController<List<FilterPreset>>.broadcast();

  FilterState _filterState = const FilterState();
  final List<FilterPreset> _presets = [...FilterPreset.builtInPresets];
  final Map<String, FilterPreset> _presetsById = {};

  FilterService() {
    // Initialize built-in presets
    for (final preset in FilterPreset.builtInPresets) {
      _presetsById[preset.id] = preset;
    }
  }

  /// Stream of filter state updates
  Stream<FilterState> get filterStateStream => _filterStateController.stream;

  /// Stream of preset list updates
  Stream<List<FilterPreset>> get presetStream => _presetController.stream;

  /// Get current filter state
  FilterState get filterState => _filterState;

  /// Get all presets
  List<FilterPreset> get presets => List.unmodifiable(_presets);

  /// Get custom presets only
  List<FilterPreset> get customPresets =>
      _presets.where((p) => !p.isBuiltIn).toList();

  /// Get a preset by ID
  FilterPreset? getPreset(String id) => _presetsById[id];

  /// Update filter state
  void updateFilterState(FilterState state) {
    _filterState = state;
    _filterStateController.add(_filterState);
  }

  /// Set quick search text
  void setSearchText(String text) {
    updateFilterState(_filterState.copyWith(searchText: text));
  }

  /// Clear quick search
  void clearSearch() {
    updateFilterState(_filterState.copyWith(searchText: ''));
  }

  /// Add a filter
  void addFilter(Filter filter) {
    updateFilterState(_filterState.copyWith(
      filters: [..._filterState.filters, filter],
    ));
  }

  /// Remove a filter
  void removeFilter(String id) {
    updateFilterState(_filterState.copyWith(
      filters: _filterState.filters.where((f) => f.maybeMap(
        simple: (s) => s.id != id,
        combined: (c) => c.id != id,
        quickSearch: (q) => q.id != id,
        orElse: () => true,
      )).toList(),
    ));
  }

  /// Clear all filters
  void clearFilters() {
    updateFilterState(const FilterState());
  }

  /// Apply a preset
  void applyPreset(String id) {
    final preset = _presetsById[id];
    if (preset != null) {
      // Update last used time
      final updatedPreset = preset.copyWith(lastUsedAt: DateTime.now());
      _presetsById[id] = updatedPreset;
      final index = _presets.indexWhere((p) => p.id == id);
      if (index != -1) {
        _presets[index] = updatedPreset;
        _presetController.add(presets);
      }

      updateFilterState(_filterState.copyWith(activePreset: updatedPreset));
    }
  }

  /// Clear active preset
  void clearPreset() {
    updateFilterState(_filterState.copyWith(activePreset: null));
  }

  /// Toggle show marked only
  void toggleShowMarkedOnly() {
    updateFilterState(_filterState.copyWith(
      showMarkedOnly: !_filterState.showMarkedOnly,
    ));
  }

  /// Toggle show errors only
  void toggleShowErrorsOnly() {
    updateFilterState(_filterState.copyWith(
      showErrorsOnly: !_filterState.showErrorsOnly,
    ));
  }

  /// Add hidden pattern
  void addHiddenPattern(String pattern) {
    if (!_filterState.hiddenPatterns.contains(pattern)) {
      updateFilterState(_filterState.copyWith(
        hiddenPatterns: [..._filterState.hiddenPatterns, pattern],
      ));
    }
  }

  /// Remove hidden pattern
  void removeHiddenPattern(String pattern) {
    updateFilterState(_filterState.copyWith(
      hiddenPatterns:
          _filterState.hiddenPatterns.where((p) => p != pattern).toList(),
    ));
  }

  /// Toggle method filter
  void toggleMethodFilter(HttpMethod method) {
    final methods = [..._filterState.selectedMethods];
    if (methods.contains(method)) {
      methods.remove(method);
    } else {
      methods.add(method);
    }
    updateFilterState(_filterState.copyWith(selectedMethods: methods));
  }

  /// Set status code filter
  void setStatusCodeFilter(List<int> codes) {
    updateFilterState(_filterState.copyWith(selectedStatusCodes: codes));
  }

  /// Set content type filter
  void setContentTypeFilter(List<String> types) {
    updateFilterState(_filterState.copyWith(selectedContentTypes: types));
  }

  /// Set date range filter
  void setDateRange(DateTime? from, DateTime? to) {
    updateFilterState(_filterState.copyWith(
      fromDate: from,
      toDate: to,
    ));
  }

  /// Save current filter state as a preset
  void saveAsPreset(String id, String name, {String? description}) {
    // Combine all active filters into one
    final activeFilters = <Filter>[];

    if (_filterState.searchText.isNotEmpty) {
      activeFilters.add(Filter.quickSearch(
        id: 'qs_$id',
        searchText: _filterState.searchText,
      ));
    }

    activeFilters.addAll(_filterState.filters);

    Filter combinedFilter;
    if (activeFilters.isEmpty) {
      combinedFilter = Filter.quickSearch(id: 'empty_$id', searchText: '');
    } else if (activeFilters.length == 1) {
      combinedFilter = activeFilters.first;
    } else {
      combinedFilter = Filter.combined(
        id: 'combined_$id',
        combinator: FilterCombinator.and,
        filters: activeFilters,
      );
    }

    final preset = FilterPreset(
      id: id,
      name: name,
      filter: combinedFilter,
      description: description,
      isBuiltIn: false,
      createdAt: DateTime.now(),
    );

    addPreset(preset);
  }

  /// Add a preset
  void addPreset(FilterPreset preset) {
    _presets.add(preset);
    _presetsById[preset.id] = preset;
    _presetController.add(presets);
  }

  /// Update a preset
  void updatePreset(FilterPreset preset) {
    final index = _presets.indexWhere((p) => p.id == preset.id);
    if (index != -1 && !_presets[index].isBuiltIn) {
      _presets[index] = preset;
      _presetsById[preset.id] = preset;
      _presetController.add(presets);
    }
  }

  /// Remove a preset
  void removePreset(String id) {
    final preset = _presetsById[id];
    if (preset != null && !preset.isBuiltIn) {
      _presets.removeWhere((p) => p.id == id);
      _presetsById.remove(id);

      // Clear active preset if it was the removed one
      if (_filterState.activePreset?.id == id) {
        updateFilterState(_filterState.copyWith(activePreset: null));
      }

      _presetController.add(presets);
    }
  }

  /// Build a filter from UI state
  static Filter buildFilter({
    FilterField? field,
    FilterOperator? operator,
    String? value,
    String? headerName,
  }) {
    if (field == null || operator == null || value == null) {
      throw ArgumentError('Field, operator, and value are required');
    }

    return Filter.simple(
      id: 'filter_${DateTime.now().millisecondsSinceEpoch}',
      field: field,
      operator: operator,
      value: value,
      headerName: headerName,
    );
  }

  /// Dispose of resources
  void dispose() {
    _filterStateController.close();
    _presetController.close();
  }
}

/// Common filter patterns for noise reduction
class NoisePatterns {
  static const List<String> commonNoise = [
    // Analytics
    'google-analytics.com',
    'analytics.google.com',
    'www.google-analytics.com',
    'stats.g.doubleclick.net',
    'facebook.com/tr',
    'connect.facebook.net',
    'bat.bing.com',

    // Fonts
    'fonts.googleapis.com',
    'fonts.gstatic.com',
    'use.typekit.net',

    // CDNs (may want to keep these)
    // 'cdn.jsdelivr.net',
    // 'cdnjs.cloudflare.com',

    // Social widgets
    'platform.twitter.com',
    'platform.linkedin.com',

    // Error tracking
    'sentry.io',
    'bugsnag.com',
    'rollbar.com',

    // Extensions
    'chrome-extension://',
    'moz-extension://',
  ];

  static const List<String> commonFileExtensions = [
    '.woff',
    '.woff2',
    '.ttf',
    '.eot',
    '.ico',
    '.map',
  ];
}
