/** 长期个人专注画像（五维 + 趋势） */
@Observed
export class FocusProfile {
  id: string = ''
  bestFocusTime: string = '09:30 - 11:30'
  averageFocusDuration: number = 42   // 平均单次专注时长（分钟）
  focusThreshold: number = 48         // 当前专注阈值（分钟）
  efficiency: number = 82
  concentration: number = 75
  stability: number = 68
  execution: number = 86
  antiDistraction: number = 72
  weeklyTrend: number[] = []          // 近 7 天每日净专注分钟
  monthlyTrend: number[] = []         // 近 30 天平均专注时长演变
  updatedAt: number = 0
}
