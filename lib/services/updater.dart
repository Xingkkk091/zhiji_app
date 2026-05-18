import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 查 GitHub Releases 看有沒有新版本。
/// 規則: 比對 latest release 的 tag 跟 pubspec.yaml 的 version。
/// tag 格式: v1.0.1 或 1.0.1 都可。
class Updater {
  final String owner;
  final String repo;
  Updater({required this.owner, required this.repo});

  Future<_Release?> _fetchLatest() async {
    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
    try {
      final res = await http.get(url, headers: {'Accept': 'application/vnd.github+json'});
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String?)?.replaceFirst(RegExp(r'^v'), '');
      final htmlUrl = j['html_url'] as String?;
      String? apkUrl;
      final assets = j['assets'] as List<dynamic>?;
      if (assets != null) {
        for (final a in assets) {
          final m = a as Map<String, dynamic>;
          final name = m['name'] as String? ?? '';
          if (name.toLowerCase().endsWith('.apk')) {
            apkUrl = m['browser_download_url'] as String?;
            break;
          }
        }
      }
      if (tag == null) return null;
      return _Release(tag: tag, htmlUrl: htmlUrl, apkUrl: apkUrl);
    } catch (_) {
      return null;
    }
  }

  Future<void> checkAndPrompt(BuildContext context, {bool silent = false}) async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version;
    final latest = await _fetchLatest();
    if (latest == null) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法取得更新資訊')),
        );
      }
      return;
    }

    final isNewer = _compareVersion(latest.tag, current) > 0;
    if (!isNewer) {
      if (!silent && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已是最新版 v$current')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('有新版本 v${latest.tag}'),
        content: Text('目前 v$current → 最新 v${latest.tag}\n\n打開下載頁面安裝？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('稍後')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('前往下載')),
        ],
      ),
    );
    if (go == true) {
      final url = latest.apkUrl ?? latest.htmlUrl;
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  /// 1.2.3 vs 1.2.4 → 比較版本字串
  static int _compareVersion(String a, String b) {
    final pa = a.split('.').map(int.tryParse).map((e) => e ?? 0).toList();
    final pb = b.split('.').map(int.tryParse).map((e) => e ?? 0).toList();
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final ai = i < pa.length ? pa[i] : 0;
      final bi = i < pb.length ? pb[i] : 0;
      if (ai != bi) return ai - bi;
    }
    return 0;
  }
}

class _Release {
  final String tag;
  final String? htmlUrl;
  final String? apkUrl;
  _Release({required this.tag, this.htmlUrl, this.apkUrl});
}
