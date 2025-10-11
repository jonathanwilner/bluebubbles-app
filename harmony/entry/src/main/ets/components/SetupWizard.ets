import { SettingsRepository } from '../state/SettingsRepository';
import HttpService, { HttpConfiguration } from '../network/HttpService';

function parseCustomHeaders(raw: string): Record<string, string> {
  const sanitized = raw.trim();
  if (!sanitized) {
    return {};
  }
  try {
    const parsed = JSON.parse(sanitized);
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
    console.error('Failed to parse custom headers', err);
  }
  return {};
}

@Component
export struct SetupWizard {
  settings: SettingsRepository;
  onConfigured: (client: HttpService) => void;

  @State private serverAddress: string = '';
  @State private guidAuthKey: string = '';
  @State private customHeadersText: string = '';
  @State private busy: boolean = false;
  @State private errorMessage: string = '';
  @State private success: boolean = false;

  aboutToAppear() {
    this.serverAddress = this.settings.serverAddress;
    this.guidAuthKey = this.settings.guidAuthKey;
    this.customHeadersText = JSON.stringify(this.settings.customHeaders, null, 2);
  }

  private buildConfiguration(): HttpConfiguration {
    const serverAddress = this.serverAddress.trim();
    const guidAuthKey = this.guidAuthKey.trim();
    const customHeaders = parseCustomHeaders(this.customHeadersText);
    return { serverAddress, guidAuthKey, customHeaders };
  }

  private async connect(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorMessage = '';
    this.success = false;
    try {
      const configuration = this.buildConfiguration();
      if (!configuration.serverAddress || !configuration.guidAuthKey) {
        this.errorMessage = 'Server address and GUID auth key are required.';
        return;
      }
      const probeClient = new HttpService(configuration);
      await probeClient.ping();
      await this.settings.save(configuration);
      const client = new HttpService({
        serverAddress: this.settings.serverAddress,
        guidAuthKey: this.settings.guidAuthKey,
        customHeaders: this.settings.customHeaders,
      });
      this.success = true;
      this.onConfigured?.(client);
    } catch (err) {
      console.error('Failed to connect to server', err);
      this.errorMessage = err?.message ?? 'Unable to connect to BlueBubbles server.';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Text('Connect to Your BlueBubbles Server')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ bottom: 24 })
        .textAlign(TextAlign.Center)

      Column() {
        Text('Server URL')
          .fontSize(14)
          .fontColor('#99FFFFFF')
          .margin({ bottom: 8 })
        TextInput({ placeholder: 'https://example.com' })
          .caretColor(Color.White)
          .fontSize(16)
          .text(this.serverAddress)
          .height(48)
          .backgroundColor('#22FFFFFF')
          .padding({ left: 16, right: 16 })
          .borderRadius(12)
          .onChange(value => this.serverAddress = value)
      }
      .width('100%')

      Column() {
        Text('GUID Auth Key')
          .fontSize(14)
          .fontColor('#99FFFFFF')
          .margin({ top: 24, bottom: 8 })
        TextInput({ placeholder: 'Copy from the macOS server' })
          .secure(true)
          .caretColor(Color.White)
          .fontSize(16)
          .text(this.guidAuthKey)
          .height(48)
          .backgroundColor('#22FFFFFF')
          .padding({ left: 16, right: 16 })
          .borderRadius(12)
          .onChange(value => this.guidAuthKey = value)
      }
      .width('100%')

      Column() {
        Text('Custom Headers (JSON)')
          .fontSize(14)
          .fontColor('#99FFFFFF')
          .margin({ top: 24, bottom: 8 })
        TextArea({ placeholder: '{"ngrok-skip-browser-warning": "true"}' })
          .caretColor(Color.White)
          .fontSize(14)
          .text(this.customHeadersText)
          .height(120)
          .backgroundColor('#22FFFFFF')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .borderRadius(12)
          .onChange(value => this.customHeadersText = value)
      }
      .width('100%')

      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontColor('#FF6B6B')
          .fontSize(14)
          .margin({ top: 16 })
          .textAlign(TextAlign.Center)
      }

      if (this.success) {
        Text('Connection successful!')
          .fontColor('#7CFFB2')
          .fontSize(14)
          .margin({ top: 16 })
          .textAlign(TextAlign.Center)
      }

      Button(this.busy ? 'Connecting…' : 'Save & Connect')
        .type(ButtonType.Capsule)
        .width('100%')
        .height(52)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.busy ? '#335C6BC0' : '#5C6BC0')
        .margin({ top: 32 })
        .disabled(this.busy)
        .onClick(() => this.connect())
    }
    .padding({ left: 32, right: 32, top: 48, bottom: 24 })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#101421')
    .width('100%')
    .height('100%')
  }
}
