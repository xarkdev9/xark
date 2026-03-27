import 'message_gateway.dart';
import 'realtime_gateway.dart';
import 'transient_queue.dart';

export 'message_gateway.dart';
export 'realtime_gateway.dart';
export 'transient_queue.dart';

class PortRegistry {
  final MessageGateway messageGateway;
  final RealtimeGateway realtimeGateway;
  final TransientQueue transientQueue;

  const PortRegistry({
    required this.messageGateway,
    required this.realtimeGateway,
    required this.transientQueue,
  });
}
