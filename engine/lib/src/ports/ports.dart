import 'package:e2ee_chat_sdk/src/ports/ai_adapter.dart';
import 'package:e2ee_chat_sdk/src/ports/message_gateway.dart';
import 'package:e2ee_chat_sdk/src/ports/push_adapter.dart';
import 'package:e2ee_chat_sdk/src/ports/realtime_gateway.dart';
import 'package:e2ee_chat_sdk/src/ports/transient_queue.dart';

export 'package:e2ee_chat_sdk/src/ports/ai_adapter.dart';
export 'package:e2ee_chat_sdk/src/ports/message_gateway.dart';
export 'package:e2ee_chat_sdk/src/ports/push_adapter.dart';
export 'package:e2ee_chat_sdk/src/ports/realtime_gateway.dart';
export 'package:e2ee_chat_sdk/src/ports/transient_queue.dart';

class PortRegistry {
  final MessageGateway messageGateway;
  final RealtimeGateway realtimeGateway;
  final TransientQueue transientQueue;
  final PushAdapter? pushAdapter;
  final AIAdapter? aiAdapter;

  const PortRegistry({
    required this.messageGateway,
    required this.realtimeGateway,
    required this.transientQueue,
    this.pushAdapter,
    this.aiAdapter,
  });
}
