-- 0004_auth.sql
--
-- Bảng user đăng nhập khi truy cập daemon (tính năng login bật/tắt trong config).
-- Mật khẩu lưu dạng bcrypt hash, không lưu plaintext.
-- User mặc định (admin) được seed lúc khởi động nếu bảng trống.

CREATE TABLE IF NOT EXISTS tm_auth_user (
	id TEXT PRIMARY KEY NOT NULL,
	username TEXT NOT NULL UNIQUE,
	password_hash TEXT NOT NULL,
	created_date DATETIME DEFAULT CURRENT_TIMESTAMP,
	modified_date DATETIME DEFAULT CURRENT_TIMESTAMP
);
