import { MessageRole } from "@normalized:N&&&entry/src/main/ets/models/Enums&";
/** AI 对话消息 */
@Observed
export class AIMessage {
    id: string = '';
    role: MessageRole = MessageRole.AI;
    content: string = '';
    timestamp: number = 0;
}
