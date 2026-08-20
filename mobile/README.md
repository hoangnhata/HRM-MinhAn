# HRM Minh An — Mobile App (Flutter)

Ứng dụng di động nội bộ cho hệ thống quản trị nhân sự Bệnh viện Minh An, đồng bộ dữ liệu và quy trình nghiệp vụ với bản web (React) qua cùng một backend Spring Boot (`/j1-api`).

## 1. Công nghệ sử dụng

| Thành phần            | Lựa chọn                              |
|------------------------|----------------------------------------|
| Framework              | Flutter 3 (Dart ^3.12)                |
| Quản lý state          | `flutter_riverpod`                    |
| Điều hướng             | `go_router` (khai báo route, redirect theo trạng thái đăng nhập) |
| Gọi API                | `dio` (interceptor tự gắn JWT, tự xử lý 401/403) |
| Lưu trữ an toàn         | `flutter_secure_storage` (JWT, thông tin phiên) |
| Font & theme           | `google_fonts` — **Inter**, dùng chung palette và typography với web |
| Biểu đồ Dashboard      | `fl_chart` (donut trạng thái, area tuyển dụng) + thanh ngang phòng ban |
| Motion UI              | `flutter_animate`, `flutter_slidable` |
| Ảnh & chữ ký            | `cached_network_image`, `image_picker`, `signature` |
| Định dạng ngày/số       | `intl` (vi-VN) |
| Push thông báo          | `firebase_core`, `firebase_messaging`, `flutter_local_notifications` (cần `google-services.json`) |

## 2. Cấu trúc thư mục (feature-first)

```
lib/
├─ core/                     # Hạ tầng dùng chung toàn app
│  ├─ config/                # AppConfig: base URL, timeout, resolve URL tuyệt đối
│  ├─ network/                # ApiClient (Dio) + ApiException
│  ├─ storage/                 # TokenStorage (JWT, phiên đăng nhập)
│  ├─ theme/                   # AppColors, AppTheme (đồng bộ giao diện web)
│  ├─ router/                  # go_router, route paths, AppShell (bottom nav)
│  ├─ utils/                    # Formatters, UserRole, Validators
│  └─ widgets/                  # Widget dùng chung: StatusChip, EmptyState, SectionCard...
├─ shared/
│  └─ models/                  # DTO dùng chung nhiều feature (Employee, Department, PagedResponse...)
└─ features/
   ├─ auth/                    # Đăng nhập, đổi mật khẩu bắt buộc, thiết lập chữ ký
   ├─ dashboard/                # Bảng điều khiển theo vai trò
   ├─ profile/                  # Hồ sơ cá nhân, avatar, đổi mật khẩu, chữ ký
   ├─ notifications/             # Thông báo, badge, đánh dấu đã đọc
   ├─ employees/                 # Danh sách/chi tiết nhân viên, phòng ban
   ├─ attendance/                 # Bảng công tháng, công phép, đơn công (tạo/duyệt/rút)
   ├─ evaluation/                  # Đánh giá điều dưỡng (của tôi / chờ duyệt / duyệt / lịch sử)
   ├─ salary/                      # Lương của tôi, bảng lương theo kỳ
   └─ requests/                     # Engine chung cho 7 loại đơn từ khác (nghỉ con nhỏ, chuyển khoa,
                                     #  chuyển chính thức, xin trực chính, đào tạo, hội thảo, đổi ca)
```

Mỗi feature tuân theo 3 lớp: `data/` (repository gọi API) → `application/` (Riverpod controller/state) → `presentation/` (màn hình, widget).

## 3. Cấu hình kết nối backend

Mặc định app gọi backend production đã deploy:

`https://erp.benhvienminhan.com/j1-api`

