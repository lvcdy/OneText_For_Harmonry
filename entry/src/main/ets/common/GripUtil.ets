import { motion } from '@kit.MultimodalAwarenessKit';

export class GripUtil {
  static getLeftHandHeld(status: motion.HoldingHandStatus): boolean | null {
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      return true;
    }

    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD ||
      status === motion.HoldingHandStatus.BOTH_HANDS_HELD) {
      return false;
    }

    return null;
  }
}
