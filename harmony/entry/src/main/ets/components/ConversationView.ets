import HttpService from '../network/HttpService';
import { ChatSummary, computeChatTitle } from '../models/chat';
import { MessageModel } from '../models/message';
import { formatTimestamp } from '../utils/dates';
import { createTempGuid } from '../utils/guid';

@Component
export struct ConversationView {
  chat: ChatSummary;
  httpClient: HttpService;
  onBack: () => void;

  @State private messages: MessageModel[] = [];
  @State private isLoading: boolean = true;
  @State private errorMessage: string = '';
  @State private composerText: string = '';
  @State private isSending: boolean = false;

  aboutToAppear() {
    this.loadMessages();
  }

  private async loadMessages() {
    this.isLoading = true;
    this.errorMessage = '';
    try {
      const messages = await this.httpClient.fetchMessages(this.chat.guid);
      this.messages = messages;
    } catch (err) {
      console.error('Failed to load chat messages', err);
      this.errorMessage = err?.message ?? 'Unable to fetch messages from the server.';
    } finally {
      this.isLoading = false;
    }
  }

  private async sendMessage() {
    const value = this.composerText.trim();
    if (!value || this.isSending) {
      return;
    }
    this.isSending = true;
    const tempGuid = createTempGuid();
    const optimistic: MessageModel = {
      guid: tempGuid,
      text: value,
      isFromMe: true,
      dateCreated: new Date(),
      hasAttachments: false,
    };
    const previous = this.messages;
    this.messages = [...previous, optimistic];
    this.composerText = '';
    try {
      await this.httpClient.sendMessage(this.chat.guid, tempGuid, value);
      await this.loadMessages();
    } catch (err) {
      console.error('Failed to send message', err);
      this.errorMessage = err?.message ?? 'Failed to deliver message.';
      this.messages = previous;
    } finally {
      this.isSending = false;
    }
  }

  private renderMessages() {
    if (this.isLoading) {
      return Flex({ direction: FlexDirection.Column, justifyContent: FlexAlign.Center, alignItems: ItemAlign.Center }) {
        Progress()
          .type(ProgressType.Circular)
          .width(28)
          .height(28)
        Text('Loading messages…')
          .fontColor('#88FFFFFF')
          .fontSize(14)
          .margin({ top: 12 })
      }
      .width('100%')
      .height('100%');
    }
    if (this.errorMessage) {
      return Column() {
        Text('Unable to load messages')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
        Text(this.errorMessage)
          .fontColor('#FF8A80')
          .fontSize(14)
          .margin({ top: 8 })
        Button('Try Again')
          .type(ButtonType.Capsule)
          .fontSize(16)
          .backgroundColor('#3949AB')
          .margin({ top: 24 })
          .onClick(() => this.loadMessages())
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    }
    return Scroll() {
      Column({ space: 12 }) {
        ForEach(this.messages, message => {
          MessageBubble({
            message,
            isFromMe: message.isFromMe,
            showSender: this.chat.participants.length > 1,
          })
        }, message => message.guid)
      }
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
    };
  }

  build() {
    Column() {
      Row() {
        Button('Back')
          .type(ButtonType.Capsule)
          .fontSize(14)
          .backgroundColor('#3949AB')
          .padding({ left: 18, right: 18 })
          .height(36)
          .onClick(() => this.onBack?.())
        Column() {
          Text(computeChatTitle(this.chat))
            .fontSize(20)
            .fontWeight(FontWeight.SemiBold)
            .fontColor(Color.White)
          if (this.chat.participants.length > 1) {
            const participants = this.chat.participants.map(item => item.displayName ?? item.address).join(', ');
            Text(participants)
              .fontSize(12)
              .fontColor('#88FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 })
        Spacer()
      }
      .padding({ top: 16, left: 16, right: 16, bottom: 12 })

      this.renderMessages()
        .layoutWeight(1)

      if (this.errorMessage && !this.isLoading) {
        Text(this.errorMessage)
          .fontColor('#FF8A80')
          .fontSize(12)
          .margin({ left: 16, right: 16, bottom: 8 })
          .textAlign(TextAlign.Center)
      }

      Row({ space: 12 }) {
        TextArea({ placeholder: 'iMessage…' })
          .layoutWeight(1)
          .fontSize(16)
          .text(this.composerText)
          .backgroundColor('#1A263D')
          .borderRadius(18)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .caretColor(Color.White)
          .onChange(value => this.composerText = value)
        Button(this.isSending ? 'Sending…' : 'Send')
          .type(ButtonType.Capsule)
          .backgroundColor(this.isSending ? '#335C6BC0' : '#5C6BC0')
          .height(44)
          .padding({ left: 20, right: 20 })
          .fontSize(16)
          .disabled(this.isSending || !this.composerText.trim())
          .onClick(() => this.sendMessage())
      }
      .padding({ left: 16, right: 16, top: 12, bottom: 24 })
      .backgroundColor('#141C30')
    }
    .backgroundColor('#0D111F')
    .width('100%')
    .height('100%')
  }
}

@Component
struct MessageBubble {
  message: MessageModel;
  isFromMe: boolean;
  showSender: boolean;

  build() {
    if (this.isFromMe) {
      Row() {
        Column() {
          Text(this.message.text || (this.message.hasAttachments ? 'Attachment' : ''))
            .fontColor(Color.White)
            .fontSize(16)
            .margin({ bottom: 4 })
          Text(formatTimestamp(this.message.dateCreated))
            .fontColor('#E0E0E0')
            .fontSize(10)
            .textAlign(TextAlign.End)
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor('#0B84FF')
        .borderRadius(18)
        .maxWidth('80%')
      }
      .justifyContent(FlexAlign.End)
    } else {
      Row() {
        Column() {
          if (this.showSender && this.message.handle?.displayName) {
            Text(this.message.handle.displayName)
              .fontColor('#88FFFFFF')
              .fontSize(12)
              .margin({ left: 4, bottom: 4 })
          }
          Column() {
            Text(this.message.text || (this.message.hasAttachments ? 'Attachment' : ''))
              .fontColor(Color.Black)
              .fontSize(16)
              .margin({ bottom: 4 })
            Text(formatTimestamp(this.message.dateCreated))
              .fontColor('#555A64')
              .fontSize(10)
          }
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .backgroundColor('#E5E7EB')
          .borderRadius(18)
          .maxWidth('80%')
        }
      }
      .justifyContent(FlexAlign.Start)
    }
  }
}
