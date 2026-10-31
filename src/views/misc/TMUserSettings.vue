<template>
  <div class="flex flex-col tm-user-setting">
    <div class="flex setting-content">
      <div class="flex flex-col setting-group">
        <div class="flex user-setting-item">
          <div>{{ $t("i18nCommon.apiTesting.tooltipUrlAgent") }}</div>
          <div class="input-setting">
            <TMInput
              v-model="currentUserSetting.agentURL"
              v-tooltip="$t('i18nCommon.apiTesting.tooltipUrlAgent')"
              :noMargin="true"
              :placeHolder="$t('i18nCommon.apiTesting.agentUrl')"
            />
          </div>
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nUserSettings.settings.theme") }}</div>
          <TMComboBox
            :width="200"
            v-model="currentUserSetting.theme"
            :options="themeOption"
            :noMargin="true"
          />
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nUserSettings.settings.backgroundEffect") }}</div>
          <TMComboBox
            :width="200"
            v-model="currentUserSetting.backgroundEffect"
            :options="backgroundEffectOption"
            :noMargin="true"
          />
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nUserSettings.settings.cursorEffect") }}</div>
          <TMComboBox
            :width="200"
            v-model="currentUserSetting.cursorEffect"
            :options="cursorEffectOption"
            :noMargin="true"
          />
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nUserSettings.settings.welcomeBackground") }}</div>
          <TMComboBox
            :width="200"
            v-model="currentUserSetting.welcomeBackground"
            :options="welcomeBackgroundOption"
            :noMargin="true"
          />
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nUserSettings.settings.appFont") }}</div>
          <TMComboBox
            :width="200"
            v-model="currentUserSetting.appFont"
            :options="appFontOption"
            :noMargin="true"
          />
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nUserSettings.settings.language") }}</div>
          <TMComboBox
            :width="200"
            v-model="currentUserSetting.currentLanguage"
            :options="languageOption"
            :noMargin="true"
          />
        </div>
      </div>
      <div class="divide"></div>
      <div class="flex flex-col setting-group">
        <div class="flex user-setting-item">
          <TMCheckbox
            :variant="$tmEnum.checkboxType.switch"
            v-model="currentUserSetting.wrapTab"
            :label="$t('i18nUserSettings.settings.wrapTab')"
            :noMargin="true"
          ></TMCheckbox>
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nUserSettings.settings.sideBarMenuPosition") }}</div>
          <TMComboBox
            :width="200"
            v-model="currentUserSetting.sideBarMenuPosition"
            :options="sideBarMenuPositionOption"
            :noMargin="true"
          />
        </div>
      </div>
      <div class="divide"></div>
      <div class="flex flex-col setting-group">
        <div class="user-setting-section-title">
          {{ $t("i18nCommon.security.title") }}
        </div>
        <div class="flex user-setting-item">
          <TMCheckbox
            :variant="$tmEnum.checkboxType.switch"
            v-model="securitySetting.enableLogin"
            :label="$t('i18nCommon.security.enableLogin')"
            :noMargin="true"
          ></TMCheckbox>
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nCommon.security.currentPassword") }}</div>
          <div class="input-setting">
            <TMInput
              v-model="securitySetting.currentPassword"
              :inputType="'password'"
              :noMargin="true"
            />
          </div>
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nCommon.security.newUsername") }}</div>
          <div class="input-setting">
            <TMInput v-model="securitySetting.newUsername" :noMargin="true" />
          </div>
        </div>
        <div class="flex user-setting-item">
          <div>{{ $t("i18nCommon.security.newPassword") }}</div>
          <div class="input-setting">
            <TMInput
              v-model="securitySetting.newPassword"
              :inputType="'password'"
              :noMargin="true"
            />
          </div>
        </div>
        <TMButton
          :noMargin="true"
          @click="applySecuritySetting"
          :label="$t('i18nCommon.security.apply')"
        />
      </div>
    </div>
    <TMButton
      :noMargin="true"
      @click="saveSetting"
      :label="$t('i18nUserSettings.saveSetting')"
    />
  </div>
</template>
<script>
import TMAutomation from "@/common/automation/TMAutomation.js";
import TMAgentAPI from "@/common/api/request/AgentAPI/TMAgentAPI.js";
import TMAuthAPI from "@/common/api/request/AgentAPI/TMAuthAPI.js";
import { getUserSettingDefault } from "@/common/TMUserSettingDefault.js";
import { appState } from "@/stores/TMAppState.js";

