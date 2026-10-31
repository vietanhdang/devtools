package model

// TMUserSetting lưu setting của user xuống daemon (bảng tm_user_setting).
// Mỗi setting_key một row, setting_value là chuỗi JSON.
type TMUserSetting struct {
	TMBaseModel
	SettingKey   string `json:"setting_key"`
	SettingValue string `json:"setting_value"`
}

func (m TMUserSetting) TableName() string {
	return "tm_user_setting"
}
