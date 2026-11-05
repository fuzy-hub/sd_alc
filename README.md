# ALCWALL 3.4.6

ALCWALL là bộ công cụ AutoLISP hỗ trợ triển khai tường ALC 2D trên AutoCAD for Windows. Bản 3.4.6 được kiểm thử bằng AutoCAD 2027.

## Cài đặt

1. Giữ nguyên toàn bộ cấu trúc thư mục, đặc biệt là `ALCWALL.lsp` và thư mục `src`.
2. Trong AutoCAD, mở `OPTIONS > Files > Support File Search Path` và thêm thư mục ALCWALL.
3. Chạy PowerShell `./tools/install.ps1`, rồi `APPLOAD` tệp `ALCWALL-LOAD.lsp` được tạo trong thư mục cài. Thêm tệp này vào `APPLOAD > Startup Suite > Contents > Add` để tự nạp mỗi lần mở CAD/bản vẽ. Loader này ghim đúng thư mục khi máy có nhiều bản ALCWALL. Nếu chỉ có một bản trong Support Path, vẫn có thể nạp trực tiếp `ALCWALL.lsp`.
4. Khi thấy thông báo `ALCWALL v3.4.6 modules loaded`, bộ lệnh đã sẵn sàng.

Khi cập nhật, APPLOAD lại `ALCWALL-LOAD.lsp`; loader gỡ định nghĩa lệnh cũ `ALCCUT20` còn trong phiên làm việc, chỉ dùng `ALCTRIM`.

Không nạp riêng các tệp trong `src`; `ALCWALL.lsp` là loader duy nhất.

## Thay đổi 3.4.6

- VVTK có nền che theo background bản vẽ, gom cùng bảng để di chuyển.
- VVM/VVMATCH nhận tường thẳng/L/U, L ưu tiên X của UCS, U giữ cách chia chiều dài đã thống nhất. Tự lấy bề dày và đặt đúng tim; VV/VVC giới hạn hình thẳng/L/U.
- VVM nối qua khoảng cửa 900–2000 mm trong tập chọn, tính cả chiều dài cửa, dim từng cửa và thay tim rời tương ứng để không cộng trùng. Giữ Undo và chống tạo trùng.
- ZIP có các tệp ngay tại gốc: giải nén **vào đúng thư mục cài cũ và thay tệp**, không tạo thư mục phiên bản mới. Giữ bộ nạp ALCWALL-LOAD.lsp tại máy, APPLOAD lại sau khi cập nhật. DLL không đổi so với 3.4.5; có thể giữ DLL đang dùng nếu AutoCAD đang khóa tệp.
- Bản mặt cắt 3.5.0-preview.1 tiếp tục được giữ riêng, không có trong bản ổn định này.

## Thay đổi 3.4.5

- VVTK/ALCTK: giảm cột CHIỀU DÀI còn 60%, bỏ mọi polyline khép kín; giữ LINE và polyline mở.
- Sắp số theo 20 dải ngang, trái sang phải trong mỗi dải, theo hướng nhìn hiện tại kể cả khi UCS/PLAN bị xoay.
- Thêm Find (F): bấm dòng bảng mới để highlight đúng nguồn; màu mặc định đỏ. Bảng cũ chưa có liên kết cần tạo lại, không suy đoán nguồn.
- Ghi STT cạnh LINE/pline trên layer ALC_VVTK_STT. Đánh số lại thay số cũ của nguồn được thống kê; giữ số vùng khác và bảng cũ. Một Undo phục hồi bộ cũ.
- Manage (M) trong VVTK: Numbers (N) bật/tắt số; Color (C) đổi màu Find; Exit (E) thoát. Lưu lựa chọn trong DWG, không hỏi ghi số mỗi lần tạo bảng.
- Thêm VVSUMTABLE: cộng tổng hiển thị của các bảng VVTK được chọn, mỗi bảng một dòng và một dòng tổng cộng; không tự cập nhật khi nguồn thay đổi.
- VVMATCH hỗ trợ pick/quét chọn/Pickfirst nhiều tường và bỏ qua pline tim tương ứng đã có; giữ nguồn và một Undo cho lượt tạo.
- Layer mặc định khi load đổi thành ALC_wall default; giữ layer 0. Tuong ALC và đối tượng có sẵn.

## Thay đổi 3.4.4

- Thêm VVFILTER: chọn layer mẫu hoặc dùng last pick chung với VVTK/ALCTK, chọn đối tượng rồi giữ lại tập chọn đúng layer để dùng tiếp với Copy/Move/Properties. Hỗ trợ mọi loại đối tượng; All không lọc layer.
- VVTK/ALCTK bỏ qua REVCLOUD được AutoCAD nhận diện, kể cả cùng layer hoặc dùng All; giữ pline cong thông thường. Không sửa các đối tượng nguồn.

## Thay đổi 3.4.3

- VVTK/ALCTK: Enter hoặc Space khi chưa chọn đối tượng mẫu sẽ dùng lại last pick layer của bản vẽ hiện tại, kể cả All. Chọn mới thay last pick; bỏ qua layer đã xóa. Last pick giữ trong phiên và qua APPLOAD, không lưu sang lần đóng/mở bản vẽ.

## Thay đổi 3.4.2

- VVTK/ALCTK hỏi chiều cao chữ đầu tiên, tiếp theo chọn layer mẫu hoặc A, chọn vùng thống kê rồi điểm chèn bảng. Enter giữ chiều cao chữ hiện tại.