Khi cần chạy backend local (máy ảo Android dùng `10.0.2.2`, điện thoại thật dùng IP LAN):

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/j1-api
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080/j1-api
```

## 4. Chạy dự án

```bash
cd mobile
flutter pub get
flutter analyze          # kiểm tra tĩnh, phải "No issues found!"
flutter run               # chạy trên thiết bị/emulator đã kết nối
```

Build bản release:

```bash
flutter build apk --release
flutter build appbundle --release
```

## 5. Luồng đăng nhập

1. Đăng nhập bằng tài khoản đã cấp trên hệ thống HRM.
2. Nếu tài khoản chưa từng đổi mật khẩu → bắt buộc đổi mật khẩu trước khi vào app.
3. Nếu tài khoản chưa có chữ ký số → bắt buộc vẽ và lưu chữ ký (dùng cho việc duyệt các loại đơn/phiếu).
4. Sau khi hoàn tất, JWT được lưu an toàn (`flutter_secure_storage`) và tự động gắn vào mọi request tiếp theo; hết hạn/401 sẽ tự đưa về màn đăng nhập.

## 6. Phân quyền theo vai trò

Giao diện (menu, quick action, tab duyệt...) được ẩn/hiện dựa trên `UserRole` trả về từ `/v1/account/me`, mirror đúng logic phân quyền của bản web (nhân viên chỉ xem của mình; trưởng khoa/phòng, HCNS, giám đốc... thấy thêm các tab chờ duyệt tương ứng vai trò).

## 7. Đồng bộ API với backend

Toàn bộ đường dẫn trong `features/**/data/*_repository.dart` đã được đối chiếu với các controller Spring Boot. Một số ràng buộc quan trọng của backend mà app phải tuân theo:

| Nghiệp vụ | Ràng buộc backend | Cách app xử lý |
|-----------|-------------------|----------------|
| Đổi mật khẩu | `ChangePasswordRequest` dùng field `oldPassword` | Gửi đúng `oldPassword` |
| Tạo đơn công | `shiftScope` là `@NotNull` cho mọi loại đơn | Luôn gửi, suy ra từ loại bổ sung / mốc giải trình |
| Đơn bổ sung công | Bắt buộc `requestedStart` + `requestedEnd`; bổ sung cả ngày cần thêm cặp giờ ca chiều | Form hiện ô giờ tương ứng, điền sẵn theo `/v1/attendance/schedule` |
| Đơn giải trình | Cần ít nhất một mốc chấm công kèm giờ thay thế | Chọn mốc trong 4 mốc, gửi `explainedMorningIn/Out`, `explainedAfternoonIn/Out` |
| Đơn công tác | Backend đã ngừng nhận `BUSINESS_TRIP` | Loại khỏi danh sách đơn tạo mới (dùng đơn Hội thảo) |
| Điều động | Chỉ trưởng khoa/phòng lập cho người khác, cần khung giờ | Không nằm trong luồng tạo đơn cá nhân trên mobile |
| HCNS duyệt đào tạo | Bắt buộc `monthlySupport`, `postCourseCommitment` | Bottom sheet nhập trước khi duyệt |
| Giám đốc duyệt hội thảo | Bắt buộc `withPay` | Bottom sheet chọn "Có công / Không công" |
| HCNS & Giám đốc duyệt đơn quên chấm | `waiveForgotFine` quyết định trừ hay miễn tiền phạt | Bottom sheet chọn "Vẫn trừ tiền / Miễn trừ" |

Mọi lỗi trả về từ backend (`message` trong body) được hiển thị nguyên văn trên SnackBar để người dùng biết chính xác nguyên nhân.

## 8. Thông báo đẩy (FCM) — hướng dẫn từ đầu đến cuối (Android + iOS)

Tài liệu này hướng dẫn **toàn bộ** để nhân viên nhận thông báo kiểu tin nhắn trên điện thoại (máy khóa / app tắt), đồng thời vẫn có hộp thư **Thông báo** trong app.

### 8.1. Hiểu hệ thống trước khi làm

```text
[Sự kiện HRM: có đơn chờ duyệt, duyệt xong, lương...]
        │
        ▼
[Backend Spring Boot]
  1) Lưu dòng vào bảng notifications  → hiện trong inbox app
  2) Nếu FCM bật: gửi push tới mọi device token của user
        │
        ▼
[Firebase Cloud Messaging]
        ├─► Android (FCM trực tiếp)
        └─► iOS (FCM → Apple APNs → iPhone)
        │
        ▼
[Người dùng chạm thông báo]
        │
        ▼
[App mở đúng đơn + khoanh (highlight)]
```

| Loại | Người dùng thấy ở đâu | Cần Firebase? |
|------|------------------------|---------------|
| Inbox trong app | Màn **Thông báo** khi mở app | Không |
| Push hệ thống | Banner / màn khóa Android & iOS | Có |

**ID ứng dụng (phải gõ đúng, phân biệt hoa thường / gạch dưới):**

| Nền tảng | Application / Bundle ID |
|----------|-------------------------|
| Android | `com.minhan.hrm.hrm_mobile` |
| iOS | `com.minhan.hrm.hrmMobile` |

Dùng **một** Firebase project cho cả Android + iOS + backend.

Máy **tắt nguồn hoàn toàn** chỉ nhận push khi bật lại và có mạng (giống Zalo).

Thứ tự làm khuyến nghị: **1 → 2 → 3 (Android) → 4 (iOS, nếu cần) → 5 (backend) → 6 (chạy app) → 7 (kiểm tra)**.

---

### 8.2. Bước 1 — Chuẩn bị tài khoản & máy

**Tài khoản**

1. Google (để vào [Firebase Console](https://console.firebase.google.com/)).
2. (Chỉ khi làm iOS) Tài khoản [Apple Developer Program](https://developer.apple.com/programs/) đã trả phí (~99 USD/năm), thuộc team bệnh viện.

**Máy / phần mềm**

| Việc | Cần gì |
|------|--------|
| Cấu hình Firebase, backend | Windows hoặc Mac đều được |
| Build & chạy **Android** | Windows/Mac + Flutter + Android Studio / emulator có **Google Play** hoặc máy Android thật |
| Build & chạy **iOS** | **Mac** + Xcode mới + **iPhone thật** (khuyên dùng) + cáp |

**Repo local**

- Đã clone project HRM, có thư mục `mobile/` và `backend/`.
- Flutter đã cài (`flutter doctor` không lỗi phần Android; trên Mac thêm phần iOS).

---

### 8.3. Bước 2 — Tạo Firebase project (chung)

1. Mở [https://console.firebase.google.com/](https://console.firebase.google.com/).
2. Bấm **Add project** / **Tạo dự án**.
3. Đặt tên, ví dụ: `HRM Minh An`.
4. Google Analytics: có thể **tắt** nếu không cần → **Create project** → đợi xong → **Continue**.
5. Bạn đang ở trang **Project overview** (biểu tượng bánh răng = Project settings).

Ghi nhớ: mọi file tải ở bước sau (`google-services.json`, `GoogleService-Info.plist`, service account) phải thuộc **project này**.

---

### 8.4. Bước 3 — Cấu hình Android (chi tiết)

#### 3.1. Đăng ký app Android trên Firebase

1. Trên Project overview, bấm biểu tượng **Android** (hoặc **Add app** → Android).
2. Điền form:
   - **Android package name:** `com.minhan.hrm.hrm_mobile`  
     (đúng như `applicationId` trong `mobile/android/app/build.gradle.kts`)
   - **App nickname (optional):** `HRM Minh An Android`
   - **Debug signing certificate SHA-1:** để trống lúc đầu (chỉ cần sau này nếu dùng Google Sign-In).
3. Bấm **Register app**.
4. Bấm **Download google-services.json**.

#### 3.2. Đặt file vào đúng chỗ

1. Copy file vừa tải thành đúng đường dẫn sau (tạo/ghi đè):

```text
HRM-MinhAn/mobile/android/app/google-services.json
```

**Đúng:** cùng thư mục với `mobile/android/app/build.gradle.kts`  
**Sai:** đặt ở `mobile/google-services.json` hoặc `mobile/android/google-services.json`

2. Mở file bằng Notepad, kiểm tra có đoạn:

```json
"package_name": "com.minhan.hrm.hrm_mobile"
```

Nếu package khác → đăng ký lại app Firebase với đúng ID.

3. Gradle trong project đã cấu hình: **chỉ khi file này tồn tại** mới bật plugin Google Services. Không có file thì app vẫn build được nhưng **không có push**.

#### 3.3. (Tuỳ chọn) Emulator Android

- Tạo AVD trong Android Studio dùng image có chữ **Google Play** (không dùng image “Google APIs” thuần nếu thiếu Play Services).
- Máy thật: Settings → Apps → HRM → Notifications → bật thông báo.

---

### 8.5. Bước 4 — Cấu hình iOS (chi tiết)

Bỏ qua mục này nếu chưa làm iPhone. Làm **sau** khi đã có Firebase project (Bước 2).

#### 4.1. Tạo App ID trên Apple Developer

1. Đăng nhập [https://developer.apple.com/account](https://developer.apple.com/account).
2. Vào **Certificates, Identifiers & Profiles**.
3. Cột trái chọn **Identifiers** → nút **+**.
4. Chọn **App IDs** → Continue.
5. Chọn **App** → Continue.
6. **Description:** `HRM Minh An`
7. **Bundle ID:** Explicit → nhập đúng:

```text
com.minhan.hrm.hrmMobile
```

8. Trong **Capabilities**, tick **Push Notifications**.
9. Continue → Register.

(Nếu Identifier đã tồn tại: mở ra → edit → bật Push Notifications → Save.)

#### 4.2. Tạo khóa APNs (.p8) — chỉ làm 1 lần cho team

1. Vẫn trong Apple Developer → **Keys** → **+**.
2. **Key Name:** ví dụ `HRM Minh An APNs`.
3. Tick **Apple Push Notifications service (APNs)**.
4. Continue → Register.
5. **Download** file `.p8` ngay — Apple **chỉ cho tải một lần**. Lưu vào chỗ an toàn (ví dụ `C:/secrets/` hoặc thư mục mật khẩu của IT).
6. Ghi vào sổ:
   - **Key ID** (hiện trên trang sau khi tạo, dạng 10 ký tự)
   - **Team ID** (góc phải trên của trang Account, dạng 10 ký tự)

#### 4.3. Đăng ký app iOS trên Firebase

1. Firebase Console → cùng project → **Add app** → biểu tượng **iOS**.
2. **Apple bundle ID:** `com.minhan.hrm.hrmMobile` (phải khớp Xcode / App ID).
3. App nickname: `HRM Minh An iOS` (tuỳ chọn).
4. App Store ID: để trống nếu chưa lên Store.
5. Register app → **Download GoogleService-Info.plist**.

#### 4.4. Đặt `GoogleService-Info.plist` vào Xcode

1. Copy file vào:

```text
HRM-MinhAn/mobile/ios/Runner/GoogleService-Info.plist
```

2. Trên **Mac**, mở workspace (không mở `.xcodeproj`):

```bash
open mobile/ios/Runner.xcworkspace
```

3. Trong Xcode, kéo `GoogleService-Info.plist` thả vào nhóm **Runner** (cùng cấp `Info.plist`, `AppDelegate.swift`).
4. Dialog:
   - Tick **Copy items if needed**
   - Tick target **Runner**
   - Finish
5. Chọn file trong Xcode → bên phải File Inspector → Target Membership phải có **Runner**.

Mở plist, kiểm tra `BUNDLE_ID` = `com.minhan.hrm.hrmMobile`.

#### 4.5. Upload APNs key vào Firebase

1. Firebase → bánh răng **Project settings** → tab **Cloud Messaging**.
2. Kéo xuống **Apple app configuration**.
3. Tại **APNs Authentication Key** → **Upload**.
4. Chọn file `.p8`, nhập **Key ID** và **Team ID** đã ghi → Upload.
5. Thấy trạng thái đã có key (không còn trống).

Không upload key này thì iPhone **không nhận** push dù app đã login.

#### 4.6. Signing & Capabilities trong Xcode

1. Mở `Runner.xcworkspace` → chọn target **Runner** (không phải RunnerTests).
2. Tab **Signing & Capabilities**:
   - Tick **Automatically manage signing**
   - **Team:** chọn team Apple Developer của bệnh viện
   - Bundle Identifier hiện `com.minhan.hrm.hrmMobile`
3. Bấm **+ Capability**:
   - Thêm **Push Notifications** (nếu chưa có)
   - Thêm **Background Modes** → tick **Remote notifications**
4. Repo đã có entitlements:
   - Debug → `Runner/Runner.entitlements` (`aps-environment` = **development**)
   - Release / Profile → `Runner/RunnerRelease.entitlements` (**production**)

Nếu Xcode báo lỗi provisioning: vào Apple Developer → Profiles, hoặc để Xcode tự tạo khi chọn đúng Team.

---

### 8.6. Bước 5 — Bật gửi push trên backend (chung Android + iOS)

Backend cần **Firebase Admin SDK service account** (khác với `google-services.json` / `GoogleService-Info.plist`).

#### 5.1. Tải service account

1. Firebase → **Project settings** → tab **Service accounts**.
2. Chọn **Firebase Admin SDK**.
3. Bấm **Generate new private key** → xác nhận → tải file JSON  
   (tên dạng `hrm-minhan-xxxxx-firebase-adminsdk-xxxxx.json`).
4. Đặt trên máy chạy backend, **không commit Git**, ví dụ:

```text
C:/secrets/hrm-firebase-adminsdk.json
```

Trên Linux server ví dụ: `/etc/hrm/firebase-adminsdk.json` (quyền đọc chỉ cho user chạy Java).

#### 5.2. Bật cấu hình

**Cách khuyến nghị — file `backend/.env`** (đã được gitignore):

```properties
FCM_PUSH_ENABLED=true
FCM_CREDENTIALS_PATH=C:/secrets/hrm-firebase-adminsdk.json
```

Hoặc biến môi trường Windows / service:

```text
FCM_PUSH_ENABLED=true
FCM_CREDENTIALS_PATH=C:/secrets/hrm-firebase-adminsdk.json
```

Hoặc trong `application.yml`:

```yaml
minhan:
  hrm:
    push:
      enabled: true
      credentials-path: C:/secrets/hrm-firebase-adminsdk.json
```

Đường dẫn phải **tuyệt đối**, đúng ổ đĩa, đúng dấu `/` hoặc `\\`.

#### 5.3. Database

Khởi động backend lần đầu sau khi có code push: Flyway chạy migration:

```text
V93__user_device_tokens.sql
```

Tạo bảng `user_device_tokens`. Kiểm tra:

```sql
SHOW TABLES LIKE 'user_device_tokens';
-- hoặc
DESCRIBE user_device_tokens;
```

#### 5.4. Restart backend và đọc log

Khởi động lại Spring Boot. Tìm một trong các dòng:

| Log | Ý nghĩa |
|-----|---------|
| `FCM push đã sẵn sàng` | OK — có thể gửi push |
| `FCM push disabled ...` | Chưa `FCM_PUSH_ENABLED=true` |
| `FCM credentials không tồn tại` | Sai path file JSON |
| `Không khởi tạo được Firebase Admin SDK` | File JSON hỏng / không đúng project |

---

### 8.7. Bước 6 — Build, chạy app, đăng nhập

#### 6.1. Android

```bash
cd mobile
flutter clean
flutter pub get
flutter devices
flutter run -d <id-android>
```

1. App mở → hệ thống hỏi quyền thông báo (Android 13+) → **Cho phép**.
2. Đăng nhập tài khoản HRM thật.
3. Trong logcat / debug console: không còn `FCM: Firebase chưa sẵn sàng`.
4. (Tuỳ chọn) Lọc log `FCM` để xem đăng ký token.

#### 6.2. iOS (trên Mac)

```bash
cd mobile
flutter pub get
cd ios
pod install
cd ..
flutter devices
flutter run -d <id-iphone>
```

Hoặc Run từ Xcode trên iPhone đã tin cậy máy Mac.

1. Popup quyền thông báo → **Allow**.
2. Đăng nhập HRM.
3. Settings iOS → Notifications → HRM Minh An → đảm bảo Allow Notifications bật.

#### 6.3. App đăng ký token lên backend

Sau login thành công, app gọi:

```http
POST /j1-api/v1/device-tokens
Authorization: Bearer <JWT>
Content-Type: application/json

{ "token": "<fcm-token>", "platform": "ANDROID" }
```

hoặc `"platform": "IOS"`.

Logout sẽ cố gắng `DELETE` token đó.

---

### 8.8. Bước 7 — Kiểm tra end-to-end

#### 7.1. Kiểm tra token trong DB

```sql
SELECT id, user_id, platform, LEFT(token, 28) AS token_prefix, updated_at
FROM user_device_tokens
ORDER BY updated_at DESC
LIMIT 20;
```

- Vừa login Android → có dòng `platform = ANDROID`
- Vừa login iOS → có dòng `platform = IOS`
- `user_id` khớp user đã đăng nhập

Không có dòng → app chưa init Firebase / chưa login / lỗi mạng tới API.

#### 7.2. Tạo một thông báo thật

Cách đơn giản:

1. Dùng tài khoản **nhân viên** tạo đơn cần duyệt (ví dụ đơn công / điều động).
2. Tài khoản **người duyệt** (đã login app trên điện thoại, đã Allow thông báo) phải nhận:
   - Dòng mới trong màn **Thông báo** trong app
   - **Banner hệ thống** (kéo app ra nền hoặc khóa máy để dễ thấy)

Hoặc ADMIN gọi API adhoc (Swagger / Postman) `POST /j1-api/v1/notifications/adhoc` tới `targetUserId` của máy đang test.

#### 7.3. Chạm vào push

1. Chạm banner hệ thống.
2. App mở (hoặc đưa lên foreground).
3. Vào đúng chi tiết đơn / phiếu.
4. Thấy **viền pulse khoanh** khoảng 2–3 giây.

#### 7.4. Checklist nhanh

**Chung**
- [ ] Một Firebase project
- [ ] Service account JSON + `FCM_PUSH_ENABLED=true`
- [ ] Log backend: `FCM push đã sẵn sàng`
- [ ] Bảng `user_device_tokens` tồn tại

**Android**
- [ ] Firebase Android app `com.minhan.hrm.hrm_mobile`
- [ ] File `mobile/android/app/google-services.json`
- [ ] Cho phép thông báo + login → có token `ANDROID`
- [ ] Nhận được banner khi khóa máy

**iOS**
- [ ] App ID + Push trên Apple Developer
- [ ] APNs `.p8` đã upload Firebase Cloud Messaging
- [ ] Firebase iOS app `com.minhan.hrm.hrmMobile`
- [ ] `GoogleService-Info.plist` trong target Runner
- [ ] Xcode Team + Push Notifications + Background Modes
- [ ] iPhone thật, Allow, login → token `IOS`
- [ ] Nhận được banner khi khóa máy

---

### 8.9. Xử lý sự cố

| Hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
|------------|------------------------|------------|
| Chỉ thấy trong inbox, không có banner | Chưa bật FCM backend; chưa có file Firebase trên máy; chưa Allow thông báo; chưa login lại sau khi thêm file | Lần lượt kiểm tra Bước 5 → 3/4 → 6 |
| Log `FCM: Firebase chưa sẵn sàng` | Thiếu `google-services.json` / `GoogleService-Info.plist` hoặc sai chỗ | Đặt đúng path; iOS phải thuộc target Runner |
| iOS: không có APNs token | Chưa upload `.p8`; App ID chưa bật Push; chạy Simulator; từ chối quyền thông báo | Làm lại 4.2–4.5; dùng iPhone thật |
| Token có trong DB nhưng không nhận push | Service account **khác** Firebase project với file mobile; hoặc backend chưa restart | Dùng đúng 1 project; xem log `FCM push đã sẵn sàng` |
| Android package / iOS bundle lệch | Gõ sai `_` / chữ hoa | So khớp bảng ID ở mục 8.1 |
| Push debug OK, bản TestFlight/App Store không | Entitlements vẫn `development` trên bản release | Release dùng `RunnerRelease.entitlements` (`production`) |
| Emulator Android không nhận | Image không có Google Play | Đổi AVD Google Play hoặc máy thật |
| Backend báo credentials không tồn tại | Path sai, thiếu quyền đọc file | Dùng path tuyệt đối; kiểm `dir` / `ls` file |

---

### 8.10. Bảo mật (bắt buộc với IT)

- **Không** commit lên Git: `google-services.json` (nếu policy nội bộ cấm), `GoogleService-Info.plist` (tuỳ policy), **đặc biệt** file `*-firebase-adminsdk-*.json` và `.p8`.
- Chỉ đặt credentials trên máy/server chạy backend, hạn chế quyền file.
- Khi nhân sự nghỉ việc: thu hồi / xoá key APNs hoặc service account nếu cần xoay vòng.

---

### 8.11. Tóm tắt một dòng

**Firebase (Android + iOS) → file config vào app → APNs key (iOS) → service account + `FCM_PUSH_ENABLED` trên backend → chạy app, Allow thông báo, login → có token trong DB → tạo sự kiện HRM → nhận push → chạm mở đúng đơn.**

### Phạm vi chưa có trên mobile

Các nhóm chức năng quản trị sau vẫn chỉ dùng bản web: cấu hình lịch ca & bậc phạt, ma trận công và xuất Excel, thang lương và xét nâng bậc, quản lý bảng lương, tạo mới các loại đơn từ hộ nhân viên, CRUD nhân viên và hồ sơ tài liệu, báo cáo nhân lực, nhập/đồng bộ dữ liệu, quản trị tài khoản và SSO.

