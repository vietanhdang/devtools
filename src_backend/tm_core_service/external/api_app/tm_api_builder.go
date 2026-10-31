package api_app

import (
	"net/http"
	"tm_config"
	"tm_core_service/internal/database"
	"tm_core_service/internal/middleware"
	"tm_core_service/internal/router"
	"tm_core_service/internal/service"
	"tm_core_service/tm_common"
)

// build dữ liệu database
func InitDatabase() {
	database.InitDatabase()
}

// seed user admin/admin mặc định cho tính năng đăng nhập (bảng trống mới seed)
func InitDefaultAdmin() {
	service.InitDefaultAdmin()
}

// khởi chạy api app
func RunAPIApp() {
	port := tm_config.GetConfigGlobal().APIConfig.Port
	mockPort := tm_config.GetConfigGlobal().MockAPIConfig.Port

	app := http.NewServeMux()

	addRoute(app)

	// Khởi tạo mock API service trên port riêng và tự động start tất cả mock APIs
	service.InitMockAPIService(mockPort)

	// inject 1 số kịch bản chung toàn chương tình vào handler
	var handler = tm_common.BuildHanlderAPICommon(app)

	// Xâu chuỗi Middlewares: CORS (ngoài cùng) -> Auth -> Router.
	// CORS ngoài cùng để response 401 của auth vẫn có header CORS.
	finalHandler := middleware.ApplyAuth(middleware.ApplyCORS(handler))

	addr := tm_common.BuildRunningAddressServer("Server Agent API", &port)

	if err := http.ListenAndServe(addr, finalHandler); err != nil {
		panic(err)
	}
}

// thêm các route xử lý nghiệp vụ
func addRoute(app *http.ServeMux) {
	// Inject router cho từng nghiệp vụ
	router.InjectCommonRouter(app)
	router.InjectAuthRouter(app)
	router.InjectAPITestingRouter(app)
	router.InjectMockAPIRouter(app)
	router.InjectFileOpsRouter(app)
	
	router.InjectAppDataMiner(app)
	router.InjectRDPRouter(app)
	router.InjectRDPConnectionRouter(app)
	router.InjectPostgreSQLRouter(app)
	router.InjectUltraViewerRouter(app)
}
