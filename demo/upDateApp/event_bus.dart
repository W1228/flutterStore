import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';

/// 创建EventBus
EventBus eventBus = EventBus();

/// 广播App更新
///
/// @ drief  更新消息广播
///
/// @ params details -[in] 更新公告
///
/// @ params url -[in] 更新地址
///
/// @ params force -[in] 是为否强制更新
///
/// @ params flatform -[in] 运行环境
///
/// @ return UpDateInfo
/// 监听:
///
/// ```
///  // initState
///  _upDateApp = eventBus.on<UpDateInfo>().listen((event) {
///     String url = event.url;
///    });
/// ```
///
/// 页面销毁取消监听防止内存泄漏
///
/// ```
///  _upDateApp.cancel();
/// ```
class UpDateInfo {
  List<Map<String, String>> details;
  String url;
  bool force;
  String flatform;
  UpDateInfo({this.details, this.url, this.force, @required this.flatform});
}

class UpdateAndroidProgressEvent {
  double progress;
  UpdateAndroidProgressEvent(this.progress);
}
