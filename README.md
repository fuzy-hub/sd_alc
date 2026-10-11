# ALCWALL 3.3.0

ALCWALL là bộ công cụ AutoLISP hỗ trợ triển khai tường ALC 2D trên AutoCAD for Windows. Bản 3.3.0 được kiểm thử bằng AutoCAD 2027.

## Cài đặt

1. Giữ nguyên toàn bộ cấu trúc thư mục, đặc biệt là `ALCWALL.lsp` và thư mục `src`.
2. Trong AutoCAD, mở `OPTIONS > Files > Support File Search Path` và thêm thư mục ALCWALL.
3. Chạy `APPLOAD`, chọn `ALCWALL.lsp`. Có thể thêm tệp này vào Startup Suite nếu muốn tự động nạp.
4. Khi thấy thông báo `ALCWALL v3.3.0 modules loaded`, bộ lệnh đã sẵn sàng.

Khi cập nhật, APPLOAD lại `ALCWALL.lsp`; loader gỡ định nghĩa lệnh cũ `ALCCUT20` còn trong phiên làm việc, chỉ dùng `ALCTRIM`.

Không nạp riêng các tệp trong `src`; `ALCWALL.lsp` là loader duy nhất.

## Các lệnh

| Lệnh | Công dụng |
|---|---|
| `ALCSET`, `VVSET`, `ALCS`, `VVS`, `ALSC` | Đặt pattern, màu hatch, màu nền, tỷ lệ, góc hatch và chiều dày tường |
| `ALCWALL`, `VVWALL`, `VV` | Vẽ tường từ một mép tham chiếu |
| `ALCCENTRAL`, `VVCENTRAL`, `VVC` | Vẽ tường đối xứng qua tim |
| `ALCTRIM`, `VVTRIM` | Rút đầu tường; mặc định 20 mm, Multi (M), Length (L) |
| `ALCXTEND`, `VVXTEND` | Kéo dài đầu tường; mặc định 20 mm, Multi (M), Length (L) |
| `ALCDOOR`, `VVDOOR` | Cắt lỗ cửa trên tường ALC đã đóng |
| `ALCLT`, `VVLT` | Vẽ lanh tô, cách đường tham chiếu 50 mm |
| `ALCGT`, `VVGT` | Vẽ giằng tường, cách đường tham chiếu 50 mm |
| `ALCGTS`, `VVGTS` | Đặt chiều rộng và màu cho `ALCGT` |
| `ALCTK`, `VVTK` | Lập bảng tổng chiều dài theo layer |
| `ALCTKC`, `VVTKC` | Thống kê block cửa |
| `TKDIM` | Cộng kích thước và tạo bảng |
| `TKCOUNT` | Đánh số tuần tự có khung |
| `TKMS` | Copy TEXT/MTEXT và tự tăng hậu tố `-001` đến `-999` |
| `TKALIGN` | Căn lề trái nhiều TEXT/MTEXT theo text tham chiếu, giữ nguyên khoảng cách dọc |
| `ALCDIM`, `VVDIM` | Chọn một DIM và đặt dimstyle của DIM đó thành dimstyle hiện hành |

Tất cả lệnh `ALCxxx` có alias `VVxxx` (thay tiền tố `ALC` bằng `VV`), dùng chung chức năng và Undo. Các alias ngắn `VV`, `VVC` và lệnh `ALSC` vẫn dùng được.

Thiết lập ALC chính được lưu trong bản vẽ bằng `XRECORD`. Chiều rộng và màu giằng tường được giữ trong phiên làm việc hiện tại.

Màu nền hatch có ba chế độ: màu ACI, `None` (không có nền) và
`TrueColor RGB 255,255,255` (nền trắng thực, không phải ACI 7 thích nghi).
Mỗi lần nạp `ALCWALL.lsp`, màu nền mặc định được đặt lại thành TrueColor trắng;
lựa chọn khác trong `ALCSET` có hiệu lực trong phiên hiện tại.

## Rút đầu tường 20 mm

Chạy `ALCTRIM`, bấm biên tường hoặc hatch gần đầu cần rút. Lệnh tự chọn đầu gần điểm bấm nhất và rút vào theo độ dài đã chọn (đơn vị bản vẽ là mm). Độ dài ban đầu là 20 mm; giá trị Length gần nhất được nhớ trong phiên làm việc của bản vẽ, dùng lại khi gọi lệnh hoặc load Lisp lại. Không lưu vào DWG; phiên mới mặc định 20 mm. Nhập `L` (Length), đồng cấp với `M`, để đổi sang số dương; Enter giữ độ dài hiện tại. Có thể dùng `L` cả trước và trong Multi; độ dài mới áp dụng cho các lần cắt tiếp theo trong lượt lệnh. Mặc định cắt một tường rồi kết thúc. Nhập `M` (Multi) tại lời nhắc đầu để chọn lần lượt nhiều tường, Enter kết thúc; Undo một lần khôi phục cả lượt Multi. Hỗ trợ biên tường thẳng hoặc gấp khúc L/U do ALCWALL/ALCCENTRAL tạo, hai đầu vuông và thứ tự đỉnh còn nguyên.

