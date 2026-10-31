import TMAgentAPI from "@/common/api/request/AgentAPI/TMAgentAPI.js";

/**
 * TMUserSettingAPI - API lưu setting của user xuống daemon
 * controller "user_setting". Khi daemon bật login thì endpoint này cần session.
 */
class TMUserSettingAPI extends TMAgentAPI {
  constructor(baseUrl) {
    super(baseUrl, "user_setting");
  }

  /**
   * Lấy map key → value của toàn bộ setting đã lưu trên daemon
   */
  async getAll() {
    return await this.get("/get_all");
  }

  /**
   * Lưu 1 setting theo key (upsert theo key)
   */
  async saveKey(key, value) {
    return await this.post("/save", { key, value });
  }
}

export default TMUserSettingAPI;
