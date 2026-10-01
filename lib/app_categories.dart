/// Kuratierte App-/Website-Kategorien für die Schnellauswahl beim Anlegen
/// einer Aufgabe ("Was soll während dieser Aufgabe blockiert sein?").
class AppCategory {
  final String name;
  final List<String> processes;
  final List<String> websites;

  const AppCategory({required this.name, this.processes = const [], this.websites = const []});
}

const appCategories = [
  AppCategory(
    name: 'Social Media',
    websites: [
      'instagram.com',
      'tiktok.com',
      'facebook.com',
      'twitter.com',
      'x.com',
      'reddit.com',
      'snapchat.com',
      'pinterest.com',
    ],
  ),
  AppCategory(
    name: 'Unterhaltung',
    processes: ['Spotify.exe', 'vlc.exe'],
    websites: ['youtube.com', 'netflix.com', 'primevideo.com', 'disneyplus.com', 'twitch.tv'],
  ),
  AppCategory(
    name: 'Gaming',
    processes: [
      'steam.exe',
      'EpicGamesLauncher.exe',
      'Battle.net.exe',
      'RiotClientServices.exe',
      'GalaxyClient.exe',
    ],
  ),
  AppCategory(
    name: 'Kommunikation',
    processes: ['WhatsApp.exe', 'Telegram.exe', 'slack.exe', 'Teams.exe', 'Discord.exe'],
    websites: ['web.whatsapp.com', 'web.telegram.org'],
  ),
  AppCategory(
    name: 'Shopping',
    websites: ['amazon.de', 'amazon.com', 'ebay.de', 'zalando.de'],
  ),
  AppCategory(
    name: 'News',
    websites: ['spiegel.de', 'bild.de', 'cnn.com', 'reddit.com'],
  ),
];