## Thay đổi 3.4.1

- VVA/ALCASSIGN/VVASSIGN: chọn dòng ngay bằng phím 1–9/numpad, Enter hoặc Space xác nhận; tối đa 9 layer mỗi trang, có chuyển trang và sửa PLINEWID.
- VVTK/ALCTK: chọn đối tượng mẫu để lọc layer hoặc A để bỏ lọc, rồi chọn vùng thống kê. Mỗi LINE/pline một dòng, cuối bảng cộng tổng.
- Sắp VVTK theo 20 dải ngang: trong mỗi dải từ trái sang phải, hết dải mới xuống dải tiếp theo theo chữ Z. Giữ đủ các đối tượng trùng vị trí/chiều dài.
- ALCLAYER/VVLAYER: layer mới mặc định Transparency 50%. VVMATCH hỗ trợ pick/quét chọn nhiều tường và một Undo cho cả lượt.
- Kèm thư viện chọn nhanh .NET 10 cho AutoCAD 2027. Khi cập nhật từ bản đã nạp DLL cũ, đóng/mở AutoCAD trước khi nạp bản mới; không ghi đè file DLL đang được sử dụng.

## Thay đổi 3.3.6

- Thêm ALCTKT/VVTKT: quét tường, đặt tên bảng và cộng chiều dài tim theo chiều dày, gồm cả lỗ cửa.
- Thống kê cửa theo chiều rộng, số lượng, nguồn đã lưu/suy ra; sửa chữ quá nhỏ ở các hàng cửa mới.
- Kiểm thử trực tiếp VV/VVC → ALCDOOR/VVDOOR → ALCTKT, xuất ảnh và mở lại DWG.

## Thay đổi 3.3.5

- Tự đặt `MEASUREMENT=1` (hệ mét) mỗi lần nạp ALCWALL, kể cả khi giá trị cũ là 0. Thêm `ALCWALL-LOAD.lsp` vào Startup Suite để áp dụng tự động mỗi lần mở CAD/bản vẽ. Biến này lưu theo bản vẽ và không chuyển đổi kích thước hình học đã vẽ.
- Giữ các cải tiến của mã nguồn 3.4.0 hiện có; dùng số phát hành 3.3.5 theo yêu cầu.

## Các cải tiến kế thừa từ 3.4.0

- VV/VVC khôi phục toàn bộ đối tượng mới nếu không tạo được hatch. DOOR kiểm tra hình học/layer và từ chối hatch nhiều vòng, dùng chung, nhiều hatch hoặc gradient.
- Cắt cửa giữ màu RGB/nền RGB/transparency/origin/layer của hatch, màu/nét/độ rộng/XData của biên. Các loại chưa hỗ trợ bị từ chối trước khi thay tường.
- TRIM/XTEND từ chối kết quả tự giao/suy biến; chỉ mục hatch được tạo một lần trong lượt lệnh và giải phóng cả khi Cancel/lỗi.
- TKALIGN dùng bản sao tạm để đo trực tiếp theo UCS, giữ nguyên đối tượng tham chiếu.
- Loader khóa lệnh nếu manifest/module không hợp lệ hoặc nạp lỗi. Không chỉnh module trực tiếp trong bộ cài; khi phát triển, chạy `python tools/refresh_manifest.py` rồi `python tools/validate_project.py` sau khi rà soát thay đổi.

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
| `ALCLAYER`, `VVLAYER` | Tạo layer mới có tiền tố ALC_wall_, chọn màu và đặt current ngay |
| `ALCASSIGN`, `VVASSIGN`, `VVA` | Chọn layer bắt đầu ALC bằng số hoặc chuột; đặt current và PLINEWID đã lưu |
| `VVFILTER` | Chọn đối tượng theo layer mẫu hoặc last pick; giữ kết quả trong tập chọn |
| `VVMATCH`, `VVM` | Tạo pline tim riêng từng đoạn tường thẳng/L/U, trên layer current; width theo chiều dày |
| `ALCTK`, `VVTK` | Chọn layer (hoặc All/A), quét vùng; mỗi LINE/pline một dòng và cuối bảng cộng tổng |
| `VVTK` / `ALCTK` → `Find` (`F`) | Bấm dòng bảng để tô sáng LINE/pline gốc; giữ nguyên 4 cột |
| `VVSUMTABLE` | Cộng tổng các bảng VVTK đã chọn; mỗi bảng nguồn một dòng, cuối bảng cộng tổng |
| `ALCTKT`, `VVTKT` | Quét chọn tường ALC, đặt tên bảng và cộng chiều dài tim theo chiều dày |
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

## Thống kê theo loại tường ALC

