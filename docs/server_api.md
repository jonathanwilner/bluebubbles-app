# BlueBubbles Server API

## Overview
- **Base URL:** The client derives the API root by combining the configured server origin with `/api/v1`. All REST calls go through this base path.【F:lib/services/network/http_service.dart†L18-L21】
- **Authentication:** Every request must include the `guid` query parameter, which carries the server password/key stored in the app settings. `HttpService.buildQueryParams` appends this automatically for all requests, so reproducing the calls manually requires adding `?guid=<server_key>` (or merging it with other query parameters).【F:lib/services/network/http_service.dart†L22-L31】
- **Headers:** Custom headers from the client settings are forwarded on every request. Helper logic automatically adds `ngrok-skip-browser-warning` or `skip_zrok_interstitial` when required for hosted tunnels.【F:lib/services/network/http_service.dart†L62-L70】
- **Error handling:** Requests are wrapped in `runApiGuarded`, which retries specific Cloudflare 502 errors and surfaces non-200 responses as failures. The helper `returnSuccessOrError` treats only HTTP 200 responses as success.【F:lib/services/network/http_service.dart†L33-L60】
- **Private API toggles:** Several endpoints accept a `method` field or optional parameters that toggle Apple Private API behavior based on user settings (`enablePrivateAPI`, `privateAPISend`, etc.). These toggles are visible in the payloads for chat creation, message sending, attachment uploads, and scheduled messages.【F:lib/services/network/http_service.dart†L400-L417】【F:lib/services/network/http_service.dart†L616-L714】【F:lib/services/network/http_service.dart†L650-L717】【F:lib/services/network/http_service.dart†L1030-L1072】
- **Socket authentication:** Realtime communication reuses the same `guid` credential by sending it as the Socket.IO connection query alongside the REST headers.【F:lib/services/network/socket_service.dart†L57-L65】

The tables below document every REST call made by the Flutter client, grouped by feature. Unless stated otherwise, include the `guid` query parameter in each request. 

## Server & Mac controls
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Ping | GET `/api/v1/ping` | — | — | Accepts optional alternate base URL on the client when probing connectivity; used as a health check.【F:lib/services/network/http_service.dart†L87-L97】 |
| Lock Mac | POST `/api/v1/mac/lock` | — | — | Remotely locks the host Mac running the server.【F:lib/services/network/http_service.dart†L99-L108】 |
| Restart iMessage | POST `/api/v1/mac/imessage/restart` | — | — | Restarts the Messages app on the host Mac.【F:lib/services/network/http_service.dart†L111-L119】 |
| Server info | GET `/api/v1/server/info` | — | — | Returns metadata (server version, macOS version, local IPs, etc.). Client caches responses for one minute.【F:lib/services/network/http_service.dart†L123-L147】 |
| Soft restart | GET `/api/v1/server/restart/soft` | — | — | Restarts only the BlueBubbles server services.【F:lib/services/network/http_service.dart†L149-L158】 |
| Hard restart | GET `/api/v1/server/restart/hard` | — | — | Restarts the full BlueBubbles server application.【F:lib/services/network/http_service.dart†L161-L170】 |
| Check update | GET `/api/v1/server/update/check` | — | — | Checks for available server updates.【F:lib/services/network/http_service.dart†L173-L182】 |
| Install update | POST `/api/v1/server/update/install` | — | — | Triggers server update installation.【F:lib/services/network/http_service.dart†L185-L194】 |
| Totals | GET `/api/v1/server/statistics/totals` | — | — | Returns aggregate counts of chats, handles, messages, and attachments.【F:lib/services/network/http_service.dart†L197-L205】 |
| Media totals | GET `/api/v1/server/statistics/media` or `/media/chat` | — | — | Returns media type counts, optionally split per chat when the `byChat` flag is true on the client.【F:lib/services/network/http_service.dart†L209-L221】 |
| Logs | GET `/api/v1/server/logs` | `count` (default 10000) | — | Streams recent server logs up to the requested line count.【F:lib/services/network/http_service.dart†L223-L233】 |

