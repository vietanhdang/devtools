import utility from "@/common/TMUtility.js";
import TMAutomation from "@/common/automation/TMAutomation.js";
import cache from "@/common/cache/TMCache.js";

class TMAppStartup {
  constructor() {}

  /**
   * Phương thức khởi tạo ứng dụng
   */
  async initialize() {
    await this.applyRemoteSettings();
    // đảm bảo rằng __env là một đối tượng bất biến
    utility.freezeDeepObject(window.__env);
    document.title = `${utility.defaultTitleApp()} - ${utility.getAuthorApp()}`;
  }

  /**
   * Kéo setting từ daemon về và áp dụng (theme, font, agentURL). Chạy lúc
   * khởi động và LẠI SAU KHI ĐĂNG NHẬP — lúc khởi động daemon bật login thì
   * get_all bị chặn (401), phải kéo lại sau khi có session.
   */
  async applyRemoteSettings() {
    let userSetting = await utility.getUserSettings();
    utility.userSettings = userSetting;
    TMAutomation.setGlobalInfoBeforeRequest({
      agentURL: userSetting["agentURL"],
    });

    // Toàn bộ cache localStorage (UserSettings + các ConfigLayout, profile,
    // MonacoTheme...) lưu ở daemon — kéo về ghi đè lên local. Daemon offline
    // thì dùng local như cũ. Chạy sau khi có agentURL.
    await cache.applyRemoteCache();
    userSetting = await utility.getUserSettings();
    utility.userSettings = userSetting;
    // agentURL có thể đã đổi theo server — cập nhật lại cho tầng automation
    TMAutomation.setGlobalInfoBeforeRequest({
      agentURL: userSetting["agentURL"],
    });

    utility.setTheme(userSetting["theme"]);
    utility.setAppFont(userSetting["appFont"]);
  }
}

export default new TMAppStartup();
