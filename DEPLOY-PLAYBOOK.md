# Playbook phát hành app mobile — Bệnh viện Minh An

> **Dành cho Claude Code khi mở một dự án app mới.** File này ghi lại toàn bộ hạ tầng đã
> có, bài học đã trả giá, và checklist cho app tiếp theo. Đúc kết từ việc đưa app
> *ERP Bệnh Viện Minh An* lên CH Play và App Store (tháng 9/2026, ~20 lần build, 3 lần
> App Store từ chối).
>
> Repo gốc: `https://github.com/hoangnhata/PhanmemtongMinhAn` (private). Tài liệu chi tiết
> và script nằm ở đó — đường dẫn ghi trong mục 5.

---

## 0. Ba câu hỏi phải trả lời TRƯỚC khi viết dòng code nào

Trả lời sai ba câu này là mất từ vài ngày tới vài tuần về sau. Với app ERP đã mất 3 tuần
vì trả lời sai câu 2 và 3.

| # | Câu hỏi | Vì sao quan trọng |
|---|---|---|
| 1 | **Package / Bundle ID là gì?** | Play khoá sau lần upload đầu. Apple khoá sau lần tạo app. Đổi sau = tạo app mới, người dùng cài lại từ đầu. Dùng **một ID chung** cho Android và iOS. Dạng reverse-domain: `com.benhvienminhan.<tenapp>` |
| 2 | **App có chạm dữ liệu y tế / lĩnh vực bị quản lý không?** | Nếu có → Apple **bắt buộc** tài khoản Developer dạng **Organization** đứng tên đúng tổ chức (Guideline 5.1.1(ix)). Giấy uỷ quyền **không** thay thế được. Tài khoản cá nhân là chết cứng ở vòng review |
| 3 | **Ai dùng app — công chúng hay nhân viên nội bộ?** | Nội bộ → Apple từ chối kênh App Store công khai (Guideline 3.2), phải xin **Unlisted App Distribution**. Xin trước khi nộp, không phải sau khi bị từ chối |

---

## 1. Những gì ĐÃ CÓ — tái sử dụng được

### 1.1. Tài khoản

| Dịch vụ | Định danh | Tình trạng | Dùng lại cho app mới? |
|---|---|---|---|
| **Google Play Console** | Tài khoản của Nhật Hoàng | Đang có app ERP ở Internal testing | ✅ Tạo app mới trong cùng console |
| **Apple Developer Program** | Team `DAO NGOC SON`, Team ID `BJCFV9A3UA` | ⚠️ Đang là **Individual**, đang xin chuyển sang **Organization** (Bệnh viện Minh An) | ✅ Sau khi chuyển đổi xong. App y tế phải chờ chuyển đổi xong mới nộp |
| **App Store Connect** | Nhật Hoàng = **Admin** trong team | Đủ quyền tạo app, key, chứng chỉ | ✅ |
| **Firebase** | Project `erp-minh` (số `237035798219`) | Có app Android + iOS của ERP | ✅ Thêm app mới vào cùng project, hoặc tạo project riêng nếu muốn tách |
| **Codemagic** | Personal Account của Nhật Hoàng | Đã tích hợp App Store Connect | ✅ Add application mới |
| **GitHub** | `hoangnhata`, repo private | | ✅ Tạo repo mới, **để private** |
| **Domain** | `benhvienminhan.com` tại iNET, có OneMail nhưng chưa tạo hộp thư | Cần email theo domain cho tài khoản tổ chức Apple | ⚠️ Phải tạo hộp thư trước |

### 1.2. Khoá và chứng chỉ — cái nào dùng chung, cái nào riêng

