<template>
  <div class="flex tm-welcome">
    <div class="flex flex-col wrap-container">
      <div class="container">
        <!-- Đã chọn hình nền (xem $tmEnum.welcomeBackgroundList) thì chỉ hiện ảnh
nền phủ kín màn welcome; Normal không hiện gì -->
        <div
          v-if="isShowBackground"
          class="welcome-background"
          :class="`welcome-background--${welcomeBackground}`"
        ></div>
        <TMDynamicBackgroundEffect />
      </div>
    </div>
    <TMSubSidebar
      v-model="currentConfigLayout.isShowSidebar"
      @toggleSidebar="toggleSidebar"
    >
      <template v-slot:main>
        <TMWelcomeHelp />
      </template>
    </TMSubSidebar>
  </div>
</template>

<script>
import TMWelcomeHelp from "@/views/helps/TMWelcomeHelp.vue";
import TMSubSidebar from "@/components/TMSubSidebar.vue";
import TMDynamicBackgroundEffect from "@/views/backgroundEffect/TMDynamicBackgroundEffect.vue";
import TMLayoutConfigMixin from "@/mixins/TMLayoutConfigMixin.js";
import eventBus from "@/common/event/TMEventBus.js";
import { TMEnumEventBus } from "@/common/event/TMEnumEventBus.js";
import tmEnum from "@/common/TMEnum.js";

export default {
  name: "TMWelcome",
  mixins: [TMLayoutConfigMixin],
  components: {
    TMWelcomeHelp,
    TMSubSidebar,
    TMDynamicBackgroundEffect,
  },
  data() {
    return {
      welcomeBackground: this.$tmEnum.welcomeBackground.Normal,
      keyCacheLayout: this.$tmEnum.cacheConfig.WelcomeLayout,
      languageList: Object.keys(this.$tmEnum.language).sort(),
      currentConfigLayout: {
        isShowSidebar: false,
      },
    };
  },
  computed: {
    /**
     * normal là không chọn ảnh nên không hiện lớp nền
     */
    isShowBackground() {
      let me = this;
      return me.welcomeBackground != me.$tmEnum.welcomeBackground.Normal;
    },
  },
  created() {
    // Đổi hình nền từ menu giao diện trên header thì áp dụng tức thì, không
    // cần khởi động lại app như các thiết lập khác
    this.unsubscribeBackground = eventBus.on(
      TMEnumEventBus.welcomeBackgroundChanged,
      (value) => {
        this.welcomeBackground = value;
      },
    );
  },
  methods: {
    async toggleSidebar() {
      let me = this;
      await me.updateConfigLayout();
    },
    async processWhenMounted() {
      let me = this;
      let savedBackground = await me.$tmUtility.getUserSettings(
        "welcomeBackground",
      );
      // Nếu giá trị lưu không phải là giá trị enum hợp lệ thì quay về mặc định
      if (Object.values(tmEnum.welcomeBackground).includes(savedBackground)) {
        me.welcomeBackground = savedBackground;
      } else {
        me.welcomeBackground = tmEnum.welcomeBackground.Normal;
      }
    },
  },
  mounted() {
    this.processWhenMounted();
  },
  beforeUnmount() {
    this.unsubscribeBackground?.();
  },
};
</script>

<style lang="scss" scoped>
.tm-welcome {
  width: 100%;
  height: 100%;
  position: relative;
  overflow: hidden;
}

/* Giữ nguyên các style cũ của bạn */
.wrap-container {
  height: 100%;
  flex: 1;
}

.container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--padding);
  width: 100%;
  height: 100%;
  flex: 1;
  /* làm mốc định vị cho lớp nền bên trong */
  position: relative;
}

/* Hình nền màn welcome: inset tạo khoảng cách (margin) với mép màn hình.
contain để ảnh co vừa khung mà vẫn giữ nguyên tỷ lệ gốc (không méo, không
cắt), z-index 0 để nằm dưới text author và dưới TMDynamicBackgroundEffect */
.welcome-background {
  position: absolute;
  inset: var(--padding-large);
  z-index: 0;
  border-radius: var(--border-radius);
  background-repeat: no-repeat;
  background-position: center;
  background-size: contain;
  pointer-events: none;
}

.welcome-background--avatar {
  background-image: url("@/assets/loading_avatar.jpg");
}
</style>
