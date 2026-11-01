import tmEnum from "@/common/TMEnum.js";

/**
 * FE và daemon chạy cùng máy (docker) khác port — mặc định trỏ agentURL về
 * hostname của trang hiện tại, giữ port từ config agentServer.
 */
function defaultAgentURL() {
  let configured = window.__env?.APITesting?.agentServer;
  try {
    let agent = new URL(configured);
    if (window.location.hostname) {
      agent.hostname = window.location.hostname;
    }
    return agent.origin;
  } catch (e) {
    return configured;
  }
}

/**
 * Config default toàn bộ thiết lập mặc định mà user có thể cấu hình bằng tay
 */
export function getUserSettingDefault() {
  return {
    theme: "github-light",
    appFont: tmEnum.appFont.Default,
    currentLanguage: "vi",
    agentURL: defaultAgentURL(),
    wrapTab: true,
    showSideBar: true,
    // danh sách công cụ hiển thị ở sidebar hay ở header
    sideBarMenuPosition: tmEnum.sideBarMenuPosition.Sidebar,
    cursorEffect: "off",
    backgroundEffect: "off",
    welcomeBackground: tmEnum.welcomeBackground.Crossword,
  };
}
