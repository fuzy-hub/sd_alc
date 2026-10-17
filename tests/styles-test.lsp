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

(defun alc-test--note-arial-tt-p (style / object face bold italic charset pitch)
  (setq object (vlax-ename->vla-object style))
  (vla-GetFont object 'face 'bold 'italic 'charset 'pitch)
  (and (= face "Arial") (= bold :vlax-false) (= italic :vlax-false)
       (/= (logand pitch 4) 0)
       (= (strcase (vl-filename-base (vla-get-FontFile object))) "ARIAL")))

(defun alc-test-run-styles (/ checks layer text-style dim-style iso data item pass
    old-dim old-text old-layer old-dimblk layer-data text-data dim-data
    changed-layer changed-text changed-dim before-values after-values note-style note-data changed-note)
  (setq checks nil
        layer (tblobjname "LAYER" "0. Tuong ALC")
        text-style (tblobjname "STYLE" "alc text dim")
        dim-style (tblobjname "DIMSTYLE" "ALC Dim TL")
        iso (tblobjname "DIMSTYLE" "ISO-25")
        old-dim (getvar "DIMSTYLE") old-text (getvar "TEXTSTYLE")
        old-layer (getvar "CLAYER") old-dimblk (getvar "DIMBLK"))
  (alc-test--styles-check "startup-measurement-metric" (= (getvar "MEASUREMENT") 1))
  (alc-test--styles-check "startup-resources" (and layer text-style dim-style))
  (alc-test--styles-check "startup-current-layer" (= (getvar "CLAYER") "0. Tuong ALC"))
  (alc-test--styles-check "startup-current-text" (= (strcase (getvar "TEXTSTYLE")) "ALC TEXT NOTE"))
  (alc-test--styles-check "startup-current-dim" (= (getvar "DIMSTYLE") "ALC Dim TL"))
  (setq note-style (tblobjname "STYLE" "alc text note") note-data (entget note-style))
  (alc-test--styles-check "note-style-arial-width-height"
    (and (alc-test--note-arial-tt-p note-style)
         (equal (cdr (assoc 41 note-data)) 0.75 1e-9)
         (= (cdr (assoc 40 note-data)) 0.0)))
  (alc-test--styles-check "note-current-bylayer" (= (strcase (getvar "CECOLOR")) "BYLAYER"))
  (if (and (boundp 'alc-test-legacy-style) alc-test-legacy-style)
    (alc-test--styles-check "legacy-style-renamed-keeps-identity"
      (and (equal alc-test-legacy-style text-style)
           (not (tblobjname "STYLE" "alc text")))))
  (setq data (entget text-style))
  (alc-test--styles-check "text-font-and-width"
    (and (= (strcase (cdr (assoc 3 data))) "NGHIA5.SHX")
         (equal (cdr (assoc 41 data)) 0.65 1e-9)))
  (setq pass T)
  (foreach item '(("DIMSCALE" . 100.0) ("DIMTXT" . 3.0) ("DIMASZ" . 1.8) ("DIMEXO" . 2.0)
                 ("DIMEXE" . 1.0) ("DIMRND" . 5.0) ("DIMFXL" . 4.0)
                 ("DIMGAP" . 1.0) ("DIMTIX" . 1) ("DIMCLRD" . 8)
                 ("DIMCLRE" . 8) ("DIMCLRT" . 3) ("DIMDEC" . 0)
                 ("DIMTDEC" . 0) ("DIMTMOVE" . 2) ("DIMFXLON" . 1) ("DIMTFILL" . 1))
    (alc-test--styles-check (car item) (equal (getvar (car item)) (cdr item) 1e-9)))
  (alc-test--styles-check "DIMJOGANG" (equal (getvar "DIMJOGANG") (/ pi 4.0) 1e-9))
  (alc-test--styles-check "dim-text-style" (= (strcase (getvar "DIMTXSTY")) "ALC TEXT DIM"))
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
        (if (not (member (car item) '(-1 0 2 5 69 70 100 102 105 330 360
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
          (alc-test--replace-dxf
            (alc-test--replace-dxf dim-data '(40 . 33.0)) '(140 . 4.0)) '(69 . 0)))
  (setq changed-note (alc-test--replace-dxf
    (alc-test--replace-dxf note-data '(41 . 1.1)) '(40 . 120.0)))
  (entmod changed-note)
  (vla-put-FontFile (vlax-ename->vla-object note-style) "tahoma.ttf")
  (vla-SetFont (vlax-ename->vla-object note-style) "Tahoma" :vlax-false :vlax-false 0 38)
  (setq changed-note (entget note-style))
  (entmod changed-layer) (entmod changed-text) (entmod changed-dim)
  (setq changed-layer (entget layer) changed-text (entget text-style) changed-dim (entget dim-style)
        before-values (mapcar 'getvar '("CLAYER" "TEXTSTYLE" "DIMSTYLE" "DIMBLK" "DIMSCALE" "DIMCLRD")))
  ;; Start elsewhere, with an override, and check that reload activates saved
  ;; ALC resources without overwriting their intentionally edited definitions.
  (setvar "CLAYER" "0")
  (setvar "TEXTSTYLE" "Standard")
  (command "_.-DIMSTYLE" "_Restore" (if iso "ISO-25" "Standard"))
  (setvar "DIMSCALE" 99.0)
  (setvar "CECOLOR" "2")
  (setvar "MEASUREMENT" 0)
  (load (strcat (alc-test--root) "/ALCWALL.lsp"))
  (setq after-values (mapcar 'getvar '("CLAYER" "TEXTSTYLE" "DIMSTYLE" "DIMBLK" "DIMSCALE" "DIMCLRD")))
  (alc-test--styles-check "reload-resets-measurement-metric" (= (getvar "MEASUREMENT") 1))
  (alc-test--styles-check "reload-updates-note-height-preserves-other-values"
    (equal (alc-test--replace-dxf
      (alc-test--replace-dxf changed-note '(40 . 0.0)) (assoc 3 note-data)) (entget note-style)))
  (alc-test--styles-check "reload-repairs-existing-font-to-arial-TT"
    (alc-test--note-arial-tt-p note-style))
  (alc-test--styles-check "reload-resets-yellow-to-bylayer"
    (= (strcase (getvar "CECOLOR")) "BYLAYER"))
  (alc-test--styles-check "reload-preserves-existing-layer" (equal changed-layer (entget layer)))
  (alc-test--styles-check "reload-preserves-existing-text-style" (equal changed-text (entget text-style)))
  (alc-test--styles-check "reload-background-fill-preserves-other-dim-values"
    (and (= (getvar "DIMTFILL") 1)
         (equal (vl-remove-if '(lambda (pair) (= (car pair) 69)) changed-dim)
                (vl-remove-if '(lambda (pair) (= (car pair) 69)) (entget dim-style)))))
  (alc-test--styles-check "reload-activates-existing-resources"
    (and (= (getvar "CLAYER") "0. Tuong ALC")
         (= (strcase (getvar "TEXTSTYLE")) "ALC TEXT NOTE")
         (= (getvar "DIMSTYLE") "ALC Dim TL")
         (equal (getvar "DIMSCALE") 33.0 1e-9)
         (equal (getvar "DIMTXT") 4.0 1e-9)))
  (entmod layer-data) (entmod text-data) (entmod dim-data) (entmod note-data)
  (alc--activate-drawing-resources)
  (princ)
)
