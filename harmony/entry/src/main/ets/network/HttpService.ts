import http from '@ohos.net.http';
import { ChatSummary, parseChat } from '../models/chat';
import { MessageModel, parseMessage } from '../models/message';
import type { StoredSettings } from '../state/SettingsRepository';

interface ApiResponse<T> {
  data?: T;
  [key: string]: unknown;
}

interface RequestOptions {
  query?: Record<string, string | number | boolean | undefined>;
  body?: Record<string, unknown>;
}

function ensureScheme(address: string): string {
  if (!address) {
    return '';
  }
  if (address.startsWith('http://') || address.startsWith('https://')) {
    return address;
  }
  return `https://${address}`;
}

function sanitizeBase(address: string): string {
  if (!address) {
    return '';
  }
  try {
    const normalized = ensureScheme(address);
    const parsed = new URL(normalized);
    return `${parsed.protocol}//${parsed.host}`;
  } catch (err) {
    console.error('Failed to parse server address', err);
    return ensureScheme(address);
  }
}

export interface HttpConfiguration extends Pick<StoredSettings, 'serverAddress' | 'guidAuthKey' | 'customHeaders'> {}

export class HttpService {
  private readonly base: string;
  private readonly guid: string;
  private readonly headers: Record<string, string>;

  constructor(settings: HttpConfiguration) {
    this.base = sanitizeBase(settings.serverAddress);
    this.guid = settings.guidAuthKey;
    this.headers = {
      'Content-Type': 'application/json',
      ...settings.customHeaders,
    };
  }

  private buildUrl(path: string, query?: Record<string, string | number | boolean | undefined>): string {
    const params = new URLSearchParams();
    if (query) {
      Object.entries(query).forEach(([key, value]) => {
        if (value === undefined || value === null || value === '') {
          return;
        }
        params.append(key, String(value));
      });
    }
    if (this.guid) {
      params.append('guid', this.guid);
    }
    const qs = params.toString();
    const trimmed = path.startsWith('/') ? path : `/${path}`;
    return `${this.base}/api/v1${trimmed}${qs ? `?${qs}` : ''}`;
  }

  private async request<T>(method: http.RequestMethod, path: string, options: RequestOptions = {}): Promise<ApiResponse<T>> {
    const client = http.createHttp();
    try {
      const url = this.buildUrl(path, options.query);
      const requestOptions: http.HttpRequestOptions = {
        method,
        readTimeout: 15000,
        connectTimeout: 15000,
        header: this.headers,
        expectDataType: http.HttpDataType.JSON,
      };
      if (options.body) {
        requestOptions.extraData = JSON.stringify(options.body);
      }
      const response = await client.request(url, requestOptions);
      const status = response.responseCode ?? 500;
      let result: ApiResponse<T> | undefined;
      if (typeof response.result === 'string') {
        try {
          result = JSON.parse(response.result) as ApiResponse<T>;
        } catch (err) {
          console.error('Failed to parse string response', err);
          result = { data: undefined } as ApiResponse<T>;
        }
      } else if (response.result && typeof response.result === 'object') {
        result = response.result as ApiResponse<T>;
      } else {
        result = { data: undefined } as ApiResponse<T>;
      }
      if (status >= 200 && status < 300) {
        return result ?? { data: undefined } as ApiResponse<T>;
      }
      const error = result ?? { data: undefined } as ApiResponse<T>;
      throw Object.assign(new Error('Request failed'), { responseCode: status, body: error });
    } finally {
      client.destroy();
    }
  }

  async ping(): Promise<boolean> {
    const response = await this.request(http.RequestMethod.GET, '/ping');
    return response !== undefined;
  }

  async fetchChats(): Promise<ChatSummary[]> {
    const response = await this.request<unknown[]>(http.RequestMethod.POST, '/chat/query', {
      body: {
        with: ['participants', 'lastmessage'],
        offset: 0,
        limit: 200,
        sort: 'lastmessage',
      },
    });
    const payload = response?.data ?? [];
    return payload
      .filter(item => typeof item === 'object' && item !== null)
      .map(item => parseChat(item as Record<string, unknown>));
  }

  async fetchMessages(chatGuid: string, options: { limit?: number; before?: number; after?: number } = {}): Promise<MessageModel[]> {
    const query = {
      with: 'handle,attachment,message.attributedBody,message.messageSummaryInfo,message.payloadData',
      limit: options.limit ?? 50,
      sort: 'DESC',
      before: options.before,
      after: options.after,
    };
    const response = await this.request<unknown[]>(http.RequestMethod.GET, `/chat/${chatGuid}/message`, {
      query,
    });
    const payload = response?.data ?? [];
    return payload
      .filter(item => typeof item === 'object' && item !== null)
      .map(item => parseMessage(item as Record<string, unknown>))
      .reverse();
  }

  async sendMessage(chatGuid: string, tempGuid: string, message: string): Promise<void> {
    const payload = message && message.trim().length > 0 ? message : ' ';
    await this.request(http.RequestMethod.POST, '/message/text', {
      body: {
        chatGuid,
        tempGuid,
        message: payload,
      },
    });
  }
}

export default HttpService;
