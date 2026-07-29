@import XCTest;
@import patrol;
@import ObjectiveC.runtime;

// Patrol's iOS entrypoint. Expands into an XCUITest class that Patrol's
// runtime introspects to discover the Dart tests bundled by patrol_cli
// into `integration_test/test_bundle.dart`. All real test logic lives in
// Dart — do not add XCUITest assertions here.
PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
