package service

import (
	"encoding/json"
	"net/http"

	"tm_core_service/internal/database"
	"tm_core_service/tm_common"
)

// Lưu setting của user xuống daemon (thay vì localStorage) để đổi máy /
// xoá cache trình duyệt vẫn giữ nguyên cấu hình. Mỗi loại setting 1 row
// theo key (tên key = KeyFormat của cache frontend).

// HandleGetAllUserSetting GET /user_setting/get_all — trả map key → value
// của toàn bộ setting đã lưu (rỗng nếu chưa có gì).
func HandleGetAllUserSetting(w http.ResponseWriter, r *http.Request) {
	db, err := database.GetConnectionDB()
	if err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Lỗi kết nối database"})
		return
	}

	rows, err := db.Query("SELECT setting_key, setting_value FROM tm_user_setting")
	if err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Lỗi đọc setting"})
		return
	}
	defer rows.Close()

	data := map[string]interface{}{}
	for rows.Next() {
		var key, value string
		if err := rows.Scan(&key, &value); err != nil {
			continue
		}
		var parsed interface{}
		if json.Unmarshal([]byte(value), &parsed) == nil {
			data[key] = parsed
		}
	}

	authWriteJSON(w, map[string]interface{}{"success": true, "data": data})
}

// HandleSaveUserSetting POST /user_setting/save {key, value} — upsert 1 key.
func HandleSaveUserSetting(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Key   string      `json:"key"`
		Value interface{} `json:"value"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Key == "" {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Dữ liệu không hợp lệ"})
		return
	}

	raw, err := json.Marshal(req.Value)
	if err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Dữ liệu không hợp lệ"})
		return
	}

	db, err := database.GetConnectionDB()
	if err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Lỗi kết nối database"})
		return
	}

	_, err = db.Exec(
		`INSERT INTO tm_user_setting (id, setting_key, setting_value, created_date, modified_date)
		VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
		ON CONFLICT(setting_key) DO UPDATE SET setting_value = excluded.setting_value, modified_date = CURRENT_TIMESTAMP`,
		tm_common.GenUUID(), req.Key, string(raw),
	)
	if err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Lỗi lưu setting"})
		return
	}

	authWriteJSON(w, map[string]interface{}{"success": true, "message": "Đã lưu setting"})
}