Gõ `ALCTK` hoặc `VVTK`: chọn chiều cao chữ trước (Enter giữ giá trị hiện tại), rồi bấm chọn đối tượng mẫu hoặc bấm vào khoảng trống rồi quét vùng trực tiếp, không cần gõ W; Enter để kết thúc chọn mẫu. Quét trái sang phải chọn đối tượng nằm trọn trong khung; phải sang trái lấy cả đối tượng cắt khung. Các layer có trong tập đối tượng này sẽ được dùng làm bộ lọc thống kê. Nhập `A` (All) ở bước chọn đối tượng để lấy mọi layer như trước. Enter hoặc Space khi chưa chọn đối tượng mẫu sẽ dùng lại danh sách layer đã chọn gần nhất (last pick) trong bản vẽ hiện tại; nếu lượt trước chọn A thì dùng lại All. Lần đầu chưa có last pick sẽ hủy. Chọn mẫu mới sẽ thay lựa chọn đã nhớ; các layer đã xóa được bỏ qua, không tự chuyển sang All. Last pick giữ trong phiên bản vẽ và qua APPLOAD lại, không lưu sang lần đóng/mở bản vẽ. Sau đó quét vùng cần thống kê, rồi chọn điểm chèn bảng; việc ghi số STT cạnh LINE/pline dùng lựa chọn lưu trong VVTK → Manage (M). Chỉ LINE/POLYLINE trong vùng thống kê thuộc các layer đã lấy từ đối tượng mẫu được ghi vào bảng. Mỗi LINE hoặc pline là một dòng riêng (STT, layer, đơn vị m, chiều dài toàn bộ đối tượng), kể cả cùng layer hoặc cùng chiều dài; pline nhiều đỉnh không bị tách thành nhiều dòng. Chiều cao khung bao của các đối tượng thực sự được thống kê, sau khi chiếu sang hệ tọa độ hướng nhìn hiện tại (DCS), được chia đều thành 20 dải ngang, mỗi dải chạy hết chiều rộng vùng thống kê; không chia cột. Chiều cao mỗi dải bằng (Ymax toàn vùng − Ymin toàn vùng) / số dải. Mỗi đối tượng vào dải chứa Ymax theo hướng nhìn của chính nó, kể cả khi chạy qua nhiều dải. Duyệt dải từ trên xuống; trong mỗi dải xếp Xmin tăng dần từ trái sang phải theo chữ Z. Nếu Xmin bằng nhau thì xét Ymax giảm dần, cuối cùng theo handle để giữ thứ tự ổn định khi trùng vị trí. Điểm đúng ranh giới trong thuộc dải phía dưới; mép dưới ngoài cùng thuộc dải cuối. Đổi số dải bằng `(setq *alc-stat-grid-size* 10)` để dùng 10 dải ngang, hoặc đặt lại 20; nhận số nguyên từ 1 đến 1000. Thiết lập giữ trong phiên bản vẽ và qua APPLOAD, không lưu sau khi đóng bản vẽ. Vùng không có chiều cao được xếp trong một dải từ trái sang phải. Không phụ thuộc hướng vẽ pline hay thứ tự chọn. Mọi LWPOLYLINE/POLYLINE có thuộc tính Closed = Yes đều bị loại khỏi các dòng chi tiết và tổng chiều dài, gồm polyline 2D/3D và dạng có cung, kể cả trên layer đã chọn hoặc dùng All. REVCLOUD cũng được bỏ qua; LINE và polyline mở (kể cả có cung) vẫn được tính. Dòng cuối cộng tổng chiều dài. Các đối tượng mẫu chỉ xác định layer, không giới hạn các đối tượng được tính trong vùng thống kê. All vẫn chỉ tính trong vùng thống kê đã quét.

Gõ `ALCTKT` (hoặc `VVTKT`), quét chọn vùng có tường rồi Enter, nhập tên bảng và chọn điểm chèn. Enter ở tên bảng dùng “BẢNG THỐNG KÊ TƯỜNG ALC”. Bảng gồm STT, loại tường (ALC 100, ALC 150, ALC 200…), đơn vị m, chiều dài và dòng tổng cộng. Ngay bên dưới là phần “CỬA ĐÃ TÍNH TRONG CHIỀU DÀI TƯỜNG”: nhóm theo rộng cửa (mm), số lượng (cái) và chi tiết số cửa “Đã lưu / Suy ra”. Cuối phần cửa có tổng số cửa và tổng chiều rộng được cộng (m). Ví dụ 2 cửa 900 mm và 1 cửa 1200 mm sẽ hiển thị 2 loại, tổng 3 cửa và tổng rộng 3.000 m. Các cửa cùng rộng được gom chung dù thuộc loại tường khác nhau. Chỉ những lỗ mở đã được cộng vào chiều dài tường mới xuất hiện ở phần cửa; không có cửa thì bảng ghi rõ trạng thái này. Cỡ chữ dùng thiết lập thống kê hiện tại. Một lần Undo xóa bảng vừa tạo.

Mỗi tường được tính một lần kể cả khi quét cả biên lẫn hatch. Chiều dài lấy theo tim tường và cộng cả chiều rộng lỗ cửa khi chọn đủ hai đoạn tường hai bên, hỗ trợ tường thẳng/L/U và sau rút/kéo; không cộng chu vi, lanh tô hoặc giằng. Vùng quét dùng cách chọn đối tượng thông thường của AutoCAD: đối tượng được chọn được tính toàn bộ, không cắt chiều dài theo khung quét. Bảng là kết quả tại thời điểm chạy lệnh; chạy lại sau khi sửa tường.

ALCDOOR lưu vị trí hai đầu lỗ cửa trong XData theo WCS, được dịch/chuyển khi copy tường. Lỗ cửa có thông tin lưu chỉ được cộng một lần nếu cả hai đoạn tường liền cửa đều được chọn; chọn cả biên và hatch không làm tăng thêm lần cộng. Khi một bên bị xóa hoặc đầu tường tại cửa đã dịch khỏi vị trí ghi nhận, lỗ đó không tự được cộng từ thông tin cũ.

