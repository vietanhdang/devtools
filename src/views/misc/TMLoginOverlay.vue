<template>
  <div class="flex tm-login-overlay">
    <div class="flex flex-col tm-login-card">
      <div class="tm-login-title">{{ $t("i18nCommon.login.title") }}</div>
      <TMInput
        ref="usernameInput"
        v-model="username"
        :placeHolder="$t('i18nCommon.login.usernamePlaceholder')"
        :noMargin="true"
        @keyup.enter="login"
      />
      <TMInput
        v-model="password"
        :inputType="'password'"
        :placeHolder="$t('i18nCommon.login.passwordPlaceholder')"
        :noMargin="true"
        @keyup.enter="login"
      />
      <div v-if="errorMessage" class="tm-login-error">{{ errorMessage }}</div>
      <TMButton
        :noMargin="true"
        :readOnly="isLoggingIn"
        :label="isLoggingIn ? $t('i18nCommon.login.loggingIn') : $t('i18nCommon.login.button')"
        @click="login"
      />
    </div>
  </div>
</template>

<script>
import TMAuthAPI from "@/common/api/request/AgentAPI/TMAuthAPI.js";
import { appState } from "@/stores/TMAppState.js";

/**
 * Màn hình đăng nhập full-screen khi daemon bật tính năng login.
 * Là component thường (KHÔNG dùng TMDialogUtil) để không bị đóng bằng Esc
 * hay click ngoài — đăng nhập là bắt buộc mới vào được app.
 */
export default {
  name: "TMLoginOverlay",

  data() {
    return {
      username: "",
      password: "",
      errorMessage: "",
      isLoggingIn: false,
    };
  },

  mounted() {
    let me = this;
    me.$refs.usernameInput?.$el?.querySelector("input")?.focus();
  },

  methods: {
    async login() {
      let me = this;
      if (me.isLoggingIn || !me.username || !me.password) {
        return;
      }

      me.isLoggingIn = true;
      me.errorMessage = "";
      try {
        const res = await new TMAuthAPI().login(me.username, me.password);
        const body = res?.data;
        if (body?.success) {
          appState.isLoggedIn = true;
        } else {
          me.errorMessage =
            body?.message || me.$t("i18nCommon.login.invalidCredentials");
        }
      } catch (e) {
        me.errorMessage = me.$t("i18nCommon.login.invalidCredentials");
      } finally {
        me.isLoggingIn = false;
      }
    },
  },
};
</script>

<style lang="scss" scoped>
.tm-login-overlay {
  position: fixed;
  inset: 0;
  z-index: 2000;
  background-color: var(--bg-main-color);
  justify-content: center;
  align-items: center;

  .tm-login-card {
    width: 320px;
    gap: var(--padding);
    padding: calc(var(--padding) * 2);
    background-color: var(--bg-layer-color);
    border-radius: var(--border-radius);

    .tm-login-title {
      font-size: 1.2rem;
      font-weight: bold;
      text-align: center;
    }

    .tm-login-error {
      color: var(--danger-color, #e5484d);
      font-size: 0.85rem;
      text-align: center;
    }
  }
}
</style>
