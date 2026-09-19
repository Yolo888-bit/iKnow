/** AI 答疑记录 */
@Observed
export class QuestionRecord {
  id: string = ''
  /** 所属用户（本地体验模式下一个设备一个 id；预留多档案隔离） */
  userId: string = ''
  sessionId: string = ''
  question: string = ''
  answer: string = ''
  createdAt: number = 0
}
