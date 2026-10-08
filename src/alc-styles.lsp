;;; ALCWALL v3.0.0 - create missing resources and make them current on load.

(defun alc--ensure-text-style ()
  (if (not (tblobjname "STYLE" "alc text"))
      (progn
        (entmakex '((0 . "STYLE") (100 . "AcDbSymbolTableRecord")
          (100 . "AcDbTextStyleTableRecord") (2 . "alc text") (70 . 0)
          (40 . 0.0) (41 . 0.65) (50 . 0.0) (71 . 0) (42 . 0.0)
          (3 . "NGHIA5.SHX") (4 . "")))
        (if (not (findfile "NGHIA5.SHX"))
          (prompt "\nALC text style requires NGHIA5.SHX in the CAD font/support path."))
        ))
  (tblobjname "STYLE" "alc text")
)

(defun alc--archtick-record (/ block saved result)
  ;; DIMBLK loads the native architectural tick block. Always restore its
  ;; previous value, including any override on the user's current dim style.
  (if (not (setq block (tblobjname "BLOCK" "_ARCHTICK")))
    (progn
      (setq saved (getvar "DIMBLK")
            result (vl-catch-all-apply 'setvar (list "DIMBLK" "_ARCHTICK")))
      (setvar "DIMBLK" (if (= saved "") "." saved))
      (if (not (vl-catch-all-error-p result))
        (setq block (tblobjname "BLOCK" "_ARCHTICK")))))
  ;; tblobjname BLOCK returns AcDbBlockBegin; DIMBLK needs its BLOCK_RECORD.
  (if block (cdr (assoc 330 (entget block))))
)

(defun alc--iso25-data (/ source)
  (if (setq source (tblobjname "DIMSTYLE" "ISO-25"))
    (vl-remove-if
      '(lambda (pair) (member (car pair) '(-1 5 105 330 102 360)))
      (entget source))
    ;; ISO-25 baseline from the stock AutoCAD 2027 acadiso.dwt, for drawings
    ;; such as imperial templates which do not have a named ISO-25 style.
    '((0 . "DIMSTYLE") (100 . "AcDbSymbolTableRecord")
      (100 . "AcDbDimStyleTableRecord") (2 . "ISO-25") (70 . 0)
      (41 . 2.5) (42 . 0.625) (43 . 3.75) (44 . 1.25)
      (73 . 0) (74 . 0) (77 . 1) (78 . 8) (140 . 2.5) (141 . 2.5)
      (143 . 0.0393700787401575) (147 . 0.625) (171 . 3) (172 . 1)
      (271 . 2) (272 . 2) (274 . 3) (278 . 44) (283 . 0) (284 . 8)))
)

(defun alc--ensure-dim-style (/ existing text-style arrow data pair)
  (if (setq existing (tblobjname "DIMSTYLE" "ALC Dim TL"))
      existing
      (if (and (setq text-style (alc--ensure-text-style))
               (setq arrow (alc--archtick-record)))
        (progn
          (setq data (alc--iso25-data))
          (foreach pair
            (append
              '((2 . "ALC Dim TL") (70 . 0)
                (40 . 100.0) (41 . 1.8) (42 . 2.0) (44 . 1.0) (45 . 5.0)
                (49 . 4.0) (140 . 3.0) (147 . 1.0) (174 . 1)
                (176 . 8) (177 . 8) (178 . 3) (271 . 0) (272 . 0)
                (279 . 2) (290 . 1) (142 . 0.0) (173 . 0))
              (list (cons 50 (/ pi 4.0)) (cons 340 text-style)
                    (cons 342 arrow) (cons 343 arrow) (cons 344 arrow)))
            (setq data (if (assoc (car pair) data)
                         (subst pair (assoc (car pair) data) data)
                         (append data (list pair)))))
          (entmake data)
          (tblobjname "DIMSTYLE" "ALC Dim TL"))))
)

(defun alc--activate-drawing-resources (/ item result)
  (foreach item '(("LAYER" "0. Tuong ALC" "CLAYER")
                 ("STYLE" "alc text" "TEXTSTYLE")
                 ("DIMSTYLE" "ALC Dim TL" "DIMSTYLE"))
    (if (tblsearch (car item) (cadr item))
      (progn
        ;; DIMSTYLE is read-only to setvar. Restore also applies all saved
        ;; style values, so previous drawing overrides do not remain active.
        (setq result
          (if (= (car item) "DIMSTYLE")
            (vl-catch-all-apply 'command-s
              (list "_.-DIMSTYLE" "_Restore" (cadr item)))
            (vl-catch-all-apply 'setvar (list (caddr item) (cadr item)))))
        (if (vl-catch-all-error-p result)
          (prompt (strcat "\nCannot make " (cadr item) " current: "
            (vl-catch-all-error-message result)))))))
  (princ)
)

(defun alc--init-drawing-resources (/ item result)
  (foreach item '((alc--ensure-wall-layer . "layer 0. Tuong ALC")
                 (alc--ensure-text-style . "text style alc text")
                 (alc--ensure-dim-style . "dim style ALC Dim TL"))
    (setq result (vl-catch-all-apply (car item) nil))
    (if (or (not result) (vl-catch-all-error-p result))
      (prompt (strcat "\nCannot create " (cdr item) ": "
        (if (vl-catch-all-error-p result)
          (vl-catch-all-error-message result) "drawing resource write failed")))))
  (alc--activate-drawing-resources)
  (princ)
)

(princ)