## Push & notification device management
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Add FCM device | POST `/api/v1/fcm/device` | — | `{ "name": <string>, "identifier": <string> }` | Registers a new Firebase Cloud Messaging device with the server.【F:lib/services/network/http_service.dart†L235-L246】 |
| Get FCM client state | GET `/api/v1/fcm/client` | — | — | Fetches the server’s current FCM configuration payload.【F:lib/services/network/http_service.dart†L248-L257】 |

## Attachments
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Attachment metadata | GET `/api/v1/attachment/{guid}` | — | — | Retrieves metadata for an attachment record.【F:lib/services/network/http_service.dart†L260-L269】 |
| Download attachment | GET `/api/v1/attachment/{guid}/download` | `original` (bool) | — | Streams attachment bytes; supports optional original-quality flag and progress callbacks.【F:lib/services/network/http_service.dart†L272-L284】 |
| Download Live Photo | GET `/api/v1/attachment/{guid}/live` | — | — | Streams Live Photo bundles with extended timeouts.【F:lib/services/network/http_service.dart†L286-L298】 |
| Attachment blurhash | GET `/api/v1/attachment/{guid}/blurhash` | — | — | Fetches precomputed blurhash image data.【F:lib/services/network/http_service.dart†L300-L311】 |
| Attachment count | GET `/api/v1/attachment/count` | — | — | Returns total attachment count stored on the server.【F:lib/services/network/http_service.dart†L314-L323】 |

## Chat management
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Query chats | POST `/api/v1/chat/query` | — | `{ "with": [], "offset": <int>, "limit": <int>, "sort": <string?> }` | Supports eager-loading participants, last message, SMS flag, and archive state via the `with` array.【F:lib/services/network/http_service.dart†L326-L340】 |
| Chat messages | GET `/api/v1/chat/{chatGuid}/message` | `with`, `sort`, `before`, `after`, `offset`, `limit` | — | Retrieves paginated messages for a chat with optional joins (attachments, handles, attributed bodies).【F:lib/services/network/http_service.dart†L342-L355】 |
| Manage participants | POST `/api/v1/chat/{chatGuid}/participant/{method}` | — | `{ "address": <string> }` | Adds or removes a participant; both `chatParticipant` and `addRemoveParticipant` wrappers call this route.【F:lib/services/network/http_service.dart†L358-L370】【F:lib/services/network/http_service.dart†L470-L479】 |
| Leave chat | POST `/api/v1/chat/{chatGuid}/leave` | — | — | Leaves a group chat via AppleScript or Private API depending on server support.【F:lib/services/network/http_service.dart†L373-L382】 |
| Update chat name | PUT `/api/v1/chat/{chatGuid}` | — | `{ "displayName": <string> }` | Renames a group chat.【F:lib/services/network/http_service.dart†L385-L397】 |
| Create chat | POST `/api/v1/chat/new` | — | `{ "addresses": [], "message": <string?>, "service": <string>, "method": "private-api"\|"apple-script" }` | Creates a new conversation and sends the first message using Private API when enabled.【F:lib/services/network/http_service.dart†L399-L415】 |
| Chat count | GET `/api/v1/chat/count` | — | — | Returns total chat count.【F:lib/services/network/http_service.dart†L418-L427】 |
| Get chat | GET `/api/v1/chat/{chatGuid}` | `with` | — | Fetches a single chat with optional participant and last-message joins.【F:lib/services/network/http_service.dart†L430-L444】 |
| Mark chat read | POST `/api/v1/chat/{chatGuid}/read` | — | — | Marks all messages as read in the chat.【F:lib/services/network/http_service.dart†L446-L455】 |
| Mark chat unread | POST `/api/v1/chat/{chatGuid}/unread` | — | — | Forces the chat to appear unread (for reminders).【F:lib/services/network/http_service.dart†L458-L467】 |
| Get chat icon | GET `/api/v1/chat/{chatGuid}/icon` | — | — | Downloads the current chat icon image.【F:lib/services/network/http_service.dart†L482-L494】 |
| Set chat icon | POST `/api/v1/chat/{chatGuid}/icon` | — | `multipart/form-data` containing `icon` file | Uploads a replacement group icon (supports progress callbacks).【F:lib/services/network/http_service.dart†L496-L511】 |
| Delete chat icon | DELETE `/api/v1/chat/{chatGuid}/icon` | — | — | Removes the custom chat icon.【F:lib/services/network/http_service.dart†L513-L520】 |
| Delete chat | DELETE `/api/v1/chat/{chatGuid}` | — | — | Deletes the chat thread from the database.【F:lib/services/network/http_service.dart†L528-L537】 |
| Delete message in chat | DELETE `/api/v1/chat/{chatGuid}/{messageGuid}` | — | — | Deletes a specific message from a chat (server-side).【F:lib/services/network/http_service.dart†L540-L548】 |

