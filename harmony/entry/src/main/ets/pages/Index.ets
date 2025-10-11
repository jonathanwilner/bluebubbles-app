import HttpService from '../network/HttpService';
import settingsRepository, { SettingsRepository } from '../state/SettingsRepository';
import { ChatSummary } from '../models/chat';
import { ConversationList } from '../components/ConversationList';
import { ConversationView } from '../components/ConversationView';
import { SetupWizard } from '../components/SetupWizard';

@Entry
@Component
export struct Index {
  private settings: SettingsRepository = settingsRepository;
  private unsubscribe?: () => void;

  @State private httpClient?: HttpService;
  @State private selectedChat?: ChatSummary;
  @State private showSettings: boolean = false;

  aboutToAppear() {
    this.unsubscribe = this.settings.subscribe(() => this.refreshClient());
    this.showSettings = !this.settings.isConfigured();
    this.refreshClient();
  }

  aboutToDisappear() {
    this.unsubscribe?.();
  }

  private refreshClient() {
    if (this.settings.isConfigured()) {
      this.httpClient = new HttpService({
        serverAddress: this.settings.serverAddress,
        guidAuthKey: this.settings.guidAuthKey,
        customHeaders: this.settings.customHeaders,
      });
      if (!this.selectedChat) {
        this.showSettings = false;
      }
    } else {
      this.httpClient = undefined;
      this.showSettings = true;
    }
  }

  private handleChatSelected(chat: ChatSummary) {
    this.selectedChat = chat;
  }

  private handleSettingsClosed(client: HttpService) {
    this.httpClient = client;
    this.showSettings = false;
    this.selectedChat = undefined;
  }

  build() {
    if (!this.httpClient || this.showSettings) {
      return SetupWizard({
        settings: this.settings,
        onConfigured: (client: HttpService) => this.handleSettingsClosed(client),
      });
    }

    if (this.selectedChat) {
      return ConversationView({
        chat: this.selectedChat,
        httpClient: this.httpClient,
        onBack: () => this.selectedChat = undefined,
      });
    }

    return ConversationList({
      httpClient: this.httpClient,
      onSelect: (chat: ChatSummary) => this.handleChatSelected(chat),
      onOpenSettings: () => this.showSettings = true,
    });
  }
}
