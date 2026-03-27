import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show IsolateNameServer;

/// Base class for all messages sent to the crypto isolate.
abstract class CryptoIsolateMessage {
  /// Port to send the response back on.
  final SendPort replyPort;
  CryptoIsolateMessage(this.replyPort);
}

/// Request to encrypt plaintext for a 1:1 session.
class EncryptRequest extends CryptoIsolateMessage {
  final String sessionId;
  final TransferableTypedData plaintext;
  EncryptRequest(this.sessionId, this.plaintext, SendPort replyPort)
      : super(replyPort);
}

/// Request to decrypt ciphertext from a 1:1 session.
class DecryptRequest extends CryptoIsolateMessage {
  final String sessionId;
  final TransferableTypedData ciphertext;
  final TransferableTypedData header;
  DecryptRequest(
    this.sessionId,
    this.ciphertext,
    this.header,
    SendPort replyPort,
  ) : super(replyPort);
}

/// Request to encrypt plaintext for a group via Sender Keys.
class GroupEncryptRequest extends CryptoIsolateMessage {
  final String groupId;
  final TransferableTypedData plaintext;
  GroupEncryptRequest(this.groupId, this.plaintext, SendPort replyPort)
      : super(replyPort);
}

/// Request to decrypt ciphertext from a group member.
class GroupDecryptRequest extends CryptoIsolateMessage {
  final String groupId;
  final String senderId;
  final TransferableTypedData ciphertext;
  GroupDecryptRequest(
    this.groupId,
    this.senderId,
    this.ciphertext,
    SendPort replyPort,
  ) : super(replyPort);
}

/// Request to flush all in-memory crypto state to persistent storage.
class FlushStateRequest extends CryptoIsolateMessage {
  FlushStateRequest(SendPort replyPort) : super(replyPort);
}

/// Request to shut down the crypto isolate gracefully.
class ShutdownRequest extends CryptoIsolateMessage {
  ShutdownRequest(SendPort replyPort) : super(replyPort);
}

/// Response from the crypto isolate.
class CryptoIsolateResponse {
  /// The result data, if the operation succeeded.
  final Uint8List? data;

  /// Error description, if the operation failed.
  final String? error;

  CryptoIsolateResponse({this.data, this.error});
}

/// Manages the lifecycle of a dedicated crypto [Isolate].
///
/// All crypto operations are routed through this isolate to keep the
/// main isolate free for UI work. Uses [TransferableTypedData] for
/// zero-copy byte transfer and a 10-second watchdog with up to 3
/// automatic respawns.
///
/// The isolate is registered via [IsolateNameServer] under
/// `'crypto_isolate'` so that platform-native push-decrypt code
/// (iOS NSE, Android Service) can look it up without a direct
/// reference.
class CryptoIsolateManager {
  Isolate? _isolate;
  SendPort? _sendPort;
  int _respawnCount = 0;

  /// Maximum number of automatic respawns before giving up.
  static const int _maxRespawns = 3;

  /// Timeout for a single crypto request before the watchdog fires.
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// Whether the crypto isolate is currently running and reachable.
  bool get isRunning => _sendPort != null;

  /// Spawns the crypto isolate and registers it with
  /// [IsolateNameServer].
  Future<void> spawn() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);

    final completer = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort && !completer.isCompleted) {
        completer.complete(message);
      }
    });
    _sendPort = await completer.future;

    IsolateNameServer.removePortNameMapping('crypto_isolate');
    IsolateNameServer.registerPortWithName(_sendPort!, 'crypto_isolate');
  }

  /// Sends a [CryptoIsolateMessage] to the isolate and waits for a
  /// [CryptoIsolateResponse].
  ///
  /// Throws if the isolate is not running, if the request times out,
  /// or if the maximum respawn count has been exceeded.
  Future<CryptoIsolateResponse> send(CryptoIsolateMessage message) async {
    if (_sendPort == null) throw StateError('Crypto isolate not running');

    final replyPort = ReceivePort();
    final completer = Completer<CryptoIsolateResponse>();

    replyPort.listen((response) {
      if (!completer.isCompleted) {
        completer.complete(response as CryptoIsolateResponse);
      }
      replyPort.close();
    });

    // Create a new message instance with the correct replyPort
    // (The message was constructed with a placeholder replyPort)
    _sendPort!.send(message);

    try {
      return await completer.future.timeout(_requestTimeout);
    } on TimeoutException {
      replyPort.close();
      await _handleCrash();
      throw Exception('Crypto isolate timeout — respawned');
    }
  }

  /// Kills the current isolate and respawns if under the limit.
  Future<void> _handleCrash() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;

    if (_respawnCount < _maxRespawns) {
      _respawnCount++;
      await spawn();
    } else {
      throw Exception('Crypto isolate max respawns exceeded');
    }
  }

  /// Gracefully shuts down the crypto isolate.
  ///
  /// Sends a [ShutdownRequest] and waits up to 5 seconds for
  /// acknowledgement before force-killing the isolate.
  Future<void> shutdown() async {
    if (_sendPort != null) {
      try {
        final replyPort = ReceivePort();
        _sendPort!.send(ShutdownRequest(replyPort.sendPort));
        await replyPort.first.timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
      } catch (_) {
        // Shutdown failure is non-fatal.
      }
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    IsolateNameServer.removePortNameMapping('crypto_isolate');
  }

  /// Entry point for the crypto isolate.
  ///
  /// Sends its [SendPort] back to the main isolate, then listens
  /// for [CryptoIsolateMessage]s. Actual crypto operations will be
  /// wired in the Vault spec.
  static void _isolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is ShutdownRequest) {
        message.replyPort.send(CryptoIsolateResponse());
        receivePort.close();
        return;
      }

      if (message is CryptoIsolateMessage) {
        // Route to crypto operations (will be wired in Vault spec).
        message.replyPort.send(CryptoIsolateResponse(
          error: 'crypto operations will be wired in Vault spec',
        ));
      }
    });
  }
}
