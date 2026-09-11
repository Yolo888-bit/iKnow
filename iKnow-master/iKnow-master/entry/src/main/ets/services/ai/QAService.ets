import { AIRequest, AIResponse } from './AIService'

/**
 * 答疑服务契约（PRD §13 / §14，场景 qa_text / qa_image）
 */
export interface QAMessage {
  role: string
  content: string
}

export interface QATextPayload {
  question: string
  subject?: string
  history?: Array<QAMessage>
}

/** 图片答疑：仅传端侧 OCR 后的文本引用 / 资源句柄，绝不传原始影像（§14.7） */
export interface QAImagePayload {
  imageRef: string
  question?: string
}

export interface QAResp {
  answer: string
  references?: string[]
  /** §14.7 QA 必须携带免责声明 */
  disclaimer: string
  scene: 'qa_text' | 'qa_image'
}

export interface QAService {
  askText(req: AIRequest<QATextPayload>): Promise<AIResponse<QAResp>>
  askImage(req: AIRequest<QAImagePayload>): Promise<AIResponse<QAResp>>
}

/** qa_text / qa_image 输出 JSON Schema 版本（供 SchemaValidator 校验） */
export const QA_SCHEMA_VERSION = 'qa@2026-09-11'
