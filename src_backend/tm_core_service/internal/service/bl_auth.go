package service

import (
	"encoding/json"
	"net/http"

	"golang.org/x/crypto/bcrypt"

	"tm_core_service/internal/auth"
	"tm_core_service/internal/database"
	"tm_core_service/tm_common"
	"tm_config"
)

// Đăng nhập daemon bằng cookie session (store ở internal/auth, dùng chung
// với middleware). Cookie tm_session HttpOnly tự đi kèm mọi request +
// WebSocket handshake (RDP /rdp/ws, UltraViewer /ultraviewer/ws) nên
// middleware chỉ cần check cookie. Restart daemon = mất session — chấp nhận
// vì tool 1 user.

// InitDefaultAdmin tạo user admin/admin nếu bảng tm_auth_user trống.
// Chỉ seed khi trống — không bao giờ đè mật khẩu đã đổi.
func InitDefaultAdmin() {
	db := database.GetConnectionDB()
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM tm_auth_user").Scan(&count)
	if err != nil || count > 0 {
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte("admin"), bcrypt.DefaultCost)
	if err != nil {
		return
	}

	_, _ = db.Exec(
		"INSERT INTO tm_auth_user (id, username, password_hash, created_date, modified_date) VALUES (?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
		tm_common.GenUUID(), "admin", string(hash),
	)
}

func authWriteJSON(w http.ResponseWriter, body map[string]interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(body)
}

// HandleAuthStatus GET /auth/status — trạng thái login (exempt middleware).
func HandleAuthStatus(w http.ResponseWriter, r *http.Request) {
	authWriteJSON(w, map[string]interface{}{
		"success": true,
		"data": map[string]interface{}{
			"enabled":   tm_config.GetConfigGlobal().AuthConfig.Enable,
			"logged_in": auth.IsValidSession(auth.TokenFromRequest(r)),
		},
	})
}

// HandleAuthLogin POST /auth/login {username, password}
// Sai tài khoản trả 200 success:false (lỗi nhẹ, không 5xx — Luật 3).
func HandleAuthLogin(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Dữ liệu không hợp lệ"})
		return
	}

	db := database.GetConnectionDB()
	var id, hash string
	err := db.QueryRow("SELECT id, password_hash FROM tm_auth_user WHERE username = ?", req.Username).Scan(&id, &hash)
	if err != nil || bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Sai tài khoản hoặc mật khẩu"})
		return
	}

	// Không Secure flag: deploy HTTP trong LAN. Nếu sau này có TLS thì bật thêm.
	http.SetCookie(w, &http.Cookie{
		Name:     auth.CookieName,
		Value:    auth.CreateSession(),
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Path:     "/",
		MaxAge:   int(auth.SessionTTL.Seconds()),
	})

	authWriteJSON(w, map[string]interface{}{"success": true, "message": "Đăng nhập thành công"})
}

// HandleAuthLogout POST /auth/logout
func HandleAuthLogout(w http.ResponseWriter, r *http.Request) {
	auth.ClearSession(auth.TokenFromRequest(r))
	http.SetCookie(w, &http.Cookie{
		Name:     auth.CookieName,
		Value:    "",
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
		Path:     "/",
		MaxAge:   -1,
	})
	authWriteJSON(w, map[string]interface{}{"success": true, "message": "Đã đăng xuất"})
}

// HandleAuthChangeCredentials POST /auth/change_credentials
// {current_password, new_username, new_password} — verify mật khẩu hiện tại trước.
// new_username/new_password rỗng = giữ nguyên cái cũ tương ứng.
func HandleAuthChangeCredentials(w http.ResponseWriter, r *http.Request) {
	var req struct {
		CurrentPassword string `json:"current_password"`
		NewUsername     string `json:"new_username"`
		NewPassword     string `json:"new_password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Dữ liệu không hợp lệ"})
		return
	}

	db := database.GetConnectionDB()
	var id, username, hash string
	err := db.QueryRow("SELECT id, username, password_hash FROM tm_auth_user ORDER BY created_date LIMIT 1").Scan(&id, &username, &hash)
	if err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Không tìm thấy user đăng nhập"})
		return
	}

	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.CurrentPassword)) != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Mật khẩu hiện tại không đúng"})
		return
	}

	newUsername := username
	if req.NewUsername != "" {
		newUsername = req.NewUsername
	}
	newHash := hash
	if req.NewPassword != "" {
		encoded, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
		if err != nil {
			authWriteJSON(w, map[string]interface{}{"success": false, "message": "Không hash được mật khẩu mới"})
			return
		}
		newHash = string(encoded)
	}

	_, err = db.Exec("UPDATE tm_auth_user SET username = ?, password_hash = ?, modified_date = CURRENT_TIMESTAMP WHERE id = ?", newUsername, newHash, id)
	if err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Lỗi lưu thông tin đăng nhập"})
		return
	}

	authWriteJSON(w, map[string]interface{}{"success": true, "message": "Đã đổi thông tin đăng nhập"})
}

// HandleAuthSetEnabled POST /auth/set_enabled {enable}
// Yêu cầu đã login (kể cả khi tắt login — tránh người khác trong LAN tắt hộ).
// Lưu vào config.json để giữ lại sau restart.
func HandleAuthSetEnabled(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Enable bool `json:"enable"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Dữ liệu không hợp lệ"})
		return
	}

	tm_config.GetConfigGlobal().AuthConfig.Enable = req.Enable
	if err := tm_config.SaveConfigGlobal(); err != nil {
		authWriteJSON(w, map[string]interface{}{"success": false, "message": "Lỗi lưu config"})
		return
	}

	if !req.Enable {
		auth.ClearAllSessions()
	}

	authWriteJSON(w, map[string]interface{}{"success": true, "message": "Đã cập nhật cấu hình đăng nhập"})
}
