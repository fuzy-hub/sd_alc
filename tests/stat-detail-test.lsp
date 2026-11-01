;;; One length row per curve, plus a single final total.
(defun alc-test--detail-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "stat-detail-test.log")))
  (alc-test--write-lines "stat-detail-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test-run-stat-detail (/ name a b line closed arc zero selection rows totals subset table old-table entity
    expected item index pass spatial-left spatial-top spatial-right spatial-same spatial-selection spatial-rows tiny-x high-pline tiny-y tie-object tie-selection reverse-selection entry result near-entries ordered)
  (foreach name '("ALC_Detail_A" "ALC_Detail_B" "ALC_Detail_C" "ALC_Detail_D")
    (if (not (tblsearch "LAYER" name))
      (entmake (list '(0 . "LAYER") (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous")))))
  (setq a (entmakex '((0 . "LWPOLYLINE") (100 . "AcDbEntity") (8 . "ALC_Detail_A")
      (100 . "AcDbPolyline") (90 . 3) (70 . 0) (10 0.0 0.0) (10 1000.0 0.0) (10 1000.0 2000.0)))
        b (entmakex '((0 . "LWPOLYLINE") (100 . "AcDbEntity") (8 . "ALC_Detail_A")
      (100 . "AcDbPolyline") (90 . 2) (70 . 0) (10 0.0 10.0) (10 3000.0 10.0)))
        line (entmakex '((0 . "LINE") (8 . "ALC_Detail_B") (10 0.0 20.0 0.0) (11 750.0 20.0 0.0)))
        closed (entmakex '((0 . "LWPOLYLINE") (100 . "AcDbEntity") (8 . "ALC_Detail_C")
      (100 . "AcDbPolyline") (90 . 4) (70 . 1)
      (10 0.0 0.0) (10 3000.0 0.0) (10 3000.0 4000.0) (10 0.0 4000.0)))
        arc (entmakex '((0 . "LWPOLYLINE") (100 . "AcDbEntity") (8 . "ALC_Detail_D")
      (100 . "AcDbPolyline") (90 . 2) (70 . 0) (10 0.0 0.0) (42 . 1.0) (10 1000.0 0.0)))
        zero (entmakex '((0 . "LINE") (8 . "ALC_Detail_A") (10 0.0 0.0 0.0) (11 0.0 0.0 0.0)))
        selection (ssadd) expected (+ 6000.0 750.0 (* pi 500.0)))
  (foreach entity (list a b line closed arc zero) (ssadd entity selection))
  (setq rows (alc--collect-length-rows selection))
  (alc-test--detail-check "one-row-per-positive-length-open-object" (= (length rows) 4))
  (setq subset (alc--collect-length-rows (alc--stat-filter-selection selection '("ALC_Detail_A"))))
  (alc-test--detail-check "same-layer-and-same-length-remain-two-rows"
    (and (= (length subset) 2) (= (caar subset) "ALC_Detail_A") (= (caadr subset) "ALC_Detail_A")
      (equal (cdar subset) 3000.0 1e-6) (equal (cdadr subset) 3000.0 1e-6)))
  (alc-test--detail-check "multi-vertex-pline-stays-one-row-with-full-length"
    (equal (cdr (assoc "ALC_Detail_A" rows)) (alc--curve-length a) 1e-6))
  (alc-test--detail-check "closed-pline-is-excluded-from-detail-rows"
    (not (assoc "ALC_Detail_C" rows)))
  (alc-test--detail-check "arc-length-not-chord-length"
    (equal (cdr (assoc "ALC_Detail_D" rows)) (* pi 500.0) 1e-6))
  (alc-test--detail-check "detail-grand-total-matches-all-object-lengths"
    (equal (alc--total-layer-length rows) expected 1e-6))
  (setq subset (alc--collect-length-rows (alc--stat-filter-selection selection '("ALC_Detail_A"))))
  (alc-test--detail-check "layer-filter-preserves-separate-detail-rows"
    (and (= (length subset) 2) (equal (alc--total-layer-length subset) 6000.0 1e-6)))
  (alc-test--detail-check "empty-selection-has-no-detail-rows"
    (not (alc--collect-length-rows nil)))
  (setq table (alc--add-length-detail-table rows '(20000.0 0.0 0.0) 100.0))
  (alc-test--detail-check "detail-table-has-four-data-rows-and-final-total"
    (= (vla-get-Rows table) 7))
  (setq index 2 pass T)
  (foreach item rows
    (if (not (and (= (vla-GetText table index 0) (itoa (1- index)))
                  (= (vla-GetText table index 1) (car item))
                  (= (vla-GetText table index 3) (rtos (/ (cdr item) 1000.0) 2 3))))
      (setq pass nil))
    (setq index (1+ index)))
  (alc-test--detail-check "detail-table-displays-each-object-in-spatial-order" pass)
  (alc-test--detail-check "last-row-displays-grand-total-in-metres"
    (and (= (vla-GetText table 6 1) "TỔNG CỘNG")
         (= (vla-GetText table 6 3) (rtos (/ expected 1000.0) 2 3))))
  ;; Other schedules continue to use the existing aggregated table wrapper.
  (setq totals (alc--collect-layer-lengths selection)
        old-table (alc--add-length-table totals '(40000.0 0.0 0.0) 100.0))
  (alc-test--detail-check "summary-excludes-layer-containing-only-closed-pline"
    (and (= (vla-get-Rows old-table) 6)
      (= (vla-GetText old-table 1 3) "CHIỀU DÀI TỔNG THEO LAYER")
      (= (vla-GetText old-table 2 3) (rtos 6.0 2 3))))
  ;; Pick order and endpoint direction intentionally disagree with spatial order.
  (setq spatial-left (entmakex '((0 . "LINE") (8 . "ALC_Detail_A") (10 -200.0 -100.0 0.0) (11 -100.0 -100.0 0.0)))
        spatial-top (entmakex '((0 . "LINE") (8 . "ALC_Detail_B") (10 0.0 500.0 0.0) (11 -200.0 500.0 0.0)))
        spatial-right (entmakex '((0 . "LINE") (8 . "ALC_Detail_C") (10 100.0 1000.0 0.0) (11 400.0 1000.0 0.0)))
        spatial-same (entmakex '((0 . "LINE") (8 . "ALC_Detail_B") (10 -200.0 500.0 0.0) (11 0.0 500.0 0.0)))
        spatial-selection (ssadd))
  (foreach entity (list spatial-right spatial-left spatial-top spatial-same) (ssadd entity spatial-selection))
  (setq spatial-rows (alc--collect-length-rows spatial-selection))
  (alc-test--detail-check "left-before-right-even-when-right-object-is-higher"
    (and (= (length spatial-rows) 4) (= (car (last spatial-rows)) "ALC_Detail_C")))
  (alc-test--detail-check "same-left-edge-sorts-top-before-bottom"
    (equal (mapcar 'cdr spatial-rows) '(200.0 200.0 100.0 300.0)))
  (alc-test--detail-check "reversed-vertices-use-left-edge-not-start-point"
    (= (caar spatial-rows) "ALC_Detail_B"))
  (alc-test--detail-check "coincident-equal-length-objects-remain-two-rows"
    (and (equal (car spatial-rows) (cadr spatial-rows))
      (equal (alc--total-layer-length spatial-rows) 800.0 1e-6)))
  (setq tiny-x (entmakex '((0 . "LINE") (8 . "ALC_Detail_C")
          (10 -199.9999999 2000.0 0.0) (11 200.0000001 2000.0 0.0)))
        high-pline (entmakex '((0 . "LWPOLYLINE") (100 . "AcDbEntity") (8 . "ALC_Detail_D")
          (100 . "AcDbPolyline") (90 . 3) (70 . 0)
          (10 -200.0 -200.0) (10 -100.0 3000.0) (10 0.0 -300.0)))
        tiny-y (entmakex '((0 . "LINE") (8 . "ALC_Detail_C")
          (10 -200.0 500.0000001 0.0) (11 400.0 500.0000001 0.0)))
        tie-object (entmakex '((0 . "LINE") (8 . "ALC_Detail_D")
          (10 -200.0 500.0 0.0) (11 -200.0 100.0 0.0))))
  (setq tie-selection (ssadd)) (ssadd tiny-x tie-selection) (ssadd spatial-left tie-selection)
  (alc-test--detail-check "near-Xmin-uses-Ymax-first"
    (equal (mapcar 'car (alc--collect-length-rows tie-selection)) '("ALC_Detail_C" "ALC_Detail_A")))
  (setq entry (alc--stat-length-entry high-pline "ALC_Detail_D" (alc--curve-length high-pline)))
  (alc-test--detail-check "extents-are-Xmin-and-Ymax-not-start-or-lowest-vertex"
    (and (= (car entry) -200.0) (= (cadr entry) 3000.0)))
  (setq tie-selection (ssadd)) (ssadd spatial-top tie-selection) (ssadd high-pline tie-selection)
  (alc-test--detail-check "equal-Xmin-highest-Ymax-wins-even-with-lower-start-point"
    (= (caar (alc--collect-length-rows tie-selection)) "ALC_Detail_D"))
  (setq tie-selection (ssadd)) (ssadd spatial-top tie-selection) (ssadd tiny-y tie-selection)
  (alc-test--detail-check "strict-Ymax-includes-tiny-height-differences"
    (= (caar (alc--collect-length-rows tie-selection)) "ALC_Detail_C"))
  (setq tie-selection (ssadd) reverse-selection (ssadd))
  (ssadd tie-object tie-selection) (ssadd spatial-top tie-selection)
  (ssadd spatial-top reverse-selection) (ssadd tie-object reverse-selection)
  (alc-test--detail-check "exact-spatial-ties-remain-stable-across-opposite-selection-orders"
    (and (equal (alc--collect-length-rows tie-selection) (alc--collect-length-rows reverse-selection))
      (= (length (alc--collect-length-rows tie-selection)) 2)))
  ;; Tolerance boundaries and grouping must not depend on pick order.
  (setq near-entries '((0.0 0.0 "101" ("Left" . 100.0))
                       (9.999999 100.0 "102" ("Near" . 200.0))
                       (10.0 200.0 "103" ("Boundary" . 300.0))))
  (setq ordered (mapcar 'cadddr (alc--stat-sort-entries near-entries)))
  (alc-test--detail-check "X-difference-under-10-sorts-highest-Ymax-first"
    (equal (mapcar 'car ordered) '("Near" "Left" "Boundary")))
  (alc-test--detail-check "X-difference-exactly-10-starts-new-group"
    (equal (mapcar 'car (mapcar 'cadddr (alc--stat-sort-entries
      (list (car near-entries) (caddr near-entries))))) '("Left" "Boundary")))
  (alc-test--detail-check "grouping-independent-of-selection-order"
    (equal ordered (mapcar 'cadddr (alc--stat-sort-entries (reverse near-entries)))))
  (alc-test--detail-check "chain-of-near-X-does-not-merge-wide-columns"
    (equal (mapcar 'car (mapcar 'cadddr (alc--stat-sort-entries
      '((0.0 0.0 "101" ("Zero" . 100.0))
        (9.0 100.0 "102" ("Nine" . 200.0))
        (18.0 200.0 "103" ("Eighteen" . 300.0)))))) '("Nine" "Zero" "Eighteen")))
  (alc-test--detail-check "negative-X-coordinates-use-same-under-10-rule"
    (equal (mapcar 'car (mapcar 'cadddr (alc--stat-sort-entries
      '((-20.0 0.0 "101" ("Left" . 100.0))
        (-10.000001 100.0 "102" ("Near" . 200.0))
        (-10.0 200.0 "103" ("Boundary" . 300.0)))))) '("Near" "Left" "Boundary")))
  (defun alc--object-bounds (entity) nil)
  (setq result (vl-catch-all-apply 'alc--stat-length-entry
    (list high-pline "ALC_Detail_D" (alc--curve-length high-pline))))
  (alc-test--detail-check "missing-extents-fails-explicitly-instead-of-using-start-point"
    (vl-catch-all-error-p result))
  (load (strcat (getenv "ALCWALL_TEST_ROOT") "/src/alc-align.lsp"))
  (foreach entity (list tiny-x high-pline tiny-y tie-object) (entdel entity))
  (foreach entity (list spatial-left spatial-top spatial-right spatial-same) (entdel entity))
  (vla-Delete table) (vla-Delete old-table)
  (foreach entity (list a b line closed arc zero) (entdel entity))
  (alc-test-run-stat-closed)
  (princ))
(defun alc-test--stat-legacy-polyline (points flags / point)
  (entmake (list '(0 . "POLYLINE") '(66 . 1) '(8 . "ALC_Detail_A")
    (cons 70 flags) '(10 0.0 0.0 0.0)))
  (foreach point points
    (entmake (list '(0 . "VERTEX") '(8 . "ALC_Detail_A") (cons 10 point)
      (cons 70 (if (= (logand flags 8) 8) 32 0)))))
  (entmake '((0 . "SEQEND")))
  (entlast))

(defun alc-test-run-stat-closed (/ closed2 closed3 open2 open3 closed-lw open-lw
    entities before selection closed-only rows totals expected entity data)
  (setq closed2 (alc-test--stat-legacy-polyline '((0.0 0.0 0.0) (3000.0 0.0 0.0) (3000.0 4000.0 0.0)) 1)
        closed3 (alc-test--stat-legacy-polyline '((0.0 0.0 0.0) (0.0 300.0 400.0) (1200.0 300.0 400.0)) 9)
        open2 (alc-test--stat-legacy-polyline '((0.0 0.0 0.0) (3000.0 0.0 0.0) (3000.0 4000.0 0.0)) 0)
        open3 (alc-test--stat-legacy-polyline '((0.0 0.0 0.0) (0.0 300.0 400.0) (1200.0 300.0 400.0)) 8)
        closed-lw (alc--create-lwpolyline-wcs-on-layer
          '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0)) T '(0.0 0.0 1.0) "ALC_Detail_A")
        open-lw (alc--create-lwpolyline-wcs-on-layer
          '((0.0 0.0 0.0) (1000.0 0.0 0.0)) nil '(0.0 0.0 1.0) "ALC_Detail_A"))
  (foreach entity (list closed-lw open-lw)
    (setq data (entget entity))
    (entmod (subst (cons 70 (logior (cdr (assoc 70 data)) 128)) (assoc 70 data) data)))
  (vla-SetBulge (vlax-ename->vla-object closed-lw) 0 0.5)
  (setq entities (list closed2 closed3 open2 open3 closed-lw open-lw)
        before (mapcar 'entget entities) selection (ssadd) closed-only (ssadd)
        expected 9700.0)
  (foreach entity entities (ssadd entity selection))
  (foreach entity (list closed2 closed3 closed-lw) (ssadd entity closed-only))
  (alc-test--detail-check "legacy-2D-closed-polyline-is-excluded"
    (and (= (cdr (assoc 0 (entget closed2))) "POLYLINE")
      (not (alc--collect-length-rows (ssadd closed2)))))
  (alc-test--detail-check "legacy-3D-closed-polyline-is-excluded"
    (and (= (logand (cdr (assoc 70 (entget closed3))) 9) 9)
      (not (alc--collect-length-rows (ssadd closed3)))))
  (alc-test--detail-check "closed-curved-LWPOLYLINE-with-flag-129-is-excluded"
    (and (= (cdr (assoc 70 (entget closed-lw))) 129)
      (not (alc--collect-length-rows (ssadd closed-lw)))))
  (alc-test--detail-check "open-LWPOLYLINE-with-flag-128-is-kept"
    (equal (alc--total-layer-length (alc--collect-length-rows (ssadd open-lw))) 1000.0 1e-6))
  (alc-test--detail-check "open-legacy-2D-and-3D-polylines-keep-full-length"
    (and (equal (alc--total-layer-length (alc--collect-length-rows (ssadd open2))) 7000.0 1e-6)
      (equal (alc--total-layer-length (alc--collect-length-rows (ssadd open3))) 1700.0 1e-6)))
  (setq rows (alc--collect-length-rows (alc--stat-filter-selection selection 'all))
        totals (alc--collect-layer-lengths selection))
  (alc-test--detail-check "All-mode-mixed-selection-has-only-three-open-rows"
    (and (= (length rows) 3) (equal (alc--total-layer-length rows) expected 1e-6)))
  (alc-test--detail-check "aggregate-total-also-excludes-every-closed-polyline"
    (and (= (length totals) 1) (equal (alc--total-layer-length totals) expected 1e-6)))
  (alc-test--detail-check "closed-only-selection-produces-no-rows-or-total"
    (and (not (alc--collect-length-rows closed-only)) (not (alc--collect-layer-lengths closed-only))))
  (alc-test--detail-check "statistics-leaves-all-source-polylines-unchanged"
    (equal before (mapcar 'entget entities)))
  (alc-test--detail-check "VVFILTER-layer-selection-still-includes-closed-polylines"
    (= (sslength (alc--stat-filter-selection selection '("ALC_Detail_A"))) 6))
  (foreach entity entities (entdel entity))
  (princ))
(princ)
