package middleware

import (
	"encoding/json"
	"net/http"
	"strings"

	"tm_config"
	"tm_core_service/internal/auth"
)

// ApplyAuth chặn request khi tính năng đăng nhập đang bật.
// Bọc TRONG ApplyCORS (CORS ngoài cùng) để response 401 vẫn có header CORS.
// Đọc config live mỗi request nên bật/tắt trong Settings có tác dụng ngay.
// Phủ luôn WebSocket (RDP /rdp/ws, UltraViewer /ultraviewer/ws) vì browser
// gửi cookie trong handshake — chặn 401 trước khi Upgrade.
func ApplyAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !tm_config.GetConfigGlobal().AuthConfig.Enable {
			next.ServeHTTP(w, r)
			return
		}

		// Middleware chạy trước bước lowercase path của BuildHanlderAPICommon
		// nên phải tự lowercase khi so sánh.
		path := strings.ToLower(r.URL.Path)

		if r.Method == http.MethodOptions ||
			path == "/auth/login" ||
			path == "/auth/status" ||
			(path == "/" && r.Method == http.MethodGet) {
			next.ServeHTTP(w, r)
			return
		}

		cookie, err := r.Cookie(auth.CookieName)
		if err == nil && auth.IsValidSession(cookie.Value) {
			next.ServeHTTP(w, r)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"success": false,
			"message": "unauthorized",
			"data":    nil,
		})
	})
}
