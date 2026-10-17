(setq *alc-module-version* "3.3.5")
;;; ALCWALL v3.3.5 - create missing resources and make them current on load.

(defun alc--ensure-text-style (/ old data)
  ;; Rename the existing STYLE record to retain DIM and entity references.
  (if (and (not (tblobjname "STYLE" "alc text dim"))
           (setq old (tblobjname "STYLE" "alc text")))
    (progn
      (setq data (entget old))
      (entmod (subst '(2 . "alc text dim") (assoc 2 data) data))))
  (if (not (tblobjname "STYLE" "alc text dim"))
      (progn
        (entmakex '((0 . "STYLE") (100 . "AcDbSymbolTableRecord")
          (100 . "AcDbTextStyleTableRecord") (2 . "alc text dim") (70 . 0)
          (40 . 0.0) (41 . 0.65) (50 . 0.0) (71 . 0) (42 . 0.0)
          (3 . "NGHIA5.SHX") (4 . "")))
        (if (not (findfile "NGHIA5.SHX"))
          (prompt "\nALC text style requires NGHIA5.SHX in the CAD font/support path."))
        ))
  (tblobjname "STYLE" "alc text dim")
)

(defun alc--ensure-note-style (/ style data object)
  (if (not (tblobjname "STYLE" "alc text note"))
    (entmakex '((0 . "STYLE") (100 . "AcDbSymbolTableRecord")
      (100 . "AcDbTextStyleTableRecord") (2 . "alc text note") (70 . 0)
      (40 . 0.0) (41 . 0.75) (50 . 0.0) (71 . 0) (42 . 0.0)
      (3 . "arial.ttf") (4 . ""))))
  ;; Apply the requested variable height to existing note styles as well.
  (if (setq style (tblobjname "STYLE" "alc text note"))
    (progn
      (setq data (entget style))
      (if (/= (cdr (assoc 40 data)) 0.0)
        (if (not (entmod (subst '(40 . 0.0) (assoc 40 data) data)))
          (setq style nil)))
      (if style
        (progn
          (setq object (vlax-ename->vla-object style))
          ;; Set both the font file and TrueType face metadata for Arial (TT).
          (vla-put-FontFile object "arial.ttf")
          (vla-SetFont object "Arial" :vlax-false :vlax-false 0 38)))))
  style
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
      (progn
        ;; Explicit migration updates the text-style reference and text fill.
        (setq text-style (alc--ensure-text-style) data (entget existing))
        (if (and text-style (not (equal (cdr (assoc 340 data)) text-style)))
          (setq data (if (assoc 340 data)
            (subst (cons 340 text-style) (assoc 340 data) data)
            (append data (list (cons 340 text-style))))))
        (setq data (if (assoc 69 data)
          (subst '(69 . 1) (assoc 69 data) data)
          (append data '((69 . 1)))))
        (if (entmod data) existing))
      (if (and (setq text-style (alc--ensure-text-style))
               (setq arrow (alc--archtick-record)))
        (progn
          (setq data (alc--iso25-data))
          (foreach pair
            (append
              '((2 . "ALC Dim TL") (70 . 0) (69 . 1)
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
                 ("STYLE" "alc text note" "TEXTSTYLE")
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
  ;; Notes inherit the color of the current wall layer.
  (if (= (strcase (getvar "TEXTSTYLE")) "ALC TEXT NOTE")
    (setvar "CECOLOR" "BYLAYER"))
  (princ)
)

(defun alc--init-drawing-resources (/ item result pass)
  (setq pass T)
  (foreach item '((alc--ensure-wall-layer . "layer 0. Tuong ALC")
                 (alc--ensure-text-style . "text style alc text dim")
                 (alc--ensure-note-style . "text style alc text note")
                 (alc--ensure-dim-style . "dim style ALC Dim TL"))
    (setq result (vl-catch-all-apply (car item) nil))
    (if (or (not result) (vl-catch-all-error-p result))
      (progn (setq pass nil) (prompt (strcat "\nCannot create " (cdr item) ": "
        (if (vl-catch-all-error-p result)
          (vl-catch-all-error-message result) "drawing resource write failed"))))))
  (if pass (alc--activate-drawing-resources))
  pass
)

(princ)
