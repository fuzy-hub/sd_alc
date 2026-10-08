;;; Resource creation, exact DIM variables and preservation of existing styles.
(defun alc-test--styles-check (name pass)
  (setq checks (cons (strcat (if pass "PASS " "FAIL ") name) checks))
  (alc-test--write-lines (strcat (alc-test--root) "/tests/results/styles-test.log")
    (reverse checks))
)

(defun alc-test--replace-dxf (data pair)
  (if (assoc (car pair) data) (subst pair (assoc (car pair) data) data)
    (append data (list pair)))
)

(defun alc-test-run-styles (/ checks layer text-style dim-style iso data item pass
    old-dim old-text old-layer old-dimblk layer-data text-data dim-data
    changed-layer changed-text changed-dim before-values after-values)
  (setq checks nil
        layer (tblobjname "LAYER" "0. Tuong ALC")
        text-style (tblobjname "STYLE" "alc text")
        dim-style (tblobjname "DIMSTYLE" "ALC Dim TL")
        iso (tblobjname "DIMSTYLE" "ISO-25")
        old-dim (getvar "DIMSTYLE") old-text (getvar "TEXTSTYLE")
        old-layer (getvar "CLAYER") old-dimblk (getvar "DIMBLK"))
  (alc-test--styles-check "startup-resources" (and layer text-style dim-style))
  (alc-test--styles-check "startup-current-layer" (= (getvar "CLAYER") "0. Tuong ALC"))
  (alc-test--styles-check "startup-current-text" (= (strcase (getvar "TEXTSTYLE")) "ALC TEXT"))
  (alc-test--styles-check "startup-current-dim" (= (getvar "DIMSTYLE") "ALC Dim TL"))
  (setq data (entget text-style))
  (alc-test--styles-check "text-font-and-width"
    (and (= (strcase (cdr (assoc 3 data))) "NGHIA5.SHX")
         (equal (cdr (assoc 41 data)) 0.65 1e-9)))
  (setq pass T)
  (foreach item '(("DIMSCALE" . 100.0) ("DIMTXT" . 3.0) ("DIMASZ" . 1.8) ("DIMEXO" . 2.0)
                 ("DIMEXE" . 1.0) ("DIMRND" . 5.0) ("DIMFXL" . 4.0)
                 ("DIMGAP" . 1.0) ("DIMTIX" . 1) ("DIMCLRD" . 8)
                 ("DIMCLRE" . 8) ("DIMCLRT" . 3) ("DIMDEC" . 0)
                 ("DIMTDEC" . 0) ("DIMTMOVE" . 2) ("DIMFXLON" . 1))
    (alc-test--styles-check (car item) (equal (getvar (car item)) (cdr item) 1e-9)))
  (alc-test--styles-check "DIMJOGANG" (equal (getvar "DIMJOGANG") (/ pi 4.0) 1e-9))
  (alc-test--styles-check "dim-text-style" (= (strcase (getvar "DIMTXSTY")) "ALC TEXT"))
  (alc-test--styles-check "archtick-arrow"
    (= (vl-string-left-trim "_" (strcase (getvar "DIMBLK"))) "ARCHTICK"))
  (alc-test--styles-check "arrow-not-tick-size" (= (getvar "DIMTSZ") 0.0))
  (alc-test--styles-check "same-arrow-both-ends" (= (getvar "DIMSAH") 0))
  (setq checks (cons (strcat "INFO arrow=" (vl-princ-to-string (getvar "DIMBLK"))
    " DIMTSZ=" (vl-princ-to-string (getvar "DIMTSZ"))
    " DIMSAH=" (vl-princ-to-string (getvar "DIMSAH"))) checks))
  ;; ISO-25 properties not requested as changes should be inherited intact.
  (if iso
    (progn
      (setq data (entget dim-style) pass T)
      (foreach item (entget iso)
        (if (not (member (car item) '(-1 0 2 5 70 100 102 105 330 360
             40 41 42 44 45 49 50 140 142 147 173 174 176 177 178 271 272
             279 290 340 342 343 344)))
          (if (not (equal (cdr (assoc (car item) data)) (cdr item) 1e-9))
            (setq pass nil))))
      (alc-test--styles-check "inherits-iso25-other-values" pass)))
  (command "_.-DIMSTYLE" "_Restore" old-dim)
  (setvar "DIMBLK" (if (= old-dimblk "") "." old-dimblk))
  ;; Change each resource on purpose. A reload must preserve complete records.
  (setq layer-data (entget layer) text-data (entget text-style) dim-data (entget dim-style)
        changed-layer (alc-test--replace-dxf layer-data '(62 . 2))
        changed-text (alc-test--replace-dxf text-data '(41 . 1.25))
        changed-dim (alc-test--replace-dxf
          (alc-test--replace-dxf dim-data '(40 . 33.0)) '(140 . 4.0)))
  (entmod changed-layer) (entmod changed-text) (entmod changed-dim)
  (setq changed-layer (entget layer) changed-text (entget text-style) changed-dim (entget dim-style)
        before-values (mapcar 'getvar '("CLAYER" "TEXTSTYLE" "DIMSTYLE" "DIMBLK" "DIMSCALE" "DIMCLRD")))
  ;; Start elsewhere, with an override, and check that reload activates saved
  ;; ALC resources without overwriting their intentionally edited definitions.
  (setvar "CLAYER" "0")
  (setvar "TEXTSTYLE" "Standard")
  (command "_.-DIMSTYLE" "_Restore" (if iso "ISO-25" "Standard"))
  (setvar "DIMSCALE" 99.0)
  (load (strcat (alc-test--root) "/ALCWALL.lsp"))
  (setq after-values (mapcar 'getvar '("CLAYER" "TEXTSTYLE" "DIMSTYLE" "DIMBLK" "DIMSCALE" "DIMCLRD")))
  (alc-test--styles-check "reload-preserves-existing-layer" (equal changed-layer (entget layer)))
  (alc-test--styles-check "reload-preserves-existing-text-style" (equal changed-text (entget text-style)))
  (alc-test--styles-check "reload-preserves-existing-dim-style" (equal changed-dim (entget dim-style)))
  (alc-test--styles-check "reload-activates-existing-resources"
    (and (= (getvar "CLAYER") "0. Tuong ALC")
         (= (strcase (getvar "TEXTSTYLE")) "ALC TEXT")
         (= (getvar "DIMSTYLE") "ALC Dim TL")
         (equal (getvar "DIMSCALE") 33.0 1e-9)
         (equal (getvar "DIMTXT") 4.0 1e-9)))
  (entmod layer-data) (entmod text-data) (entmod dim-data)
  (alc--activate-drawing-resources)
  (princ)
)
