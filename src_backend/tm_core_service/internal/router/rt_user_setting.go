package router

import (
	"net/http"

	"tm_core_service/internal/service"
)

// Inject các route lưu setting của user xuống daemon (UserSettingsV2)
func InjectUserSettingRouter(app *http.ServeMux) {
	app.HandleFunc("GET /user_setting/get", service.HandleGetUserSetting)
	app.HandleFunc("GET /user_setting/get_all", service.HandleGetAllUserSetting)
	app.HandleFunc("POST /user_setting/save", service.HandleSaveUserSetting)
}
