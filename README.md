# DỰ ÁN ZEV — HỆ THỐNG QUẢN LÝ BẢN QUYỀN & ỨNG DỤNG iOS ZEV

<p align="center">
  <img src="https://files.catbox.moe/kony5d.png" alt="Zev Logo" width="130" style="border-radius: 26px;"/>
</p>

<p align="center">
  <b>Ứng dụng iOS Zev và Hệ thống Quản trị Máy chủ Quản lý Key, File Bản Vá & Thiết Bị HWID</b><br/>
  <i>Tối ưu giao diện cho iPhone & iPad theo phong cách Dark Mode cao cấp, tích hợp cơ chế nạp file bản vá từ dự án 3105-2.0.</i>
</p>

---

## 📌 1. THÔNG TIN DỰ ÁN

- **Tên ứng dụng:** Zev
- **GitHub Repository:** [https://github.com/vonhatqui/Zev.git](https://github.com/vonhatqui/Zev.git)
- **Tên miền máy chủ (cPanel):** `https://crackbomaydihihi.sbs` (Hỗ trợ cấu hình đổi tên miền linh hoạt)
- **Mật khẩu quản trị server key:** `1` (Tài khoản: `admin` | Mật khẩu: `1`)
- **Hỗ trợ kỹ thuật / Mua Key (Zalo):** `0365829172` ([https://zalo.me/0365829172](https://zalo.me/0365829172))

---

## 🚀 2. KIẾN TRÚC & LUỒNG HOẠT ĐỘNG ỨNG DỤNG ZEV

### 1️⃣ Thiết Lập Lần Đầu (Setup App — Onboarding)
- **Chỉ xuất hiện 1 lần duy nhất** khi người dùng mới tải và mở app lần đầu (lưu trạng thái vào `UserDefaults`).
- **Cho phép thông báo:** Nút cấp quyền nhận thông báo đẩy khi có bản cập nhật hoặc key sắp hết hạn.
- **Chọn ngôn ngữ:** Hỗ trợ song ngữ Tiếng Việt 🇻🇳 và Tiếng Anh 🇬🇧.
- **Đồng ý điều khoản:** Ô tích checkbox xác nhận điều khoản sử dụng.
- **Nút "Tiếp Theo":** Chỉ sáng lên khi người dùng đã tích chọn đồng ý điều khoản, bấm để chuyển tiếp sang trang Đăng nhập Key.

### 2️⃣ Đăng Nhập Theo Key (Login by Key)
- Ô nhập mã key bản quyền (hỗ trợ nút Dán mã nhanh từ bộ nhớ tạm và Xóa nhanh).
- **Khung thông tin hỗ trợ thiết bị ngay dưới ô nhập key:**
  - **Mã máy (HWID):** Lấy mã định danh phần cứng IDFV lưu an toàn trong Keychain.
  - **Phiên bản iOS:** Lấy chính xác phiên bản hệ điều hành (ví dụ: `iOS 17.5.1`).
  - **Điện thoại:** Tra cứu tên thương mại chính xác của máy (ví dụ: `iPhone 15 Pro Max`, `iPad Pro 11-inch (M4)`, v.v.).
- **Modal Thành Công (Success Modal):**
  - Khi xác thực key thành công, hiển thị popup với **Dấu tích xanh**, chữ **"Thành công" / "Success"**.
  - Hiển thị thời gian còn lại của key (ví dụ: *Còn 30 ngày* hoặc *Vĩnh viễn*).
  - Nút **"Xác nhận"**: Bấm xác nhận sẽ chuyển ngay vào giao diện Chọn Game.

### 3️⃣ Giao Diện Chọn Game (Game Selection)
Hiển thị 2 thẻ card tương ứng với 2 phiên bản game:
1. **Free Fire Thường** (`com.dts.freefireth`)
2. **Free Fire MAX** (`com.dts.freefiremax`)
- Tích hợp logo chính thức của cả 2 phiên bản.
- **Phát hiện cài đặt thời gian thực:**
  - Ở cuối mỗi card hiển thị huy hiệu:
    - 🟢 **"Sẵn sàng"** nếu phát hiện trên máy đã cài đặt game.
    - 🔴/🟡 **"Chưa Cài Đặt"** nếu chưa phát hiện game trên máy.
- Bấm vào game bất kỳ để vào giao diện Main Tab và tự động tải danh mục/chức năng tương ứng từ máy chủ.

### 4️⃣ Giao Diện Tab Chính (Gồm 2 Tab: Main & Cá Nhân)

#### 🏠 Tab 1: Main (icon ngôi nhà)
- **Khung trên đầu:** Bố cục dạng khung viền 3 cột chuẩn yêu cầu:
  ```
  ┌────────────────────────────────────────────────────────┐
  │   THIẾT BỊ        │   PHIÊN BẢN      │   TRẠNG THÁI   │
  │ iPhone 15 Pro Max │    iOS 17.5.1    │ 🟢 Có hỗ trợ   │
  └────────────────────────────────────────────────────────┘
  ```
  - Kiểm tra đối chiếu tự động với **bảng hỗ trợ của dự án 3105-2.0**:
    - `iOS 17.0 – 17.7.x`
    - `iOS 18.0 – 18.7.1`
    - `iOS 26.0 – 26.6.1`
    - `iOS 27 Beta 1 – 4`
    - Khớp phiên bản hiển thị **"Có hỗ trợ"**, ngược lại hiển thị **"Chưa hỗ trợ"**.
- **Danh mục menu chức năng:**
  - 📂 **Menu Project:** Logo `https://files.catbox.moe/wetz7r.png` (Gồm: *Menu V1*, *Menu CheatExternal*).
  - 🎯 **Aim Cache:** Logo `https://files.catbox.moe/z7c8o6.png` (Gồm: *Aim Head*, *Aim Body*, *Aim Neck*).
  - 👕 **Modskin FFTH:** Logo `https://files.catbox.moe/dvyw27.png` (Gồm: *Modskin Alock*, *Modskin Katri*, hỗ trợ nút **Preview** xem trước ảnh skin).
  - 🛡️ **Setup Antiban:** Nút tải app **sing-box** trực tiếp trên App Store (`https://apps.apple.com/app/sing-box/id6451272673`) và tải cấu hình Antiban từ máy chủ.
- **Cơ chế nạp file & áp dụng patch:**
  - Tải chức năng động từ server khi chọn game.
  - Những chức năng **chưa có file trên máy chủ** hoặc trạng thái `unsupported`: Khi bấm vào app sẽ hiển thị thông báo **"Chưa Hỗ Trợ"**.
  - Những chức năng **đã có file trên máy chủ** (`.3105`, `.bytes`, cache file, `localConfig.json`): Tự động xác định đường dẫn container của game và nạp file vào thư mục tương ứng (`Documents/`, `Documents/cached/`, `Library/Preferences/`), có cơ chế sao lưu tự động để khôi phục.

#### 👤 Tab 2: Cá Nhân (icon con người)
- **Kênh hỗ trợ & Mua key:** Nổi bật số Zalo **0365829172** kèm nút mở nhanh Zalo chat và sao chép số.
- **Thông tin thời gian key:** Hiển thị mã key, thời gian hết hạn hoặc vĩnh viễn.
- **Trạng thái hỗ trợ iOS:** Tra cứu chi tiết thiết bị và danh sách các phiên bản iOS 3105-2.0 hỗ trợ.
- **Tiện ích:** Nút **"Đổi Game"** cho phép quay lại màn hình chọn game bất cứ lúc nào, nút Xóa cache và nút **"Đăng xuất Key"**.

---

## 🖥️ 3. HỆ THỐNG MÁY CHỦ QUẢN TRỊ SERVER KEY & APP

Nằm tại thư mục `server/`:
- **Đăng nhập quản trị:** Truy cập `https://crackbomaydihihi.sbs/admin/`
  - Tên đăng nhập: `admin`
  - Mật khẩu: `1`
- **Dashboard (`/admin/`):** Tổng quan số lượng key, thiết bị kích hoạt, hoạt động gần đây.
- **Quản lý Key (`/admin/keys/`):**
  - Tạo key mới (1 ngày, 7 ngày, 30 ngày, 90 ngày, 1 năm, Vĩnh viễn hoặc tùy chỉnh).
  - Tìm kiếm key theo mã, lọc theo trạng thái (Active, Expired, Revoked).
  - Gia hạn thêm ngày cho key, sửa thời gian.
  - Khóa / Mở khóa / Thu hồi / Xóa key.
  - **Reset HWID:** Xóa liên kết máy khi khách đổi thiết bị mới.
- **Quản lý Chức năng & File (`/admin/features/` — Tab chuyên biệt):**
  - Chọn theo Game: Free Fire Thường (`com.dts.freefireth`) & Free Fire MAX (`com.dts.freefiremax`).
  - Thêm, sửa, xóa Danh mục (Menu Project, Aim Cache, Modskin, Antiban) kèm URL logo.
  - Thêm, sửa Chức năng (Menu V1, CheatExternal, Modskin Alock, Katri, v.v.).
  - **Upload & Nạp File:** Hỗ trợ mọi định dạng file `.3105`, `.bytes`, `.gzip`, `.unityfs`, `.json`, `.zip`, `.config`.
  - **Tự xác định đích đến (Target Path):** Chọn vị trí nạp vào game (`Documents/`, `Documents/cached/`, `Library/Preferences/`, `sing-box`).
  - **Bật / Tắt trạng thái:** Chức năng chưa có file hoặc đặt `unsupported` sẽ làm app tự động báo "Chưa Hỗ Trợ".
- **Cấu hình App (`/admin/app/`):** Bật/tắt bảo trì hệ thống, sửa thông báo, cấu hình số Zalo hỗ trợ.
- **Dual-Engine Database:** Hỗ trợ sẵn cả MySQL (cPanel) và SQLite (tự động kích hoạt không cần cài đặt phức tạp).

---

## 📦 4. CÁCH BUILD XUẤT FILE `Zev.ipa`

### Cách 1: Tự động Build IPA trên GitHub Actions (Không cần Mac)
1. Truy cập repository [github.com/vonhatqui/Zev](https://github.com/vonhatqui/Zev) trên trình duyệt.
2. Tạo file mới: `.github/workflows/build-ipa.yml`.
3. Copy toàn bộ nội dung từ file `ci/build-ipa.yml` và bấm **Commit changes**.
4. Vào tab **Actions** trên GitHub: Runner `macos-14` sẽ tự động biên dịch và đóng gói thành file **`Zev.ipa`** sẵn sàng tải về trong mục *Artifacts / Releases*.

### Cách 2: Biên dịch trực tiếp trên macOS
Mở Terminal trên máy Mac:
```bash
cd ios
bash build_ipa.sh
```
File **`Zev.ipa`** sẽ được tạo ngay trong thư mục `ios/`. Cài đặt trực tiếp vào iPhone/iPad qua **TrollStore, Scarlet, Esign, AltStore hoặc Sideloadly**.

---

## 🛠️ 5. CẬP NHẬT XCODE PROJECT KHI THÊM FILE
Khi bổ sung thêm file Swift hoặc tài nguyên mới, chạy lệnh:
```bash
python generate_xcodeproj.py
```
Script sẽ tự động quét toàn bộ thư mục `ios/Zev` và cập nhật file `Zev.xcodeproj` một cách hoàn hảo.