Theo lựa chọn của người dùng, với tường cũ chưa lưu đầy đủ lịch sử cửa, lệnh tự coi khe hở giữa hai đầu tường cùng layer, cùng chiều dày, cùng trục và hướng ra đối diện là cửa. Chỉ ghép hai đầu gần nhau nhất theo cả hai chiều; không ghép xuyên qua đoạn tường giữa. Khoảng cách khe không bị giới hạn nên các khe hở có chủ ý trên tường cũ cũng có thể được cộng. Dòng lệnh báo số khe đã suy ra để rà soát. Tường mới có dấu phiên bản 2 không dùng cách suy ra khe hở này; cửa mới dùng thông tin ALCDOOR đã lưu.

Tường vẽ mới bằng VV/VVC có dấu nhận diện ALC riêng, được giữ khi cắt cửa, rút/kéo và copy. Tường cũ chưa có dấu được nhận diện theo layer `0. Tuong ALC`, hatch liên kết một biên ANSI37 (hoặc pattern ALC hiện tại khác ANSI31) và hình học dải tường thẳng đều bề dày. Không thể phân biệt tuyệt đối một đối tượng vẽ tay có cùng layer/hatch/hình dạng với tường cũ. Tường cũ đã đổi layer/pattern, biên cong/hình học không hợp lệ hoặc không xác định được chiều dày sẽ bị bỏ qua; với hình chữ nhật cũ chưa có dấu, cạnh ngắn được coi là chiều dày, trừ đoạn cửa ngắn có thể ghép thẳng hàng với đoạn tường cùng chiều dày trong vùng chọn. Tường có dấu vẫn được đọc trên layer khóa hoặc layer tùy chỉnh và dùng bề dày đã lưu để nhận đúng đoạn tường ngắn sau cắt cửa.

## Rút đầu tường 20 mm

Chạy `ALCTRIM`, bấm biên tường hoặc hatch gần đầu cần rút. Lệnh tự chọn đầu gần điểm bấm nhất và rút vào theo độ dài đã chọn (đơn vị bản vẽ là mm). Độ dài ban đầu là 20 mm; giá trị Length gần nhất được nhớ trong phiên làm việc của bản vẽ, dùng lại khi gọi lệnh hoặc load Lisp lại. Không lưu vào DWG; phiên mới mặc định 20 mm. Nhập `L` (Length), đồng cấp với `M`, để đổi sang số dương; Enter giữ độ dài hiện tại. Có thể dùng `L` cả trước và trong Multi; độ dài mới áp dụng cho các lần cắt tiếp theo trong lượt lệnh. Mặc định cắt một tường rồi kết thúc. Nhập `M` (Multi) tại lời nhắc đầu để chọn lần lượt nhiều tường, Enter kết thúc; Undo một lần khôi phục cả lượt Multi. Hỗ trợ biên tường thẳng hoặc gấp khúc L/U do ALCWALL/ALCCENTRAL tạo, hai đầu vuông và thứ tự đỉnh còn nguyên.

Giữ polyline và hatch hiện có, cập nhật biên hatch, giữ pattern, scale, angle, màu và nền. Một lần `UNDO` khôi phục thao tác. Layer bị khóa, biên cong, hatch nhiều vòng hoặc đoạn đầu dài không quá độ dài cắt sẽ bị từ chối. Biên đã chỉnh thứ tự đỉnh hoặc cắt phức tạp có thể không được hỗ trợ. Text/DIM độc lập không tự cập nhật.

## Kéo dài đầu tường

Chạy `ALCXTEND` hoặc `VVXTEND`, bấm biên tường hoặc hatch gần đầu cần kéo. Lệnh dịch đầu gần điểm bấm nhất ra ngoài theo hướng đoạn cuối, giữ nguyên đầu còn lại. Mặc định kéo thêm 20 mm. `L` (Length) và `M` (Multi) hoạt động như `ALCTRIM`: đổi Length trước hoặc trong Multi, Enter ở Length giữ giá trị hiện tại, chọn một tường rồi kết thúc hoặc chọn nhiều tường và Enter để kết thúc Multi. Length của kéo dài được nhớ riêng với Length của rút ngắn trong phiên bản vẽ, kể cả khi load Lisp lại; không lưu vào DWG.

Giữ đối tượng biên và hatch hiện có, thuộc tính và liên kết hatch; Undo một lần khôi phục cả lượt. Hỗ trợ cùng dạng tường thẳng/L/U có hai đầu vuông và thứ tự đỉnh còn nguyên. Độ dài kéo thêm có thể lớn hơn đoạn đầu hiện có. Các giới hạn về layer khóa, biên cong, hatch nhiều vòng, biên đã sửa phức tạp và Text/DIM độc lập giống `ALCTRIM`; kết quả tự giao hoặc suy biến sẽ bị từ chối trước khi cập nhật.

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

Script mở một tiến trình AutoCAD 2027 riêng và ghi nhãn phiên, PID, thời gian khởi động trong `tests/results/<session>/session.json`. Log, marker hoàn tất và DWG sinh ra nằm trong chính thư mục phiên; fixture đầu vào không bị ghi đè. Các lệnh dùng ActiveX nên cần AutoCAD đầy đủ; Core Console không chạy được bộ test này vì không hỗ trợ đầy đủ ActiveX, bao gồm SetFont của text style. Các log ZWCAD trong bản ZIP gốc là dữ liệu lịch sử.

`ALCDOOR` chỉ thay tường cũ sau khi tạo thành công đủ hai boundary và hai hatch mới. Khi một bước thất bại, các đối tượng tạm bị xóa và tường cũ được giữ lại.

## Phát triển và phát hành

