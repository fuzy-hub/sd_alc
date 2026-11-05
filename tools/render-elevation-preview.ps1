param([string]$Root=(Split-Path -Parent $PSScriptRoot))
Add-Type -AssemblyName System.Drawing
$data=Get-Content -LiteralPath (Join-Path $Root 'examples/mat-cat-mau.json') -Raw | ConvertFrom-Json
$mcBitmap=[Drawing.Bitmap]::new(1900,1240)
$mcGraphics=[Drawing.Graphics]::FromImage($mcBitmap)
$mcGraphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$mcGraphics.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$mcGraphics.Clear([Drawing.Color]::White)
$mcFont=[Drawing.Font]::new('Arial',17)
$mcSmall=[Drawing.Font]::new('Arial',13)
$mcTitle=[Drawing.Font]::new('Arial',27,[Drawing.FontStyle]::Bold)
$mcInk=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#243447'))
$mcBorder=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#31524a'),1.1)
$mcConcrete=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#e5e9ed'))
$mcGray=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#98a3ad'),1)
$mcBrick=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#f1f7f3'))
$mcCut=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#fff1d4'))
$mcFoam=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml('#eee3fb'))
$mcPurple=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#9a70ba'),1)
$mcAxis=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#a24d36'),1.1)
$mcAxis.DashStyle=[Drawing.Drawing2D.DashStyle]::Dash
$mcDim=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#526172'),1)
function X([double]$v) { [single](150+$v*0.2) }
function Y([double]$v) { [single](1000-$v*0.2) }
function Label([double]$x,[double]$y,[string]$t,[bool]$small=$false) {
 $f=if($small){$mcSmall}else{$mcFont}
 $mcGraphics.DrawString($t,$f,$mcInk,[single]$x,[single]$y)
}
function Concrete([double]$bottom,[double]$height) {
 $r=[Drawing.RectangleF]::new((X 0),(Y ($bottom+$height)),(0.2*$data.config.LENGTH),(0.2*$height))
 $mcGraphics.FillRectangle($mcConcrete,$r)
 $mcGraphics.DrawRectangle($mcGray,$r.X,$r.Y,$r.Width,$r.Height)
 $mcGraphics.SetClip($r)
 for($py=$r.Y+9;$py -lt $r.Bottom;$py+=17) {
  for($px=$r.X+10;$px -lt $r.Right;$px+=27) {
   $points=[Drawing.PointF[]]@([Drawing.PointF]::new($px,$py),[Drawing.PointF]::new($px+5,$py-4),[Drawing.PointF]::new($px+7,$py+3))
   $mcGraphics.DrawPolygon($mcGray,$points)
  }
 }
 $mcGraphics.ResetClip()
}
$span=[double]$data.config.LENGTH
$top=[double]$data.config.TOP
$tieBase=[double]$data.config.'TIE-BASE'
$tie=[double]$data.plan.TIE
$foam=[double]$data.plan.FOAM
$upper=$top+$data.config.BEAM+$data.config.'TOP-SLAB'
$mcGraphics.DrawString('TRIỂN KHAI TƯỜNG ALC — 3.5.0',$mcTitle,$mcInk,[single]150,[single]55)
Label 150 106 'Khoang mẫu 6000 mm · Gạch 1100 × 600 mm · Mạch 5 mm · Khe sàn/giằng 10 mm'
Concrete (-$data.config.SLAB) $data.config.SLAB
Concrete $tieBase $tie
Concrete $top $data.config.BEAM
Concrete ($top+$data.config.BEAM) $data.config.'TOP-SLAB'
foreach($piece in $data.pieces) {
 $r=[Drawing.RectangleF]::new((X $piece[0]),(Y ($piece[1]+$piece[3])),[single]($piece[2]*0.2),[single]($piece[3]*0.2))
 $brush=if($piece[2] -lt 1100 -or $piece[3] -lt 600){$mcCut}else{$mcBrick}
 $mcGraphics.FillRectangle($brush,$r)
 $mcGraphics.DrawRectangle($mcBorder,$r.X,$r.Y,$r.Width,$r.Height)
}
$r=[Drawing.RectangleF]::new((X 0),(Y $top),[single]($span*0.2),[single]($foam*0.2))
$mcGraphics.FillRectangle($mcFoam,$r)
$mcGraphics.SetClip($r)
for($px=$r.X-20;$px -lt $r.Right+20;$px+=12) { $mcGraphics.DrawLine($mcPurple,[single]$px,[single]$r.Bottom,[single]($px+20),[single]$r.Y) }
$mcGraphics.ResetClip()
$mcGraphics.DrawRectangle($mcPurple,$r.X,$r.Y,$r.Width,$r.Height)
$mcRef=[Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml('#388da2'),1)
$mcRef.DashStyle=[Drawing.Drawing2D.DashStyle]::Dash
$mcGraphics.DrawLine($mcRef,(X 0),(Y $data.config.CEILING),(X $span),(Y $data.config.CEILING))
foreach($v in @(0,$span)) {
 $mcGraphics.DrawLine($mcAxis,(X $v),(Y (-$data.config.SLAB-180)),(X $v),(Y ($upper+350)))
 $mcGraphics.DrawEllipse($mcDim,[single]((X $v)-20),[single]((Y ($upper+250))-20),[single]40,[single]40)
 Label ((X $v)-7) ((Y ($upper+250))-13) $(if($v -eq 0){'1'}else{'2'})
}
$dy=Y (-$data.config.SLAB-260)
$mcGraphics.DrawLine($mcDim,(X 0),$dy,(X $span),$dy)
foreach($v in @(0,$span)) { $mcGraphics.DrawLine($mcDim,[single]((X $v)-8),[single]($dy+8),[single]((X $v)+8),[single]($dy-8)) }
Label ((X ($span/2))-28) ($dy+8) '6000'
$dx=X ($span+400)
$mcGraphics.DrawLine($mcDim,$dx,(Y 0),$dx,(Y $top))
foreach($v in @(0,$top)) { $mcGraphics.DrawLine($mcDim,[single]($dx-8),[single]((Y $v)+8),[single]($dx+8),[single]((Y $v)-8)) }
Label ($dx-65) ((Y ($top/2))-12) '3300'
$levels=@(@(0,'Mặt sàn +0.000'),@($tieBase,'Đáy giằng +1.500'),@(($tieBase+$tie),'Đỉnh giằng +1.650'),@($data.config.CEILING,'Trần tham chiếu +3.000'),@($top,'Đáy dầm +3.300'),@($upper,'Mặt sàn trên +3.750'))
foreach($l in $levels) { Label 1505 ((Y $l[0])-11) $l[1] }
Label 1505 ((Y ($top-$foam/2))+8) "Foam $foam mm" $true
Label 150 1125 "Giằng $tie mm · Foam $foam mm · Ước tính $($data.plan.STOCK) viên cấp · $($data.plan.'CUT-PIECES') miếng cắt · Tận dụng $($data.plan.REUSED) phần cắt"
Label 150 1164 'Ô vàng: viên cắt. Hình minh họa theo dữ liệu tính của VVMC; xem DWG để kiểm tra kích thước.' $true
Label 150 1194 'Phạm vi thử bố trí một khoang chưa có cửa; kích thước giằng/foam cần theo cấu tạo được duyệt.' $true
$mcBitmap.Save((Join-Path $Root 'examples/mat-cat-mau.png'),[Drawing.Imaging.ImageFormat]::Png)
$mcGraphics.Dispose();$mcBitmap.Dispose()
