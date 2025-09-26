/// Status markers used throughout the application for consistent visual indicators
enum StatusMarker {
  success('[✓]'),
  error('[✗]'),
  warning('[!]'),
  bullet('•'),
  successBullet('✓'),
  errorBullet('✗'),
  warningBullet('!');

  final String symbol;

  const StatusMarker(this.symbol);

  @override
  String toString() => symbol;
}
