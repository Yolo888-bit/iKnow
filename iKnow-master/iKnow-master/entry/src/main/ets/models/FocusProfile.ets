/** 长期个人专注画像（五维 + 趋势，PRD §6） */
@Observed
export class FocusProfile {
  id: string = ''
  bestFocusTime: string = '09:30 - 11:30'
  averageFocusDuration: number = 42   // 平均单次专注时长（分钟）
  focusThreshold: number = 48         // 当前专注阈值（分钟）
  efficiency: number = 0
  concentration: number = 0
  stability: number = 0
  execution: number = 0
  antiDistraction: number = 0
  weeklyTrend: number[] = []          // 近 7 天每日净专注分钟
  monthlyTrend: number[] = []         // 近 30 天平均专注时长演变
  // ---- §6 统计样本（N>=3 才显示五维，否则"还在了解你"）----
  sampleCount: number = 0             // 已纳入统计的会话数
  recentConcentrations: number[] = [] // 最近若干次净专注率（%）
  recentDistractionRates: number[] = [] // 最近若干次分心率（0-1）
  updatedAt: number = 0
}