Git checkout `github-publish-3.0` là nguồn chuẩn hiện tại; tên thư mục được giữ để tương thích đường dẫn cũ. Không duy trì bản staging mã nguồn thứ hai bằng tay. Thư mục cha có thể dùng như bản triển khai cục bộ, nhưng phải cập nhật từ checkout đã kiểm tra.

1. Sửa mã trong Git checkout; cập nhật VERSION, phiên bản module/loader, CHANGELOG và RELEASE tương ứng.
2. `python tools/refresh_manifest.py`, `python tools/validate_project.py`.
3. `python -m unittest discover -s tests -p 'test_*.py' -v`.
4. `./tests/run-autocad-tests.ps1 -FullAutoCAD` (toàn bộ); `-HardeningOnly` cho bộ hồi quy 3.4, `-TrimOnly` cho rút/kéo; `-StylesOnly` cũng tự mở AutoCAD đầy đủ vì kiểm tra font cần ActiveX.
5. Rà soát log/marker và báo cáo của đúng phiên, commit nguồn rồi `python tools/package_release.py`. Công cụ kiểm tra manifest, nội dung ZIP và xuất tệp metadata SHA-256/commit/dirty. Chỉ phát hành từ commit sạch đã kiểm thử.

CI chạy kiểm tra tĩnh, kiểm thử cổng xác nhận kết quả và đóng gói; không thay thế kiểm thử AutoCAD 2027. Kiểm tra DCL chọn/Cancel bằng chuột vẫn cần thực hiện thủ công trước khi phát hành rộng.

## Giới hạn hình học

- Chỉ hỗ trợ tường 2D tạo bởi các đoạn thẳng; không xử lý segment cung trong polyline.
- Các điểm được chiếu về mặt phẳng UCS hiện tại; nên tránh tường không đồng phẳng.
- Offset có thể thất bại tại góc quá gắt, đoạn quá ngắn hoặc hình tự giao.
- `ALCDOOR` cần đủ phần tường ở cả hai phía lỗ mở; cửa nằm đúng đầu mút sẽ bị từ chối để tránh tạo polygon suy biến.
- Layer chứa tường phải được mở khóa. Hatch pattern được chọn phải tồn tại trong AutoCAD.

## Tính năng 2.6.0

- Gõ `ALCS` hoặc `ALSC`, chọn `Angle` (A), nhập số độ thập phân. Góc mặc định 0°, lưu theo bản vẽ, góc âm hoặc trên 360° được chuẩn hóa. Đây là góc xoay thêm của hatch, không phải góc của mép tường. Hatch khi cắt cửa giữ góc ban đầu; lanh tô và giằng giữ thiết lập riêng.
- Gõ `ALSC`, chọn `Pattern` (P): bảng danh sách mẫu từ `acad.pat`/`acadiso.pat` có hình xem trước. Chọn mẫu rồi OK; Cancel giữ giá trị cũ. Preview minh họa mẫu ở góc hiện tại, không phản ánh tỷ lệ in. Giữ file `src/alc-patterns.dcl` cùng các module. PAT tùy chỉnh ngoài hai thư viện này chưa nằm trong bảng chọn.
- Mỗi lần load kiểm tra và chỉ tạo layer còn thiếu `ALC_wall default`: Blue (ACI 4), Continuous, lineweight 0.09 mm. Sau load, layer này được đặt làm current. Layer có sẵn được giữ nguyên toàn bộ thuộc tính, kể cả màu/nét/lineweight. Có thể bắt đầu vẽ trên layer này ngay sau load.

XRecord schema 4 bổ sung DXF 44 cho góc, giữ thiết lập của bản vẽ schema 2. Xem `REVIEW.txt` để biết các điểm cần cải tiến tiếp và giới hạn kiểm thử giao diện.

## Khởi tạo style — 3.2.9

Khi nạp `ALCWALL.lsp`, kiểm tra riêng từng tên layer, text style và dim style. Chỉ tạo tài nguyên chưa tồn tại; tên đã có được giữ nguyên thông số, dim style `ALC Dim TL` được bật nền chữ Background cả khi đã tồn tại; riêng `alc text note` được cập nhật font Arial (TT) và height 0.0. Sau khi kiểm tra/tạo, lập tức đặt `ALC_wall default`, `alc text note` và `ALC Dim TL` làm current. Dim style được Restore để áp dụng thông số đã lưu và xóa các override của dim style hiện hành trước đó.

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

Kiểm thử tài nguyên riêng trong AutoCAD 2027 đầy đủ: `tests/run-autocad-tests.ps1 -StylesOnly`. Kiểm thử đầy đủ hatch/cắt cửa: thêm `-FullAutoCAD`.

Bản 3.2.9 dùng tên `ALC Dim TL`. Khi tên mới chưa có, tạo với scale 100 và text height 3 rồi đặt current. Dim style cũ `ALC Dim TL65` được giữ lại để không đổi các DIM đã dùng nó.

## Text ghi chú và hatch — 3.2.9

