;;; Use real AutoCAD REVCLOUD metadata, not a geometric cloud lookalike.
(defun alc-test--revcloud-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "revcloud-test.log")))
  (alc-test--write-lines "revcloud-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test-run-revcloud (/ old-layer name cloud cloud2 cloud-copy line arc closed-arc selection only-clouds rows totals expected before table entity)
  (setq old-layer (getvar "CLAYER") name "ALC_Revcloud_Test")
  (if (not (tblsearch "LAYER" name))
    (alc--create-current-wall-layer name 3))
  (setvar "CLAYER" name)
  (initcommandversion)
  (command-s "_.REVCLOUD" "_Rectangular" '(0.0 0.0 0.0) '(1000.0 600.0 0.0))
  (setq cloud (entlast))
  (initcommandversion)
  (command-s "_.REVCLOUD" "_Rectangular" '(2000.0 0.0 0.0) '(3000.0 600.0 0.0))
  (setq cloud2 (entlast))
  (alc-test--revcloud-check "native-REVCLOUD-is-a-polyline-with-RevcloudProps"
    (and (= (cdr (assoc 0 (entget cloud))) "LWPOLYLINE")
      (assoc -3 (entget cloud '("RevcloudProps")))))
  (alc-test--revcloud-check "native-clouds-detected-on-same-statistics-layer"
    (and (alc--revcloud-p cloud) (alc--revcloud-p cloud2)))
  (entmake (list '(0 . "LINE") (cons 8 name) '(10 0.0 1000.0 0.0) '(11 1000.0 1000.0 0.0)))
  (setq line (entlast))
  (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 name)
    '(100 . "AcDbPolyline") '(90 . 2) '(70 . 0) '(10 0.0 2000.0) '(42 . 1.0) '(10 1000.0 2000.0)))
  (setq arc (entlast))
  (entmake (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 name)
    '(100 . "AcDbPolyline") '(90 . 2) '(70 . 1) '(10 0.0 3000.0) '(42 . 1.0) '(10 1000.0 3000.0) '(42 . 1.0)))
  (setq closed-arc (entlast))
  (regapp "ALC_Test_Unrelated")
  (entmod (append (entget arc) '((-3 ("ALC_Test_Unrelated" (1000 . "keep ordinary arc"))))))
  (alc-test--revcloud-check "LINE-and-open-curved-pline-with-unrelated-XData-are-kept"
    (and (not (alc--revcloud-p line)) (not (alc--revcloud-p arc))))
  (alc-test--revcloud-check "ordinary-closed-curved-pline-is-not-a-revcloud"
    (not (alc--revcloud-p closed-arc)))
  (setq selection (ssadd) only-clouds (ssadd)
        expected (+ 1000.0 (* pi 500.0) (* pi 1000.0))
        before (list (entget cloud '("*")) (entget cloud2 '("*")) (entget arc '("*"))))
  (foreach entity (list line arc closed-arc cloud cloud2) (ssadd entity selection))
  (ssadd cloud only-clouds) (ssadd cloud2 only-clouds)
  (setq rows (alc--collect-length-rows selection))
  (alc-test--revcloud-check "detail-rows-exclude-both-clouds-even-on-the-selected-layer"
    (= (length rows) 3))
  (alc-test--revcloud-check "grand-total-excludes-cloud-lengths-but-includes-real-arcs"
    (equal (alc--total-layer-length rows) expected 1e-6))
  (setq totals (alc--collect-layer-lengths selection))
  (alc-test--revcloud-check "aggregate-length-collector-also-excludes-clouds"
    (and (= (length totals) 1) (equal (cdar totals) expected 1e-6)))
  (alc-test--revcloud-check "All-mode-still-excludes-revclouds-from-statistics"
    (= (length (alc--collect-length-rows (alc--stat-filter-selection selection 'all))) 3))
  (alc-test--revcloud-check "cloud-only-selection-produces-no-length-rows"
    (and (not (alc--collect-length-rows only-clouds)) (not (alc--collect-layer-lengths only-clouds))))
  (alc-test--revcloud-check "shared-layer-filter-still-allows-clouds-for-VVFILTER"
    (= (sslength (alc--stat-filter-selection selection (list name))) 5))
  (setq cloud-copy (alc--vla-object-ename (vla-Copy (vlax-ename->vla-object cloud))))
  (ssadd cloud-copy selection)
  (alc-test--revcloud-check "copied-native-revcloud-is-also-excluded"
    (and (alc--revcloud-p cloud-copy) (= (length (alc--collect-length-rows selection)) 3)))
  (setq table (alc--add-length-detail-table rows '(20000.0 0.0 0.0) 100.0))
  (alc-test--revcloud-check "actual-table-has-only-three-data-rows-and-the-correct-total"
    (and (= (vla-get-Rows table) 6)
      (= (vla-GetText table 5 3) (rtos (/ expected 1000.0) 2 3))))
  (alc-test--revcloud-check "source-revclouds-and-ordinary-pline-are-not-modified"
    (equal before (list (entget cloud '("*")) (entget cloud2 '("*")) (entget arc '("*")))))
  (vla-Delete table)
  (foreach entity (list cloud cloud2 cloud-copy line arc closed-arc) (entdel entity))
  (setvar "CLAYER" old-layer)
  (princ))
(princ)
