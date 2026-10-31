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
    </div>
    <div class="flex flex-col setting-group setting-group-security">
      <div class="user-setting-section-title">
        {{ $t("i18nCommon.security.title") }}
      </div>
      <div class="flex security-items">
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
import eventBus from "@/common/event/TMEventBus.js";
import { TMEnumEventBus } from "@/common/event/TMEnumEventBus.js";
import { loadLocale } from "@/i18n/i18nData.js";

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
      // Trạng thái gốc từ daemon/ngôn ngữ đang dùng — để chỉ áp dụng khi đổi
      initialEnableLogin: false,
      initialLanguage: "vi",
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
      me.initialLanguage = me.currentUserSetting.currentLanguage;
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
          me.initialEnableLogin = !!data.enabled;
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
          me.securitySetting.currentPassword = "";
          me.securitySetting.newUsername = "";
          me.securitySetting.newPassword = "";
        }

        // Chỉ gọi set_enabled khi thật sự đổi — gọi lại giá trị cũ sẽ
        // clear session (tắt) và bắt đăng nhập lại oan
        if (me.securitySetting.enableLogin !== me.initialEnableLogin) {
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
          me.initialEnableLogin = me.securitySetting.enableLogin;
        }

        // Cập nhật gate đăng nhập live, KHÔNG reload app
        appState.authRequired = me.securitySetting.enableLogin;
        me.$tmToast.success(me.$t("i18nCommon.security.settingSaved"));
      } catch (e) {
        me.$tmToast.error(me.$t("i18nCommon.security.settingSaveFailed"));
      }
    },
    async saveSetting() {
      let me = this;
      me.saveTheme();
      me.saveAppFont();
      me.handleChangeAgentURL();
      // Áp dụng live qua event bus (giống menu header), không reload app —
      // reload làm app quay lại màn hình đăng nhập nếu cookie chưa kịp
      eventBus.emit(
        TMEnumEventBus.themeChanged,
        me.currentUserSetting.theme,
      );
      eventBus.emit(
        TMEnumEventBus.backgroundEffectChanged,
        me.currentUserSetting.backgroundEffect,
      );
      eventBus.emit(
        TMEnumEventBus.cursorEffectChanged,
        me.currentUserSetting.cursorEffect,
      );
      eventBus.emit(
        TMEnumEventBus.welcomeBackgroundChanged,
        me.currentUserSetting.welcomeBackground,
      );
      appState.sideBarMenuPosition = me.currentUserSetting.sideBarMenuPosition;
      if (me.currentUserSetting.currentLanguage !== me.initialLanguage) {
        await loadLocale(me.currentUserSetting.currentLanguage);
        me.initialLanguage = me.currentUserSetting.currentLanguage;
      }
      await me.$tmCache.set(
        me.$tmEnum.cacheConfig.UserSettings,
        me.currentUserSetting,
      );
      // cache.set tự đẩy xuống daemon (TMCache._queueRemoteSet)
      me.$tmToast.success(me.$t("i18nUserSettings.saveSuccess"));
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
      align-self: stretch;
      background-color: var(--bg-layer-color);
      border-radius: var(--border-radius);
    }
    .setting-group {
      width: 100%;
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
  .setting-group-security {
    width: 100%;
    gap: var(--padding);
    .user-setting-section-title {
      font-weight: bold;
    }
    .security-items {
      width: 100%;
      gap: calc(var(--padding) * 2);
      align-items: center;
      .user-setting-item {
        width: auto;
        justify-content: flex-start;
        gap: var(--padding);
        .input-setting {
          width: 200px;
        }
      }
    }
  }
}
</style>
