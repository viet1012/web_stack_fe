# Prompt cho Backend — Đăng nhập · Thêm website · Duyệt website

> Copy toàn bộ phần dưới đường kẻ và dán cho dev BE / AI agent đang làm repo backend.
>
> **Trạng thái (2026-11-27): đã làm trong dev_manager_be.** Khác contract dưới đây:
> - **Auth**: KHÔNG làm bảng user / login riêng. Login = backlog-be (`/api/production-control/auth/login`),
>   dev_manager_be chỉ kiểm token trên `F2_ProductionControl_Session` + quyền app `ITPRO` (admin = IT).
>   Chỉ có `GET /api/auth/me`.
> - **Admin (IT) thêm site Public → `live` ngay**, không cần duyệt.
> - **Ảnh**: không có `/api/uploads/preview` (POST); FE gửi `previewImage` (data URL) trong body submission,
>   giữ ảnh cũ bằng `previewUrl`. Chỉ có `GET /api/uploads/preview/{file}`. `previewUrl` là đường dẫn tương đối.
> - **Hoàn tác**: `POST /{id}/restore` = huỷ xoá (xoá mềm); `POST /{id}/reopen` (IT) = huỷ duyệt / từ chối.
> - Site người dùng nằm chung bảng `F2_websites` (cột mới: `src/main/resources/sql/itpro_website_submission.sql`).

---

## Bối cảnh

Repo backend này phục vụ **IT PRO Website Dashboard** (Flutter Web, repo FE riêng). Dashboard liệt kê các website nội bộ theo phòng ban, kiểm tra online/offline và chụp ảnh màn hình.
Các API **đang có và FE đang dùng — KHÔNG được làm thay đổi response hiện tại** (chỉ được thêm field):

- `GET /api/websites`: danh sách site `{ id, name, url, departmentName, type, status, icon, iconUrl, certWarning }`
- `GET /api/websites/status`: trạng thái theo id `{ online, authRequired, latencyMs, certWarning }`
- `GET /api/websites/{id}/favicon`: `200` trả ảnh, `204` nếu không có
- `GET /api/screenshot?url=&t=` · `GET /api/screenshot/meta?url=` · `POST /api/screenshot/refresh[?url=]`

FE đã làm xong UI (đang chạy bằng dữ liệu giả) cho tính năng mới: **người dùng tự đăng ký website (URL) lên dashboard**. Nhiệm vụ của bạn là làm backend cho tính năng này theo đúng contract bên dưới.

**Trước khi code:** đọc cấu trúc repo, **giữ nguyên stack / framework / DB / cách tổ chức code hiện có**. Nếu công ty đã có hệ thống đăng nhập tập trung (AD/LDAP/SSO), **hỏi lại trước khi tự làm bảng user riêng**.

## Nghiệp vụ

| | Ai xem được | Cần duyệt? | Trạng thái khi tạo |
|---|---|---|---|
| **Public** | Mọi người, **không cần đăng nhập** | **Có — admin phê duyệt** | `pending` |
| **Private** | **Chỉ người tạo + admin** (phải đăng nhập) | Không | `live` ngay |

- Phải đăng nhập mới được thêm website. Có 2 vai trò: `user` và `admin`.
- Trạng thái: `pending` (chờ duyệt) → `live` (đang hiển thị) hoặc `rejected` (bị từ chối, **bắt buộc có lý do**).
- Người tạo được **sửa** site của mình. Sửa site Public, hoặc đổi Private → Public, thì site **quay về `pending`** và xoá thông tin duyệt cũ. Sửa site Private thì site vẫn `live`.
- Người tạo được **xoá** site của mình: rút lại khi đang `pending`, hoặc gỡ khi đã `live` / `rejected`. Admin xoá được mọi site.
- Site `pending` / `rejected` **không bao giờ** hiện trên dashboard, kể cả với người tạo. Người tạo chỉ thấy chúng trong mục "Website của tôi".
- Ảnh xem trước là **tuỳ chọn**. Không có ảnh thì site được tự chụp màn hình như site hệ thống.

