# NotchFlow: kế hoạch cải thiện (bản nháp để chủ dự án duyệt)

Ngày 2026-11-10. Viết từ phía spec. Kế hoạch dựa trên: code app cũ (`notch`), app mới
(`notchflow-clean`, `main`), và Canopy 2 (bản cài trong `/Applications`; chỉ xem metadata,
danh sách tài nguyên, chuỗi tiếng Anh và trang getcanopy.pro).

**Quy tắc khi học từ Canopy:** chỉ lấy *ý tưởng tính năng*. Không chép code, chữ, âm thanh,
video, icon, hay cách trình bày đặc trưng của họ. Canopy là phần mềm thương mại.

---

## 1. Học được gì từ app cũ

### Cách một tính năng được dựng (app cũ ↔ app mới)
| Lớp | App cũ | App mới | Nhận xét |
|---|---|---|---|
| Đọc hệ thống | `Services/*` | `*Probes`, `*Live*` (sau protocol) | App mới tốt hơn: có fake, test được |
| Biến đổi thành sự kiện | `ViewModels/*` | `*Conductor` | Tương đương |
| Gửi vào notch | `EventHandlers/*` → `notchViewModel.send(...)` | Conductor → `FlowStage.show/remove` | Tương đương |
| Mô tả hình dạng | `Content`: kích thước compact / island / expanded, bo góc, màu viền | `FlowCard` + `FlowCardCompact/Expanded` | Đã đủ: có rộng và cao theo từng chế độ, bo góc riêng |
| Độ ưu tiên | `NotchContentRegistry` ở một chỗ | `FlowRank` | Tương đương |
| Cài đặt | `SettingsViewModel` làm trung tâm | `*Preferences` theo từng tính năng | App mới tách tốt hơn |

### Liên kết giữa các tính năng (phải giữ)
- **Focus** ẩn các thông báo khác và Lịch. Đã có.
- **Lock screen ↔ Media ↔ Mirror:** khoá máy thì hiện music panel và tắt camera. Đã có;
  lỗi gắn Space vừa sửa xong.
- **Kéo file ↔ alert:** giữ alert lại trong lúc kéo. Đã có.
- **Các trang Music / Tray / Mirror:** vuốt ngang để chuyển; click notch trống thì mở trang
  mặc định. Đã có.
- **Onboarding** giữ alert lại trong lúc chạy. Đang làm (spec 15).

### Thông số giao diện chung của app cũ
- **Hoạt ảnh:** spring 0.5 s, damping 0.70 (0.75 khi mở rộng); khoảng nghỉ 0.30 s giữa hai
  nội dung. **App mới đã khớp.**
- **Lề trang:** lề trong 20 pt, khoảng cách giữa các khối 12 pt, bo góc đáy 25 pt.
- **Nút tròn trong notch:** 45 pt, nền là màu nhấn ở 30 %, thu nhỏ còn 94 % khi nhấn. Nút
  kính trên lock screen 44 pt.
- **Chữ trong thẻ cao:** tiêu đề 14 pt semibold trắng; dòng phụ 11 pt medium, xám 55 %. Lề
  notch 45 / 40 pt, island 25 / 15 pt.
- **Điểm yếu của app cũ:** các con số này nằm rải rác trong từng view. Muốn chỉnh một chỗ
  phải sửa hàng chục file. App mới cũng đang như vậy (xem P3).

---

## 2. Canopy có gì

| Nhóm | Tính năng Canopy | NotchFlow mới |
|---|---|---|
| Nhạc | Player, lời bài hát đồng bộ, ảnh bìa động, **màu theo bài hát**, nhãn Explicit, tim đổi màu theo bài | Player + lời trên lock screen; **chưa** có màu theo bài trong notch, ảnh bìa động, Explicit |
| Nhạc | Chọn nguồn: Auto / chỉ Spotify / chỉ Music | Chưa có |
| Nhạc | Nút trái tuỳ chọn; nút phải đổi loa / tai nghe | Chưa có (app cũ có sẵn phần đổi đầu ra âm thanh) |
| Nhạc | **EQ theo từng app** (bass, mid, presence); sóng âm từ âm thanh thật | Chưa có. Cần quyền ghi âm hệ thống; khó |
| Hành vi | Mở khi hover; thu khi nhạc dừng (ngay / sau một lúc / không bao giờ) | Có ẩn khi dừng; **chưa** có mở khi hover |
| Hành vi | Ẩn khi toàn màn hình; chọn màn hình nào hiện | Một phần |
| Hành vi | **Ẩn khỏi ảnh chụp và quay màn hình** | Chưa có. Dễ làm |
| Hành vi | **Hiệu chỉnh kích thước notch** bằng viền đỏ khớp notch thật | Chỉ có offset ±5 pt, không có viền hướng dẫn |
| Hành vi | Phản hồi rung (haptic) | Chưa có |
| Thông báo | AirPods (pin và âm lượng) có **video 3D riêng cho từng mẫu** | Có pin, chỉ dùng SF Symbol |
| Thông báo | Pin, độ sáng, âm lượng (icon hoặc tên), Focus | Có |
| Thông báo | Tắt từng thông báo khi đang Focus | Chưa có |
| Lock screen | Nhạc và lời bài hát, **widget Focus**, **thời tiết**, Glass Art, giữ màn hình sáng | Nhạc và lời bài hát, giữ màn hình sáng; **chưa** có Focus, thời tiết |
| Trang | **Thời tiết** (vuốt để lật giữa player và thời tiết), cần vị trí | Chưa có |
| Khác | Khay file, chạy trên màn hình ngoài và máy không notch | Có |
| Khác | Không telemetry, cập nhật tự động, license 2 máy | Sparkle và license đang làm (spec 16) |

