export class UiStyle {
  static readonly PAGE_BG: string = '#F8FAFF';
  static readonly CARD_BORDER: string = '#ECF3FF';
  static readonly CARD_SHADOW: string = '#102F6BFF';
  static readonly CARD_SHADOW_SOFT: string = '#0A2F6BFF';
  static readonly GLASS_CARD_BG: string = '#CCFFFFFF';
  static readonly GLASS_CARD_BG_SOFT: string = '#B8FFFFFF';
  static readonly GLASS_CONTROL_BG: string = '#E6FFFFFF';
  static readonly GLASS_SELECTED_BG: string = '#1A2F6BFF';
  static readonly GLASS_CARD_BORDER: string = '#66FFFFFF';
  static readonly GLASS_CARD_SHADOW: string = '#1F000000';
  static readonly SELECTED_BG: string = '#EEF3FF';
  static readonly CONTROL_BG: string = '#F3F5F8';
  static readonly TRANSPARENT: string = '#00FFFFFF';
  static readonly DANGER: string = '#D94841';
  static readonly OVERLAY_BG: string = '#80000000';
  static readonly TAG_BLUE: string = '#2196F3';
  static readonly TAG_GREEN: string = '#4CAF50';

  static readonly PAGE_SIDE: number = 20;
  // 鸿蒙7: 使用 @Env(SystemProperties.WINDOW_AVOID_AREA) 动态获取避让区域，不再需要硬编码
  // FULLSCREEN_TOP_INSET 已迁移到各页面的 getStatusBarHeight() 方法
  static readonly CARD_RADIUS: number = 30;
  static readonly DIALOG_RADIUS: number = 24;
  static readonly CHIP_RADIUS: number = 18;
  static readonly CARD_GAP: number = 16;
  static readonly CARD_SIDE: number = 22;
  static readonly HEADER_HEIGHT: number = 96;
  static readonly HEADER_ROW_HEIGHT: number = 52;
  static readonly LIST_ROW_HEIGHT: number = 58;
  static readonly BOTTOM_ACTION_HEIGHT: number = 128;
  static readonly FLOAT_TAB_BOTTOM_SPACE: number = 124;
}
