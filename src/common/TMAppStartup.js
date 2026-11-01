import utility from "@/common/TMUtility.js";
import TMAutomation from "@/common/automation/TMAutomation.js";
import cache from "@/common/cache/TMCache.js";

class TMAppStartup {
  constructor() {}

  /**
   * Phương thức khởi tạo ứng dụng
   */
  async initialize() {
    let userSetting = await utility.getUserSettings();
    utility.userSettings = userSetting;
    let setConfig = TMAutomation.setGlobalInfoBeforeRequest({
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
    // đảm bảo rằng __env là một đối tượng bất biến
    utility.freezeDeepObject(window.__env);
    document.title = `${utility.defaultTitleApp()} - ${utility.getAuthorApp()}`;
  }
}

export default new TMAppStartup();
