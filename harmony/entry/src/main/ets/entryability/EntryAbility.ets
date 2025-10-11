
import Ability from '@ohos.app.ability.UIAbility';
import common from '@ohos.app.ability.common';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import settingsRepository from '../state/SettingsRepository';

@Entry
export default class EntryAbility extends Ability {
  onCreate(want, launchParam) {
    hilog.info(0x0000, 'BlueBubbles', `EntryAbility onCreate, want: ${JSON.stringify(want)}`);
  }

  onDestroy() {
    hilog.info(0x0000, 'BlueBubbles', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage) {
    hilog.info(0x0000, 'BlueBubbles', 'onWindowStageCreate');
    const context = this.context as common.UIAbilityContext;
    settingsRepository.initialize(context).then(() => {
      windowStage.loadContent('pages/Index');
    }).catch((err) => {
      hilog.error(0x0000, 'BlueBubbles', `Failed to initialize settings: ${JSON.stringify(err)}`);
      windowStage.loadContent('pages/Index');
    });
  }

  onWindowStageDestroy() {
    hilog.info(0x0000, 'BlueBubbles', 'onWindowStageDestroy');
  }

  onForeground() {
    hilog.info(0x0000, 'BlueBubbles', 'EntryAbility onForeground');
  }

  onBackground() {
    hilog.info(0x0000, 'BlueBubbles', 'EntryAbility onBackground');
  }
}
