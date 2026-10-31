import TMAgentAPI from "@/common/api/request/AgentAPI/TMAgentAPI.js";

/**
 * TMAuthAPI - API đăng nhập của daemon (controller "auth")
 * Cookie session tự đi kèm request nhờ credentials: "include" trong TMHttpClient.
 */
class TMAuthAPI extends TMAgentAPI {
  constructor(baseUrl) {
    super(baseUrl, "auth");
  }

  /**
   * Trạng thái đăng nhập của daemon: {enabled, logged_in}
   */
  async status() {
    return await this.get("/status");
  }

  /**
   * Đăng nhập {username, password} — thành công thì BE set cookie tm_session
   */
  async login(username, password) {
    return await this.post("/login", { username, password });
  }

  async logout() {
    return await this.post("/logout", {});
  }

  /**
   * Đổi thông tin đăng nhập. new_username/new_password rỗng = giữ nguyên.
   */
  async changeCredentials(currentPassword, newUsername, newPassword) {
    return await this.post("/change_credentials", {
      current_password: currentPassword,
      new_username: newUsername,
      new_password: newPassword,
    });
  }

  /**
   * Bật/tắt tính năng đăng nhập (lưu vào config daemon)
   */
  async setEnabled(enable) {
    return await this.post("/set_enabled", { enable });
  }
}

export default TMAuthAPI;
