import utility from "@/common/TMUtility.js";
import TMAutomation from "@/common/automation/TMAutomation.js";

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

    // UserSettingsV2: setting chính lưu ở daemon — kéo về merge đè lên local
    // (daemon offline thì dùng local như cũ). Chạy sau khi có agentURL.
    userSetting = await utility.loadRemoteUserSettings();
    utility.userSettings = userSetting;

    utility.setTheme(userSetting["theme"]);
    utility.setAppFont(userSetting["appFont"]);
    // đảm bảo rằng __env là một đối tượng bất biến
    utility.freezeDeepObject(window.__env);
    document.title = `${utility.defaultTitleApp()} - ${utility.getAuthorApp()}`;
  }
}

export default new TMAppStartup();
