package model

// TMAuthUser user đăng nhập khi truy cập daemon (bảng tm_auth_user).
// Auth không đi qua CRUD generic (endpoint login/logout có shape riêng),
// model này để đúng quy ước bảng + dùng cho truy vấn SQL trong bl_auth.go.
type TMAuthUser struct {
	TMBaseModel
	Username     string `json:"username"`
	PasswordHash string `json:"password_hash"`
}

func (m TMAuthUser) TableName() string {
	return "tm_auth_user"
}