export default {
  name: "TMUserSettings",

  data() {
    let me = this;
    return {
      currentUserSetting: getUserSettingDefault(),
      // Setting đăng nhập lưu ở DAEMON (config + db), không phải cache client
      securitySetting: {
        enableLogin: false,
        currentPassword: "",
        newUsername: "",
        newPassword: "",
      },
      themeOption: me.$tmEnum.monacoThemeList,
      languageOption: [
        { value: "vi", label: me.$t("i18nGlobal.language.vi") },
        { value: "en", label: me.$t("i18nGlobal.language.en") },
      ],
    };
  },
  computed: {
    welcomeBackgroundOption() {
      return this.$tmEnum.welcomeBackgroundList.map((item) => ({
        label: this.$t(item.labelKey),
        value: item.value,
      }));
    },
    backgroundEffectOption() {
      return this.$tmEnum.backgroundEffectList.map((item) => ({
        label: this.$t(item.labelKey),
        value: item.value,
      }));
    },
    cursorEffectOption() {
      return this.$tmEnum.cursorEffectList.map((item) => ({
        label: this.$t(item.labelKey),
        value: item.value,
      }));
    },
    sideBarMenuPositionOption() {
      return this.$tmEnum.sideBarMenuPositionList.map((item) => ({
        label: this.$t(item.labelKey),
        value: item.value,
      }));
    },
    appFontOption() {
      return this.$tmEnum.appFontList.map((item) => ({
        label: this.$t(item.labelKey),
        value: item.value,
      }));
    },
  },
  created() {
    let me = this;
    me.processWhenCreated();
    me.processSecurityWhenCreated();
  },
  methods: {
    async processWhenCreated() {
      let me = this;
      let cacheData = await me.$tmUtility.getUserSettings();
      if (cacheData) {
        me.currentUserSetting = Object.assign(me.currentUserSetting, cacheData);
      }
    },
    /**
     * Trạng thái đăng nhập lấy từ daemon (config server), không phải cache client
     */
    async processSecurityWhenCreated() {
      let me = this;
      try {
        const res = await new TMAuthAPI().status();
        const data = res?.data?.data;
        if (data) {
          me.securitySetting.enableLogin = !!data.enabled;
        }
      } catch (e) {
        // Daemon không trả lời — giữ mặc định tắt
      }
    },
    /**
     * Áp dụng setting đăng nhập: bật/tắt + đổi thông tin đăng nhập (nếu điền)
     */
    async applySecuritySetting() {
      let me = this;
      let hasCredentials =
        me.securitySetting.currentPassword &&
        (me.securitySetting.newUsername || me.securitySetting.newPassword);

      try {
        if (hasCredentials) {
          const credRes = await new TMAuthAPI().changeCredentials(
            me.securitySetting.currentPassword,
            me.securitySetting.newUsername,
            me.securitySetting.newPassword,
          );
          if (!credRes?.data?.success) {
            me.$tmToast.error(
              credRes?.data?.message ||
                me.$t("i18nCommon.security.settingSaveFailed"),
            );
            return;
          }
          me.$tmToast.success(me.$t("i18nCommon.security.credentialsChanged"));
        }

        const enableRes = await new TMAuthAPI().setEnabled(
          me.securitySetting.enableLogin,
        );
        if (!enableRes?.data?.success) {
          me.$tmToast.error(
            enableRes?.data?.message ||
              me.$t("i18nCommon.security.settingSaveFailed"),
          );
          return;
        }
        me.$tmToast.success(me.$t("i18nCommon.security.settingSaved"));

        // Đồng bộ lại trạng thái gate login rồi reload cho sạch
        appState.authRequired = me.securitySetting.enableLogin;
        me.$tmUtility.reloadApp();
      } catch (e) {
        me.$tmToast.error(me.$t("i18nCommon.security.settingSaveFailed"));
      }
    },
    async saveSetting() {
      let me = this;
      me.saveTheme();
      me.saveAppFont();
      me.handleChangeAgentURL();
      await me.$tmCache.set(
        me.$tmEnum.cacheConfig.UserSettings,
        me.currentUserSetting,
      );
      // UserSettingsV2: đẩy xuống daemon (best-effort, lỗi thì còn cache local)
      await me.$tmUtility.syncUserSettingsToServer();
      me.$tmUtility.reloadApp();
    },
    handleChangeAgentURL() {
      let me = this;
      TMAutomation.setGlobalInfoBeforeRequest({
        agentURL: me.currentUserSetting.agentURL,
      });
    },
    saveTheme() {
      let me = this;
      me.$tmUtility.setTheme(me.currentUserSetting.theme);
    },
    saveAppFont() {
      let me = this;
      me.$tmUtility.setAppFont(me.currentUserSetting.appFont);
    },
  },
  mounted() {},
};
</script>

<style lang="scss" scoped>
.tm-user-setting {
  width: 100%;
  height: 100%;
  justify-content: flex-start;
  align-items: center;
  gap: var(--padding);
  .setting-content {
    width: 100%;
    gap: var(--padding);
    .divide {
      width: var(--padding);
      height: 100%;
      background-color: var(--bg-layer-color);
      border-radius: var(--border-radius);
    }
    .setting-group {
      width: 100%;
      height: 100%;
      gap: var(--padding);
      justify-content: flex-start;
      .user-setting-section-title {
        font-weight: bold;
      }
      .user-setting-item {
        width: 100%;
        justify-content: space-between;
        .input-setting {
          width: 200px;
        }
      }
    }
  }
}
</style>
