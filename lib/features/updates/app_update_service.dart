import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GithubReleaseAsset {
  const GithubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
  });

  final String name;
  final String downloadUrl;
  final int sizeBytes;

  String get formattedSize {
    if (sizeBytes <= 0) return 'APK';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class GithubReleaseInfo {
  const GithubReleaseInfo({
    required this.tagName,
    required this.title,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.isPrerelease,
    required this.assets,
  });

  final String tagName;
  final String title;
  final String body;
  final String htmlUrl;
  final DateTime? publishedAt;
  final bool isPrerelease;
  final List<GithubReleaseAsset> assets;

  String get cleanVersion {
    final raw = tagName.trim();
    return raw.startsWith('v') || raw.startsWith('V') ? raw.substring(1) : raw;
  }

  /// Selects the best APK asset from the GitHub release (preferring arm64-v8a or universal .apk).
  GithubReleaseAsset? get preferredApkAsset {
    final apkAssets = assets
        .where((a) => a.name.toLowerCase().endsWith('.apk'))
        .toList();
    if (apkAssets.isEmpty) return null;
    for (final asset in apkAssets) {
      final lower = asset.name.toLowerCase();
      if (lower.contains('arm64') || lower.contains('v8a')) {
        return asset;
      }
    }
    return apkAssets.first;
  }

  String get formattedDate {
    final dt = publishedAt;
    if (dt == null) return 'GitHub Release';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.repository,
    this.latestRelease,
    this.allReleases = const [],
    required this.isUpdateAvailable,
    required this.checkedAt,
    this.errorMessage,
  });

  final String currentVersion;
  final int currentBuildNumber;
  final String repository;
  final GithubReleaseInfo? latestRelease;
  final List<GithubReleaseInfo> allReleases;
  final bool isUpdateAvailable;
  final DateTime checkedAt;
  final String? errorMessage;
}