## 1. Auth

| Method | Path | Body / Kết quả |
|---|---|---|
| POST | `/api/auth/login` | `{ username, password }` → `200 { token, expiresAt, user }`; sai → `401 { code:"INVALID_CREDENTIALS", message }` |
| GET | `/api/auth/me` | Header `Authorization: Bearer <token>` → `{ username, displayName, role: "user"\|"admin" }` |
| POST | `/api/auth/logout` | Huỷ token (nếu stack hỗ trợ), trả `204` |

- Dùng **Bearer token** (FE khác origin; cookie cross-site phức tạp hơn). Token hết hạn sau ~8 giờ.
- Mật khẩu hash bằng bcrypt/argon2. Secret ký token lấy từ **biến môi trường**, không hard-code, không commit.
- Giới hạn số lần đăng nhập sai (rate limit theo IP + username).

## 2. Mở rộng API cũ (chỉ THÊM field, không đổi field cũ)

**`GET /api/websites`**: token là **tuỳ chọn**:

- Không có token: site hệ thống + site người dùng có `visibility=public` và `status=live`
- Có token (user): như trên + site **Private** của chính user đó
- Có token (admin): như trên + **mọi** site Private
- Mỗi phần tử thêm 3 field: `visibility: "public"|"private"` (site hệ thống = `"public"`), `owner: string|null` (site hệ thống = `null`), `previewUrl: string|null` (URL tuyệt đối tới ảnh tự tải lên)
- Id của site người dùng **không được trùng** id site hệ thống

**`GET /api/websites/status`**: trả cả site người dùng, **cùng quy tắc lọc** như trên (không lộ site Private cho người không có quyền).

**Screenshot / favicon:** phải hoạt động với URL của site người dùng (`live`). Bỏ qua việc chụp nếu site đã có `previewUrl`.

## 3. Submissions (site người dùng thêm)

Đối tượng `Submission` (JSON, thời gian dạng **ISO-8601 UTC**):

```json
{
  "id": 101,
  "name": "Quản lý khuôn",
  "url": "http://192.168.122.40:8080",
  "department": "PRO",
  "note": "Theo dõi lịch bảo trì khuôn",
  "visibility": "public",
  "status": "pending",
  "owner": "lan.nguyen",
  "createdAt": "2026-11-27T02:15:00Z",
  "reviewedAt": null,
  "reviewedBy": null,
  "rejectReason": null,
  "previewUrl": null
}
```

| Method | Path | Quyền | Mô tả |
|---|---|---|---|
| GET | `/api/submissions/mine` | user | Site của tôi, mới nhất trước |
| POST | `/api/submissions` | user | Tạo mới. Body `{ name, url, department, visibility, note?, previewUrl? }` → `201 Submission` |
| PUT | `/api/submissions/{id}` | chủ sở hữu | Sửa (cùng body như POST). Áp dụng quy tắc quay về `pending` ở trên → `200 Submission` |
| DELETE | `/api/submissions/{id}` | chủ sở hữu / admin | → `204` |
| GET | `/api/submissions?status=pending` | admin | Hàng chờ, **cũ nhất trước** |
| GET | `/api/submissions?status=reviewed` | admin | Đã xử lý (`live`/`rejected` có `reviewedAt`), mới xử lý trước |
| POST | `/api/submissions/{id}/approve` | admin | Chỉ khi đang `pending` → `live`, ghi `reviewedAt/By` → `200 Submission` |
| POST | `/api/submissions/{id}/reject` | admin | Body `{ reason }` (bắt buộc) → `rejected` → `200 Submission` |
| POST | `/api/submissions/{id}/restore` | chủ sở hữu / admin | **Hoàn tác** thao tác ngay trước đó (FE có nút "Hoàn tác" trong ~5 giây sau duyệt / từ chối / xoá). Có thể làm bằng soft-delete + lưu trạng thái trước. Nếu khó thì báo lại, FE sẽ bỏ nút này |