- `alc text note`: Arial (TT), file `arial.ttf`, đặt đầy đủ typeface TrueType bằng SetFont, width factor 0.75, height 0.00. Font Arial (TT) và height 0.0 cũng được cập nhật khi style đã tồn tại. Đây là text style current sau load.
- Màu đối tượng hiện hành được đặt ByLayer (`CECOLOR=BYLAYER`) khi kích hoạt style note. Text mới lấy màu của layer `ALC_wall default` đang current; layer tạo mới vẫn Blue (ACI 4).
- `alc text` cũ được đổi tên thành `alc text dim` trên cùng STYLE record để giữ liên kết DIM đã có. `ALC Dim TL` tham chiếu `alc text dim`; font NGHIA5.SHX và width factor 0.65 được giữ. Nếu cả hai tên đã có, giữ các style có sẵn và cho ALC Dim TL tham chiếu alc text dim.
- Hatch Scale mặc định là 25. Với XRecord trước schema 4, giá trị mặc định cũ 250 được chuyển sang 25 một lần; các giá trị tùy chỉnh khác giữ nguyên. Sau nâng cấp schema 4, giá trị 250 do người dùng chọn được giữ nguyên.
- Tỷ lệ dim vẫn 100 và chiều cao text dim vẫn 3. Text ghi chú/dim chỉ tạo mới khi tên tương ứng chưa tồn tại.

## Tạo layer ALC

Gõ `ALCLAYER` hoặc `VVLAYER`, nhập tên sau tiền tố `ALC_wall_`, rồi chọn màu trong bảng màu AutoCAD. Ví dụ nhập `Tang 1` sẽ tạo `ALC_wall_Tang 1` và đặt current ngay. Layer mới mặc định Transparency 50%, không hỏi thêm thông số. Có thể nhập cả tiền tố mà không bị lặp. Enter ở tên hoặc Cancel bảng màu hủy, không tạo layer. Tên trùng/không hợp lệ được yêu cầu nhập lại; layer có sẵn giữ nguyên. Một lần Undo hoàn tác cả tạo layer và đổi current.

## Chọn layer và độ rộng polyline

Gõ `VVA`, `ALCASSIGN` hoặc `VVASSIGN`. Bảng liệt kê layer nội bộ bắt đầu bằng `ALC`, tối đa 9 layer mỗi trang. Bấm phím số 1–9 (hoặc numpad) để đổi dòng chọn ngay, đồng thời cập nhật PLINEWID. Nhấn Enter hoặc Space để xác nhận và kết thúc lệnh; Esc hủy, giữ nguyên layer current và PLINEWID. Nếu có hơn 9 layer, dùng Trước/Sau hoặc PageUp/PageDown; mỗi trang vẫn dùng số 1–9. Layer current được chọn sẵn khi mở bảng. Có thể chọn dòng bằng chuột. Khi bấm/Tab vào ô PLINEWID, phím số dùng để sửa độ rộng; Enter/Space xác nhận giá trị đó. Layer chưa có width yêu cầu nhập giá trị trước khi xác nhận. Hộp thoại dùng .NET 10 tích hợp của AutoCAD 2027; DLL đi kèm được NETLOAD khi dùng lệnh lần đầu. PLINEWID được lưu theo layer trong DWG.

Độ rộng được lưu trong layer của chính DWG, giữ khi nạp lại Lisp hoặc đổi tên layer. Khi chưa có giá trị lưu, lấy số ở cuối tên nếu được ngăn bởi dấu gạch dưới/khoảng trắng/gạch nối: `ALC_wall_100` → 100, `ALC_wall_150` → 150. Tên như `ALC_wall_Tang1` không tự hiểu 1 là độ rộng; nhập một lần trong ô PLINEWID. Giá trị cho phép từ 0 trở lên và có thể ghi đè số suy ra từ tên. Layer xref không được liệt kê; layer đóng băng cần thaw trước khi chọn. Lệnh đổi độ rộng mặc định cho polyline vẽ sau đó, không sửa polyline đã có và không đổi chiều dày tường của VV/VVC.

## Chọn đối tượng theo layer — VVFILTER

Gõ `VVFILTER`, bấm/quét chọn đối tượng mẫu để lấy các layer cần lọc rồi Enter. Enter/Space khi chưa chọn mẫu sẽ dùng last pick chung với VVTK/ALCTK; `A` chọn All. Sau đó bấm/quét chọn các đối tượng cần lọc và Enter. Kết quả chỉ giữ các đối tượng thuộc bộ lọc trong tập chọn hiện hành để dùng tiếp với Copy, Move, Properties… Không giới hạn loại đối tượng, không chỉ các layer ALC và không quét toàn bản vẽ ngoài vùng/tập đối tượng bạn chọn. Với block, lọc theo layer của chính block, không đi sâu các đối tượng bên trong. Không thay đổi hình học, layer hay PLINEWID. Nếu không có đối tượng khớp, tập chọn được xóa. Chưa có last pick và không chọn mẫu thì hủy trước bước chọn đối tượng.

## Tìm đối tượng của dòng VVTK — Find

Gõ `VVTK` (hoặc `ALCTK`), nhập `F` / `Find` ngay tại lời nhắc chiều cao chữ, rồi bấm vào một dòng chi tiết của bảng. LINE/pline gốc được tô sáng; có thể bấm tiếp dòng khác, Enter kết thúc. Khi kết thúc, đối tượng cuối cùng được giữ trong tập chọn. Find không thay đổi hình học, nội dung bảng hoặc tạo bước Undo cho việc tìm. Bắt điểm được tạm tắt khi bấm ô và khôi phục sau đó.

Màu highlight trong Find mặc định là đỏ (ACI 1). Tại lời nhắc bấm dòng, nhập `C` / `Color` để chọn màu ACI 1–255 trong hộp chọn màu. Màu đã chọn được nhớ trong phiên bản vẽ, kể cả khi APPLOAD lại; Cancel giữ màu hiện tại. Chỉ màu hiệu ứng chọn thay đổi trong lượt Find; màu thật, layer và thuộc tính LINE/pline được giữ nguyên. Khi Enter/ESC kết thúc, các thiết lập highlight chung được khôi phục.