Nằm ở `d:\MinhAn\_BACKUP_KEYSTORE_ERP\` (ngoài Git). File `DOC-KHI-MAT-KEYSTORE.txt` trong
đó ghi mật khẩu và hướng dẫn.

| Khoá | Phạm vi | App mới có dùng lại? |
|---|---|---|
| **APNs key** `APNS_8QPWK4J86M.p8` (Sandbox & Production) | **Cấp team** | ✅ Dùng chung — mọi app trong team `BJCFV9A3UA`. Upload lại vào Firebase app iOS mới |
| **App Store Connect API key** `CODEMAGIC_9F336YNW8F.p8`, tích hợp Codemagic tên `MinhAnAppStore` | Cấp team | ✅ Dùng chung cho mọi app trong team |
| **Apple Distribution certificate** (đã tạo qua Codemagic) | Cấp team | ✅ Dùng chung |
| **Provisioning profile** | **Cấp app** (theo Bundle ID) | ❌ Tạo mới cho mỗi Bundle ID |
| **Android upload keystore** `upload-keystore.jks` | Kỹ thuật thì ký được nhiều app | ⚠️ **Nên tạo keystore riêng** cho mỗi app. Mất một cái không kéo theo cái khác |
| **Firebase service account** (trên server, `F:\secrets\erp-minh-firebase-adminsdk-*.json`) | Cấp project Firebase | ✅ Backend gửi push cho mọi app trong project, không cần thêm gì |
| `google-services.json`, `GoogleService-Info.plist` | **Cấp app** | ❌ Tải mới từ Firebase cho mỗi app |

**Đừng xoá khoá cũ** khi tạo khoá mới: team chỉ được giữ 2 khoá APNs và ~3 chứng chỉ
Distribution. Xoá nhầm là app cũ hỏng push.

### 1.3. Script và mẫu đã viết — copy sang dự án mới

| File trong repo ERP | Dùng để | Cần sửa gì |
|---|---|---|
| `tools/make-store-screenshots.ps1` | Chuẩn hoá screenshot ra 4 bộ (App Store 1284×2778, Play phone/tablet 1080×1920) | Không |
| `codemagic.yaml` | Build iOS → TestFlight | `bundle_identifier`, thư mục Flutter |
| `frontend/ios/Podfile` | Bắt buộc có — Windows không sinh file này | Không |
| `frontend/ios/Runner/AppDelegate.swift` | Sửa lỗi iOS không nhận push trên template UIScene | Không |
| `frontend/lib/services/fcm_service.dart` | Chờ APNs token trước khi `getToken()` | Không |
| `frontend/lib/services/fcm_registration_service.dart` | Gửi token lên backend, lưu lỗi để chẩn đoán | Endpoint API |
| `frontend/lib/presentation/screens/settings_screen.dart` — `_PushDiagnosticCard` | Bảng chẩn đoán push trên máy thật, ẩn sau thao tác nhấn giữ | Không |
| `frontend/android/app/build.gradle.kts` | Đọc `key.properties`, fallback debug key | `applicationId`, `namespace` |
| `releases/store-assets/privacy-policy.html` | Chính sách quyền riêng tư | Tên app, dữ liệu thu thập |
| `releases/store-listing-vi.md` | Mô tả store + cách trả lời Data safety / App Privacy | Nội dung app |
| `releases/GIAY-UY-QUYEN-APP-STORE.docx` | Mẫu giấy uỷ quyền song ngữ | Tên app, Apple ID |
| `HUONG_DAN_NOP_APPSTORE.md` | Quy trình App Store đầy đủ + 3 lần từ chối và cách xử lý | Đọc, không copy |
| `noti.md` mục 9.7 | Bẫy push iOS chi tiết | Đọc |

---

## 2. Bài học đã trả giá — đọc trước khi build

Mỗi dòng dưới đây là một lần build lại hoặc một lần bị từ chối. Xếp theo giai đoạn.

### 2.1. Khi tạo dự án Flutter

- **Tạo trên Windows thì thiếu `ios/Podfile`.** Codemagic sẽ tự sinh Podfile tạm thiếu
  `platform :ios` và fail. Copy Podfile từ repo ERP vào ngay.
- **Ghim phiên bản Flutter** trong `codemagic.yaml` (`flutter: 3.44.6`), đừng để `stable`.
  Flutter lên bản mới là build vỡ dù không sửa dòng code nào.
- **`themeMode: ThemeMode.light`** nếu giao diện chỉ thiết kế cho nền sáng. Để `system`
  thì máy đặt chế độ tối sẽ ra chữ trắng trên nền trắng ở mọi ô nhập không khai `style`.
- `applicationId` (Android) có thể khác `namespace` — không cần đổi namespace khi đổi
  package.

### 2.2. Push notification trên iOS — 4 vòng build mới ra

Triệu chứng chung: quyền `authorized`, Firebase khởi tạo, nhưng không bao giờ có token.

1. **Template iOS mới của Flutter (UIScene)**: `firebase_messaging` **không tự gọi**
   `registerForRemoteNotifications()`. Phải gọi tay trong `AppDelegate` và gán
   `Messaging.messaging().apnsToken` thủ công. Lấy nguyên `AppDelegate.swift` từ repo ERP.
2. **Dart phải chờ APNs token** trước `getToken()`, và đặt `_initialised = true` **trước**
   khi lấy token — không thì một lần ném lỗi là cả service chết.
3. **Khoá APNs phải chọn "Sandbox & Production"** lúc tạo. Chọn nhầm Sandbox là Apple trả
   `BadEnvironmentKeyInToken` ở production. Không sửa được, phải tạo khoá mới.
4. **Firebase phải có khoá ở ô Production** — cùng file `.p8` nạp vào cả hai ô.
5. Kiểm tra khoá độc lập với Firebase bằng script `apnscheck.mjs` (gọi thẳng APNs với
   token giả): production trả `BadDeviceToken` là khoá đúng.
6. Không đọc được `debugPrint` trên bản TestFlight → **luôn có bảng chẩn đoán trong app**.

### 2.3. Backend

- `node --watch` sinh tiến trình con; Ctrl+C có thể để lại **con mồ côi giữ port** trong
  khi cửa sổ log đã chết. Mất nửa ngày vì nhìn log của tiến trình sai. Chạy `node index.js`
  hoặc dựng service, log ra file.
- Service account Firebase là **cấp project** — thêm app mới không cần đụng backend.

### 2.4. Google Play

- Screenshot phải đúng **16:9 hoặc 9:16**; ảnh chụp iPhone/Android đời mới không đúng tỉ lệ
  → dùng script chuẩn hoá.
- Tablet 7" và 10" **bắt buộc** — script xuất luôn, dùng chung ảnh phone.
- Package name khoá ngay lần upload đầu.
- **Xác minh nhà phát triển Android** (deadline 30/09/2026): đăng ký tên gói trong Play
  Console trước khi phát hành.

### 2.5. App Store — thứ tự bị từ chối thực tế

| Lần | Lý do | Sửa bằng |
|---|---|---|
| 1 | **2.1 Information Needed** — tài khoản mới, Apple đòi 6 mục thông tin + video quay màn hình | Trả lời đủ 6 mục, quay video trên máy thật từ lúc mở app tới lúc đăng xuất |
| 2 | **3.2 Business** — app nội bộ trên kênh công khai | Xin Unlisted tại `developer.apple.com/contact/request/unlisted-app/` — được duyệt trong 3 ngày làm việc |
| 2 | **2.3.6** — có nhắn tin (bình luận trên phiếu) mà Age Rating chưa khai | Age Ratings → Messaging and Chat = Yes |
| 3 | **5.1.1(ix)** — app y tế, tài khoản phải là **Organization** | Chuyển đổi tài khoản. Giấy uỷ quyền **không** được nhận. Transfer app cũng không được (cần đã phát hành) |

Những thứ tôi tự phát hiện và gỡ trước khi Apple thấy — đều là lý do từ chối chắc chắn:

- Mục **"Sắp triển khai"** với màn hình *"dùng tạm trên ERP web"* → 2.1 App Completeness
  + 4.2 Minimum Functionality.
- **Trợ lý ảo gọi Gemini bằng key rỗng** → hiện lỗi "chưa cấu hình API key" trên mọi màn
  hình → 2.1. Đồng thời gọi endpoint không công khai của Google Translate.
- **Mô tả store nhắc tính năng không có** (chấm công, trợ lý) → 2.3.
- **Screenshot lộ tên và mã bệnh nhân thật** → 5.1.2, và là công bố dữ liệu y tế ra công khai.
- **Tài khoản demo là tài khoản cá nhân, mật khẩu `123`** trên hệ thống mở Internet.
- Thiếu purpose string cho API mà plugin tham chiếu (`file_picker` → Photo Library, Camera).

### 2.6. Metadata App Store — chọn gì

| Ô | Chọn | Đừng chọn |
|---|---|---|
| Category | Business / Productivity | **Medical** — kích hoạt bộ quy định app y tế |
| Age Rating → Medical or Treatment Information | Infrequent/Mild | **Frequent** — bắt khai thiết bị y tế được quản lý |
| Age Rating → Messaging and Chat | Yes nếu có bất kỳ bình luận/trao đổi nào | |
| Availability | Chỉ Việt Nam | All countries — dính Digital Services Act EU |
| Version Release | Manually | Automatically |
| Screenshot thứ tự | Màn hình có nội dung trước, đăng nhập cuối | Đăng nhập đầu — 2.3.3 |

---

## 3. Checklist cho app MỚI

Tick theo thứ tự. Mục có ⏱ là việc lâu, làm sớm.

### Giai đoạn 0 — Quyết định (trước khi code)

- [ ] Chốt Bundle ID / Package name, dùng chung hai nền tảng
- [ ] Xác định: app có dữ liệu y tế không? → cần tài khoản Organization
- [ ] Xác định: nội bộ hay công khai? → nội bộ thì sẽ xin Unlisted
- [ ] ⏱ Nếu tài khoản Apple chưa là Organization: làm mục 15 của `HUONG_DAN_NOP_APPSTORE.md` trước
- [ ] ⏱ Tạo email theo domain `@benhvienminhan.com` (iNET → OneMail) nếu chưa có

### Giai đoạn 1 — Hạ tầng cho app

- [ ] Repo GitHub mới, **private**, `.gitignore` chặn `*.jks`, `key.properties`, `*.p8`,
      `google-services.json`, `.env`, `uploads/`
- [ ] Firebase: Add app Android + iOS vào `erp-minh` (hoặc project mới) → tải
      `google-services.json`, `GoogleService-Info.plist`
- [ ] Firebase → Cloud Messaging → upload `APNS_8QPWK4J86M.p8` vào **cả hai ô** (Key ID
      `8QPWK4J86M`, Team ID `BJCFV9A3UA`)
- [ ] Android: tạo `upload-keystore.jks` mới + `key.properties`, sao lưu ra
      `d:\MinhAn\_BACKUP_KEYSTORE_<TENAPP>\`
- [ ] Apple: đăng ký App ID (Identifiers) với capability **Push Notifications**
- [ ] Apple: tạo Provisioning Profile App Store cho Bundle ID mới
- [ ] Codemagic: Add application → Switch to YAML → Code signing identities → Fetch profile mới
- [ ] Copy `codemagic.yaml`, `Podfile`, `AppDelegate.swift`, `fcm_service.dart`,
      `fcm_registration_service.dart`, `_PushDiagnosticCard` từ repo ERP

### Giai đoạn 2 — Trước khi build phát hành

- [ ] Gỡ mọi màn hình placeholder / "sắp có" / "coming soon"
- [ ] Gỡ mọi tính năng cần config mà bản phát hành không có (API key, service ngoài)
- [ ] Không gọi endpoint không công khai của bên thứ ba
- [ ] `Info.plist` có purpose string cho **mọi** API mà plugin tham chiếu
- [ ] `ITSAppUsesNonExemptEncryption = false` trong Info.plist
- [ ] `TARGETED_DEVICE_FAMILY = 1` nếu không test trên iPad
- [ ] `themeMode: ThemeMode.light` nếu không có dark mode thật
- [ ] Test push trên **iPhone thật**, app **tắt hẳn**, xem bảng chẩn đoán

### Giai đoạn 3 — Tài liệu store (dùng chung hai cửa hàng)

- [ ] Tài khoản demo **riêng** cho reviewer, mật khẩu mạnh, quyền vừa đủ, dữ liệu giả
- [ ] Xác nhận backend đăng nhập được từ ngoài Việt Nam
- [ ] Privacy policy ở URL thật (không `#`), mở được ẩn danh
- [ ] 4 screenshot từ bản phát hành, **không dữ liệu thật**, chạy `make-store-screenshots.ps1`
- [ ] Icon 512 (Play) + 1024 (Apple), PNG **không alpha**
- [ ] Mô tả store chỉ nêu tính năng **thật sự có**

