# DỰ ÁN ZEV — HỆ THỐNG QUẢN LÝ BẢN QUYỀN & ỨNG DỤNG iOS

<p align="center">
  <img src="https://files.catbox.moe/kony5d.png" alt="Zev Logo" width="120" style="border-radius: 24px;"/>
</p>

<p align="center">
  <b>Hệ thống quản lý bản quyền, khóa thiết bị HWID, phân phối file và ứng dụng iOS Zev hiện đại.</b><br/>
  <i>Tối ưu giao diện cho iPhone và iPad — Thiết kế Dark Mode sang trọng, mượt mà.</i>
</p>

---

## 📌 1. THÔNG TIN DỰ ÁN

- **Tên dự án:** ZEV
- **GitHub Repository:** [https://github.com/vonhatqui/Zev.git](https://github.com/vonhatqui/Zev.git)
- **Tên miền máy chủ (cPanel):** `https://crackbomaydihihi.sbs`
- **Khả năng mở rộng:** Hệ thống hỗ trợ thay đổi tên miền và cấu hình API máy chủ động (qua giao diện ứng dụng hoặc code) mà không cần build lại toàn bộ ứng dụng.

---

## 📂 2. CẤU TRÚC THƯ MỤC

```text
Zev/
├── ios/                          # ỨNG DỤNG iOS (SWIFT / SWIFTUI)
│   ├── Package.swift             # Cấu hình Swift Package
│   └── Zev/
│       ├── App/
│       │   ├── ZevApp.swift      # Entry point & State Manager toàn cục
│       │   └── ZevTheme.swift    # Design System: màu sắc, typography, gradient
│       ├── Config/
│       │   └── AppConfig.swift   # Cấu hình API, tên miền động, cache TTL
│       ├── Models/
│       │   └── Models.swift      # Data models chuẩn hoá từ Server API
│       ├── Services/
│       │   ├── APIService.swift  # Gọi REST API (async/await, Token Auth)
│       │   ├── DeviceService.swift # Định danh thiết bị HWID, model thương mại
│       │   └── KeychainService.swift # Lưu trữ an toàn Key & Token trên iOS
│       ├── ViewModels/
│       │   ├── AuthViewModel.swift
│       │   ├── GameViewModel.swift
│       │   └── FileViewModel.swift
│       ├── Views/
│       │   ├── Components/       # Card, Button, Badge, Toast, Chip
│       │   ├── Onboarding/       # SplashView & Onboarding 3 bước mượt mà
│       │   ├── Auth/             # KeyActivationView (Kích hoạt Key & HWID)
│       │   ├── Main/             # HomeView, GameListView, GameDetailView, FileDownloadView
│       │   └── Profile/          # ProfileView & SettingsView (Đổi Domain động)
│       └── Resources/
│           └── Info.plist        # Quyền và cấu hình iOS app
│
└── server/                       # HỆ THỐNG MÁY CHỦ (PHP 8.x + MYSQL)
    ├── admin/                    # ADMIN PANEL QUẢN TRỊ
    │   ├── assets/               # CSS Design system & JS tiện ích
    │   ├── keys/                 # Quản lý Key: Tạo hàng loạt, gia hạn, reset HWID
    │   ├── app/                  # Quản lý bảo trì, cập nhật phiên bản, thông báo
    │   ├── files/                # Upload file (dylib, mod, deb, config)
    │   ├── logs/                 # Nhật ký xác thực, HWID liên kết, error logs
    │   ├── login.php             # Đăng nhập Admin bảo mật
    │   └── index.php             # Dashboard thống kê thời gian thực
    ├── config/
    │   ├── config.sample.php     # File cấu hình mẫu
    │   └── config.php            # File cấu hình hoạt động (chứa cPanel DB config)
    ├── database/
    │   └── schema.sql            # CSDL MySQL: 7 bảng tối ưu & dữ liệu khởi tạo
    ├── public/
    │   ├── .htaccess             # Định tuyến URL rewrite & Security headers
    │   └── index.php             # Router trung tâm API RESTful (/api/v1/...)
    ├── src/                      # Controllers, Middleware & Helpers
    │   ├── Auth/AdminAuth.php    # Xác thực đăng nhập bcrypt
    │   ├── Config/Database.php   # Singleton PDO Wrapper
    │   ├── Controllers/          # KeyController, GameController, FileController...
    │   ├── Middleware/           # RateLimiter, ApiAuth
    │   └── helpers.php           # Tiện ích chung & mã hóa
    └── uploads/                  # Thư mục lưu trữ file được bảo vệ
```

---

## 🚀 3. HƯỚNG DẪN TRIỂN KHAI SERVER TRÊN CPANEL (`crackbomaydihihi.sbs`)

### Bước 1: Tạo Database & Người dùng MySQL trên cPanel
1. Đăng nhập vào cPanel của `crackbomaydihihi.sbs`.
2. Mở **MySQL Database Wizard**.
3. Tạo Database mới (ví dụ: `zev_database`).
4. Tạo User và Mật khẩu (ví dụ: `zev_dbuser` / mật khẩu bảo mật).
5. Gán **All Privileges** (Tất cả quyền) cho User trên Database vừa tạo.

### Bước 2: Import CSDL (`schema.sql`)
1. Trong cPanel, mở công cụ **phpMyAdmin**.
2. Chọn cơ sở dữ liệu `zev_database`.
3. Nhấp vào tab **Import** (Nhập).
4. Chọn file `server/database/schema.sql` và nhấn **Go** (Thực hiện).
   * File này sẽ tự động tạo cấu trúc bảng, các khóa ngoại và tài khoản Admin mặc định.

### Bước 3: Upload mã nguồn Server
1. Mở **File Manager** trên cPanel.
2. Tải toàn bộ thư mục `server/` lên thư mục gốc của domain (thường là `public_html`).
   - Nếu trỏ Document Root trực tiếp vào `public_html/public`, file code bên ngoài sẽ được bảo vệ an toàn nhất.
   - Nếu để toàn bộ trong `public_html`, các file `.htaccess` đã được thiết lập để chặn truy cập trực tiếp vào `src/`, `config/`, và `uploads/`.

### Bước 4: Cấu hình `config.php`
Chỉnh sửa file `server/config/config.php` với thông tin Database cPanel của bạn:
```php
'db' => [
    'host'     => 'localhost',
    'port'     => 3306,
    'name'     => 'tên_database_của_bạn',
    'user'     => 'tên_user_của_bạn',
    'password' => 'mật_khẩu_của_bạn',
    'charset'  => 'utf8mb4',
],
'app' => [
    'base_url' => 'https://crackbomaydihihi.sbs',
]
```

### Bước 5: Đăng nhập Admin Panel
- Truy cập: `https://crackbomaydihihi.sbs/admin/`
- **Tài khoản mặc định:**
  - **Tên đăng nhập:** `admin`
  - **Mật khẩu mặc định:** `ZevAdmin2026!@#`
  *(Khuyến nghị đổi mật khẩu ngay sau lần đăng nhập đầu tiên).*

---

## 📱 4. HƯỚNG DẪN BUILD & PHÁT TRIỂN ỨNG DỤNG iOS (SWIFTUI)

### Yêu cầu môi trường
- macOS 13+ (Ventura, Sonoma, Sequoia)
- Xcode 15+
- iOS Deployment Target: **iOS 15.0 trở lên** (hỗ trợ cả iPhone và iPad)

### Các bước mở dự án
1. Clone hoặc copy thư mục `ios` vào máy Mac.
2. Mở Xcode -> **File** -> **Open...** -> chọn thư mục `ios/Package.swift` (hoặc tạo Xcode App Project và kéo thư mục `Zev` vào).
3. Đặt **Bundle Identifier**: `com.zev.app` (hoặc bundle ID của bạn).
4. Chọn Team signing của bạn trong tab **Signing & Capabilities**.
5. Chọn thiết bị thử nghiệm (Simulator hoặc iPhone/iPad thật) và nhấn **Run (Cmd + R)**.

### Thay đổi tên miền API linh hoạt
1. **Qua giao diện ứng dụng (Không cần build lại):**
   - Mở ứng dụng Zev -> Chuyển đến tab **Tài khoản** -> Nhấp icon **Bánh răng Cài đặt**.
   - Tại mục **Cấu Hình Tên Miền Máy Chủ (API)**, nhập URL mới (ví dụ: `https://api.yourdomain.com`).
   - Nhấn **Lưu & Kiểm Tra** — hệ thống sẽ test kết nối ngay lập tức!
2. **Qua mã nguồn:**
   - Mở file `ios/Zev/Config/AppConfig.swift`.
   - Sửa `defaultBaseURL`:
     ```swift
     static let defaultBaseURL: String = "https://crackbomaydihihi.sbs"
     ```

---

## 🔒 5. CƠ CHẾ BẢN QUYỀN & BẢO MẬT

1. **Khóa phần cứng (HWID Lock):**
   - Mỗi Key khi người dùng kích hoạt lần đầu sẽ được mã hoá và liên kết cố định với mã nhận diện thiết bị `identifierForVendor` (IDFV).
   - Thiết bị khác khi nhập cùng Key sẽ nhận phản hồi từ chối bản quyền `403 Forbidden`.
   - Admin có thể thực hiện **Reset HWID** trong Admin Panel khi khách hàng đổi thiết bị.
2. **Phân phối File bảo mật (One-Time Download Token):**
   - File tải về (dylib, mod menu, patch) không để lộ link trực tiếp.
   - Client phải gửi yêu cầu với Key hợp lệ để server tạo một Token tải về ngắn hạn (hết hạn sau 5 phút và tự huỷ sau khi tải).
3. **Chế độ bảo trì máy chủ (Maintenance Mode):**
   - Admin có thể bật tắt chế độ bảo trì từ xa ngay trên trang Admin. Toàn bộ người dùng đang mở app sẽ nhận thông báo bảo trì theo ngôn ngữ đã chọn.

---

## 👨‍💻 6. BẢN QUYỀN & LIÊN HỆ HỖ TRỢ
- **Dự án Zev** được phát triển riêng biệt theo kiến trúc tối ưu.
- Mọi thắc mắc kỹ thuật hoặc yêu cầu tính năng: Vui lòng liên hệ Telegram qua Admin Panel.
