import common from '@ohos.app.ability.common';
import dataPreferences from '@ohos.data.preferences';

export interface StoredSettings {
  serverAddress: string;
  guidAuthKey: string;
  customHeaders: Record<string, string>;
}

type SettingsListener = () => void;

const PREFERENCES_NAME = 'bluebubbles_settings';

function parseHeaders(raw: string | undefined): Record<string, string> {
  if (!raw) {
    return {};
  }
  try {
    const parsed = JSON.parse(raw);
    if (parsed && typeof parsed === 'object') {
      const headers: Record<string, string> = {};
      Object.keys(parsed).forEach((key) => {
        const value = parsed[key];
        if (typeof value === 'string') {
          headers[key] = value;
        }
      });
      return headers;
    }
  } catch (err) {
    console.error('Failed to parse stored headers', err);
  }
  return {};
}

function serializeHeaders(headers: Record<string, string>): string {
  if (!headers) {
    return '{}';
  }
  return JSON.stringify(headers);
}

export class SettingsRepository {
  private static instance?: SettingsRepository;

  private context?: common.UIAbilityContext;
  private preferences?: dataPreferences.Preferences;
  private listeners: Set<SettingsListener> = new Set();
  private initialized = false;

  serverAddress = '';
  guidAuthKey = '';
  customHeaders: Record<string, string> = {};

  static getInstance(): SettingsRepository {
    if (!SettingsRepository.instance) {
      SettingsRepository.instance = new SettingsRepository();
    }
    return SettingsRepository.instance;
  }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) {
      return;
    }
    this.context = context;
    try {
      this.preferences = await dataPreferences.getPreferences(this.context, PREFERENCES_NAME);
      this.serverAddress = await this.preferences.get('serverAddress', '');
      this.guidAuthKey = await this.preferences.get('guidAuthKey', '');
      const headerJson = await this.preferences.get('customHeaders', '{}');
      this.customHeaders = parseHeaders(headerJson);
    } catch (err) {
      console.error('Failed to initialize settings repository', err);
      this.serverAddress = '';
      this.guidAuthKey = '';
      this.customHeaders = {};
    }
    this.initialized = true;
    this.notify();
  }

  isConfigured(): boolean {
    return !!this.serverAddress && !!this.guidAuthKey;
  }

  subscribe(listener: SettingsListener): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private notify(): void {
    this.listeners.forEach(listener => listener());
  }

  async save(partial: Partial<StoredSettings>): Promise<void> {
    this.serverAddress = partial.serverAddress ?? this.serverAddress;
    this.guidAuthKey = partial.guidAuthKey ?? this.guidAuthKey;
    this.customHeaders = partial.customHeaders ?? this.customHeaders;

    if (!this.preferences && this.context) {
      this.preferences = await dataPreferences.getPreferences(this.context, PREFERENCES_NAME);
    }

    if (!this.preferences) {
      console.error('Preferences not ready; cannot persist settings');
      this.notify();
      return;
    }

    try {
      await this.preferences.put('serverAddress', this.serverAddress);
      await this.preferences.put('guidAuthKey', this.guidAuthKey);
      await this.preferences.put('customHeaders', serializeHeaders(this.customHeaders));
      await this.preferences.flush();
    } catch (err) {
      console.error('Failed to persist settings', err);
    }

    this.notify();
  }

  async clear(): Promise<void> {
    this.serverAddress = '';
    this.guidAuthKey = '';
    this.customHeaders = {};
    if (!this.preferences && this.context) {
      this.preferences = await dataPreferences.getPreferences(this.context, PREFERENCES_NAME);
    }
    if (this.preferences) {
      await this.preferences.clear();
      await this.preferences.flush();
    }
    this.notify();
  }
}

export default SettingsRepository.getInstance();
