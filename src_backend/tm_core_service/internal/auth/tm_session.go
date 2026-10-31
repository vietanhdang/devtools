package auth

import (
	"net/http"
	"sync"
	"time"

	"tm_core_service/tm_common"
)

// Session store in-memory cho đăng nhập daemon.
// Cookie tm_session HttpOnly tự đi kèm mọi request + WebSocket handshake.
// Restart daemon = mất session (login lại) — chấp nhận vì tool 1 user.
// Package riêng để middleware và service cùng dùng mà không tạo import cycle
// (service đã import middleware từ bl_api_mock.go).

const (
	CookieName = "tm_session"
	SessionTTL = 7 * 24 * time.Hour
)

var (
	sessionMu sync.Mutex
	sessions  = map[string]time.Time{} // token -> hạn session
)

func CreateSession() string {
	token := tm_common.GenUUID()
	sessionMu.Lock()
	sessions[token] = time.Now().Add(SessionTTL)
	sessionMu.Unlock()
	return token
}

// IsValidSession check token còn hạn, đồng thời dọn các token hết hạn.
func IsValidSession(token string) bool {
	if token == "" {
		return false
	}
	sessionMu.Lock()
	defer sessionMu.Unlock()

	now := time.Now()
	for t, exp := range sessions {
		if now.After(exp) {
			delete(sessions, t)
		}
	}

	exp, ok := sessions[token]
	return ok && now.Before(exp)
}

func ClearSession(token string) {
	sessionMu.Lock()
	delete(sessions, token)
	sessionMu.Unlock()
}

func ClearAllSessions() {
	sessionMu.Lock()
	sessions = map[string]time.Time{}
	sessionMu.Unlock()
}

// TokenFromRequest đọc token từ cookie tm_session (rỗng nếu không có).
func TokenFromRequest(r *http.Request) string {
	cookie, err := r.Cookie(CookieName)
	if err != nil {
		return ""
	}
	return cookie.Value
}