Giữ polyline và hatch hiện có, cập nhật biên hatch, giữ pattern, scale, angle, màu và nền. Một lần `UNDO` khôi phục thao tác. Layer bị khóa, biên cong, hatch nhiều vòng hoặc đoạn đầu dài không quá độ dài cắt sẽ bị từ chối. Biên đã chỉnh thứ tự đỉnh hoặc cắt phức tạp có thể không được hỗ trợ. Text/DIM độc lập không tự cập nhật.

## Kéo dài đầu tường

Chạy `ALCXTEND` hoặc `VVXTEND`, bấm biên tường hoặc hatch gần đầu cần kéo. Lệnh dịch đầu gần điểm bấm nhất ra ngoài theo hướng đoạn cuối, giữ nguyên đầu còn lại. Mặc định kéo thêm 20 mm. `L` (Length) và `M` (Multi) hoạt động như `ALCTRIM`: đổi Length trước hoặc trong Multi, Enter ở Length giữ giá trị hiện tại, chọn một tường rồi kết thúc hoặc chọn nhiều tường và Enter để kết thúc Multi. Length của kéo dài được nhớ riêng với Length của rút ngắn trong phiên bản vẽ, kể cả khi load Lisp lại; không lưu vào DWG.

Giữ đối tượng biên và hatch hiện có, thuộc tính và liên kết hatch; Undo một lần khôi phục cả lượt. Hỗ trợ cùng dạng tường thẳng/L/U có hai đầu vuông và thứ tự đỉnh còn nguyên. Độ dài kéo thêm có thể lớn hơn đoạn đầu hiện có. Các giới hạn về layer khóa, biên cong, hatch nhiều vòng, biên đã sửa phức tạp và Text/DIM độc lập giống `ALCTRIM`; cần tránh kéo đầu tường gấp khúc tới mức tự giao.

## Cấu trúc

- `ALCWALL.lsp`: loader và số phiên bản.
- `src/alc-settings.lsp`: cấu hình và giao diện thiết lập.
- `src/alc-styles.lsp`: khởi tạo text/dim style còn thiếu.
- `src/alc-trim.lsp`: rút/kéo dài đầu tường với độ dài tùy chọn và cập nhật hatch.
- `src/alc-geometry.lsp`: hình học, polyline, offset và chia polygon.
- `src/alc-wall.lsp`: tường, hatch, cửa, lanh tô và giằng.
- `src/alc-schedule.lsp`: các bảng thống kê và đánh số.
- `src/alc-align.lsp`: căn chỉnh TEXT/MTEXT.
- `src/alc-commands.lsp`: các lệnh công khai, alias VV và quản lý Undo/lỗi.
- `tests`: smoke test, bộ sinh DWG và script chạy AutoCAD 2027.
- `legacy`: bản v1 nguyên khối để đối chiếu lịch sử.

## Kiểm thử

Chạy từ PowerShell:

```powershell
.\tests\run-autocad-tests.ps1 -FullAutoCAD
```

Script mở một tiến trình AutoCAD 2027 riêng và ghi nhãn phiên, PID, thời gian khởi động trong `tests/results/<session>/session.json`. Các lệnh dùng ActiveX nên cần AutoCAD đầy đủ; Core Console chỉ phù hợp kiểm tra nạp mã và XRecord. Các log ZWCAD trong bản ZIP gốc là dữ liệu lịch sử.

`ALCDOOR` chỉ thay tường cũ sau khi tạo thành công đủ hai boundary và hai hatch mới. Khi một bước thất bại, các đối tượng tạm bị xóa và tường cũ được giữ lại.

## Giới hạn hình học

- Chỉ hỗ trợ tường 2D tạo bởi các đoạn thẳng; không xử lý segment cung trong polyline.
- Các điểm được chiếu về mặt phẳng UCS hiện tại; nên tránh tường không đồng phẳng.
- Offset có thể thất bại tại góc quá gắt, đoạn quá ngắn hoặc hình tự giao.
- `ALCDOOR` cần đủ phần tường ở cả hai phía lỗ mở; cửa nằm đúng đầu mút sẽ bị từ chối để tránh tạo polygon suy biến.
- Layer chứa tường phải được mở khóa. Hatch pattern được chọn phải tồn tại trong AutoCAD.

## Tính năng 2.6.0

