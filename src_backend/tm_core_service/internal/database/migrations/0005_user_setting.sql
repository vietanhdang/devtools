-- 0005_user_setting.sql
--
-- Lưu setting của user (UserSettingsV2) xuống daemon thay vì localStorage:
-- đổi máy / xoá cache trình duyệt vẫn giữ nguyên cấu hình.
-- Mỗi loại setting 1 row, value là chuỗi JSON.

CREATE TABLE IF NOT EXISTS tm_user_setting (
	id TEXT PRIMARY KEY NOT NULL,
	setting_key TEXT NOT NULL UNIQUE,
	setting_value TEXT NOT NULL,
	created_date DATETIME DEFAULT CURRENT_TIMESTAMP,
	modified_date DATETIME DEFAULT CURRENT_TIMESTAMP
);