---

## 3. Kế hoạch đề xuất (bạn chọn thứ tự)

### P0: chạy đúng trên máy thật (làm trước mọi thứ)
1. **Merge bản sửa lock screen, rồi bạn khoá máy thử.** Notch và music panel phải hiện trên
   lock screen.
2. **QA từng tính năng trên máy thật** (phase 6): lock screen, HUD, AirPods, VPN, USB,
   Timer, Lịch, chụp và quay màn hình. Lỗi tìm được sẽ sửa theo cùng quy trình
   (spec → build → review → test).
3. **Hiệu chỉnh notch** kiểu Canopy: trong Settings → Notch, hiện viền đỏ quanh hình notch
   và cho chỉnh rộng/cao từng 0.5 pt cho đến khi khớp notch thật. Notch lệch vài pt là lỗi
   dễ thấy nhất.

### P1: hiệu ứng, bố cục, nút, chữ (thấy ngay sự khác biệt)
4. **Màu theo bài hát:** lấy màu chủ đạo từ ảnh bìa cho viền, thanh tiến độ, equalizer và
   nút trong notch, như music panel trên lock screen đã làm.
5. **Bộ nút player:**
   - các nút chính 45 pt, đều nhau, tâm thẳng hàng;
   - nút phải đổi đầu ra âm thanh (loa / tai nghe / AirPods);
   - nút trái tuỳ chọn trong Settings: yêu thích, lặp, trộn bài, hoặc lời bài hát.
6. **Chuẩn hoá chữ:** 3 cỡ cho notch (tiêu đề 14 semibold; phụ 11 medium xám 55 %; số lớn
   cho đồng hồ và phần trăm). Bỏ các cỡ lẻ. Tên dài chạy chữ ở mọi nơi.
7. **Mở khi hover** (tuỳ chọn, mặc định tắt). Thu khi nhạc dừng có ba lựa chọn: ngay, sau
   N giây, không bao giờ.
8. **Ẩn khỏi ảnh chụp và quay màn hình** (tuỳ chọn, mặc định bật). Rất nhỏ.
9. **Haptic** nhẹ khi đổi trang, mở rộng, bấm nút (trackpad Force Touch).
10. **Ảnh bìa động** (phóng nhẹ và trôi màu khi đang phát) và nhãn **Explicit**.

### P2: tính năng mới học từ Canopy (cần bạn quyết)
11. **Trang Thời tiết** trong notch, thêm widget thời tiết và widget Focus trên lock screen.
    Cần quyền Vị trí và một nguồn thời tiết (Apple WeatherKit cần tài khoản developer có
    trả phí). **Cần bạn quyết.**
12. **Hoạt ảnh AirPods khi kết nối:** phải tự làm tài sản mới (3D hoặc minh hoạ). Không
    được dùng video của Canopy. **Cần bạn quyết về tài sản.**
13. **Tắt từng thông báo khi đang Focus.** Nhỏ, không cần quyết.
14. **Chọn nguồn nhạc:** Auto / Spotify / Music. Nhỏ.
15. **EQ theo từng app và sóng âm thật:** cần quyền ghi âm hệ thống và xử lý âm thanh, nặng
    và rủi ro. **Đề xuất để sau phiên bản đầu.**

### P3: cấu trúc code (để chỉnh nhanh về sau)
16. **Một file "design tokens"** cho mọi cỡ chữ, kích thước nút, lề, bo góc và spring. Mỗi
    lần bạn muốn đổi "nút to hơn" hay "chữ nhỏ lại", chỉ sửa một chỗ.
17. **Gom thư mục:** `Status/`, `HUD/`, `LockScreen/`, `Media/` vào `Features/` như Timer
    và Tray. Không đổi hành vi.

### Đang chạy song song (không cần duyệt)
- Spec 15 (Settings, tìm kiếm, onboarding) và spec 16 (license, Sparkle): đang code.
- Phase 5: icon, cờ ngôn ngữ, bản tiếng Việt cho các câu xin quyền.
- Phase 7: luật sư, ký app, feed Sparkle, đổi bundle ID. Cần bạn.

---

## 4. Cần bạn trả lời
1. **Thứ tự:** P0 → P1 → P2? Hay có mục P1/P2 nào muốn làm sớm hơn?
2. **Thời tiết (11):** làm không? Dùng WeatherKit (trả phí developer) hay một nguồn miễn phí?
3. **Hoạt ảnh AirPods (12):** tự làm tài sản 3D mới, hay chỉ dùng SF Symbol có chuyển động?
4. **EQ (15):** để sau phiên bản đầu, đồng ý không?
5. **Pin iPhone khi dùng hotspot:** đọc bản ghi không có tài liệu (nhẹ), dùng private
   framework, hay bỏ?
