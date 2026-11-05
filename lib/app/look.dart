/// Design-system-wide look flags, mirrored from [AppController] (the
/// source of truth, persisted in prefs) so paint-level code — card
/// shadows, glows, the workbench sheet — can read the current look
/// without threading a parameter through every widget. The controller
/// re-syncs this whenever the flags change, and pages rebuild on the
/// same notification, so what paints is always the current look.
class Look {
  static bool richShadows = true;
  static bool glowBlur = true;
  static bool liteRows = true;
}