Bảng VVTK tạo mới tự lưu liên kết nguồn trong từng dòng, giữ nguyên 4 cột và chiều rộng cột chiều dài đã chỉnh. Liên kết không dựa vào việc so khớp chiều dài/layer nên phân biệt được các đối tượng trùng số liệu; vẫn tìm được sau khi di chuyển đối tượng, di chuyển/xoay bảng, chèn dòng hoặc lưu/mở lại DWG. Find không tự đổi góc nhìn; có thể pan/zoom để xem đối tượng được tô sáng.

Bảng tạo trước bản cập nhật này cần chạy lại VVTK để có liên kết. Nếu đối tượng gốc đã xóa, dữ liệu dòng đã chỉnh hoặc bảng được đưa sang bản vẽ khác, Find sẽ báo và không đoán đối tượng thay thế. Copy riêng bảng trong cùng DWG giữ liên kết tới các đối tượng gốc; tạo lại VVTK nếu muốn thống kê các đối tượng vừa copy. Bảng thống kê vẫn là kết quả tại thời điểm tạo, không tự cập nhật số liệu.

## Cộng các bảng VVTK — VVSUMTABLE

Gõ `VVSUMTABLE`, nhập chiều cao chữ (Enter giữ giá trị hiện tại), pick/quét chọn các bảng VVTK rồi Enter và chọn điểm chèn. Có thể chọn sẵn bảng trước khi gọi lệnh. Bảng mới có STT, TÊN BẢNG, ĐƠN VỊ, CHIỀU DÀI (m), mỗi dòng lấy giá trị đang hiển thị ở ô TỔNG CỘNG của một bảng nguồn; cuối bảng cộng tổng các dòng đó. Không cộng lại các dòng chi tiết. Bố cục, cỡ chữ và chiều rộng cột chiều dài bằng 60% ban đầu giống VVTK hiện tại. Cột tên bảng được mở rộng theo nhãn nguồn để dễ đọc; AutoCAD tự điều chỉnh chiều cao tối thiểu theo nội dung chữ.

Các dòng được sắp theo vị trí Xmin/Ymax như VVTK. Nhãn kèm handle của bảng nguồn trong dấu vuông để phân biệt các bảng cùng tên; tên mặc định được rút gọn thành BẢNG. Bảng đổi tiêu đề vẫn được nhận diện nếu giữ các cột STT/TÊN LAYER/ĐƠN VỊ/CHIỀU DÀI và dòng TỔNG CỘNG đơn vị m. Hỗ trợ bảng VVTK cũ gộp theo layer. Bảng khác cấu trúc, ô tổng không phải số thập phân hoặc bảng tổng hợp VVSUMTABLE sẽ bị báo bỏ qua. Dấu chấm hoặc dấu phẩy được hiểu là dấu thập phân; không dùng dấu phân nhóm hàng nghìn trong ô tổng.

Giữ nguyên các bảng nguồn; một Undo xóa bảng tổng hợp mới. Enter ở bước chọn bảng hoặc điểm chèn sẽ hủy. Bảng tổng hợp lưu kết quả tại thời điểm chạy lệnh, không tự cập nhật khi sửa bảng nguồn; chạy lại VVSUMTABLE để tổng hợp giá trị mới.

## Tạo pline tim tường — VVMATCH / VVM

Gõ `VVMATCH` hoặc `VVM`, pick hoặc quét chọn nhiều biên/hatch tường ALC thẳng, L hoặc U bằng Window/Crossing; Enter xác nhận. Có thể chọn sẵn trước khi gọi lệnh. Chọn cả biên và hatch của cùng tường chỉ xử lý một lần. Mỗi nhánh tạo một LWPOLYLINE mở hai đỉnh, nằm đúng tim tường: thẳng có 1 pline, L có 2, U có 3. Các nhánh thẳng hàng qua cửa được gom thành một pline liên tục. Pline dùng layer current, màu và transparency ByLayer; width theo bề dày thực tế. Giữ current layer, PLINEWID và tường/hatch gốc; một Undo xóa toàn bộ pline đã tạo trong lượt.

Chữ U: đoạn nối hai chân lấy hết chiều dài phủ bì; hai chân dừng ở mép đoạn nối, tránh tính trùng góc. Ví dụ trong hình đã thống nhất: 1455 + 880 + 490 = 2825 mm. Chữ L: nhánh gần trục X của UCS hiện hành hơn lấy hết phần góc; nhánh còn lại dừng ở mép nhánh ưu tiên. Khi hai nhánh cùng nghiêng 45° với X, ưu tiên trục có hệ số góc dương trong UCS để kết quả không phụ thuộc chiều vẽ biên. Các pline được tách ngắn/dài tại góc nhưng vẫn nằm đúng tim từng nhánh.

Chỉ nhận dải tường đều bề dày, góc vuông, dạng thẳng/L/U không tự giao. Hình Z, T, nhiều nhánh, cạnh cong, bề dày không đều hoặc hình học không xác định duy nhất sẽ được bỏ qua và thông báo. L/U đọc bề dày từ cặp mép tường thực tế, kể cả khi dấu bề dày cũ không còn khớp. Với hình chữ nhật, giữ cách nhận bề dày cũ để xử lý đúng đoạn tường ngắn sau cắt cửa: ưu tiên dấu/layer nếu khớp cạnh thực tế, tường cũ thiếu thông tin dùng cạnh ngắn. Biên nguồn cũ cần layer bắt đầu ALC hoặc tên `0. Tuong ALC`; tường có dấu ALC dùng được trên layer khác. Layer current cần mở khóa; layer nguồn khóa vẫn có thể đọc.

