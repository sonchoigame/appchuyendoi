# NSMOD 3105 Converter — iOS

Ứng dụng SwiftUI chuyển đổi Bundle ID bên trong tệp patch `.3105`, giữ nguyên `Documents/`, `Library/` và dữ liệu file. Không cần ZIP.

## Chức năng
- Mở file .3105 từ ứng dụng Tệp, nhập mật khẩu gốc của member.
- Đọc danh sách Bundle ID (Application), chọn ID cũ và nhập ID mới.
- Đóng gói lại đúng schema 3105PATCH 1–9, mật khẩu file xuất luôn là `nsmod`.
- Kiểm tra AES-256-GCM / PBKDF2-HMAC-SHA256 và SHA-256 từng file trước và sau khi đóng gói.
- Không thay đổi App Group mappings, relativePath hoặc replacementData.
- Màn hình Trang chủ với Web Crack, Telegram, TikTok; phần Converter là chức năng chính.
- Popup Telegram xuất hiện mỗi lần mở app: lần đầu phải bấm link Telegram để mở khóa nút Đóng. App chỉ xác nhận thao tác bấm link, **không xác minh việc tham gia kênh**.
- Không tự vẽ status bar, pin, sóng hoặc Dynamic Island: sử dụng giao diện hệ thống iPhone.
- Nút "Xong" trên bàn phím và chạm vào khoảng trống để đóng bàn phím.
- Cài đặt tối giản: "Được phát triển bởi NSMOD".

## Link chính thức
- Telegram: https://t.me/sonchoigame23
- TikTok: https://www.tiktok.com/@pettersiuto
- Web Crack: https://nsmod.github.io/nsmodcrack

## Build iOS / IPA
Dùng GitHub Actions: **Actions → Build unsigned IPA → Run workflow**.
Workflow chạy trên macOS, cài xcodegen, tạo project Xcode và đóng gói `NSMOD3105.ipa` **chưa ký** (unsigned). Sau đó có thể ký bằng chứng chỉ hợp lệ với ESign hoặc công cụ khác. IPA unsigned không thể cài trực tiếp.

Trên macOS: `brew install xcodegen`; `xcodegen generate`; mở `NSMOD3105.xcodeproj`.

## Bảo mật và giới hạn
Xử lý file và mật khẩu ở thiết bị, không upload server, không lưu mật khẩu gốc. Không đưa file patch cá nhân lên repository. Tối đa 512 MiB để hạn chế áp lực bộ nhớ. Chỉ thay bundle ID ứng dụng được chọn; metadata khác và dữ liệu file giữ nguyên về mặt ngữ nghĩa. Yêu cầu file gốc có mật khẩu đúng; tool không vượt qua mã hóa.

> Mã nguồn sẵn sàng cho build trên macOS/GitHub Actions. Cần kiểm tra kết quả build và thử thực tế trên iPhone trước khi công bố IPA ổn định.
