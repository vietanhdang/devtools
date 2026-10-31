import TMAgentAPI from "@/common/api/request/AgentAPI/TMAgentAPI.js";

/**
 * TMUserSettingAPI - API lưu setting của user xuống daemon (UserSettingsV2)
 * controller "user_setting". Khi daemon bật login thì endpoint này cần session.
 */
class TMUserSettingAPI extends TMAgentAPI {
  constructor(baseUrl) {
    super(baseUrl, "user_setting");
  }

  /**
   * Lấy toàn bộ setting đã lưu (null nếu chưa có)
   */
  async get() {
    return await this.get("/get");
  }

  /**
   * Lưu toàn bộ setting (upsert theo key "user_settings")
   */
  async save(value) {
    return await this.post("/save", { value });
  }

  /**
   * Lấy map key → value của toàn bộ setting đã lưu trên daemon
   */
  async getAll() {
    return await this.get("/get_all");
  }

  /**
   * Lưu 1 setting theo key riêng (upsert theo key)
   */
  async saveKey(key, value) {
    return await this.post("/save", { key, value });
  }
}

export default TMUserSettingAPI;