Trong tập tường được chọn, hai nhánh cùng tim, cùng bề dày và cùng mặt phẳng có khoảng trống từ **900 đến 2000 mm**, gồm cả hai mốc, được coi là có cửa. VVM nối pline qua khoảng trống, nên VVTK tính cả chiều dài cửa. Mỗi cửa được đánh dấu bằng một dim aligned theo dimstyle hiện hành, đặt lệch khỏi tim; hệ số đo chiều dài của dim bằng 1 để thể hiện đúng chiều rộng. Nhiều cửa liên tiếp được nối trên cùng một pline. Ví dụ: tường 1000 + cửa 900 + tường 1000 → pline 2900 mm và một dim cửa 900 mm.

Chỉ xét tường trong tập chọn; chọn một phía cửa không tự tìm và nối sang phía còn lại. Không nối khi lệch tim, khác bề dày/mặt phẳng, khoảng trống ngoài 900–2000 mm hoặc các khoảng tường chồng lấn làm tuyến không rõ ràng. Việc nhận cửa dựa trên khoảng trống hình học, không cần ký hiệu cửa hay dữ liệu cắt cửa trước đó.

Lệnh kiểm tra pline tim theo hai đầu, width và mặt phẳng, kể cả pline khác layer hoặc đảo chiều; dim cửa do VVM tạo cũng được nhận lại theo vị trí và mặt phẳng. Chạy lại không tạo trùng; dim bị xóa được tạo lại. Khi gom qua cửa, các pline tim rời hoặc tuyến đã gom ngắn hơn có hai đầu trùng đầu đoạn nguồn được thay bằng tuyến đầy đủ để tránh VVTK đếm trùng. Layer của các pline cần thay phải được mở khóa. Giữ nguyên tường/hatch nguồn và các pline khác không khớp; không quét thêm hatch/tường ngoài tập chọn.

Một Undo khôi phục pline tim cũ và xóa cả pline/dim mới của lượt; lượt không thay đổi gì không thêm bước Undo rỗng. Nếu tạo pline/dim hoặc thay pline cũ bị lỗi, hủy toàn bộ đầu ra mới và giữ đầu ra cũ. Pline và dim là kết quả tại thời điểm chạy lệnh, không tự cập nhật theo nguồn.

VV/VVC chỉ nhận đường vẽ thẳng, L hoặc U: tối đa 3 đoạn, hai góc vuông rẽ cùng chiều. Điểm thẳng hàng được gộp khi kiểm tra; điểm làm thành hình Z, cạnh xiên tại góc, quay ngược hoặc thêm nhánh thứ tư sẽ bị từ chối ngay và cho chọn lại. Tường thẳng có thể đặt ở góc bất kỳ; toàn bộ L/U có thể xoay hoặc lật hướng.

Kiểm thử mã nguồn: dùng PowerShell 7.6 (.NET 10) để chạy `./tests/run-autocad-tests.ps1 -FullAutoCAD`. Công cụ biên dịch hộp thoại chỉ phục vụ phát triển; người dùng dùng DLL đã đi kèm bản ZIP.

REVCLOUD đã bị mất cả dấu `RevcloudProps` lẫn thuộc tính nhận diện của AutoCAD không được suy đoán chỉ từ hình dạng, để tránh loại nhầm pline cong thông thường.

VVTK ghi số: tại lời nhắc chiều cao chữ, chọn Manage (M) → Numbers (N) → Yes (Y)/No (N) để bật/tắt; Color (C) chọn màu Find; Exit (E) quay lại. Chữ viết hoa trong mỗi từ khóa là phím tắt. Cả hai lựa chọn được lưu trong DWG, giữ qua APPLOAD và mở lại bản vẽ; mặc định ghi số Yes, màu Find đỏ. Không hỏi ghi số mỗi lần tạo bảng. Khi bật, tạo TEXT riêng trên ALC_VVTK_STT (mặc định đỏ), trùng STT từng dòng, cỡ chữ bằng bảng, cách điểm nửa chiều dài curve 0.8 chiều cao chữ theo hướng lên UCS. Layer riêng có thể bật/tắt. Khi đánh số lại, thay số cũ của các đối tượng được thống kê; giữ số của nguồn khác và giữ bảng cũ. Số từ bản trước chưa có dấu nguồn được nhận diện theo vị trí đặt tự động; không cần chọn thêm nguồn. Chỉ xóa số cũ sau khi bộ mới tạo thành công; lỗi giữ bộ cũ; Undo phục hồi bộ cũ và xóa đầu ra mới. Chọn No chỉ tạo bảng và giữ các số hiện có. Không sửa pline gốc. Số không tự cập nhật khi chỉnh sửa pline; có thể MOVE chữ để tránh chồng lấn.

Thứ tự VVTK/VVSUMTABLE dùng chiều ngang/dọc theo hướng nhìn khi tạo bảng, kể cả UCS/PLAN hoặc view bị xoay. Khung bao WCS được chiếu qua tám góc sang DCS, không xoay hay di chuyển nguồn. Đổi hướng nhìn sau khi tạo bảng không tự đánh số lại bảng/số đã có.
