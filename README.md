# IT PRO — Website Dashboard

Flutter Web dashboard theo dõi các website nội bộ: trạng thái online/offline, độ trễ, chứng chỉ, ảnh chụp màn hình, favicon. Nhóm theo phòng ban, hỗ trợ Sáng/Tối + 10 chủ đề màu theo lĩnh vực.

- Flutter **3.38** (stable), Dart **^3.10**. Chỉ chạy trên **web** (dùng `dart:html`).
- Trạng thái, ảnh chụp, favicon đều lấy từ **backend** (FE không tự ping site).

---

## Mục lục

1. [Chạy project](#1-chạy-project)
2. [Cấu hình backend](#2-cấu-hình-backend)
3. [API backend cần có](#3-api-backend-cần-có)
4. [Cấu trúc thư mục](#4-cấu-trúc-thư-mục)
5. [Tính năng giao diện](#5-tính-năng-giao-diện)
6. [Theme Sáng/Tối, chủ đề màu & rèm cửa](#theme)
7. [Màu, font, icon](#7-màu-font-icon)
8. [Dữ liệu lưu ở trình duyệt](#8-dữ-liệu-lưu-ở-trình-duyệt)
9. [Hiệu năng — những điều KHÔNG nên làm](#9-hiệu-năng--những-điều-không-nên-làm)
10. [Lưu ý & việc còn tồn đọng](#10-lưu-ý--việc-còn-tồn-đọng)

---

## 1. Chạy project

```bash
cd D:\Viet\web_stack_fe
flutter pub get
```

### Chọn API khi chạy

| Muốn dùng | Lệnh | BE |
|---|---|---|
| **API local** (BE chạy ở máy mình) | `flutter run -d chrome --web-port=5000` | `http://localhost:9999` |
| **API public** (BE trên server) | `flutter run -d chrome --web-port=5000 --dart-define=API_BASE=http://192.168.122.16:9095` | `http://192.168.122.16:9095` |

- **VS Code:** F5 → chọn *FE · BE local (localhost:9999)* hoặc *FE · BE server (192.168.122.16:9095)* ([`.vscode/launch.json`](.vscode/launch.json)).
- **Luôn giữ `--web-port=5000`**: đổi cổng = đổi origin → mất localStorage (đăng nhập, sao, cache ảnh…).
- API local cần bật **dev_manager_be** ở máy mình trước.
- Kiểm tra đang gọi BE nào: Console trình duyệt → dòng `[API] http://…`.

### Hiệu năng & deploy

```bash
# Debug chậm hơn bản thật 5–10 lần → đánh giá độ mượt bằng release
flutter run -d chrome --web-port=5000 --release

# Build deploy (output: build/web). Mở từ địa chỉ server → tự dùng BE server.
flutter build web --release
# Ép BE khác khi build:
flutter build web --release --dart-define=API_BASE=http://<host>:<port>
```

> **Sau khi thêm package, asset, font hoặc đổi layout lớn: dừng hẳn (`q`) rồi chạy lại.**
> Hot reload/hot restart có thể không nạp thay đổi → thấy lỗi "cũ" dù code đã sửa.
> Cách kiểm tra đang chạy đúng bản mới: tab trình duyệt có tiêu đề **IT PRO** + logo, header có nút **Giao diện** (icon bảng màu).

---

## 2. Cấu hình backend

Địa chỉ BE được **chọn tự động** bởi `resolveApiBase()` trong [`lib/services/website_service.dart`](lib/services/website_service.dart) — **không cần sửa code** khi đổi dev ↔ server. Thứ tự ưu tiên:

| # | Điều kiện | BE dùng |
|---|---|---|
| 1 | Có `--dart-define=API_BASE=…` | Địa chỉ đó |
| 2 | Trang mở ở `localhost` / `127.0.0.1` | `kLocalApi` = `http://localhost:9999` |
| 3 | Còn lại (mở từ server / máy khác) | `kServerApi` = `http://192.168.122.16:9095` |

Đổi cổng BE local / địa chỉ server → sửa hằng `kLocalApi` / `kServerApi`.
Mọi API (danh sách site, status, screenshot, favicon, đăng nhập, submissions) dùng chung địa chỉ này.

**CORS:** backend phải trả header CORS cho origin của FE, cho **cả** `/api/websites/{id}/favicon` (favicon được tải bằng canvas, không dùng thẻ `<img>`; thiếu CORS → hiện icon glyph thay vì favicon).

---

## 3. API backend cần có

| Method | Path | Dùng cho | Ghi chú |
|---|---|---|---|
| GET | `/api/websites` | Danh sách site | Xem field bên dưới |
| GET | `/api/websites/status` | Trạng thái **tất cả** site (1 request) | Map theo `id` |
| GET | `/api/websites/{id}/favicon` | Favicon thật | `200` = ảnh, `204` = không có → hiện glyph |
| GET | `/api/screenshot?url=…&t=…` | Ảnh chụp site (preview) | `t` = cache-bust |
| GET | `/api/screenshot/meta?url=…` | Trạng thái ảnh chụp | `{ state: ok\|loading\|blank\|offline, capturedAt, hasImage }` |
| POST | `/api/screenshot/refresh[?url=…]` | Chụp lại (không `url` = tất cả) | Gọi khi bấm Refresh |

### Field của site (`GET /api/websites`)

| Field | Kiểu | Bắt buộc | Ý nghĩa |
|---|---|---|---|
| `id` | int | ✔ | |
| `name` | string | ✔ | |
| `url` | string | ✔ | |
| `departmentName` | string | | `KVH`, `PRO`, `HR`, `IT`, `MA`, `PC`, `TE`, `WH` (quyết định màu & thứ tự) |
| `type` | string | | Không hiển thị; chỉ dùng chọn hình placeholder preview |
| `status` | bool | | |
| `icon` | string | | Tên icon Lucide, vd `bar-chart`, `factory` (xem [mục 7](#icon)) |
| `iconUrl` | string | | URL favicon tuỳ chỉnh — BE ưu tiên dùng khi trả `/favicon` |
| `certWarning` | bool | | Chứng chỉ tự ký |

### Response `GET /api/websites/status`

Chấp nhận **một trong hai** dạng:

```jsonc
// Dạng mảng
[ { "id": 1, "online": true, "authRequired": false, "latencyMs": 28, "certWarning": false } ]

// Dạng map theo id
{ "1": { "online": true, "authRequired": false, "latencyMs": 28, "certWarning": false } }
```

- `online` thiếu/null → **Not checked** (xám), không tính là offline. Có thể dùng `status` thay `online`.
- Request lỗi → mọi site về **Not checked**.
- Lần gọi đầu, response thô được log ra console trình duyệt: `[status] raw response: …` (để đối chiếu format).

Logic: [`status_store.dart`](lib/services/status_store.dart) (`refreshAll`) → [`website_service.dart`](lib/services/website_service.dart) (`fetchStatus`).

---

## 4. Cấu trúc thư mục

```
lib/
├── main.dart                     # Khởi tạo: preload font, load theme, MaterialApp + ThemeCurtain
├── models/
│   ├── website.dart              # Website (id, name, url, departmentName, type, icon, iconUrl, certWarning, isPrivate, owner)
│   └── submission.dart           # Site người dùng thêm: visibility, trạng thái duyệt
├── services/
│   ├── website_service.dart      # Dio + mọi endpoint (baseUrl ở đây)
│   ├── status_store.dart         # Trạng thái từng site (ValueNotifier theo URL), lastSeen
│   ├── screenshot_store.dart     # Meta/ảnh chụp
│   ├── visit_store.dart          # Đếm lượt mở site
│   ├── auth_store.dart           # Đăng nhập (token backlog-be)
│   └── submission_store.dart     # Thêm / duyệt website (/api/submissions)
├── theme/
│   └── dash_theme.dart           # Token màu Light/Dark, DashPalette (chủ đề màu), StatusTone, màu phòng ban, font, Motion, ThemeController
├── screens/
│   └── dashboard.dart            # Trang chính: header, toolbar, frequently visited, banner, lưới nhóm
└── widgets/
    ├── sidebar.dart              # Sidebar (mở rộng / thu gọn / màn hẹp), logo, System health
    ├── website_card.dart         # Card site
    ├── site_icons.dart           # SiteIcon (favicon → glyph), map tên icon Lucide
    ├── dash_ui.dart              # Helper dùng chung: chip, chip trạng thái, Cert warning, copy/open
    ├── theme_curtain.dart        # Hiệu ứng rèm cửa khi đổi theme
    ├── theme_picker.dart         # Popover "Giao diện": Sáng/Tối + lưới chủ đề màu
    ├── site_thumbnail.dart       # Ảnh preview + placeholder
    ├── preview_dialog.dart       # Dialog xem live (iframe)
    ├── iframe_view.dart
    ├── form_ui.dart              # Dialog/side panel, DashButton, DashTextField, chip trạng thái duyệt
    ├── login_dialog.dart         # Đăng nhập + ensureLoggedIn()
    ├── upload_dialog.dart        # Form Thêm website / Sửa & gửi lại
    ├── my_sites_panel.dart       # Panel "Website của tôi"
    ├── review_panel.dart         # Panel "Duyệt website" (admin)
    └── account_button.dart       # Avatar + menu tài khoản
assets/logo.png                   # Logo sidebar (128px, resize từ web/favicon.png)
web/icons/favicon-64.png          # Icon tab trình duyệt
```

File cũ không còn được import ở đâu (có thể xoá): `screens/port_screen.dart`, `widgets/animated_logo.dart`, `widgets/rocket_loading_screen.dart`, `widgets/glass_card.dart`, `theme/app_theme.dart`. `widgets/team_art.dart` chỉ còn dùng class `DeptHealth`.

---

## 5. Tính năng giao diện

### Header
- Tiêu đề + dòng tóm tắt: `● 16/16 online · median 20 ms · updated 14:25:27`
  (chấm xanh nếu không có site offline, đỏ nếu có).
- Màn rộng: **search + bộ lọc All/Online/Offline nằm cùng hàng tiêu đề** (tiết kiệm chiều cao). Màn hẹp: xuống hàng riêng.
- Nút **ẩn/hiện preview** (icon ảnh): bật/tắt ảnh preview của **tất cả** card cùng lúc, nhớ lựa chọn (`itpro.showPreview`).
- Nút **Giao diện** (icon bảng màu, chấm nhỏ = màu chủ đề đang dùng): mở popover chọn **Sáng/Tối** + **chủ đề màu** (xem [mục 6](#theme)).
- Nút **Refresh** (chụp lại ảnh + gọi lại status, khoá 10s).
- Phím tắt: `/` focus ô search, `Esc` xoá search.
- Tự refresh mỗi 60s; tạm dừng khi tab trình duyệt bị ẩn.

### Favorites
- Khung cùng kiểu khung phòng ban, tiêu đề **★ Favorites** (sao vàng) + số site.
- **Chỉ gồm site gắn sao ★** — bấm ☆ trên bất kỳ card nào để thêm, bấm ★ để gỡ. Luôn hiện (kể cả offline), không giới hạn, **không hết hạn** (lưu `itpro.starred`). Chưa gắn sao site nào → ẩn khung.
- Dữ liệu theo **từng trình duyệt** (localStorage), không đồng bộ giữa máy/người dùng.
- Mỗi ô **chính là `WebsiteCard`** (giống hệt card trong lưới). Không đủ chỗ → cuộn ngang.
- **Kéo thả để đổi thứ tự** (`_FavSlot`: `Draggable` + `DragTarget`): nhấn giữ card → kéo → thả lên ô khác. Kéo sang trái = chèn trước, sang phải = chèn sau. Thứ tự lưu ở `itpro.favOrder`.

### Thêm website · Đăng nhập · Duyệt
- **Đăng nhập** = mã NV + mật khẩu (bảng `HSE_Patrol_Account`). FE gọi `POST /api/auth/login` của dev_manager_be; BE kiểm mật khẩu, tạo session trong `F2_ProductionControl_Session` (DB `F2Database`, BE kết nối KVH → truy vấn chéo DB, đổi bằng `app.auth-db`) → trả token + user. Vai trò lấy từ quyền app `ITPRO`: **admin = IT** (K Common / PE IT), còn lại = người dùng.
- **Địa chỉ BE tự chọn** (`resolveApiBase()` trong [`website_service.dart`](lib/services/website_service.dart)) — không cần sửa code khi đổi dev ↔ server:

  | Mở dashboard ở | BE dùng |
  |---|---|
  | `localhost` / `127.0.0.1` (flutter run) | `http://localhost:9999` (BE máy dev) |
  | địa chỉ khác (server 192.168.122.16, …) | `http://192.168.122.16:9095` |
  | có `--dart-define=API_BASE=…` | địa chỉ đó (vd. chạy FE ở máy dev nhưng dùng BE server) |

  VS Code: chọn cấu hình chạy *FE · BE local* hoặc *FE · BE server* trong [`.vscode/launch.json`](.vscode/launch.json).
- **Nút `+ Thêm website`** (nút đặc duy nhất ở header; màn < 900px nằm ở thanh trên cạnh logo). Chưa đăng nhập → mở dialog đăng nhập trước.
- **Form** ([`upload_dialog.dart`](lib/widgets/upload_dialog.dart)): URL (tự thêm `http://`, bỏ `/` cuối, báo trùng) → Tên (tự gợi ý từ title trang) + Phòng ban → **Ảnh xem trước** (tuỳ chọn, PNG/JPG/WebP, không giới hạn dung lượng — tự thu nhỏ còn 1280px rồi gửi lên BE; **bỏ trống → tự chụp màn hình**) → **Ai có thể xem?**

  | | Ai xem | Người thường thêm | IT thêm |
  |---|---|---|---|
  | **Public** | Mọi người, không cần đăng nhập | **Chờ IT duyệt** | Hiện ngay |
  | **Private** | Chỉ người thêm + IT (phải đăng nhập) | Hiện ngay, có 🔒 | Hiện ngay |

  Người thường sửa site Public / đổi sang Public → quay về chờ duyệt. Lỗi từ BE (trùng URL, hết phiên…) hiện ngay trong form.
- **Avatar** (góc phải): menu *Website của tôi* · *Duyệt website* (IT) · *Đăng xuất*. Chấm vàng = có site chờ duyệt (IT), chấm đỏ = site của bạn bị từ chối.
- **Website của tôi** ([`my_sites_panel.dart`](lib/widgets/my_sites_panel.dart)): lọc Tất cả / Chờ duyệt / Đang hiển thị / Bị từ chối; bị từ chối hiện lý do + *Sửa & gửi lại*; rút lại / gỡ = xoá mềm, có *Hoàn tác* (`POST /restore`).
- **Duyệt website** (IT, [`review_panel.dart`](lib/widgets/review_panel.dart)): hàng chờ (gửi sớm nhất trước); *Phê duyệt* / *Từ chối* (bắt buộc lý do); tab *Đã xử lý*; *Hoàn tác* = đưa về hàng chờ (`POST /reopen`).
- **API** (dev_manager_be, cần `Authorization: Bearer <token>`; quyền kiểm ở BE):

  | Method | Path | Dùng cho |
  |---|---|---|
  | GET | `/api/auth/me` | User + `role: admin\|user` |
  | GET | `/api/websites` · `/status` | Token tuỳ chọn: BE tự lọc site Private theo người xem |
  | GET | `/api/submissions/mine` | Site của tôi |
  | POST · PUT · DELETE | `/api/submissions` · `/{id}` | Thêm `{name,url,department,visibility,note,previewImage?,previewUrl?}` · sửa · xoá mềm |
  | POST | `/api/submissions/{id}/restore` | Hoàn tác xoá |
  | GET | `/api/submissions?status=pending\|reviewed` | Hàng chờ / đã xử lý (IT) |
  | POST | `/api/submissions/{id}/approve` · `/reject {reason}` · `/reopen` | Duyệt / từ chối / hoàn tác (IT) |

### Lưới card (nhóm theo phòng ban)
- Mỗi phòng ban là **một khung**: không màu, chỉ **viền đen (Light) / trắng (Dark)**, bo 16px.
- Tiêu đề khung: `KVH  ● 3/3` — chấm xanh nếu tất cả online, đỏ nếu có site offline (chi tiết ở tooltip).
- **Xếp gọn (first-fit):** nhóm nhỏ (1–2 site) tự lấp chỗ trống cạnh nhóm khác → hầu hết không phải cuộn. Cột card luôn thẳng hàng.
- **Không lệch:** khung cùng hàng cao bằng nhau; card cùng hàng cao bằng nhau; khung ảnh preview luôn bám đáy card (tên/host dài 2 dòng không đẩy lệch ảnh).
- Thứ tự: KVH → PRO → HR → IT → MA → PC → TE → WH; trong nhóm: **offline lên đầu**, rồi theo tên.
- Banner đỏ phía trên lưới liệt kê site offline của phòng ban đang chọn.

### Card site (tối giản: tên · địa chỉ · preview)
- **Hàng trên:** icon (44px, favicon hoặc glyph Lucide) · **tên** · **chấm trạng thái** · host (mono, bỏ `http(s)://`) · 3 nút icon: **☆/★ gắn sao** (ghim lên Frequently visited), mở tab mới, Copy URL (đổi ✓ 1.4s).
- **Bên dưới: ảnh preview 16:9 luôn hiện**, nằm trong khung "cửa sổ trình duyệt" (`ScreenFrame`: viền, bo 8, thanh 3 chấm) trên mọi card (ảnh chụp từ BE; site offline → ảnh xám). Bấm ảnh = mở site (tab mới + ghi lượt).
  Chưa có ảnh chụp → hình placeholder + nút *Open live* (dialog xem live).
- Trạng thái chỉ là **1 dấu chấm**, chi tiết ở tooltip:
  xanh `Online · 5 ms` (< 100ms) · cam `Slow · 342 ms` / `Login required` / `Checking…` · đỏ `Offline` (viền card đỏ) · xám `Not checked`.
- Chứng chỉ tự ký: icon khiên cam cạnh chấm, tooltip *"Chứng chỉ tự ký – trình duyệt sẽ cảnh báo khi mở"* (vẫn tính là online).
- Không hiển thị phòng ban / `type` trên card (`type` chỉ dùng chọn hình placeholder).

### Sidebar
- Logo IT PRO, **All sites**, danh sách **DEPARTMENTS** (ô viết tắt màu phòng ban, số site, viên đỏ `↓n` nếu có offline), **System health x/y** + thanh tiến độ.
- Mục đang chọn: nền đặc **màu nhấn của chủ đề** (`brand`, Graphite = vàng) + chữ `onBrand` + bóng nhẹ.
- **Thu gọn/mở rộng** (nút `«` / `»`): 232px ↔ 64px, có animation, nhớ trạng thái. Khi thu gọn: chỉ còn ô viết tắt + tooltip.
- Màn < 900px: sidebar chuyển thành thanh ngang phía trên (logo + health + chip phòng ban).

---

<a id="theme"></a>

## 6. Theme Sáng/Tối, chủ đề màu & rèm cửa

### Chọn giao diện

Nút **Giao diện** ở header → popover ([`theme_picker.dart`](lib/widgets/theme_picker.dart)):

- **Sáng | Tối** — mặc định theo hệ điều hành; bấm → nhớ lựa chọn (`dash.themeMode`), đổi có hiệu ứng rèm.
- **Chủ đề màu** — lưới 2 cột, mỗi ô có "cửa sổ thu nhỏ" vẽ bằng màu chủ đề. Bấm = đổi ngay (popover vẫn mở để thử tiếp), nhớ lựa chọn (`dash.palette`).

| Chủ đề | Lĩnh vực | Màu nhấn | | Chủ đề | Lĩnh vực | Màu nhấn |
|---|---|---|---|---|---|---|
| Graphite | Mặc định | `#FFC93C` | | Steel | Xưởng | `#0284C7` |
| Indigo | IT | `#4F46E5` | | Navy | KVH | `#1D4ED8` |
| Teal | MA | `#0D9488` | | Plum | HR | `#7C3AED` |
| Forest | PC | `#059669` | | Rose | TE | `#BE185D` |
| Copper | Product | `#C2410C` | | Bronze | Văn phòng | `#A16207` |

Nguyên tắc "sạch & tinh tế":

- Nền / viền / chữ chỉ **ám rất nhẹ** sắc độ chủ đề (HSL độ bão hoà thấp).
- Màu nhấn chỉ ở vài điểm: mục sidebar đang chọn, viền tour, vùng bôi chữ, chấm trên nút Giao diện.
- Nút chính (`ink`, vd. *Thêm website*) = **tông rất đậm** của màu nhấn (Sáng) / **tông rất nhạt** (Tối) thay cho đen/trắng thuần.
- Màu trạng thái (`StatusTone`) và màu phòng ban **không đổi** theo chủ đề.

Code ([`dash_theme.dart`](lib/theme/dash_theme.dart)):

- `DashPalette` (id, name, scope, light, dark). Graphite = bảng `DashColors.light/dark` viết tay; các chủ đề khác sinh bằng `DashColors.tinted(hue, brand, tint)`.
- **Thêm chủ đề:** thêm 1 dòng `DashPalette.tinted(...)` vào `DashPalette.all` (`hue` = sắc độ nền, `tint` = độ ám, `brand` = màu nhấn).
- `ThemeController.mode` + `ThemeController.palette`; `main.dart` dựng & cache `ThemeData` theo (chủ đề, sáng/tối).
- Đổi chủ đề **không dùng rèm**: bật `Motion.instant` trong đúng frame đổi màu để tránh hàng trăm animation chạy cùng lúc.

### Token màu
Mọi màu lấy từ theme, **không ghi cứng mã màu trong widget**:

| Nhóm | Truy cập | Gồm |
|---|---|---|
| `DashColors` | `context.dash` | `bg`, `surface`, `surface2`, `border`, `text`, `muted`, `textSoft`, `faint`, `hostText`, `ink`/`onInk` (nút chính), `navActive`, `brand`/`onBrand` (màu nhấn chủ đề) |
| `StatusTone` | `context.tone` | `okFg/okBg`, `slowFg/slowBg`, `offFg/offBg/offBorder`, `bannerBg/bannerText`, `idleFg/idleBg`, `dotOk/dotBad` |
| Màu phòng ban | `context.dept('KVH')` | `fg`, `bg` — Dark tự sáng chữ ~40%, nền = màu gốc 20% alpha |

Bảng Dark (Graphite): trung tính (nền `#0D1015`, card `#161A21`, viền `#2A303A`, chữ `#E8EAEE`), chip trạng thái dùng nền = màu chữ ~12% alpha.

Thêm màu mới → thêm field vào `DashColors`/`StatusTone` (cả `light`, `dark`, `DashColors.tinted`, `copyWith`, `lerp`).

### Hiệu ứng rèm cửa — [`theme_curtain.dart`](lib/widgets/theme_curtain.dart)

Đặt trong `MaterialApp.builder`; nút Sáng/Tối trong popover gọi `ThemeCurtain.of(context)?.toggle()`. Màu nền rèm lấy theo chủ đề đang dùng.

| Nhịp | Thời gian | Diễn biến |
|---|---|---|
| 1. Khép rèm | 280ms | 2 tấm rèm **màu nền theme hiện tại** trượt từ 2 bên vào giữa — bắt đầu ngay khi bấm |
| 2. Đổi màu | 220ms | Rèm kín → đổi theme **ngầm phía sau**; màu rèm chuyển **dần** nền cũ → nền mới |
| 3. Mở rèm | 340ms | Rèm trượt ra, lộ theme mới |

Thiết kế có chủ đích:
- **Không chụp màn hình** (`toImage`) — trên Flutter web CanvasKit việc chụp gây nháy 1 frame + trễ lúc bấm.
- **Không có bước nhảy độ sáng**: rèm khép cùng màu nền cũ, đổi màu từ từ khi kín, mở ra cùng màu nền mới → không chớp sáng/tối.
- Frame rebuild nặng (đổi toàn bộ màu) **nằm sau rèm kín** → người dùng không thấy giật.
- `Motion.instant = true` trong đúng frame đổi theme: các `AnimatedContainer`… đổi màu ngay thay vì tự animate ngầm 200ms phía sau rèm.
- Chặn click khi đang đổi; người dùng bật **giảm chuyển động** → đổi ngay, không rèm.
- `themeAnimationDuration: Duration.zero` — **không** để `MaterialApp` tự lerp `ThemeData` (gây rebuild toàn trang mỗi frame).

Chỉnh tốc độ: hằng `_close`, `_morph`, `_open` trong `ThemeCurtainState`.

---

## 7. Màu, font, icon

### Màu phòng ban

> **Hiện KHÔNG dùng trên UI** (khung, card, icon, sidebar đều trung tính đen/trắng/xám).
> Bảng dưới chỉ còn quyết định **thứ tự** phòng ban (`deptRank`); giữ lại để bật lại khi cần.

(Light: fg / bg)

| | fg | bg | | fg | bg |
|---|---|---|---|---|---|
| KVH | `#1D4ED8` | `#E8EEFD` | MA | `#0F766E` | `#E2F4F1` |
| PRO | `#C2410C` | `#FDEEE4` | PC | `#15803D` | `#E4F4E9` |
| HR | `#7C3AED` | `#F1EAFE` | TE | `#BE185D` | `#FCE7F1` |
| IT | `#4338CA` | `#E8E8FB` | WH | `#475569` | `#EDF0F4` |

Phòng ban khác → dùng màu WH. Alias: `PRODUCTION` → PRO, `WAREHOUSE` → WH.
Vàng `#FFC93C` (`Brand.yellow`): màu nhấn của chủ đề Graphite, sao ★ Favorites, badge admin. Mục đang chọn dùng `c.brand` (đổi theo chủ đề).

### Font (`google_fonts`, preload lúc khởi động)
- **Inter** — nội dung · **Space Grotesk** — tiêu đề/số liệu (`displayText()`) · **JetBrains Mono** — URL/host (`monoText()`).
- Font tải từ Google lúc chạy → máy không có internet sẽ dùng font hệ thống.

<a id="icon"></a>
### Icon — Lucide (`lucide_icons_flutter`)
Toàn bộ icon dùng **Lucide** (nét mảnh, đồng bộ). Không dùng `Icons.*` của Material trong dashboard.

Icon site — field `icon` trong config, hoặc tự đoán theo tên site, không khớp → `globe`:

| Site | `icon` | | Site | `icon` |
|---|---|---|---|---|
| Cost Monitoring | `bar-chart` | | HR | `users` |
| Fixed Asset | `package` | | MA Monitoring | `monitor` |
| HeatGuide | `flame` | | Packing PO | `clipboard-list` |
| HeatPress | `layers-2` / `press` | | TE | `wrench` |
| Molybden | `layers` | | KVH PJ | `folder` |
| Utility | `zap` | | S-Patrol | `shield-check` |
| Follow Sale Press | `trending-up` | | Warehouse | `warehouse` |
| Production Control | `factory` | | *(khác)* | `globe` |

Thêm icon: sửa `kSiteIcons` (và `_byName` nếu muốn tự đoán) trong [`site_icons.dart`](lib/widgets/site_icons.dart).

**Favicon:** `SiteIcon` hiện glyph ngay, tải favicon nền; `200` → thay bằng ảnh, `204`/lỗi → giữ glyph (ghi nhớ trong phiên, không gọi lại).

---

## 8. Dữ liệu lưu ở trình duyệt

| Key (localStorage) | Nội dung |
|---|---|
| `itpro.visits` | `{ siteId: [timestamp ms…] }`, giữ 30 ngày — đếm lượt mở (hiện không hiển thị) |
| `itpro.sidebarCollapsed` | `'1'` / `'0'` |
| `itpro.showPreview` | `'1'` / `'0'` — hiện/ẩn preview mọi card (mặc định hiện) |
| `itpro.favOrder` | `[siteId, …]` — thứ tự kéo thả của Favorites |
| `itpro.starred` | `[siteId, …]` — site gắn sao (hiện ở Favorites, không hết hạn) |
| `itpro.auth` | Token đăng nhập + tên / vai trò hiển thị (**không** lưu mật khẩu). Vai trò được xác nhận lại qua `/api/auth/me` mỗi lần mở trang |
| `flutter.dash.themeMode` | `light` / `dark` (không có = theo hệ điều hành) |
| `flutter.dash.palette` | id chủ đề màu: `graphite`, `it`, `ma`, `pc`, `product`, `factory`, `kvh`, `hr`, `te`, `classic` (không có = Graphite) |
| `flutter.dash.lastSeen.v2` | Lần cuối mỗi site online |

(Key có tiền tố `flutter.` do `shared_preferences` thêm vào.)

---

## 9. Hiệu năng — những điều KHÔNG nên làm

Rút ra khi tối ưu lag đổi phòng ban / đổi theme:

| Đừng | Vì sao | Thay bằng |
|---|---|---|
| `IntrinsicHeight` + widget đổi cỡ động (`AnimatedSize`) hoặc `LayoutBuilder` bên trong | **Overflow** (ước lượng ≠ cỡ thật) / lỗi intrinsic | Hiện chỉ dùng `IntrinsicHeight` để các khung & card cùng hàng cao bằng nhau — card **không** được chứa `AnimatedSize`/`LayoutBuilder` |
| `RenderRepaintBoundary.toImage()` để làm hiệu ứng | Trên web gây nháy 1 frame + trễ | Vẽ hình đơn giản (`CustomPainter`) |
| Animate `ThemeData` (`themeAnimationDuration`) | Rebuild + layout toàn trang mỗi frame | Đổi tức thì, che bằng rèm |
| `WebHtmlElementStrategy.fallback` cho icon nhỏ | Mỗi icon thành 1 platform view `<img>` → rất nặng | `.never` (+ CORS ở BE) |
| `BoxShadow` trong suốt luôn bật | Vẫn tốn 1 lượt blur | Chỉ thêm shadow khi hover |
| Gọi `GoogleFonts.*()` trong mỗi `build` | Tra font + đăng ký load hàng trăm lần | `displayText()` / `monoText()` (đã cache) |
| `height` cố định cho widget có nội dung thay đổi (skeleton) | Overflow khi đổi cỡ icon/font | `mainAxisSize: MainAxisSize.min` |
| `setState` / `InkWell.onHover` để đổi nền khi hover | Mỗi lần chuột vào/ra rebuild cả mục (~17ms ở debug) | `HoverSurface` ([`dash_ui.dart`](lib/widgets/dash_ui.dart)) cho card, nút, ô Frequently visited; `_HoverTile` cho sidebar — `ValueNotifier` + `CustomPainter(repaint:)` → hover chỉ repaint |

Card bọc `RepaintBoundary` → hover 1 card không repaint cả lưới.

---

## 10. Lưu ý & việc còn tồn đọng

- [ ] **Gỡ khối debug** trong [`main.dart`](lib/main.dart): `FlutterError.onError = … forceReport: true` (in đầy đủ mọi lỗi, chỉ chạy ở debug).
- [ ] Màn trắng loé lên khi **tải lại trang** ở Dark (trình duyệt hiện nền trắng trước khi Flutter tải xong) — có thể sửa bằng nền tối trong `web/index.html`.
- [ ] Dialog Preview chưa rà kỹ ở Dark.
- [ ] Xoá các widget cũ không dùng (xem [mục 4](#4-cấu-trúc-thư-mục)).
- Nếu bản **release** vẫn lag: Chrome DevTools → **Performance** → ghi lại thao tác → xem frame dài.
