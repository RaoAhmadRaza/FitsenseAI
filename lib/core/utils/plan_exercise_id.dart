// Deterministic plan exercise ID helper.
// Pattern: plan_<planId>ex<index>
class PlanExerciseId {
  static String build(String planId, int index) => 'plan_${planId}ex$index';
}