## Message operations
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Message count | GET `/api/v1/message/count`, `/count/updated`, or `/count/me` | `after`, `before` | — | Counts messages; alternate paths return counts of updated messages or the user’s own messages.【F:lib/services/network/http_service.dart†L552-L566】 |
| Query messages | POST `/api/v1/message/query` | — | `{ "with": [], "where": [], "sort": "DESC", "before": <int?>, "after": <int?>, "chatGuid": <string?>, "offset": <int>, "limit": <int>, "convertAttachments": <bool> }` | Flexible message search supporting filters and eager-loading related entities.【F:lib/services/network/http_service.dart†L569-L584】 |
| Get message | GET `/api/v1/message/{guid}` | `with` | — | Fetches a single message with optional joins (chat, attachments, attributed body).【F:lib/services/network/http_service.dart†L586-L599】 |
| Embedded media | GET `/api/v1/message/{guid}/embedded-media` | — | — | Streams inline media for Digital Touch/handwritten messages with extended timeouts.【F:lib/services/network/http_service.dart†L602-L614】 |
| Send text | POST `/api/v1/message/text` | — | `{ "chatGuid": <string>, "tempGuid": <string>, "message": <string>, "method": <string?>, ... }` | Sends a message; when Private API send is enabled the payload may include `effectId`, `subject`, `selectedMessageGuid`, `partIndex`, and `ddScan` (Ventura+).【F:lib/services/network/http_service.dart†L616-L647】 |
| Send attachment | POST `/api/v1/message/attachment` | — | Multipart form with `attachment`, `chatGuid`, `tempGuid`, `name`, optional `method`, and Private API extras (`effectId`, `subject`, `selectedMessageGuid`, `partIndex`, `isAudioMessage`). | Uploads attachments with large transfer timeouts and optional Private API metadata.【F:lib/services/network/http_service.dart†L650-L686】 |
| Send multipart | POST `/api/v1/message/multipart` | — | `{ "chatGuid": <string>, "tempGuid": <string>, "parts": [ ... ], optional Private API extras }` | Used for multi-part messages (e.g., subject + body, text + attachments) with optional `ddScan` flags on Ventura.【F:lib/services/network/http_service.dart†L689-L717】 |
| React (tapback) | POST `/api/v1/message/react` | — | `{ "chatGuid": <string>, "selectedMessageText": <string>, "selectedMessageGuid": <string>, "reaction": <string>, "partIndex": <int?> }` | Sends iMessage reactions.【F:lib/services/network/http_service.dart†L719-L737】 |
| Unsend | POST `/api/v1/message/{guid}/unsend` | — | `{ "partIndex": <int> }` | Retracts a sent message (supports targeting specific parts).【F:lib/services/network/http_service.dart†L740-L751】 |
| Edit | POST `/api/v1/message/{guid}/edit` | — | `{ "editedMessage": <string>, "backwardsCompatibilityMessage": <string>, "partIndex": <int> }` | Sends iMessage edits plus fallback text for older devices.【F:lib/services/network/http_service.dart†L754-L767】 |
| Notify | POST `/api/v1/message/{guid}/notify` | — | — | Asks the server to emit a “notify anyway” alert for suppressed messages.【F:lib/services/network/http_service.dart†L770-L778】 |

