import tmEnum from "@/common/TMEnum.js";

/**
 * FE và daemon cùng máy, đi qua reverse proxy (https) — mặc định agentURL là
 * origin của trang + /api (proxy chuyển tiếp sang backend), tránh mixed content
 * khi trỏ thẳng http://host:7777.
 */
function defaultAgentURL() {
  let configured = window.__env?.APITesting?.agentServer;
  if (window.location.origin?.startsWith("http")) {
    return `${window.location.origin}/api`;
  }
  return configured;
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
    welcomeBackground: tmEnum.welcomeBackground.Normal,
  };
}
