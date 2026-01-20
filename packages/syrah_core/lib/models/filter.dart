import 'package:freezed_annotation/freezed_annotation.dart';

import 'network_flow.dart';
import 'http_request.dart';

part 'filter.freezed.dart';
part 'filter.g.dart';

/// Field to filter on
enum FilterField {
  url,
  host,
  path,
  method,
  statusCode,
  contentType,
  requestHeader,
  responseHeader,
  requestBody,
  responseBody,
  duration,
  size,
  protocol,
  state,
  tags,
}

/// Comparison operator for filter
enum FilterOperator {
  equals,
  notEquals,
  contains,
  notContains,
  startsWith,
  endsWith,
  regex,
  greaterThan,
  lessThan,
  greaterOrEqual,
  lessOrEqual,
  exists,
  notExists,
  inList,
  notInList,
}

/// Combinator for multiple filters
enum FilterCombinator {
  and,
  or,
}

/// Represents a filter condition
@freezed
class Filter with _$Filter {
  const Filter._();

  /// Simple filter on a field
  const factory Filter.simple({
    /// Unique identifier
    required String id,

    /// Field to filter on
    required FilterField field,

    /// Comparison operator
    required FilterOperator operator,

    /// Value to compare against
    required String value,

    /// For header filters, the header name
    String? headerName,

    /// Whether the filter is enabled
    @Default(true) bool isEnabled,
  }) = SimpleFilter;

  /// Combined filter with multiple conditions
  const factory Filter.combined({
    required String id,
    required FilterCombinator combinator,
    required List<Filter> filters,
    @Default(true) bool isEnabled,
  }) = CombinedFilter;

  /// Quick search filter (searches across multiple fields)
  const factory Filter.quickSearch({
    required String id,
    required String searchText,
    @Default(true) bool isEnabled,
  }) = QuickSearchFilter;

  factory Filter.fromJson(Map<String, dynamic> json) => _$FilterFromJson(json);

  /// Check if this filter matches the given flow
  bool matches(NetworkFlow flow) {
    return when(
      simple: (id, field, operator, value, headerName, isEnabled) {
        if (!isEnabled) return true;
        return _matchSimple(flow, field, operator, value, headerName);
      },
      combined: (id, combinator, filters, isEnabled) {
        if (!isEnabled) return true;
        if (filters.isEmpty) return true;

        if (combinator == FilterCombinator.and) {
          for (final filter in filters) {
            if (!filter.matches(flow)) return false;
          }
          return true;
        } else {
          for (final filter in filters) {
            if (filter.matches(flow)) return true;
          }
          return false;
        }
      },
      quickSearch: (id, searchText, isEnabled) {
        if (!isEnabled) return true;
        if (searchText.isEmpty) return true;
        return _matchQuickSearch(flow, searchText);
      },
    );
  }

  static bool _matchSimple(
    NetworkFlow flow,
    FilterField field,
    FilterOperator operator,
    String value,
    String? headerName,
  ) {
    final fieldValue = _getFieldValue(flow, field, headerName);

    switch (operator) {
      case FilterOperator.equals:
        return fieldValue?.toLowerCase() == value.toLowerCase();
      case FilterOperator.notEquals:
        return fieldValue?.toLowerCase() != value.toLowerCase();
      case FilterOperator.contains:
        return fieldValue?.toLowerCase().contains(value.toLowerCase()) ?? false;
      case FilterOperator.notContains:
        return !(fieldValue?.toLowerCase().contains(value.toLowerCase()) ??
            false);
      case FilterOperator.startsWith:
        return fieldValue?.toLowerCase().startsWith(value.toLowerCase()) ??
            false;
      case FilterOperator.endsWith:
        return fieldValue?.toLowerCase().endsWith(value.toLowerCase()) ?? false;
      case FilterOperator.regex:
        try {
          return RegExp(value).hasMatch(fieldValue ?? '');
        } catch (_) {
          return false;
        }
      case FilterOperator.greaterThan:
        final numValue = double.tryParse(value);
        final numField = double.tryParse(fieldValue ?? '');
        if (numValue == null || numField == null) return false;
        return numField > numValue;
      case FilterOperator.lessThan:
        final numValue = double.tryParse(value);
        final numField = double.tryParse(fieldValue ?? '');
        if (numValue == null || numField == null) return false;
        return numField < numValue;
      case FilterOperator.greaterOrEqual:
        final numValue = double.tryParse(value);
        final numField = double.tryParse(fieldValue ?? '');
        if (numValue == null || numField == null) return false;
        return numField >= numValue;
      case FilterOperator.lessOrEqual:
        final numValue = double.tryParse(value);
        final numField = double.tryParse(fieldValue ?? '');
        if (numValue == null || numField == null) return false;
        return numField <= numValue;
      case FilterOperator.exists:
        return fieldValue != null && fieldValue.isNotEmpty;
      case FilterOperator.notExists:
        return fieldValue == null || fieldValue.isEmpty;
      case FilterOperator.inList:
        final values =
            value.split(',').map((e) => e.trim().toLowerCase()).toList();
        return values.contains(fieldValue?.toLowerCase());
      case FilterOperator.notInList:
        final values =
            value.split(',').map((e) => e.trim().toLowerCase()).toList();
        return !values.contains(fieldValue?.toLowerCase());
    }
  }

