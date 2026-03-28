/// E2EE Flutter Chat Engine
///
/// Public API -- the only file external packages should import.
library chat_engine;

export 'src/domain/models/chat_engine_error.dart';
export 'src/domain/models/commitment_proof.dart';
export 'src/domain/models/connection_state.dart';
export 'src/domain/models/contact_match.dart';
export 'src/domain/models/decision_item.dart';
export 'src/domain/models/conversation.dart';
export 'src/domain/models/decrypted_message.dart';
export 'src/domain/models/hello_response_chunk.dart';
export 'src/domain/models/key_fingerprint.dart';
export 'src/domain/models/media_metadata.dart';
export 'src/domain/models/media_payload.dart';
export 'src/domain/models/message.dart';
export 'src/domain/models/presence_state.dart';
export 'src/domain/models/receipt.dart';
export 'src/domain/models/typing_indicator.dart';
export 'src/domain/models/user_profile.dart';
export 'src/domain/models/invite_link.dart';
export 'src/domain/models/join_result.dart';
export 'src/media/upload_progress.dart';
export 'src/observer/chat_engine_observer.dart';
export 'src/chat_engine_impl.dart' show ChatEngineImpl;
export 'src/public_api/chat_engine.dart';
export 'src/auth/auth_service.dart';
export 'src/public_api/chat_engine_config.dart';
export 'src/public_api/chat_session.dart';
