import utility from "@/common/TMUtility.js";
import TMAutomation from "@/common/automation/TMAutomation.js";
import cache from "@/common/cache/TMCache.js";
import TMAgentAPI from "@/common/api/request/AgentAPI/TMAgentAPI.js";

class TMAppStartup {
  constructor() {}

  /**
   * agentURL trong setting không tới được daemon (vd mới xoá cache nên
   * rơi về mặc định localhost, trong khi daemon ở máy khác) — nếu trang
   * này do daemon phục vụ thì origin của trang chính là địa chỉ daemon,
   * thử lại bằng origin. Không tới được thì mới chịu, giữ như cũ.
   * Không có bước này: xoá localStorage là vượt qua được màn đăng nhập.
   */
  async daemonReachable() {
    try {
      const res = await new TMAgentAPI().heathCheck();
      // Chỉ nhận response JSON chuẩn của daemon — vite dev server cũng
      // trả 200 cho "/" nhưng là HTML.
      return res?.data?.success === true;
    } catch (e) {
      return false;
    }
  }

  async resolveAgentURL() {
    if (await this.daemonReachable()) {
      return;
    }
    if (!window.location.origin?.startsWith("http")) {
      return;
    }
    const previous = window.__tmAPI?.automation?.agentURL;
    TMAutomation.setGlobalInfoBeforeRequest({
      agentURL: window.location.origin,
    });
    if (await this.daemonReachable()) {
      return;
    }
    // origin cũng không phải daemon — trả lại agentURL cũ
    TMAutomation.setGlobalInfoBeforeRequest({ agentURL: previous });
  }

  /**
   * Phương thức khởi tạo ứng dụng
   */
  async initialize() {
    let userSetting = await utility.getUserSettings();
    utility.userSettings = userSetting;
    let setConfig = TMAutomation.setGlobalInfoBeforeRequest({
      agentURL: userSetting["agentURL"],
    });

    // Tự tìm lại địa chỉ daemon nếu agentURL trong setting không dùng được
    await this.resolveAgentURL();

    // Toàn bộ cache localStorage (UserSettings + các ConfigLayout, profile,
    // MonacoTheme...) lưu ở daemon — kéo về ghi đè lên local. Daemon offline
    // thì dùng local như cũ. Chạy sau khi đã biết agentURL.
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