  static String? _getFieldValue(
    NetworkFlow flow,
    FilterField field,
    String? headerName,
  ) {
    switch (field) {
      case FilterField.url:
        return flow.request.url;
      case FilterField.host:
        return flow.request.host;
      case FilterField.path:
        return flow.request.path;
      case FilterField.method:
        return flow.request.method.name;
      case FilterField.statusCode:
        return flow.response?.statusCode.toString();
      case FilterField.contentType:
        return flow.response?.contentTypeHeader ?? flow.request.contentTypeHeader;
      case FilterField.requestHeader:
        if (headerName == null) return null;
        return flow.request.getHeader(headerName);
      case FilterField.responseHeader:
        if (headerName == null) return null;
        return flow.response?.getHeader(headerName);
      case FilterField.requestBody:
        return flow.request.bodyText;
      case FilterField.responseBody:
        return flow.response?.bodyText;
      case FilterField.duration:
        return flow.duration?.inMilliseconds.toString();
      case FilterField.size:
        return flow.totalSize.toString();
      case FilterField.protocol:
        return flow.protocol.name;
      case FilterField.state:
        return flow.state.name;
      case FilterField.tags:
        return flow.tags.join(',');
    }
  }

  static bool _matchQuickSearch(NetworkFlow flow, String searchText) {
    final lowerSearch = searchText.toLowerCase();

    // Check URL
    if (flow.request.url.toLowerCase().contains(lowerSearch)) return true;

    // Check method
    if (flow.request.method.name.toLowerCase().contains(lowerSearch)) {
      return true;
    }

    // Check status code
    if (flow.response?.statusCode.toString().contains(lowerSearch) ?? false) {
      return true;
    }

    // Check content type
    if (flow.request.contentTypeHeader?.toLowerCase().contains(lowerSearch) ??
        false) {
      return true;
    }
    if (flow.response?.contentTypeHeader?.toLowerCase().contains(lowerSearch) ??
        false) {
      return true;
    }

    // Check tags
    for (final tag in flow.tags) {
      if (tag.toLowerCase().contains(lowerSearch)) return true;
    }

    // Check notes
    if (flow.notes?.toLowerCase().contains(lowerSearch) ?? false) return true;

    // Check body (limited search for performance)
    if (flow.request.bodyText?.toLowerCase().contains(lowerSearch) ?? false) {
      return true;
    }
    if (flow.response?.bodyText?.toLowerCase().contains(lowerSearch) ?? false) {
      return true;
    }

    return false;
  }
}

/// Represents a saved filter preset
@freezed
class FilterPreset with _$FilterPreset {
  const FilterPreset._();

  const factory FilterPreset({
    required String id,
    required String name,
    required Filter filter,
    String? description,
    @Default(false) bool isBuiltIn,
    required DateTime createdAt,
    DateTime? lastUsedAt,
  }) = _FilterPreset;

  factory FilterPreset.fromJson(Map<String, dynamic> json) =>
      _$FilterPresetFromJson(json);

