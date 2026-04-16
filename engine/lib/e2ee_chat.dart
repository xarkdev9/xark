/// E2EE Chat SDK
///
/// Public API -- the only file external packages should import.
library e2ee_chat;

export 'src/config/brand_config.dart';
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
export 'src/discovery/discovery_mixin.dart';
export 'src/discovery/models/carousel_card.dart';
export 'src/discovery/models/discovery_filter.dart';
export 'src/discovery/models/discovery_item.dart';
export 'src/discovery/models/discovery_item_detail.dart';
export 'src/discovery/models/error_report.dart';
export 'src/discovery/models/taste_profile.dart';
export 'src/extensions/chat_engine_decisions.dart';
export 'src/public_api/chat_engine.dart';
export 'src/auth/auth_service.dart';
export 'src/public_api/chat_engine_config.dart';
export 'src/public_api/chat_session.dart';
