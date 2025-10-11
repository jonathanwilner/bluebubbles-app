import HttpService from '../network/HttpService';
import { ChatSummary, computeChatSubtitle, computeChatTitle } from '../models/chat';
import { formatRelativeTime } from '../utils/dates';

@Component
export struct ConversationList {
  httpClient: HttpService;
  onSelect: (chat: ChatSummary) => void;
  onOpenSettings: () => void;

  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';
  @State private chats: ChatSummary[] = [];

  aboutToAppear() {
    this.loadChats();
  }

  private async loadChats() {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      const chats = await this.httpClient.fetchChats();
      chats.sort((left, right) => {
        const leftDate = left.lastMessage?.dateCreated?.getTime?.() ?? 0;
        const rightDate = right.lastMessage?.dateCreated?.getTime?.() ?? 0;
        return rightDate - leftDate;
      });
      this.chats = chats;
    } catch (err) {
      console.error('Failed to load chats', err);
      this.errorMessage = err?.message ?? 'Unable to retrieve chats from the server.';
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      Row() {
        Column() {
          Text('BlueBubbles')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text('Stay connected to iMessage through your Mac')
            .fontSize(14)
            .fontColor('#88FFFFFF')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('Settings')
          .type(ButtonType.Capsule)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#3949AB')
          .padding({ left: 16, right: 16 })
          .height(36)
          .onClick(() => this.onOpenSettings?.())
      }
      .alignItems(VerticalAlign.Center)

      if (this.isLoading) {
        Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
          Progress()
            .type(ProgressType.Circular)
            .width(32)
            .height(32)
          Text('Loading conversations…')
            .fontSize(14)
            .fontColor('#88FFFFFF')
            .margin({ top: 12 })
        }
        .width('100%')
        .height('80%')
      } else if (this.errorMessage) {
        Column() {
          Text('We could not load your chats.')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
          Text(this.errorMessage)
            .fontSize(14)
            .fontColor('#FF8A80')
            .margin({ top: 12 })
          Button('Try Again')
            .type(ButtonType.Capsule)
            .backgroundColor('#3949AB')
            .fontSize(16)
            .margin({ top: 24 })
            .onClick(() => this.loadChats())
        }
        .width('100%')
        .height('70%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          List({ space: 0, edgeEffect: EdgeEffect.Spring }) {
            ForEach(this.chats, chat => {
              ListItem() {
                ConversationTile({
                  chat,
                  onSelect: this.onSelect,
                })
              }
            }, chat => chat.guid)
          }
        }
        .margin({ top: 24 })
      }
    }
    .padding({ left: 24, right: 24, top: 24, bottom: 24 })
    .backgroundColor('#0D111F')
    .height('100%')
    .width('100%')
  }
}

@Component
struct ConversationTile {
  chat: ChatSummary;
  onSelect: (chat: ChatSummary) => void;

  private initials(): string {
    if (this.chat.participants.length === 1) {
      return this.chat.participants[0].initials ?? '•';
    }
    const title = computeChatTitle(this.chat);
    return title
      .split(/\s+/)
      .filter(token => token.length > 0)
      .map(token => token[0])
      .join('')
      .substring(0, 2)
      .toUpperCase();
  }

  build() {
    Column() {
      Row({ space: 16 }) {
        Stack() {
          Circle()
            .width(48)
            .height(48)
            .fill(Color.White)
            .opacity(0.12)
          Text(this.initials())
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }

        Column({ space: 6 }) {
          Row() {
            Text(computeChatTitle(this.chat))
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            if (this.chat.lastMessage) {
              Text(formatRelativeTime(this.chat.lastMessage.dateCreated))
                .fontSize(12)
                .fontColor('#88FFFFFF')
            }
          }
          Text(computeChatSubtitle(this.chat))
            .fontSize(14)
            .fontColor(this.chat.hasUnreadMessage ? Color.White : '#99FFFFFF')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .padding({ top: 16, bottom: 16 })

      Divider()
        .color('#1F2A40')
        .strokeWidth(1)
    }
    .width('100%')
    .onClick(() => this.onSelect?.(this.chat))
  }
}