  /// Built-in filter presets
  static List<FilterPreset> get builtInPresets => [
        FilterPreset(
          id: 'errors',
          name: 'Errors Only',
          filter: Filter.simple(
            id: 'errors-filter',
            field: FilterField.statusCode,
            operator: FilterOperator.greaterOrEqual,
            value: '400',
          ),
          description: 'Show only requests with status code >= 400',
          isBuiltIn: true,
          createdAt: DateTime.now(),
        ),
        FilterPreset(
          id: 'xhr',
          name: 'XHR/Fetch',
          filter: Filter.simple(
            id: 'xhr-filter',
            field: FilterField.contentType,
            operator: FilterOperator.contains,
            value: 'json',
          ),
          description: 'Show only JSON API requests',
          isBuiltIn: true,
          createdAt: DateTime.now(),
        ),
        FilterPreset(
          id: 'images',
          name: 'Images',
          filter: Filter.simple(
            id: 'images-filter',
            field: FilterField.contentType,
            operator: FilterOperator.contains,
            value: 'image',
          ),
          description: 'Show only image requests',
          isBuiltIn: true,
          createdAt: DateTime.now(),
        ),
        FilterPreset(
          id: 'slow',
          name: 'Slow Requests',
          filter: Filter.simple(
            id: 'slow-filter',
            field: FilterField.duration,
            operator: FilterOperator.greaterThan,
            value: '1000',
          ),
          description: 'Show requests taking > 1 second',
          isBuiltIn: true,
          createdAt: DateTime.now(),
        ),
        FilterPreset(
          id: 'large',
          name: 'Large Responses',
          filter: Filter.simple(
            id: 'large-filter',
            field: FilterField.size,
            operator: FilterOperator.greaterThan,
            value: '1000000',
          ),
          description: 'Show responses > 1MB',
          isBuiltIn: true,
          createdAt: DateTime.now(),
        ),
      ];
}

/// Active filter state for the UI
@freezed
class FilterState with _$FilterState {
  const FilterState._();

  const factory FilterState({
    /// Quick search text
    @Default('') String searchText,

    /// Active filters
    @Default([]) List<Filter> filters,

    /// Selected preset
    FilterPreset? activePreset,

    /// Show only marked flows
    @Default(false) bool showMarkedOnly,

    /// Show only flows with errors
    @Default(false) bool showErrorsOnly,

    /// Hide flows matching certain patterns (noise reduction)
    @Default([]) List<String> hiddenPatterns,

    /// Selected methods to show
    @Default([]) List<HttpMethod> selectedMethods,

    /// Selected status codes to show
    @Default([]) List<int> selectedStatusCodes,

    /// Selected content types to show
    @Default([]) List<String> selectedContentTypes,

    /// Date range filter
    DateTime? fromDate,
    DateTime? toDate,
  }) = _FilterState;

  factory FilterState.fromJson(Map<String, dynamic> json) =>
      _$FilterStateFromJson(json);

  /// Check if any filter is active
  bool get hasActiveFilter =>
      searchText.isNotEmpty ||
      filters.isNotEmpty ||
      activePreset != null ||
      showMarkedOnly ||
      showErrorsOnly ||
      hiddenPatterns.isNotEmpty ||
      selectedMethods.isNotEmpty ||
      selectedStatusCodes.isNotEmpty ||
      selectedContentTypes.isNotEmpty ||
      fromDate != null ||
      toDate != null;

  /// Check if a flow matches all active filters
  bool matches(NetworkFlow flow) {
    // Quick search
    if (searchText.isNotEmpty) {
      if (!Filter.quickSearch(id: 'quick', searchText: searchText)
          .matches(flow)) {
        return false;
      }
    }

    // Active filters
    for (final filter in filters) {
      if (!filter.matches(flow)) return false;
    }

    // Active preset
    if (activePreset != null && !activePreset!.filter.matches(flow)) {
      return false;
    }

    // Marked only
    if (showMarkedOnly && !flow.isMarked) return false;

    // Errors only
    if (showErrorsOnly && flow.state != FlowState.failed) {
      if (flow.response == null || !flow.response!.isError) return false;
    }

    // Hidden patterns
    for (final pattern in hiddenPatterns) {
      if (flow.request.url.contains(pattern)) return false;
    }

    // Selected methods
    if (selectedMethods.isNotEmpty &&
        !selectedMethods.contains(flow.request.method)) {
      return false;
    }

    // Selected status codes
    if (selectedStatusCodes.isNotEmpty &&
        flow.response != null &&
        !selectedStatusCodes.contains(flow.response!.statusCode)) {
      return false;
    }

    // Selected content types
    if (selectedContentTypes.isNotEmpty) {
      final ct = flow.response?.contentTypeHeader ?? '';
      bool matches = false;
      for (final type in selectedContentTypes) {
        if (ct.contains(type)) {
          matches = true;
          break;
        }
      }
      if (!matches) return false;
    }

    // Date range
    if (fromDate != null && flow.createdAt.isBefore(fromDate!)) return false;
    if (toDate != null && flow.createdAt.isAfter(toDate!)) return false;

    return true;
  }
}
