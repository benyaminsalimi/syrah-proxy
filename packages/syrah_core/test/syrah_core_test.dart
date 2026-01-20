/// Main test file for Syrah Core
///
/// Run all tests with: dart test
/// Run with coverage: dart test --coverage=coverage
library;

import 'models/filter_test.dart' as filter_test;
import 'models/http_models_test.dart' as http_models_test;
import 'services/filter_service_test.dart' as filter_service_test;
import 'utils/graphql_parser_test.dart' as graphql_parser_test;
import 'utils/curl_generator_test.dart' as curl_generator_test;
import 'utils/code_generator_test.dart' as code_generator_test;

void main() {
  // Model tests
  filter_test.main();
  http_models_test.main();

  // Service tests
  filter_service_test.main();

  // Utility tests
  graphql_parser_test.main();
  curl_generator_test.main();
  code_generator_test.main();
}
