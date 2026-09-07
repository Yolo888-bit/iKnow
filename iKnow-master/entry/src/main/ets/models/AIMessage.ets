import { MessageRole } from './Enums'

/** AI 对话消息 */
@Observed
export class AIMessage {
  id: string = ''
  role: MessageRole = MessageRole.AI
  content: string = ''
  timestamp: number = 0
}