- Gõ `ALCS` hoặc `ALSC`, chọn `Angle` (A), nhập số độ thập phân. Góc mặc định 0°, lưu theo bản vẽ, góc âm hoặc trên 360° được chuẩn hóa. Đây là góc xoay thêm của hatch, không phải góc của mép tường. Hatch khi cắt cửa giữ góc ban đầu; lanh tô và giằng giữ thiết lập riêng.
- Gõ `ALSC`, chọn `Pattern` (P): bảng danh sách mẫu từ `acad.pat`/`acadiso.pat` có hình xem trước. Chọn mẫu rồi OK; Cancel giữ giá trị cũ. Preview minh họa mẫu ở góc hiện tại, không phản ánh tỷ lệ in. Giữ file `src/alc-patterns.dcl` cùng các module. PAT tùy chỉnh ngoài hai thư viện này chưa nằm trong bảng chọn.
- Mỗi lần load kiểm tra và chỉ tạo layer còn thiếu `0. Tuong ALC`: Blue (ACI 4), Continuous, lineweight 0.09 mm. Sau load, layer này được đặt làm current. Layer có sẵn được giữ nguyên toàn bộ thuộc tính, kể cả màu/nét/lineweight. Có thể bắt đầu vẽ trên layer này ngay sau load.

XRecord schema 4 bổ sung DXF 44 cho góc, giữ thiết lập của bản vẽ schema 2. Xem `REVIEW.txt` để biết các điểm cần cải tiến tiếp và giới hạn kiểm thử giao diện.

## Khởi tạo style — 3.2.9

Khi nạp `ALCWALL.lsp`, kiểm tra riêng từng tên layer, text style và dim style. Chỉ tạo tài nguyên chưa tồn tại; tên đã có được giữ nguyên thông số, dim style `ALC Dim TL` được bật nền chữ Background cả khi đã tồn tại; riêng `alc text note` được cập nhật font Arial (TT) và height 0.0. Sau khi kiểm tra/tạo, lập tức đặt `0. Tuong ALC`, `alc text note` và `ALC Dim TL` làm current. Dim style được Restore để áp dụng thông số đã lưu và xóa các override của dim style hiện hành trước đó.

Text style `alc text dim`: font `NGHIA5.SHX`, width factor 0.65, height 0 để dùng chiều cao của đối tượng/dim. Font cần có trong thư mục Fonts hoặc Support Path; bộ Lisp không kèm file font.

Dim style `ALC Dim TL` kế thừa ISO-25 của bản vẽ rồi đặt:

| Thuộc tính | Giá trị |
|---|---|
| Overall scale | 100.0000 |
| Text height | 3.0000 |
| Text fill | Background (DIMTFILL = 1), màu nền bản vẽ |
| Arrow size / Arrow | 1.8000 / ArchTick, cả hai đầu |
| Ext line offset / extension | 2.0000 / 1.0000 |
| Roundoff | 5.0000 |
| Fixed ext line length / enabled | 4.0000 / On |
| Large radius jog angle | 45° |
| Text offset / inside | 1.0000 / On |
| Dim line / Ext line color | 8 / 8 |
| Text color | 3 (Green) |
| Precision / Tol precision | 0 / 0 |
| Fit: text movement | 2 |
| Text style | alc text dim |

Các thông số khác giữ theo ISO-25. Nếu bản vẽ thiếu ISO-25, dùng nền ISO-25 từ template `acadiso.dwt` chuẩn AutoCAD 2027. Nếu `alc text dim` đã có thì dim style mới tham chiếu style có sẵn, không đổi font/width factor của nó.

Kiểm thử tài nguyên riêng trong Core Console: `tests/run-autocad-tests.ps1 -StylesOnly`. Kiểm thử đầy đủ hatch/cắt cửa: thêm `-FullAutoCAD`.

Bản 3.2.9 dùng tên `ALC Dim TL`. Khi tên mới chưa có, tạo với scale 100 và text height 3 rồi đặt current. Dim style cũ `ALC Dim TL65` được giữ lại để không đổi các DIM đã dùng nó.

## Text ghi chú và hatch — 3.2.9

- `alc text note`: Arial (TT), file `arial.ttf`, đặt đầy đủ typeface TrueType bằng SetFont, width factor 0.75, height 0.00. Font Arial (TT) và height 0.0 cũng được cập nhật khi style đã tồn tại. Đây là text style current sau load.
- Màu đối tượng hiện hành được đặt ByLayer (`CECOLOR=BYLAYER`) khi kích hoạt style note. Text mới lấy màu của layer `0. Tuong ALC` đang current; layer tạo mới vẫn Blue (ACI 4).
- `alc text` cũ được đổi tên thành `alc text dim` trên cùng STYLE record để giữ liên kết DIM đã có. `ALC Dim TL` tham chiếu `alc text dim`; font NGHIA5.SHX và width factor 0.65 được giữ. Nếu cả hai tên đã có, giữ các style có sẵn và cho ALC Dim TL tham chiếu alc text dim.
- Hatch Scale mặc định là 25. Với XRecord trước schema 4, giá trị mặc định cũ 250 được chuyển sang 25 một lần; các giá trị tùy chỉnh khác giữ nguyên. Sau nâng cấp schema 4, giá trị 250 do người dùng chọn được giữ nguyên.
- Tỷ lệ dim vẫn 100 và chiều cao text dim vẫn 3. Text ghi chú/dim chỉ tạo mới khi tên tương ứng chưa tồn tại.