### Giai đoạn 4 — Google Play

- [ ] Đăng ký tên gói ở Xác minh nhà phát triển Android
- [ ] Upload AAB → Internal testing → test → Production
- [ ] Store listing, App content (App access = có đăng nhập + demo), Data safety

### Giai đoạn 5 — App Store

- [ ] Tạo app trên App Store Connect (Bundle ID đúng, SKU, ngôn ngữ Vietnamese)
- [ ] **Nếu nội bộ: xin Unlisted ngay** (`/contact/request/unlisted-app/`), ghi chú trong Review Notes
- [ ] App Information: Category, Content Rights, Age Ratings
- [ ] App Privacy: Privacy Policy URL + Data Types
- [ ] Pricing: Free, chỉ Việt Nam
- [ ] Build qua Codemagic → TestFlight → test máy thật
- [ ] Trang phiên bản: screenshot, mô tả, keywords, build, Sign-In Info, Notes tiếng Anh, Manually release
- [ ] Quay video màn hình 2–3 phút từ lúc mở app tới đăng xuất — đính kèm ngay lần nộp đầu
- [ ] Add for Review

---

## 4. Những thứ CÒN THIẾU tính đến 14/09/2026

Phải xong trước khi app y tế nào lên được App Store:

| Việc | Trạng thái | Chặn gì |
|---|---|---|
| Tài khoản Apple chuyển sang **Organization** | Đang làm — cần D-U-N-S + email domain + Developer Support | **Mọi app y tế** trên iOS |
| Email theo domain `@benhvienminhan.com` | Chưa tạo — domain có OneMail sẵn tại iNET | Form chuyển đổi tài khoản Apple |
| D-U-N-S Number của bệnh viện | Chưa tra | Chuyển đổi tài khoản Apple |
| Quyền quản trị domain `benhvienminhan.com` tại iNET | Chưa rõ ai giữ | Tạo email; gia hạn domain |
| ERP app trên App Store | Bị từ chối lần 3, chờ chuyển đổi tài khoản | — |
| ERP app trên Play Production | Còn ở Internal testing | Chỉ cần bấm Promote |

App mới nếu **không** chạm dữ liệu y tế thì không bị chặn bởi hàng đầu — nhưng vẫn nên
chờ chuyển đổi xong để mọi app đứng tên bệnh viện.

---

## 5. Ai làm được gì

| Việc | Ai |
|---|---|
| Build Android, Codemagic, Firebase, Play Console, App Store Connect | Nhật Hoàng (Admin) |
| Tạo khoá APNs, chứng chỉ, chuyển đổi tài khoản Apple | Đào Ngọc Sơn (Account Holder) hoặc Admin |
| Ký giấy uỷ quyền, đứng tên tổ chức với Apple | Giám đốc bệnh viện |
| Tài khoản demo trên ERP | Phòng CNTT |
| Backend, DB `192.168.8.16`, secrets trên `F:\` | Phòng CNTT |
