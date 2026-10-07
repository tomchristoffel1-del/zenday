/// Welche lokalen Schlüssel zwischen Geräten abgeglichen werden. Bewusst eine
/// Positivliste: geräteabhängige Dinge (Fokus-Modus, Blocklisten, App-Limits,
/// Nutzungszähler, Autostart, Designmodus) bleiben lokal.
const _exactKeys = {
  'zenday_templates',
  'zenday_onboarded',
  'zenday_focus_points',
  'zenday_study_modules',
  'zenday_assignments',
  'zenday_study_running_start',
};

const _prefixes = [
  'zenday_adhoc_',
  'zenday_tpldone_',
  'zenday_order_',
  'zenday_dayfocus_',
  'zenday_tracking_',
  'zenday_ssess_',
  'zenday_income_',
];

bool isSyncableKey(String key) => _exactKeys.contains(key) || _prefixes.any(key.startsWith);
