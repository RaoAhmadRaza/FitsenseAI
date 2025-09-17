/// Centralized route names & helpers for dynamic segments.
class AppRoutes {
  // Static base routes
  static const home = '/home';
  static const plans = '/plans';
  static const history = '/history';
  static const profile = '/profile';
  static const sensors = '/sensors';

  // Dynamic patterns (documentation only)
  // /plans/:id
  // /workout/:sessionId
  // /session/summary/:sessionId

  static String planDetail(String planId) => '/plans/$planId';
  static String workout(String sessionId) => '/workout/$sessionId';
  static String sessionSummary(String sessionId) =>
      '/session/summary/$sessionId';
}
