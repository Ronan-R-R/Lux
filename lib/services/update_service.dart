import 'dart:convert';
import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  final String repoOwner;
  final String repoName;

  UpdateService({required this.repoOwner, required this.repoName});

  /// Checks GitHub releases API for a newer tag and returns a URL to download if available
  Future<String?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. 1.0.0

      final httpClient = HttpClient();
      final request = await httpClient.getUrl(
          Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest'));
      request.headers.set('User-Agent', 'Lux-Update-Service');
      final response = await request.close();
      
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody);
        
        final latestVersion = data['tag_name'] as String; // e.g. v1.0.1
        final cleanLatest = latestVersion.replaceAll('v', '');

        if (_isNewer(currentVersion, cleanLatest)) {
          // Find asset for current platform
          final assets = data['assets'] as List;
          String? downloadUrl;
          
          if (Platform.isAndroid) {
            final apkAsset = assets.firstWhere((a) => a['name'].toString().contains('.apk'), orElse: () => null);
            if (apkAsset != null) downloadUrl = apkAsset['browser_download_url'];
          } else if (Platform.isWindows) {
             final exeAsset = assets.firstWhere((a) => a['name'].toString().contains('.exe') || a['name'].toString().contains('.zip'), orElse: () => null);
             if (exeAsset != null) downloadUrl = exeAsset['browser_download_url'];
          }
          
          return downloadUrl ?? data['html_url']; // Fallback to release page
        }
      }
    } catch (e) {
      // Intentionally swallow errors so it doesn't break the app flow
      print("Update check failed: $e");
    }
    return null;
  }

  bool _isNewer(String current, String latest) {
    List<int> currParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
        int c = i < currParts.length ? currParts[i] : 0;
        int l = i < latestParts.length ? latestParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
    }
    return false;
  }

  Future<void> launchDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