## Scheduled messaging
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| List scheduled | GET `/api/v1/message/schedule` | — | — | Fetches all scheduled jobs from the server queue.【F:lib/services/network/http_service.dart†L1018-L1027】 |
| Create scheduled | POST `/api/v1/message/schedule` | — | `{ "type": "send-message", "payload": { "chatGuid": <string>, "message": <string>, "method": "private-api"\|"apple-script" }, "scheduledFor": <epoch_ms>, "schedule": {…} }` | Adds a scheduled message; honors Private API send preference when available.【F:lib/services/network/http_service.dart†L1030-L1049】 |
| Update scheduled | PUT `/api/v1/message/schedule/{id}` | — | Same structure as create (currently forces `method: "apple-script"`). | Updates an existing scheduled job’s payload and timing.【F:lib/services/network/http_service.dart†L1052-L1071】 |
| Delete scheduled | DELETE `/api/v1/message/schedule/{id}` | — | — | Removes a scheduled message.【F:lib/services/network/http_service.dart†L1074-L1083】 |

## Handle lookups
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Handle count | GET `/api/v1/handle/count` | — | — | Returns the number of handle records on the server.【F:lib/services/network/http_service.dart†L781-L789】 |
| Query handles | POST `/api/v1/handle/query` | — | `{ "with": [], "address": <string?>, "offset": <int>, "limit": <int> }` | Fetches handles with optional joins (chats, participants).【F:lib/services/network/http_service.dart†L793-L807】 |
| Get handle | GET `/api/v1/handle/{guid}` | — | — | Retrieves a specific handle record.【F:lib/services/network/http_service.dart†L810-L819】 |
| Focus status | GET `/api/v1/handle/{address}/focus` | — | — | Returns Apple Focus status for the contact when supported.【F:lib/services/network/http_service.dart†L822-L831】 |
| iMessage availability | GET `/api/v1/handle/availability/imessage` | `address` | — | Checks whether an address can receive iMessage via private API probes.【F:lib/services/network/http_service.dart†L834-L845】 |
| FaceTime availability | GET `/api/v1/handle/availability/facetime` | `address` | — | Checks FaceTime reachability for an address.【F:lib/services/network/http_service.dart†L848-L859】 |

## Contacts & iCloud account data
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| List contacts | GET `/api/v1/contact` | `extraProperties=avatar` (optional) | — | Fetches iCloud contacts, optionally including avatar blobs.【F:lib/services/network/http_service.dart†L862-L871】 |
| Lookup contacts | POST `/api/v1/contact/query` | — | `{ "addresses": [<string>…] }` | Batch-resolves specific phone numbers or emails to contacts.【F:lib/services/network/http_service.dart†L874-L885】 |
| Create contacts | POST `/api/v1/contact` | — | `[ { …contact map… }, … ]` | Uploads new contacts via the server with long send/receive timeouts for large payloads.【F:lib/services/network/http_service.dart†L888-L901】 |
| Account info | GET `/api/v1/icloud/account` | — | — | Returns iCloud account status, login state, and metadata—used as the “login” status indicator in the UI.【F:lib/services/network/http_service.dart†L1135-L1144】 |
| Account contact | GET `/api/v1/icloud/contact` | — | — | Retrieves the contact card representing the logged-in Apple ID owner.【F:lib/services/network/http_service.dart†L1146-L1154】 |
| Set account alias | POST `/api/v1/icloud/account/alias` | — | `{ "alias": <string> }` | Updates the server’s cached alias list for iMessage sending identities.【F:lib/services/network/http_service.dart†L1157-L1166】 |

## Backup management
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Get theme backup | GET `/api/v1/backup/theme` | — | — | Downloads the saved theme bundle (if any).【F:lib/services/network/http_service.dart†L903-L912】 |
| Save theme backup | POST `/api/v1/backup/theme` | — | `{ "name": <string>, "data": {…} }` | Stores a theme backup JSON payload.【F:lib/services/network/http_service.dart†L915-L924】 |
| Delete theme backup | DELETE `/api/v1/backup/theme` | — | `{ "name": <string> }` | Removes a named theme backup.【F:lib/services/network/http_service.dart†L928-L938】 |
| Get settings backup | GET `/api/v1/backup/settings` | — | — | Retrieves backed-up app settings.【F:lib/services/network/http_service.dart†L941-L950】 |
| Delete settings backup | DELETE `/api/v1/backup/settings` | — | `{ "name": <string> }` | Deletes a settings backup entry.【F:lib/services/network/http_service.dart†L953-L963】 |
| Save settings backup | POST `/api/v1/backup/settings` | — | `{ "name": <string>, "data": {…} }` | Uploads a settings backup payload.【F:lib/services/network/http_service.dart†L966-L975】 |