**Validate (trả `400` kèm message tiếng Việt):**

- `url`: chỉ chấp nhận `http`/`https` và phải có host. Tự thêm `http://` nếu thiếu, bỏ `/` cuối. **So trùng** (không phân biệt hoa/thường, bỏ scheme) với site hệ thống và mọi submission chưa bị `rejected`. Trùng thì trả `409 { code:"DUPLICATE_URL", message:"Đã có trên dashboard: <tên>" }`.
- `name`: bắt buộc, ≤ 40 ký tự. `note`: ≤ 200. `reason`: bắt buộc, ≤ 160.
- `department`: nằm trong danh sách phòng ban hợp lệ (`KVH, PRO, HR, IT, MA, PC, TE, WH` + phòng ban đang có trong DB).
- `visibility` ∈ `public|private`.

## 4. Upload ảnh xem trước

| Method | Path | Quyền | Mô tả |
|---|---|---|---|
| POST | `/api/uploads/preview` | user | `multipart/form-data`, field `file` → `201 { url }` |
| GET | `/api/uploads/preview/{file}` | công khai | Trả ảnh (có CORS, cache dài hạn) |

- Chỉ nhận PNG / JPEG / WebP, **kiểm tra bằng magic bytes** (không tin `Content-Type` hay đuôi file). Dung lượng ≤ 5 MB.
- **Encode lại** thành JPEG (bỏ metadata EXIF), cạnh dài tối đa 1280 px. Tên file ngẫu nhiên (UUID); không dùng tên file gốc làm đường dẫn.
- Dọn ảnh mồ côi (đã upload nhưng không gắn với submission nào sau 24 giờ).

## 5. Bảo mật (bắt buộc)

- **Mọi kiểm tra quyền làm ở BE.** FE chỉ ẩn/hiện giao diện. Test kỹ các trường hợp: user A gọi PUT/DELETE vào site của user B → `403`; user thường gọi approve/reject → `403`; không có token mà xem site Private (qua `/api/websites`, `/status`, `/screenshot`) → không thấy.
- **SSRF**: BE sẽ tự truy cập URL do người dùng nhập (kiểm tra status, chụp màn hình, lấy favicon):
  - Chỉ truy cập URL **đã có trong DB** (site hệ thống hoặc submission đang `live`). Không chụp URL tuỳ ý từ query string.
  - Chặn `localhost`, `127.0.0.0/8`, `169.254.0.0/16` (metadata), `::1`, và chính host/port của backend. Kiểm tra lại **sau khi resolve DNS và sau mỗi redirect**.
  - Đặt timeout, giới hạn kích thước response, giới hạn số redirect.
- Rate limit: tạo submission (vd. ≤ 20/giờ/user), upload ảnh, đăng nhập.
- Ghi log thao tác duyệt / từ chối / xoá (ai, lúc nào, site nào).

## 6. Quy ước chung

- Lỗi: `{ code: string, message: string }`. `message` là câu tiếng Việt hiển thị thẳng cho người dùng. HTTP status: `400 / 401 / 403 / 404 / 409 / 429`.
- CORS: cho phép origin của FE, header `Authorization` + `Content-Type`, các method `GET/POST/PUT/DELETE`. Áp dụng cho cả `/api/uploads/preview/*`.
- Có migration DB (bảng user nếu cần, bảng submissions, bảng ảnh upload).

## Kết quả cần bàn giao

1. Code + migration + seed: 1 tài khoản admin và 1 user thử (mật khẩu đọc từ biến môi trường hoặc in ra khi seed, **không commit vào repo**).
2. Test tự động cho: phân quyền (bảng ở mục 5), luồng `pending → live/rejected`, sửa thì quay về `pending`, chặn trùng URL, lọc Private trong `/api/websites`.
3. Cập nhật tài liệu API (README / OpenAPI) kèm ví dụ request/response.
4. Ghi rõ những điểm làm **khác** contract này (nếu có) để FE sửa theo.
