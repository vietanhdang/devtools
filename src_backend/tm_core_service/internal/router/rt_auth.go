package router

import (
	"net/http"

	"tm_core_service/internal/service"
)

// Inject các route đăng nhập của daemon
func InjectAuthRouter(app *http.ServeMux) {
	app.HandleFunc("GET /auth/status", service.HandleAuthStatus)
	app.HandleFunc("POST /auth/login", service.HandleAuthLogin)
	app.HandleFunc("POST /auth/logout", service.HandleAuthLogout)
	app.HandleFunc("POST /auth/change_credentials", service.HandleAuthChangeCredentials)
	app.HandleFunc("POST /auth/set_enabled", service.HandleAuthSetEnabled)
}