class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String defaultGithubRepo = 'ossy-harz/Tone';
  static const String _repoPrefKey = 'tone_github_update_repo';
  static const String _autoCheckPrefKey = 'tone_github_auto_check_updates';
  static const String _includePrereleasesPrefKey = 'tone_github_include_prereleases';
  static const String _skippedTagPrefKey = 'tone_github_skipped_tag';
  static const MethodChannel _channel = MethodChannel('app.melo.melo_player/library');

  String _currentVersion = '1.2.0';
  int _currentBuildNumber = 3;

  /// Opens an external web URL using the Android platform channel or intent.
  static Future<bool> openExternalUrl(String url) async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final ok = await _channel.invokeMethod<bool>('openUrl', {'url': url});
        return ok ?? false;
      }
    } catch (_) {}
    return false;
  }
  String _repository = defaultGithubRepo;
  bool _autoCheckOnStartup = true;
  bool _includePrereleases = false;
  AppUpdateCheckResult? _lastResult;
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadedApkPath;

  String get currentVersion => _currentVersion;
  int get currentBuildNumber => _currentBuildNumber;
  String get repository => _repository;
  bool get autoCheckOnStartup => _autoCheckOnStartup;
  bool get includePrereleases => _includePrereleases;
  AppUpdateCheckResult? get lastResult => _lastResult;
  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get downloadedApkPath => _downloadedApkPath;

  bool get hasUpdateAvailable => _lastResult?.isUpdateAvailable == true;

  Future<void> initialize({bool runStartupCheck = true}) async {
    final prefs = await SharedPreferences.getInstance();
    _repository = prefs.getString(_repoPrefKey)?.trim().isNotEmpty == true
        ? prefs.getString(_repoPrefKey)!.trim()
        : defaultGithubRepo;
    _autoCheckOnStartup = prefs.getBool(_autoCheckPrefKey) ?? true;
    _includePrereleases = prefs.getBool(_includePrereleasesPrefKey) ?? false;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final info = await _channel.invokeMapMethod<String, dynamic>('getAppVersion');
        if (info != null) {
          _currentVersion = (info['versionName'] as String?) ?? '1.0.0';
          _currentBuildNumber = (info['versionCode'] as num?)?.toInt() ?? 1;
        }
      } catch (_) {}
    }
    notifyListeners();

    if (runStartupCheck && _autoCheckOnStartup) {
      unawaited(checkForUpdates(silent: true));
    }
  }

  Future<void> setRepository(String repo) async {
    final clean = repo
        .trim()
        .replaceFirst(RegExp(r'^https?://github\.com/'), '')
        .replaceFirst(RegExp(r'\.git$'), '')
        .replaceAll(RegExp(r'^/|/$'), '');
    final target = clean.isEmpty ? defaultGithubRepo : clean;
    _repository = target;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_repoPrefKey, target);
    notifyListeners();
  }

  Future<void> setAutoCheckOnStartup(bool enabled) async {
    _autoCheckOnStartup = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckPrefKey, enabled);
    notifyListeners();
  }

  Future<void> setIncludePrereleases(bool enabled) async {
    _includePrereleases = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_includePrereleasesPrefKey, enabled);
    notifyListeners();
  }

  Future<void> skipReleaseTag(String tag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skippedTagPrefKey, tag);
    notifyListeners();
  }

  /// Fetches all releases from GitHub (`https://api.github.com/repos/<owner>/<repo>/releases`)
  /// and checks whether a newer version than [currentVersion] is available.
  Future<AppUpdateCheckResult> checkForUpdates({bool silent = false}) async {
    if (_isChecking && _lastResult != null) return _lastResult!;
    _isChecking = true;
    notifyListeners();

    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/$_repository/releases?per_page=15',
      );
      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Tone-Music-Player-Updater',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 404) {
        final result = AppUpdateCheckResult(
          currentVersion: _currentVersion,
          currentBuildNumber: _currentBuildNumber,
          repository: _repository,
          isUpdateAvailable: false,
          checkedAt: DateTime.now(),
          errorMessage:
              'No GitHub releases published yet on github.com/$_repository. Push a tag (e.g. v1.0.1) to publish your first release.',
        );
        _lastResult = result;
        return result;
      }

      if (response.statusCode != 200) {
        throw StateError('GitHub API returned HTTP ${response.statusCode}');
      }

      final rawList = jsonDecode(response.body);
      if (rawList is! List) {
        throw const FormatException('Unexpected GitHub releases payload');
      }

      final releases = <GithubReleaseInfo>[];
      for (final item in rawList) {
        if (item is! Map<String, dynamic>) continue;
        if (item['draft'] == true) continue;
        final isPre = item['prerelease'] == true;
        if (isPre && !_includePrereleases) continue;

        final tagName = (item['tag_name'] as String? ?? '').trim();
        if (tagName.isEmpty) continue;
        final title = (item['name'] as String?)?.trim().isNotEmpty == true
            ? (item['name'] as String).trim()
            : tagName;
        final body = (item['body'] as String? ?? '').trim();
        final htmlUrl = (item['html_url'] as String? ??
                'https://github.com/$_repository/releases')
            .trim();
        final publishedAt = DateTime.tryParse(
          item['published_at'] as String? ?? '',
        );

        final rawAssets = item['assets'] as List? ?? const [];
        final assets = <GithubReleaseAsset>[];
        for (final a in rawAssets) {
          if (a is! Map<String, dynamic>) continue;
          final name = (a['name'] as String? ?? '').trim();
          final url = (a['browser_download_url'] as String? ?? '').trim();
          final size = (a['size'] as num?)?.toInt() ?? 0;
          if (name.isNotEmpty && url.isNotEmpty) {
            assets.add(
              GithubReleaseAsset(
                name: name,
                downloadUrl: url,
                sizeBytes: size,
              ),
            );
          }
        }

        releases.add(
          GithubReleaseInfo(
            tagName: tagName,
            title: title,
            body: body.isEmpty
                ? 'Performance improvements, audio engine refinements, and bug fixes.'
                : body,
            htmlUrl: htmlUrl,
            publishedAt: publishedAt,
            isPrerelease: isPre,
            assets: assets,
          ),
        );
      }

      if (releases.isEmpty) {
        final result = AppUpdateCheckResult(
          currentVersion: _currentVersion,
          currentBuildNumber: _currentBuildNumber,
          repository: _repository,
          allReleases: const [],
          isUpdateAvailable: false,
          checkedAt: DateTime.now(),
          errorMessage:
              'No public releases found on github.com/$_repository/releases yet.',
        );
        _lastResult = result;
        return result;
      }

      final latest = releases.first;
      final isNewer = isRemoteVersionNewer(
        currentVersion: _currentVersion,
        currentBuild: _currentBuildNumber,
        remoteTag: latest.tagName,
      );

      final result = AppUpdateCheckResult(
        currentVersion: _currentVersion,
        currentBuildNumber: _currentBuildNumber,
        repository: _repository,
        latestRelease: latest,
        allReleases: releases,
        isUpdateAvailable: isNewer,
        checkedAt: DateTime.now(),
      );
      _lastResult = result;
      return result;
    } catch (e) {
      final result = AppUpdateCheckResult(
        currentVersion: _currentVersion,
        currentBuildNumber: _currentBuildNumber,
        repository: _repository,
        isUpdateAvailable: false,
        checkedAt: DateTime.now(),
        errorMessage: silent ? null : 'Could not check GitHub releases: $e',
      );
      _lastResult = result;
      return result;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Compares semantic versions (e.g. `1.0.0+1` vs `v1.1.0` or `v1.0.0+2`).
  @visibleForTesting
  static bool isRemoteVersionNewer({
    required String currentVersion,
    required int currentBuild,
    required String remoteTag,
  }) {
    final (curParts, curBuildFromStr) = _parseVersion(currentVersion);
    final (remParts, remBuild) = _parseVersion(remoteTag);
    final effectiveCurBuild = curBuildFromStr > 0 ? curBuildFromStr : currentBuild;

    for (var i = 0; i < 3; i++) {
      final c = i < curParts.length ? curParts[i] : 0;
      final r = i < remParts.length ? remParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    if (remBuild > effectiveCurBuild) return true;
    return false;
  }

  static (List<int>, int) _parseVersion(String raw) {
    var clean = raw.trim();
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1);
    }
    var buildNumber = 0;
    if (clean.contains('+')) {
      final plusParts = clean.split('+');
      clean = plusParts.first;
      buildNumber = int.tryParse(plusParts.last.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
    // Strip pre-release suffix like -beta.1 for numeric core comparison
    final core = clean.split('-').first;
    final nums = core
        .split('.')
        .map((s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    return (nums, buildNumber);
  }

  /// Checks whether an APK file for [release] has already been downloaded and is ready to install.
  Future<File?> getDownloadedApkFile(GithubReleaseInfo release) async {
    try {
      final asset = release.preferredApkAsset;
      if (asset == null) return null;
      final tempDir = await getTemporaryDirectory();
      final safeTag = release.cleanVersion.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      
      final candidates = [
        File('${tempDir.path}/melo_update_$safeTag.apk'),
        File('${tempDir.path}/tone_update_$safeTag.apk'),
      ];

      for (final file in candidates) {
        if (await file.exists()) {
          final len = await file.length();
          if (len > 1024 * 500) {
            _downloadedApkPath = file.path;
            return file;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Downloads the APK asset from GitHub Releases into cache and triggers the Android Package Installer.
  /// If the release APK has already been downloaded previously, it launches installation immediately without re-downloading.
  Future<String> downloadAndInstallRelease(GithubReleaseInfo release) async {
    final asset = release.preferredApkAsset;
    if (asset == null) {
      throw StateError(
        'Release ${release.tagName} does not have an .apk file attached yet.',
      );
    }

    // Check if the APK has already been downloaded to avoid unnecessary re-downloading.
    final existingApk = await getDownloadedApkFile(release);
    if (existingApk != null) {
      _downloadedApkPath = existingApk.path;
      _downloadProgress = 1.0;
      notifyListeners();
      return installAlreadyDownloadedApk(existingApk.path);
    }

    if (_isDownloading) {
      throw StateError('An update download is already in progress.');
    }

    _isDownloading = true;
    _downloadProgress = 0.01;
    notifyListeners();

    final client = http.Client();
    try {
      final tempDir = await getTemporaryDirectory();
      final safeTag = release.cleanVersion.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final outFile = File('${tempDir.path}/melo_update_$safeTag.apk');

      final req = http.Request('GET', Uri.parse(asset.downloadUrl));
      req.headers['User-Agent'] = 'Melo-Music-Player-Updater';
      final res = await client.send(req).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200 && res.statusCode != 206) {
        throw StateError('Download failed (HTTP ${res.statusCode})');
      }

      final totalBytes = res.contentLength ?? asset.sizeBytes;
      var receivedBytes = 0;
      final sink = outFile.openWrite();
      try {
        await for (final chunk in res.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            _downloadProgress = (receivedBytes / totalBytes).clamp(0.01, 1.0);
            notifyListeners();
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      _downloadedApkPath = outFile.path;
      _downloadProgress = 1.0;
      notifyListeners();

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final status = await _channel.invokeMethod<String>(
          'installUpdateApk',
          {'apkPath': outFile.path},
        );
        return status ?? 'INSTALLER_LAUNCHED';
      }
      return outFile.path;
    } finally {
      client.close();
      _isDownloading = false;
      notifyListeners();
    }
  }

  /// Re-triggers the Android APK installer if an APK has already been downloaded.
  Future<String> installAlreadyDownloadedApk(String apkPath) async {
    final status = await _channel.invokeMethod<String>(
      'installUpdateApk',
      {'apkPath': apkPath},
    );
    return status ?? 'INSTALLER_LAUNCHED';
  }
}
