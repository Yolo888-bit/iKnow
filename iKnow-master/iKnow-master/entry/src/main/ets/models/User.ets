import { AIPersonality } from './Enums'

/** 用户 */
@Observed
export class User {
  id: string = ''
  nickname: string = '刘灿'
  avatar: string = '🧑‍🎓'
  aiPersonality: AIPersonality = AIPersonality.GENTLE
  createdAt: number = 0
}
