package tm_config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
)

var (
	// cấu hình config global static
	configGlobal *TMCenterConfig
	oneLock      sync.Once
	// đường dẫn file config đã phát hiện (hoặc đã tạo mặc định)
	configPath string
	saveLock   sync.Mutex
)

// lấy ra cấu hình config
func GetConfigGlobal() *TMCenterConfig {
	oneLock.Do(func() {
		currentConfig := DefaultConfig()
		path, err := findConfigUpwards()

		if err != nil {
			// Trường hợp KHÔNG tìm thấy file: Tiến hành khởi tạo file mặc định
			// Lấy đường dẫn file thực thi để đặt file config ngay bên cạnh
			exePath, _ := os.Executable()
			defaultPath := filepath.Join(filepath.Dir(exePath), "config.json")
			configPath = defaultPath

			// Ghi file mặc định
			data, _ := json.MarshalIndent(currentConfig, "", "  ")
			_ = os.WriteFile(defaultPath, data, 0644)

			configGlobal = &currentConfig
			return
		}

		configPath = path

		// Trường hợp tìm thấy file: Đọc và Unmarshal như bình thường
		data, err := os.ReadFile(path)
		if err == nil {
			_ = json.Unmarshal(data, &currentConfig)
		}

		configGlobal = &currentConfig
	})

	return configGlobal
}

// SaveConfigGlobal ghi lại config hiện tại vào file config đã phát hiện.
// Dùng khi đổi setting runtime (vd bật/tắt login) để giữ lại sau restart.
func SaveConfigGlobal() error {
	saveLock.Lock()
	defer saveLock.Unlock()

	if configGlobal == nil || configPath == "" {
		GetConfigGlobal()
	}

	data, err := json.MarshalIndent(configGlobal, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(configPath, data, 0644)
}

func findConfigUpwards() (string, error) {
	// Lưu ý: os.Executable() trả về đường dẫn đầy đủ của file thực thi
	// Chúng ta cần lấy thư mục chứa nó bằng filepath.Dir
	exePath, err := os.Executable()
	if err != nil {
		return "", err
	}
	dir := filepath.Dir(exePath)

	for {
		// Kiểm tra trong thư mục /config/config.json
		candidate1 := filepath.Join(dir, "config", "config.json")
		if _, err := os.Stat(candidate1); err == nil {
			return candidate1, nil
		}

		// Kiểm tra file config.json ngay tại thư mục hiện hành
		candidate2 := filepath.Join(dir, "config.json")
		if _, err := os.Stat(candidate2); err == nil {
			return candidate2, nil
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	return "", os.ErrNotExist
}
