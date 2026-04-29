# Data Model: Flutter Stabilization Plan

## 1. ChatSession

**Purpose**: Represents all state that must exist only while one conversation is active.

### Fields

| Field | Type | Description | Rules |
|------|------|-------------|-------|
| `chatId` | string | Active chat identifier | Required; unique per session |
| `title` | string | Resolved conversation title | Derived from route/chat metadata |
| `isGroup` | boolean | Whether session targets a group chat | Impacts presentation only |
| `timeline` | list of `MessageTimelineCacheRecord` | Visible messages for the active session | Must contain only records for `chatId` |
| `currentUserId` | string | Current authenticated user | Required for optimistic sends/read state |
| `userNames` | map<string,string> | Resolved author display names | Cache-by-user within session |
| `loadingState` | enum | `idle`, `loading`, `loaded`, `error`, `offlineUnavailable` | `offlineUnavailable` only before first successful sync |
| `mediaSessionState` | enum | `idle`, `recordingVoice`, `recordingVideo`, `uploading`, `teardown` | Must reset on chat exit |

### Relationships

- Owns many `MessageTimelineCacheRecord`
- References one `RuntimeEnvironmentProfile` indirectly through injected services

### State Transitions

`idle -> loading -> loaded`  
`loading -> offlineUnavailable` when no prior successful sync exists and network is unavailable  
`loaded -> loading` during refresh/pagination  
`loaded -> error` only when no recoverable timeline is available  
`any -> teardown` on route exit or chat switch

## 2. MessageTimelineCacheRecord

**Purpose**: Canonical persisted representation of one message inside the local chat timeline.

### Fields

| Field | Type | Description | Rules |
|------|------|-------------|-------|
| `messageId` | string | Server or optimistic identifier | Required; may temporarily equal client ID |
| `clientMessageId` | string? | Optimistic client-generated ID | Optional; used for reconciliation |
| `chatId` | string | Owning chat | Required |
| `authorId` | string | Sender identifier | Required |
| `body` | string | Canonical text payload | Maps consistently between remote and local forms |
| `createdAt` | datetime | Message creation timestamp | Required |
| `updatedAt` | datetime | Last update timestamp | Defaults to `createdAt` if absent remotely |
| `status` | enum | `sending`, `sent`, `delivered`, `read`, `failed` | Used for optimistic and read-state transitions |
| `replyToMessageId` | string? | Reply target | Optional |
| `forwardedFromMessageId` | string? | Forward origin | Optional |
| `attachments` | list of `AttachmentRecord` | Attached media/files | Serialized/deserialized consistently |

### Identity Rules

- Unique by `messageId` after server acknowledgment
- During optimistic send, reconcile by `clientMessageId`
- Must never be returned from local cache under the wrong `chatId`

## 3. AttachmentRecord

**Purpose**: Normalized file metadata used in both local cache and rendered message content.

### Fields

| Field | Type | Description | Rules |
|------|------|-------------|-------|
| `attachmentId` | string? | Attachment identifier | Optional if backend does not return one |
| `fileName` | string | Original file name | Required |
| `fileSize` | integer | File size in bytes | Non-negative |
| `mimeType` | string | Content type | Required |
| `accessKey` | string | File-service access key | Required for remote fetch |
| `contentType` | enum | `image`, `voice`, `video`, `document` | Required |
| `localPath` | string? | Local media cache path | Optional; must not leak across chats |

## 4. ContactConversationLaunch

**Purpose**: Captures the app-controlled flow for opening a direct chat from a contact entry point.

### Fields

| Field | Type | Description | Rules |
|------|------|-------------|-------|
| `source` | enum | e.g. `contactProfile`, future contact entry points | Used for analytics/debug context if needed |
| `contactUserId` | string | Messenger user ID for the target contact | Required |
| `contactDisplayName` | string | Title for resulting navigation | Required |
| `status` | enum | `idle`, `checkingExisting`, `creating`, `navigating`, `failed` | Only one active launch per target at a time |
| `resolvedChatId` | string? | Final direct chat ID | Present on success |
| `failureReason` | string? | User-displayable failure summary | Present on failed outcome |

### Rules

- Canonical resolution is "reuse existing direct chat, otherwise create one"
- Repeated taps while a request is in flight must collapse to one canonical outcome
- Widget code may dispatch this request but may not own the network orchestration

## 5. RuntimeEnvironmentProfile

**Purpose**: Startup-resolved network environment configuration shared by all transport clients.

### Fields

| Field | Type | Description | Rules |
|------|------|-------------|-------|
| `environmentName` | string | Human-readable target name | Required |
| `authBaseUrl` | string | Auth service base URL | Required, validated before client creation |
| `chatBaseUrl` | string | Chat service base URL | Required, validated before client creation |
| `fileBaseUrl` | string | File service base URL | Required, validated before client creation |
| `wsBaseUrl` | string | WebSocket base URL | Required, validated before client creation |
| `validationState` | enum | `valid`, `invalid` | Invalid blocks affected flows |

## 6. ConfigurationErrorState

**Purpose**: Explicit startup/runtime-visible blocking state for missing or invalid required environment values.

### Fields

| Field | Type | Description | Rules |
|------|------|-------------|-------|
| `code` | string | Stable error code | Required for diagnostics |
| `message` | string | User/maintainer-facing explanation | Must explain configuration issue clearly |
| `missingKeys` | list<string> | Missing or invalid configuration fields | Optional but preferred |
| `affectedFlows` | list<string> | Network-dependent features that cannot start | Required for scope clarity |

### Lifecycle

- Created during startup validation before first affected network request
- Cleared only when a valid `RuntimeEnvironmentProfile` is available