## FaceTime control
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Answer call | POST `/api/v1/facetime/answer/{callUuid}` | — | `{}` | Requests the Mac to answer the specified FaceTime call and returns a join link.【F:lib/services/network/http_service.dart†L979-L991】 |
| Leave call | POST `/api/v1/facetime/leave/{callUuid}` | — | `{}` | Terminates an active FaceTime session on the host.【F:lib/services/network/http_service.dart†L993-L1003】 |

## Find My & iCloud data refresh
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| List devices | GET `/api/v1/icloud/findmy/devices` | — | — | Returns cached Find My devices from the server.【F:lib/services/network/http_service.dart†L1086-L1095】 |
| Refresh devices | POST `/api/v1/icloud/findmy/devices/refresh` | — | — | Forces the server to refresh device data (longer receive timeout).【F:lib/services/network/http_service.dart†L1098-L1108】 |
| List friends | GET `/api/v1/icloud/findmy/friends` | — | — | Returns cached Find My friends/sharing info.【F:lib/services/network/http_service.dart†L1111-L1120】 |
| Refresh friends | POST `/api/v1/icloud/findmy/friends/refresh` | — | — | Refreshes Find My friends data.【F:lib/services/network/http_service.dart†L1123-L1132】 |

## Utility endpoints
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Landing page | GET root origin | — | — | Fetches the web landing page while still attaching the `guid` query parameter.【F:lib/services/network/http_service.dart†L1006-L1015】 |
| Download from URL | GET `<arbitrary URL>` | — | — | Convenience helper for downloading external files with the client’s configured headers/timeouts.【F:lib/services/network/http_service.dart†L1169-L1178】 |

## Firebase & Google helper calls
| Action | Method & Path | Extra query parameters | Body | Notes |
| --- | --- | --- | --- | --- |
| Firebase projects | GET `https://firebase.googleapis.com/v1beta1/projects` | `access_token` | — | Lists Firebase projects for the authenticated Google user; does not require a server origin.【F:lib/services/network/http_service.dart†L1183-L1193】 |
| Google userinfo | GET `https://www.googleapis.com/oauth2/v1/userinfo` | `access_token` | — | Fetches Google account metadata for OAuth flows.【F:lib/services/network/http_service.dart†L1195-L1204】 |
| Firebase RTDB config | GET `https://{rtdb}.firebaseio.com/config.json` | `token` | — | Reads BlueBubbles server URL details stored in Firebase Realtime Database.【F:lib/services/network/http_service.dart†L1207-L1216】 |
| Firebase Firestore config | GET `https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/server/config` | `access_token` | — | Reads BlueBubbles server configuration stored in Firestore.【F:lib/services/network/http_service.dart†L1219-L1228】 |
| Firestore restart command | PATCH `https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents/server/commands?updateMask.fieldPaths=nextRestart` | — | `{ "fields": { "nextRestart": { "integerValue": <epoch_ms> } } }` | Updates the scheduled restart timestamp used by hosted deployments.【F:lib/services/network/http_service.dart†L1231-L1238】 |

## Socket commands
| Event | Transport | Payload | Purpose |
| --- | --- | --- | --- |
| `started-typing` | Socket.IO emit with ack | `{ "chatGuid": <string> }` | Sent when the user begins typing (after Private API typing preference is validated).【F:lib/services/network/socket_service.dart†L131-L145】【F:lib/app/layouts/conversation_view/widgets/text_field/conversation_text_field.dart†L242-L253】 |
| `stopped-typing` | Socket.IO emit with ack | `{ "chatGuid": <string> }` | Sent after a short debounce when typing stops to clear the indicator.【F:lib/services/network/socket_service.dart†L131-L145】【F:lib/app/layouts/conversation_view/widgets/text_field/conversation_text_field.dart†L242-L254】 |

The socket connection shares the same headers and `guid` authentication query string as REST calls, and any encrypted acknowledgements are decrypted with the stored password before being returned to the caller.【F:lib/services/network/socket_service.dart†L57-L145】
