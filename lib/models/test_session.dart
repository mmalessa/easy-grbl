import 'svg_document.dart';
import 'focus_test_config.dart';
import 'kerf_test_config.dart';
import 'spot_test_config.dart';

/// Which template-test panel (if any) is active, bundled with the preview
/// document it generated. Exactly one variant can be active at a time —
/// replaces three independent show/config/document flag triples that could
/// previously go out of sync with each other (e.g. two tests active at once
/// because switching to one test didn't reset the others).
sealed class TestSession {
  const TestSession();
}

class NoTestSession extends TestSession {
  const NoTestSession();
}

class FocusTestSession extends TestSession {
  final FocusTestConfig config;
  final SvgDocument document;
  const FocusTestSession(this.config, this.document);
}

class KerfTestSession extends TestSession {
  final KerfTestConfig config;
  final SvgDocument document;
  const KerfTestSession(this.config, this.document);
}

class SpotTestSession extends TestSession {
  final SpotTestConfig config;
  final SvgDocument document;
  const SpotTestSession(this.config, this.document);
}
