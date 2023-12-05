import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pica_comic/foundation/app.dart';
import 'package:pica_comic/foundation/log.dart';
import 'package:pica_comic/tools/io_tools.dart';
import 'package:pica_comic/tools/translations.dart';
import 'package:webdav_client/webdav_client.dart';
import '../base.dart';
import '../views/widgets/loading.dart';
import '../views/widgets/show_message.dart';
import 'package:flutter/material.dart';

class Webdav {
  static bool _isOperating = false;

  static bool _haveWaitingTask = false;

  /// Sync current data to webdav server. Return true if success.
  static Future<bool> uploadData([String? config]) async {
    if (_haveWaitingTask) {
      return true;
    }
    if (_isOperating) {
      _haveWaitingTask = true;
      while (_isOperating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    _haveWaitingTask = false;
    _isOperating = true;
    appdata.settings[46] =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    appdata.updateSettings();
    config ??= appdata.settings[45];
    var configs = config.split(';');
    if (configs.length != 4 || configs.elementAtOrNull(0) == "") {
      _isOperating = false;
      return true;
    }
    if (!configs[3].endsWith('/') && !configs[3].endsWith('\\')) {
      configs[3] += '/';
    }
    LogManager.addLog(LogLevel.info, "network", "Uploading Data");
    var client = newClient(
      configs[0],
      user: configs[1],
      password: configs[2],
      debug: false,
    );
    client.setHeaders({'content-type': 'text/plain'});
    try {
      await client.writeFromFile(
          await exportDataToFile(false), "${configs[3]}picadata");
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Sync",
          "Failed to upload data to webdav server.\n$s");
      _isOperating = false;
      return false;
    }
    _isOperating = false;
    return true;
  }

  static Future<bool> downloadData([String? config]) async {
    _isOperating = true;
    try {
      config ??= appdata.settings[45];
      var configs = config.split(';');
      if (configs.length != 4 || configs.elementAtOrNull(0) == "") {
        return true;
      }
      if (!configs[3].endsWith('/') && !configs[3].endsWith('\\')) {
        configs[3] += '/';
      }
      LogManager.addLog(LogLevel.info, "network", "Downloading Data");
      var client = newClient(
        configs[0],
        user: configs[1],
        password: configs[2],
        debug: false,
      );
      try {
        var cachePath = (await getApplicationCacheDirectory()).path;
        await client.read2File("${configs[3]}picadata",
            "$cachePath${Platform.pathSeparator}picadata");
        var res =
            await importData("$cachePath${Platform.pathSeparator}picadata");
        return res;
      } catch (e, s) {
        LogManager.addLog(LogLevel.error, "Sync",
            "Failed to download data from webdav server.\n$s");
        return false;
      }
    } finally {
      _isOperating = false;
    }
  }

  static void syncData() async {
    var configs = appdata.settings[45].split(';');
    if (configs.length != 4 || configs.elementAtOrNull(0) == "") {
      return;
    }
    var controller = showLoadingDialog(App.globalContext!, () {}, false, true, "同步数据中".tl, "隐藏".tl);
    var res = await Webdav.downloadData();
    await Future.delayed(const Duration(milliseconds: 50));
    if (!res) {
      controller.close();
      appdata.settings[45] = "${appdata.settings[45]};0";
      showMessage(App.globalContext, "下载数据失败, 已禁用同步",
          action:
              TextButton(onPressed: () {
                appdata.settings[45] = configs.join(';');
                syncData();
              }, child: Text("重试".tl,
                style: TextStyle(color: App.colors(App.globalContext!).inversePrimary),)));
    } else {
      controller.close();
    }
  }
}
