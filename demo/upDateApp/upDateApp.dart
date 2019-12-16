import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:meibohui/projectConfig.dart';
import 'package:path_provider/path_provider.dart';
import 'package:meibohui/util/event_bus.dart';
import 'package:package_info/package_info.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/*  
  # 使用的包以及版本
  url_launcher: ^5.2.5 # url转跳插件
  package_info: ^0.4.0+12 #获取app信息
  device_info: ^0.4.1+3 #获取版本信息
  event_bus: ^1.1.0 #事件监听
  permission_handler: ^4.0.0 #权限处理
  install_plugin: ^2.0.1 #Apk安装插件
 */

/// APP更新类
class UpdateApk {
  static String _version;
  static String _flatform;

  /// 检查是否有更新
  ///
  /// @params server 服务器地址
  ///
  /// @query query 服务器传参
  static checkUpdate({
    @required String server,
    @required Map query,
  }) async {
    /// 获取app版本
    _version = await _checkAppInfo();

    /// 获取运行环境 ios & android
    _flatform = await getFlatForm();

    /// 获取服务器版本
    Map _hotVersion = await _fetchVersionInfo(serverUrl: server, query: query);

    /// 对比本地与线上
    ///
    /// 为了方便在这里要求了一下格式，hotVersion返回要带有version字段，与服务器沟通这块仁者见仁智者见智，可自行实现
    if (_version != _hotVersion["version"]) {
      switch (_flatform) {
        case "android":

          /// 检查权限
          bool result = await _checkPermission();
          if (result) {
            /// 广播事件 andriod
            eventBus.fire(new UpDateInfo(
                custom: _hotVersion,
                url: _hotVersion["path"],
                force: _hotVersion["force"],
                flatform: "andriod",
                version: _hotVersion["version"]));
          } else {
            /// 广播事件 ios
            eventBus.fire(new UpDateInfo(flatform: "ios"));
            return false;
          }
          break;
        case "ios":
          break;
        default:
      }
    }
  }

  /// 获取APP版本号
  static Future _checkAppInfo() async {
    // 获取app详情
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    // 获取app版本信息
    _version = packageInfo.version;
    return _version;
  }

  /// 检查是否有权限，用于安卓
  ///
  /// @return bool
  static Future<bool> _checkPermission() async {
    if (_flatform == 'android') {
      PermissionStatus permission = await PermissionHandler()
          .checkPermissionStatus(PermissionGroup.storage);
      if (permission != PermissionStatus.granted) {
        Map<PermissionGroup, PermissionStatus> permissions =
            await PermissionHandler()
                .requestPermissions([PermissionGroup.storage]);
        if (permissions[PermissionGroup.storage] == PermissionStatus.granted) {
          return true;
        }
      } else {
        return true;
      }
    } else {
      return true;
    }
    return false;
  }

  /// 获取平台信息
  ///
  /// @return "android" || "ios"
  static Future<String> getFlatForm() async {
    String flatform;
    if (Platform.isAndroid) {
      flatform = 'android';
    } else {
      flatform = 'ios';
    }
    return flatform;
  }

  /// 拉取版本号信息
  ///
  /// @param serverUrl [post]服务器地址
  ///
  /// @param query 传参
  ///
  /// @return 当前服务器在线版本及详情
  ///
  static Future<Map> _fetchVersionInfo(
      {@required String serverUrl, Map query}) async {
    Response res = await Dio().post(serverUrl, data: query);

    /// Json序列化
    String dataStr = json.encode(res.data);

    /// 返回Map
    Map<String, dynamic> dataMap = json.decode(dataStr);
    return dataMap;
  }

  /// 下载安卓更新包
  ///
  /// @return File文件
  static Future downloadAndroid({String url, String version}) async {
    /// 创建存储文件
    Directory storageDir = await getExternalStorageDirectory();
    String storagePath = storageDir.path;
    print("====>本地版本$_version");
    print("====>版本$version");

    /// 储存目录下寻找文件 `PorjectConfig`项目设置，自己配置
    File file = new File('$storagePath/${PorjectConfig.appName}v$version.apk');
    print("文件是否存在====>${file.existsSync()}");

    /// 检查文件是否存在
    if (!file.existsSync()) {
      // 不存在则创建
      file.createSync();
    } else {
      // 存在则删除
      // file.deleteSync();
      // 也可以直接调用
      installApk(apkFile: file, success: () {});
      return false;
    }
    try {
      /// 发起下载请求
      Response response = await Dio().get("${PorjectConfig.appUpdateUrl}$url",
          onReceiveProgress: showDownloadProgress,
          options: Options(
            responseType: ResponseType.bytes,
            followRedirects: false,
          ));

      /// 读取文件
      file.writeAsBytesSync(response.data);
      return file;
    } catch (e) {
      return file;
    }
  }

  /// 处理下载进度
  ///
  /// 使用eventBus监听`UpdateAndroidProgressEvent`类中的`progress`获取从`doubule 0.0 - double 1.0`的下载进度
  static void showDownloadProgress(num received, num total) {
    if (total != -1) {
      double _progress =
          double.parse('${(received / total).toStringAsFixed(2)}');

      /// 广播进度
      eventBus.fire(new UpdateAndroidProgressEvent(_progress));
    }
  }

  /// 安装apk
  ///
  /// @params 传入File类型
  ///
  /// @params @require success & error 安装事件回调
  ///
  /// @return void
  static Future<Null> installApk(
      {@required File apkFile,
      @required Function success,
      Function error}) async {
    /// 获取文件路径
    String _apkFilePath = apkFile.path;
    if (_apkFilePath.isEmpty) {
      print('make sure the apk file is set');
      return;
    }

    /// 安装Apk appPackName为APP包名
    InstallPlugin.installApk(_apkFilePath, PorjectConfig.appPackName)

        /// 成功处理
        .then((result) {
      success(result);
    })

        /// 失败处理
        .catchError((err) {
      if (error != null) {
        error(err);
      }
    });
  }

  /// ios更新转跳
  ///
  /// ios直接跳至苹果商城更新即可，未进行尝试
  static Future<Null> iosLaunch({@required String link}) async {
    if (await canLaunch(link)) {
      await launch(link);
    } else {
      throw 'Could not launch $link';
    }
  }
}
