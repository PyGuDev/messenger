# Руководство по интеграции File Service API для фронтенда

> **Base URL**: `http://localhost:8080` (dev) — уточните у бэкенд-команды URL для staging/production.
> **Swagger UI**: `{BASE_URL}/swagger/`
> **OpenAPI spec**: `{BASE_URL}/swagger/doc.yaml`

---

## Оглавление

1. [Аутентификация (JWT)](#1-аутентификация-jwt)
2. [Общие заголовки и поведение](#2-общие-заголовки-и-поведение)
3. [Загрузка файла — POST /files](#3-загрузка-файла--post-files)
4. [Скачивание файла — GET /files/{accessKey}](#4-скачивание-файла--get-filesaccesskey)
5. [Получение метаданных — GET /files/{accessKey}/metadata](#5-получение-метаданных--get-filesaccesskeymetadata)
6. [Health check — GET /health](#6-health-check--get-health)
7. [Обработка ошибок](#7-обработка-ошибок)
8. [Rate limiting](#8-rate-limiting)
9. [TypeScript-типы](#9-typescript-типы)
10. [Полный пример: обёртка-клиент](#10-полный-пример-обёртка-клиент)

---

## 1. Аутентификация (JWT)

Все эндпоинты, кроме `/health` и `/swagger/*`, требуют JWT-токен в заголовке `Authorization`.

```
Authorization: Bearer <token>
```

**Требования к токену:**

| Параметр | Значение |
|----------|----------|
| Алгоритм | `HS256` (другие, включая `none`, отклоняются) |
| Обязательные claims | `sub` (UUID v4 пользователя), `exp` (время истечения) |
| Опциональные claims | `iss`, `aud`, `nbf` — валидируются, если настроены на сервере |

При любой ошибке аутентификации сервер возвращает **401** с телом:

```json
{ "error": "unauthorized" }
```

> Причина отказа намеренно не раскрывается. Если получаете 401, проверьте:
> - токен не истёк (`exp` в будущем)
> - `sub` присутствует и является валидным UUID
> - алгоритм подписи — `HS256`
> - заголовок `Authorization` передан ровно один раз

---

## 2. Общие заголовки и поведение

### Запрос

| Заголовок | Обязательный | Описание |
|-----------|:---:|----------|
| `Authorization` | Да* | `Bearer <JWT>` (* кроме `/health`, `/swagger/*`) |
| `X-Correlation-ID` | Нет | UUID v4 для трассировки. Если не передан — сервер сгенерирует свой |

### Ответ

Каждый ответ содержит заголовок `X-Correlation-ID` — используйте его при обращении в поддержку для поиска в логах.

---

## 3. Загрузка файла — `POST /files`

Загружает файл на сервер. Файл передаётся через `multipart/form-data`.

### Ограничения

- Максимальный размер: **2 ГБ** (2 147 483 648 байт)
- Пустые файлы запрещены (минимум 1 байт)
- Сервис автоматически дедуплицирует файлы по SHA-256

### Пример (JavaScript / fetch)

```js
async function uploadFile(file, token) {
  const formData = new FormData();
  formData.append('file', file);

  const response = await fetch('/files', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
    },
    body: formData,
  });

  if (!response.ok) {
    const err = await response.json();
    throw new Error(err.error);
  }

  return response.json();
}
```

### Пример с `<input type="file">`

```js
const input = document.querySelector('input[type="file"]');
input.addEventListener('change', async (e) => {
  const file = e.target.files[0];
  if (!file) return;

  try {
    const result = await uploadFile(file, token);
    console.log('Access key:', result.accessKey);
    console.log('File ID:', result.fileId);
    console.log('Is duplicate:', result.isDuplicate);
  } catch (err) {
    console.error('Upload failed:', err.message);
  }
});
```

### Ответ — `201 Created`

```json
{
  "accessKey": "dGhpcyBpcyBhIHRlc3QgYWNjZXNzIGtleSBmb3IgZG9j",
  "fileId": "550e8400-e29b-41d4-a716-446655440000",
  "isDuplicate": false
}
```

| Поле | Тип | Описание |
|------|-----|----------|
| `accessKey` | `string` | Уникальный ключ доступа к файлу (base64url, 43 символа). **Сохраните его** — это единственный способ скачать файл |
| `fileId` | `string (UUID)` | Идентификатор файла. Одинаковый для дубликатов с тем же содержимым |
| `isDuplicate` | `boolean` | `true` — файл с таким содержимым уже существовал; `accessKey` всё равно новый и уникальный |

### Возможные ошибки

| Код | Причина | Тело ответа |
|-----|---------|-------------|
| 400 | Пустой файл или отсутствует поле `file` | `{"error": "empty file is not allowed"}` |
| 401 | Проблема с JWT | `{"error": "unauthorized"}` |
| 413 | Файл > 2 ГБ | `{"error": "file exceeds maximum allowed size"}` |
| 422 | Содержимое не прошло валидацию | `{"error": "unprocessable file content"}` |
| 429 | Rate limit | `{"error": "rate limit exceeded"}` |
| 500 | Ошибка сервера | `{"error": "internal server error"}` |

> **Важно**: не устанавливайте `Content-Type` вручную при использовании `FormData` — браузер сам подставит `multipart/form-data` с правильным `boundary`.

---

## 4. Скачивание файла — `GET /files/{accessKey}`

Скачивает файл потоком. Сервер декомпрессирует файл на лету — клиент получает оригинальные байты.

### Пример: скачивание с сохранением через браузер

```js
async function downloadFile(accessKey, token) {
  const response = await fetch(`/files/${accessKey}`, {
    headers: {
      'Authorization': `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    const err = await response.json();
    throw new Error(err.error);
  }

  // Получаем метаданные из заголовков
  const originalSize = response.headers.get('X-Original-Size');
  const sha256 = response.headers.get('X-Sha256');

  // Сохранить как файл
  const blob = await response.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');

  // Имя файла из Content-Disposition
  const disposition = response.headers.get('Content-Disposition');
  const filenameMatch = disposition?.match(/filename="(.+?)"/);
  a.download = filenameMatch ? filenameMatch[1] : 'download';

  a.href = url;
  a.click();
  URL.revokeObjectURL(url);

  return { originalSize, sha256 };
}
```

### Пример: скачивание с прогрессом (для больших файлов)

```js
async function downloadWithProgress(accessKey, token, onProgress) {
  const response = await fetch(`/files/${accessKey}`, {
    headers: { 'Authorization': `Bearer ${token}` },
  });

  if (!response.ok) {
    const err = await response.json();
    throw new Error(err.error);
  }

  const totalSize = Number(response.headers.get('X-Original-Size')) || 0;
  const reader = response.body.getReader();
  const chunks = [];
  let received = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    received += value.length;
    if (onProgress && totalSize > 0) {
      onProgress(received / totalSize);
    }
  }

  const blob = new Blob(chunks);
  return blob;
}
```

### Заголовки ответа

| Заголовок | Тип | Описание |
|-----------|-----|----------|
| `Content-Disposition` | `string` | `attachment; filename="<fileId>"` — имя для сохранения (UUID файла) |
| `Content-Type` | `string` | Всегда `application/octet-stream` |
| `X-Original-Size` | `integer` | Размер оригинального файла в байтах |
| `X-Sha256` | `string` | SHA-256 хеш оригинального содержимого (hex, 64 символа) |
| `X-Correlation-ID` | `string` | UUID запроса |

### Возможные ошибки

| Код | Причина |
|-----|---------|
| 401 | Проблема с JWT |
| 404 | `accessKey` не найден или файл удалён |
| 429 | Rate limit |
| 500 | Хранилище недоступно или ошибка декомпрессии |

---

## 5. Получение метаданных — `GET /files/{accessKey}/metadata`

Возвращает информацию о файле **без скачивания содержимого**. Лёгкий запрос — только обращение к БД.

### Пример

```js
async function getFileMetadata(accessKey, token) {
  const response = await fetch(`/files/${accessKey}/metadata`, {
    headers: {
      'Authorization': `Bearer ${token}`,
    },
  });

  if (!response.ok) {
    const err = await response.json();
    throw new Error(err.error);
  }

  return response.json();
}
```

### Ответ — `200 OK`

```json
{
  "fileId": "550e8400-e29b-41d4-a716-446655440000",
  "hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "originalSize": 123456,
  "compressedSize": 45678,
  "createdAt": "2026-03-25T10:00:00Z"
}
```

| Поле | Тип | Описание |
|------|-----|----------|
| `fileId` | `string (UUID)` | Идентификатор файла |
| `hash` | `string` | SHA-256 хеш оригинального содержимого (hex, 64 символа) |
| `originalSize` | `integer` | Размер до сжатия (байты) |
| `compressedSize` | `integer` | Размер после сжатия (байты) |
| `createdAt` | `string (ISO 8601)` | Дата создания файла в UTC |

### Когда использовать

- Отобразить информацию о файле перед скачиванием (размер, дата)
- Проверить целостность — сравнить `hash` с локальным SHA-256
- Показать степень сжатия: `compressedSize / originalSize`

---

## 6. Health check — `GET /health`

Проверка работоспособности сервиса. **Не требует аутентификации.**

```js
const response = await fetch('/health');
const data = await response.json();
// { "status": "ok" }
```

Используйте для проверки доступности API перед отображением интерфейса загрузки.

---

## 7. Обработка ошибок

Все ошибки возвращаются в едином формате:

```json
{ "error": "описание ошибки" }
```

### Рекомендуемая стратегия обработки

```js
async function apiRequest(url, options) {
  const response = await fetch(url, options);

  if (response.ok) return response;

  const body = await response.json().catch(() => ({ error: 'unknown error' }));

  switch (response.status) {
    case 401:
      // Перенаправить на страницу логина или обновить токен
      throw new AuthError('Session expired');
    case 404:
      throw new NotFoundError(body.error);
    case 413:
      throw new FileTooLargeError(body.error);
    case 429:
      // Повторить после паузы
      const retryAfter = response.headers.get('Retry-After');
      throw new RateLimitError(body.error, Number(retryAfter));
    default:
      throw new ApiError(body.error, response.status);
  }
}
```

---

## 8. Rate limiting

API ограничивает количество запросов: **100 запросов в минуту** на пользователя (настраивается на сервере).

При превышении лимита сервер возвращает **429 Too Many Requests** со следующими заголовками:

| Заголовок | Описание |
|-----------|----------|
| `Retry-After` | Секунд до сброса лимита |
| `X-RateLimit-Limit` | Максимум запросов в минуту |
| `X-RateLimit-Remaining` | Оставшиеся запросы (0 при 429) |
| `X-RateLimit-Reset` | Unix timestamp сброса окна |

### Пример retry-логики

```js
async function fetchWithRetry(url, options, maxRetries = 3) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    const response = await fetch(url, options);

    if (response.status !== 429) return response;

    const retryAfter = Number(response.headers.get('Retry-After')) || 5;
    await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
  }

  throw new Error('Rate limit: too many retries');
}
```

---

## 9. TypeScript-типы

```ts
// --- Ответы API ---

interface UploadResponse {
  accessKey: string;   // base64url, 43 символа
  fileId: string;      // UUID
  isDuplicate: boolean;
}

interface FileMetadataResponse {
  fileId: string;         // UUID
  hash: string;           // SHA-256 hex, 64 символа
  originalSize: number;   // байты
  compressedSize: number; // байты
  createdAt: string;      // ISO 8601 UTC
}

interface HealthResponse {
  status: 'ok';
}

interface ErrorResponse {
  error: string;
}

// --- Заголовки скачивания ---

interface DownloadHeaders {
  'content-disposition': string; // attachment; filename="<uuid>"
  'content-type': 'application/octet-stream';
  'x-original-size': string;    // число в виде строки
  'x-sha256': string;           // hex, 64 символа
  'x-correlation-id': string;   // UUID
}
```

---

## 10. Полный пример: обёртка-клиент

```ts
class FileServiceClient {
  constructor(
    private baseUrl: string,
    private getToken: () => string | Promise<string>,
  ) {}

  private async headers(): Promise<Record<string, string>> {
    const token = await this.getToken();
    return { Authorization: `Bearer ${token}` };
  }

  /** Загрузить файл */
  async upload(file: File): Promise<UploadResponse> {
    const formData = new FormData();
    formData.append('file', file);

    const res = await fetch(`${this.baseUrl}/files`, {
      method: 'POST',
      headers: await this.headers(),
      body: formData,
    });

    if (!res.ok) {
      const body = await res.json();
      throw new Error(body.error);
    }

    return res.json();
  }

  /** Скачать файл и вернуть Blob */
  async download(accessKey: string): Promise<Blob> {
    const res = await fetch(`${this.baseUrl}/files/${accessKey}`, {
      headers: await this.headers(),
    });

    if (!res.ok) {
      const body = await res.json();
      throw new Error(body.error);
    }

    return res.blob();
  }

  /** Получить метаданные файла */
  async metadata(accessKey: string): Promise<FileMetadataResponse> {
    const res = await fetch(`${this.baseUrl}/files/${accessKey}/metadata`, {
      headers: await this.headers(),
    });

    if (!res.ok) {
      const body = await res.json();
      throw new Error(body.error);
    }

    return res.json();
  }
}

// Использование:
const client = new FileServiceClient('http://localhost:8080', () => authStore.token);

const { accessKey } = await client.upload(file);
const meta = await client.metadata(accessKey);
const blob = await client.download(accessKey);
```

---

## Формат accessKey

| Свойство | Значение |
|----------|----------|
| Кодировка | base64url (без паддинга `=`) |
| Длина | 43 символа |
| Допустимые символы | `A-Z`, `a-z`, `0-9`, `-`, `_` |
| Энтропия | 256 бит |
| Regex | `^[A-Za-z0-9_-]{43}$` |

> `accessKey` — это **секрет**. Любой, кто знает `accessKey` и имеет валидный JWT, может скачать файл. Не храните `accessKey` в URL-параметрах, логах или localStorage без шифрования.
