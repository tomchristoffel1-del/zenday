/// Meilensteine für die Fokuspunkte: pro erledigter Aufgabe gibt es einen
/// Punkt. Bei Erreichen eines Meilensteins wird eine kleine Belohnung
/// angezeigt. Bewusst simpel gehalten – reine Anerkennung, keine externen
/// Systeme oder Käufe.
class RewardMilestone {
  final int points;
  final String title;
  final String message;
  const RewardMilestone(this.points, this.title, this.message);
}

const rewardMilestones = [
  RewardMilestone(10, 'Guter Start', 'Zehn Aufgaben erledigt. Der Plan lebt.'),
  RewardMilestone(25, 'Im Fluss', '25 Punkte – gönn dir heute eine bewusste Pause.'),
  RewardMilestone(50, 'Halber Hundert', '50 Punkte. Zeit für eine kleine Belohnung deiner Wahl.'),
  RewardMilestone(100, 'Hundert', '100 Punkte gesammelt – das ist echte Konstanz.'),
  RewardMilestone(250, 'Tiefe Routine', '250 Punkte. Gönn dir etwas Größeres.'),
  RewardMilestone(500, 'Meisterhaft', '500 Punkte – dein Plan trägt dich zuverlässig.'),
];

/// Findet den zuletzt überschrittenen Meilenstein für die Anzeige, oder
/// null, falls [points] noch keinen erreicht hat.
RewardMilestone? milestoneJustCrossed(int before, int after) {
  for (final m in rewardMilestones) {
    if (before < m.points && after >= m.points) return m;
  }
  return null;
}
