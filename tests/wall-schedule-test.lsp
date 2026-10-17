;;; AutoCAD 2027 regression cases for ALC wall type/length schedules.
(defun alc-test--wall-schedule-check (name passed)
  (setq checks (cons (strcat (if passed "PASS " "FAIL ") name) checks))
  (alc-test--write-lines "wall-schedule-test.log" (reverse checks)))

(defun alc-test--schedule-rectangle (width wall-length y)
  (alc-test--create-wall
    (list (list 0.0 y 0.0) (list wall-length y 0.0)
      (list wall-length (+ y width) 0.0) (list 0.0 (+ y width) 0.0))))

(defun alc-test--schedule-shift (points / result)
  (append (cdr points) (list (car points))))

(defun alc-test--schedule-group-length (totals width / item result)
  (foreach item totals
    (if (equal (car item) width 1e-6) (setq result (cdr item))))
  result)

(defun alc-test--schedule-all-metrics (selection width / index entity metrics valid)
  (setq index 0 valid (and selection T))
  (if selection
    (repeat (sslength selection)
      (setq entity (ssname selection index) index (1+ index)
            metrics (alc--wall-type-metrics entity))
      (if (not (and metrics (equal (car metrics) width 1e-6)
                    (equal (alc--wall-tag-width entity) width 1e-6)))
        (setq valid nil))))
  valid)

(defun alc-test-run-wall-schedule
  (/ checks old-layer old-pattern old-thickness old-door-width old-temp
    l-points u-points normal metrics wall-100 wall-150 wall-200 hatch-100
    selection totals other-layer generic wrong-layer lintel layer-data before
    wall hatch door-result table row result boundary data copies copy single)
  (setq checks nil old-layer (getvar "CLAYER") old-pattern *alc-pattern*
        old-thickness *alc-thickness* old-door-width *alc-door-width*
        old-temp *alc-temp-entities* normal '(0.0 0.0 1.0))
  (alc-test--clear)
  (alc--ensure-wall-layer)
  (setvar "CLAYER" "0. Tuong ALC")
  (setq *alc-pattern* "ANSI37" *alc-thickness* 100.0
        l-points '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0)
          (800.0 1000.0 0.0) (800.0 200.0 0.0) (0.0 200.0 0.0))
        u-points '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0)
          (0.0 1000.0 0.0) (0.0 800.0 0.0) (800.0 800.0 0.0)
          (800.0 200.0 0.0) (0.0 200.0 0.0)))
  (alc-test--wall-schedule-check "straight-metrics-use-centerline-not-perimeter"
    (equal (alc--wall-strip-metrics
      '((0.0 0.0 0.0) (3000.0 0.0 0.0) (3000.0 100.0 0.0) (0.0 100.0 0.0)))
      '(100.0 3000.0) 1e-6))
  (alc-test--wall-schedule-check "L-wall-centerline-length"
    (equal (alc--wall-strip-metrics l-points) '(200.0 1800.0) 1e-6))
  (alc-test--wall-schedule-check "U-wall-centerline-length"
    (equal (alc--wall-strip-metrics u-points) '(200.0 2600.0) 1e-6))
  (alc-test--wall-schedule-check "cyclic-vertex-order-supported"
    (equal (alc--wall-strip-metrics (alc-test--schedule-shift l-points))
      '(200.0 1800.0) 1e-6))
  (alc-test--wall-schedule-check "reversed-vertex-order-supported"
    (equal (alc--wall-strip-metrics (reverse u-points)) '(200.0 2600.0) 1e-6))
  (alc-test--wall-schedule-check "rotated-geometry-supported"
    (equal (alc--wall-strip-metrics
      (mapcar '(lambda (p)
        (list (- (* (car p) (cos 0.37)) (* (cadr p) (sin 0.37)))
          (+ (* (car p) (sin 0.37)) (* (cadr p) (cos 0.37))) 0.0)) l-points))
      '(200.0 1800.0) 1e-5))
  (alc-test--wall-schedule-check "nonuniform-trapezoid-excluded"
    (not (alc--wall-strip-metrics
      '((0.0 0.0 0.0) (3000.0 0.0 0.0) (3000.0 200.0 0.0) (0.0 100.0 0.0)))))
  (alc-test--wall-schedule-check "self-crossing-polygon-excluded"
    (not (alc--wall-strip-metrics
      '((0.0 0.0 0.0) (1000.0 1000.0 0.0) (0.0 1000.0 0.0) (1000.0 0.0 0.0)))))
  (setq wall-100 (alc-test--schedule-rectangle 100.0 3000.0 0.0)
        wall-150 (alc-test--schedule-rectangle 150.0 2000.0 1000.0)
        wall-200 (alc-test--schedule-rectangle 200.0 4000.0 2000.0)
        hatch-100 (car (alc--find-boundary-hatches wall-100)))
  (alc-test--wall-schedule-check "legacy-ALC-wall-supported-without-tag"
    (and (not (alc--wall-tag-width wall-100))
         (equal (alc--wall-type-metrics wall-100) '(100.0 3000.0) 1e-6)))
  (setq generic (alc--create-lwpolyline-wcs
    '((0.0 3000.0 0.0) (3000.0 3000.0 0.0) (3000.0 3100.0 0.0) (0.0 3100.0 0.0))
    T normal))
  (alc-test--wall-schedule-check "untagged-polyline-without-hatch-excluded"
    (not (alc--wall-type-metrics generic)))
  (setq other-layer "ALC_SCHEDULE_OTHER")
  (if (not (tblobjname "LAYER" other-layer))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
      '(100 . "AcDbLayerTableRecord") (cons 2 other-layer) '(70 . 0) '(62 . 3) '(6 . "Continuous"))))
  (setvar "CLAYER" other-layer)
  (setq wrong-layer (alc-test--schedule-rectangle 100.0 3000.0 4000.0))
  (alc-test--wall-schedule-check "untagged-other-layer-excluded"
    (not (alc--wall-type-metrics wrong-layer)))
  (setq *alc-thickness* 100.0)
  (regapp "ALC_SCHEDULE_TEST")
  (entmod (append (entget wrong-layer)
    '((-3 ("ALC_SCHEDULE_TEST" (1000 . "keep-existing-data"))))))
  (alc-test--wall-schedule-check "wall-tag-created"
    (and (alc--wall-tag wrong-layer)
         (equal (alc--wall-tag-width wrong-layer) 100.0 1e-6)))
  (alc-test--wall-schedule-check "tag-keeps-unrelated-XData"
    (equal (assoc -3 (entget wrong-layer '("ALC_SCHEDULE_TEST")))
      '(-3 ("ALC_SCHEDULE_TEST" (1000 . "keep-existing-data")))))
  (alc-test--wall-schedule-check "tagged-custom-layer-wall-supported"
    (equal (alc--wall-type-metrics wrong-layer) '(100.0 3000.0) 1e-6))
  (setvar "CLAYER" "0. Tuong ALC")
  (setq *alc-pattern* "ANSI31"
        lintel (alc-test--schedule-rectangle 150.0 3000.0 5000.0))
  (alc-test--wall-schedule-check "legacy-lintel-wall-tie-ANSI31-excluded"
    (not (alc--wall-type-metrics lintel)))
  (setq *alc-pattern* "ANSI37" selection (ssadd))
  (foreach wall (list wall-100 wall-150 wall-200 hatch-100 generic lintel)
    (ssadd wall selection))
  (setq totals (alc--collect-wall-types selection))
  (alc-test--wall-schedule-check "group-widths-100-150-200"
    (and (= (length totals) 3)
         (equal (alc-test--schedule-group-length totals 100.0) 3000.0 1e-6)
         (equal (alc-test--schedule-group-length totals 150.0) 2000.0 1e-6)
         (equal (alc-test--schedule-group-length totals 200.0) 4000.0 1e-6)))
  (alc-test--wall-schedule-check "boundary-plus-hatch-counted-once"
    (equal (alc-test--schedule-group-length totals 100.0) 3000.0 1e-6))
  (alc-test--wall-schedule-check "collector-releases-hatch-index"
    (not *alc-hatch-index*))
  (setq layer-data (entget (tblobjname "LAYER" "0. Tuong ALC"))
        before (entget wall-100))
  (entmod (subst (cons 70 (logior 4 (cdr (assoc 70 layer-data))))
    (assoc 70 layer-data) layer-data))
  (alc-test--wall-schedule-check "locked-layer-is-counted-without-modification"
    (and (equal (alc--wall-type-metrics wall-100) '(100.0 3000.0) 1e-6)
         (equal before (entget wall-100))))
  (entmod layer-data)
  (setq table (alc--add-wall-type-table totals "TEST ALC WALLS" '(5000.0 0.0 0.0) 50.0))
  (alc-test--wall-schedule-check "table-custom-title-and-row-count"
    (and table (= (vla-get-Rows table) 7)
         (= (vla-GetText table 0 0) "TEST ALC WALLS")))
  (alc-test--wall-schedule-check "table-without-doors-has-explicit-empty-door-section"
    (= (vla-GetText table 6 0) "KHÔNG CÓ CỬA ĐƯỢC CỘNG TRONG VÙNG CHỌN"))
  (alc-test--wall-schedule-check "table-has-ALC-type-column-and-meter-values"
    (and (wcmatch (strcase (vla-GetText table 1 1)) "*ALC*")
         (wcmatch (vla-GetText table 2 1) "*100*")
         (wcmatch (vla-GetText table 3 1) "*150*")
         (wcmatch (vla-GetText table 4 1) "*200*")
         (equal (distof (vla-GetText table 2 3) 2) 3.0 1e-6)
         (equal (distof (vla-GetText table 3 3) 2) 2.0 1e-6)
         (equal (distof (vla-GetText table 4 3) 2) 4.0 1e-6)
         (equal (distof (vla-GetText table 5 3) 2) 9.0 1e-6)))
  (setq wall (alc-test--schedule-rectangle 200.0 3000.0 7000.0)
        *alc-thickness* 200.0)
  (alc--wall-tag wall)
  (alc-test--wall-schedule-check "trim-updates-current-centerline-length"
    (and (alc--shorten-wall wall '(0.0 7100.0 0.0) 20.0)
         (equal (alc--wall-type-metrics wall) '(200.0 2980.0) 1e-6)))
  (alc-test--wall-schedule-check "extend-updates-current-centerline-length"
    (and (alc--extend-wall wall '(0.0 7100.0 0.0) 50.0)
         (equal (alc--wall-type-metrics wall) '(200.0 3030.0) 1e-6)
         (equal (alc--wall-tag-width wall) 200.0 1e-6)))
  (alc-test--clear)
  (setq *alc-thickness* 200.0 *alc-door-width* 900.0
        wall (alc-test--schedule-rectangle 200.0 3000.0 0.0))
  (alc--wall-tag wall)
  ;; The first remainder is 50 mm long but still a 200 mm wall.
  (setq door-result (alc--draw-door-opening wall '(-100.0 100.0 0.0) '(50.0 100.0 0.0))
        selection (ssget "_X" '((0 . "LWPOLYLINE"))))
  (alc-test--wall-schedule-check "door-replacements-retain-width-tag"
    (and door-result selection (= (sslength selection) 2)
         (alc-test--schedule-all-metrics selection 200.0)))
  (setq totals (alc--collect-wall-types selection))
  (alc-test--wall-schedule-check "door-opening-included-once-and-short-stub-keeps-type"
    (and (= (length totals) 1)
         (equal (alc-test--schedule-group-length totals 200.0) 3000.0 1e-6)))
  (alc-test--wall-schedule-check "door-900-count-is-one-recorded"
    (equal (assoc 900.0 *alc-stat-door-types*) '(900.0 1 0)))
  (setq single (ssadd))
  (repeat (sslength selection)
    (setq wall (ssname selection 0))
    (if (equal (cadr (alc--wall-type-metrics wall)) 50.0 1e-6) (ssadd wall single))
    (ssdel wall selection))
  (alc-test--wall-schedule-check "one-door-side-does-not-add-unselected-opening"
    (equal (alc-test--schedule-group-length (alc--collect-wall-types single) 200.0) 50.0 1e-6))
  (alc-test--wall-schedule-check "one-door-side-has-no-door-count" (not *alc-stat-door-types*))
  (setq selection (ssget "_X" '((0 . "LWPOLYLINE,HATCH"))))
  (alc-test--wall-schedule-check "door-boundaries-plus-hatches-do-not-duplicate-opening"
    (equal (alc-test--schedule-group-length (alc--collect-wall-types selection) 200.0) 3000.0 1e-6))
  (alc-test--wall-schedule-check "boundary-hatch-does-not-duplicate-door-count"
    (equal (assoc 900.0 *alc-stat-door-types*) '(900.0 1 0)))
  (setq selection (ssget "_X" '((0 . "LWPOLYLINE"))) row 0 copies nil)
  (repeat (sslength selection)
    (setq copy (vla-Copy (vlax-ename->vla-object (ssname selection row))) row (1+ row))
    (vla-Move copy (vlax-3d-point '(0.0 0.0 0.0)) (vlax-3d-point '(0.0 10000.0 0.0)))
    (setq copies (cons copy copies)))
  (alc-test--wall-schedule-check "copied-door-pair-uses-transformed-opening-points"
    (equal (alc-test--schedule-group-length
      (alc--collect-wall-types (ssget "_X" '((0 . "LWPOLYLINE")))) 200.0) 6000.0 1e-6))
  (alc-test--wall-schedule-check "copied-doors-count-two-recorded"
    (equal (assoc 900.0 *alc-stat-door-types*) '(900.0 2 0)))
  (foreach copy copies (vla-Delete copy))
  (setq wall nil selection (ssget "_X" '((0 . "LWPOLYLINE"))) row 0)
  (repeat (sslength selection)
    (setq boundary (ssname selection row) row (1+ row))
    (if (> (cadr (alc--wall-type-metrics boundary)) 1000.0) (setq wall boundary)))
  (alc-test--wall-schedule-check "two-doors-on-one-wall-are-each-added-once"
    (and wall (alc--draw-door-opening wall '(950.0 100.0 0.0) '(1600.0 100.0 0.0))
      (equal (alc-test--schedule-group-length
        (alc--collect-wall-types (ssget "_X" '((0 . "LWPOLYLINE,HATCH")))) 200.0) 3000.0 1e-6)))
  (alc-test--wall-schedule-check "two-cuts-count-two-doors-of-900"
    (equal (assoc 900.0 *alc-stat-door-types*) '(900.0 2 0)))
  (alc-test--clear)
  (setq *alc-thickness* 200.0 wall (alc-test--schedule-rectangle 200.0 3000.0 0.0))
  (alc-test--wall-schedule-check "new-cut-on-legacy-wall-retains-width-and-does-not-double-gap"
    (and (alc--draw-door-opening wall '(-100.0 100.0 0.0) '(50.0 100.0 0.0))
      (equal (alc-test--schedule-group-length
        (alc--collect-wall-types (ssget "_X" '((0 . "LWPOLYLINE,HATCH")))) 200.0) 3000.0 1e-6)
      (= *alc-stat-inferred-openings* 0)))
  (alc-test--clear)
  (setq *alc-thickness* 200.0)
  (alc-test--schedule-rectangle 200.0 2000.0 0.0)
  (alc-test--create-wall '((2900.0 0.0 0.0) (4900.0 0.0 0.0)
    (4900.0 200.0 0.0) (2900.0 200.0 0.0)))
  (alc-test--create-wall '((5800.0 0.0 0.0) (7800.0 0.0 0.0)
    (7800.0 200.0 0.0) (5800.0 200.0 0.0)))
  (alc-test--wall-schedule-check "legacy-two-gaps-added-once-without-bridging-over-middle-wall"
    (and (equal (alc-test--schedule-group-length
      (alc--collect-wall-types (ssget "_X" '((0 . "LWPOLYLINE,HATCH")))) 200.0) 7800.0 1e-6)
      (= *alc-stat-inferred-openings* 2)))
  (alc-test--wall-schedule-check "legacy-900-doors-count-two-inferred"
    (equal (assoc 900.0 *alc-stat-door-types*) '(900.0 0 2)))
  (alc-test--clear)
  (alc-test--schedule-rectangle 200.0 50.0 0.0)
  (alc-test--create-wall '((950.0 0.0 0.0) (3000.0 0.0 0.0)
    (3000.0 200.0 0.0) (950.0 200.0 0.0)))
  (alc-test--wall-schedule-check "old-short-door-stub-inherits-width-of-selected-neighbor"
    (and (setq totals (alc--collect-wall-types (ssget "_X" '((0 . "LWPOLYLINE,HATCH")))))
      (= (length totals) 1)
      (equal (alc-test--schedule-group-length totals 200.0) 3000.0 1e-6)
      (= *alc-stat-inferred-openings* 1)))
  (alc-test--clear)
  (setq wall (alc-test--schedule-rectangle 200.0 2000.0 0.0))
  (alc--wall-tag wall)
  (setq wall (alc-test--create-wall '((2900.0 0.0 0.0) (4900.0 0.0 0.0)
    (4900.0 200.0 0.0) (2900.0 200.0 0.0))))
  (alc--wall-tag wall)
  (alc-test--wall-schedule-check "new-independent-walls-do-not-get-invented-door"
    (and (equal (alc-test--schedule-group-length
      (alc--collect-wall-types (ssget "_X" '((0 . "LWPOLYLINE,HATCH")))) 200.0) 4000.0 1e-6)
      (= *alc-stat-inferred-openings* 0)))
  (alc-test--wall-schedule-check "door-statistics-reset-for-selection-without-doors"
    (not *alc-stat-door-types*))
  (alc-test--clear)
  (alc-test--schedule-rectangle 200.0 2000.0 0.0)
  (alc-test--create-wall '((2900.0 1000.0 0.0) (4900.0 1000.0 0.0)
    (4900.0 1200.0 0.0) (2900.0 1200.0 0.0)))
  (alc-test--create-wall '((2900.0 25.0 0.0) (4900.0 25.0 0.0)
    (4900.0 175.0 0.0) (2900.0 175.0 0.0)))
  (alc-test--wall-schedule-check "legacy-off-axis-or-different-width-does-not-create-gap"
    (and (equal (alc-test--schedule-group-length
      (alc--collect-wall-types (ssget "_X" '((0 . "LWPOLYLINE,HATCH")))) 200.0) 4000.0 1e-6)
      (= *alc-stat-inferred-openings* 0)))
  (alc-test--clear)
  (setq *alc-thickness* 150.0 boundary (alc--track-temp (alc--create-lwpolyline-wcs
    '((0.0 0.0 0.0) (3000.0 0.0 0.0) (3000.0 150.0 0.0) (0.0 150.0 0.0)) T normal)))
  (alc-test--wall-schedule-check "new-wall-commit-records-provenance-and-width"
    (and (alc--commit-wall boundary)
         (equal (alc--wall-tag-width boundary) 150.0 1e-6)
         (equal (alc--wall-type-metrics boundary) '(150.0 3000.0) 1e-6)))
  (setq *alc-pattern* old-pattern *alc-thickness* old-thickness
        *alc-door-width* old-door-width *alc-temp-entities* old-temp)
  (setvar "CLAYER" old-layer)
  (alc--save-settings)
  (alc-test--write-lines "wall-schedule-test.log" (reverse checks))
  (princ))

(defun alc-test--wall-schedule-append (name passed / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "wall-schedule-test.log")))
  (alc-test--write-lines "wall-schedule-test.log"
    (append lines (list (strcat (if passed "PASS " "FAIL ") name)))))

(defun alc-test-wall-schedule-prepare (/ wall saved-door-width)
  (alc-test--clear)
  (alc--ensure-wall-layer)
  (setvar "CLAYER" "0. Tuong ALC")
  (setq *alc-pattern* "ANSI37")
  (setq saved-door-width *alc-door-width* *alc-door-width* 900.0
        wall (alc-test--schedule-rectangle 100.0 3000.0 0.0))
  (alc--draw-door-opening wall '(-100.0 50.0 0.0) '(1000.0 50.0 0.0))
  (setq *alc-door-width* 1200.0 wall (alc-test--schedule-rectangle 150.0 2000.0 1000.0))
  (alc--draw-door-opening wall '(-100.0 1075.0 0.0) '(400.0 1075.0 0.0))
  (setq *alc-door-width* saved-door-width)
  (alc-test--schedule-rectangle 200.0 1000.0 2000.0)
  (alc-test--create-wall '((1900.0 2000.0 0.0) (4000.0 2000.0 0.0)
    (4000.0 2200.0 0.0) (1900.0 2200.0 0.0)))
  (alc--create-lwpolyline-wcs
    '((0.0 3000.0 0.0) (3000.0 3000.0 0.0)
      (3000.0 3100.0 0.0) (0.0 3100.0 0.0)) T '(0.0 0.0 1.0))
  (setq *alc-pattern* "ANSI31")
  (alc-test--schedule-rectangle 150.0 3000.0 4000.0)
  (setq *alc-pattern* "ANSI37")
  (vl-cmdf "_.ZOOM" "_Extents")
  ;; Both selection corners and the insertion point must be visible to ssget.
  (vl-cmdf "_.ZOOM" "_Window" '(-1000.0 -1000.0 0.0) '(15000.0 8000.0 0.0))
  (princ))

(defun alc-test-wall-schedule-check-command (/ selection table)
  (setq selection (ssget "_X" '((0 . "ACAD_TABLE"))))
  (alc-test--wall-schedule-append "ALCTKT-interactive-creates-one-table"
    (and selection (= (sslength selection) 1)))
  (if (and selection (= (sslength selection) 1))
    (setq table (vlax-ename->vla-object (ssname selection 0))))
  (alc-test--wall-schedule-append "ALCTKT-interactive-custom-title-and-rows"
    (and table (= (vla-get-Rows table) 11)
      (= (vla-GetText table 0 0) "BANG TUONG TANG 1")))
  (alc-test--wall-schedule-append "ALCTKT-interactive-types-and-net-meter-total"
    (and table (wcmatch (vla-GetText table 2 1) "*100*")
      (wcmatch (vla-GetText table 3 1) "*150*")
      (wcmatch (vla-GetText table 4 1) "*200*")
      (equal (distof (vla-GetText table 5 3) 2) 9.0 1e-6)))
  (alc-test--wall-schedule-append "ALCTKT-table-door-widths-counts-sources-and-total"
    (and table (= (vla-GetText table 8 1) "900")
      (= (vla-GetText table 8 2) "2")
      (wcmatch (vla-GetText table 8 3) "*1*1*")
      (= (vla-GetText table 9 1) "1200") (= (vla-GetText table 9 2) "1")
      (wcmatch (vla-GetText table 9 3) "*1*0*")
      (= (vla-GetText table 10 2) "3")
      (equal (atof (substr (vla-GetText table 10 3)
        (+ (vl-string-search ": " (vla-GetText table 10 3)) 3))) 3.0 1e-6)))
  (if table
    (alc-test--write-lines "wall-schedule-test.log"
      (append (alc-test--read-lines (alc-test--result-path "wall-schedule-test.log"))
        (list (strcat "INFO door-900=" (vla-GetText table 8 2)
          " / door-1200=" (vla-GetText table 9 2)
          " / total=" (vla-GetText table 10 2))))))
  (princ))

(defun alc-test-wall-schedule-check-undo (/ selection totals)
  (setq selection (ssget "_X" '((0 . "LWPOLYLINE"))))
  (if selection (setq totals (alc--collect-wall-types selection)))
  (alc-test--wall-schedule-append "ALCTKT-one-undo-removes-table-and-keeps-walls"
    (and (= (alc-test--entity-count "ACAD_TABLE") 0)
      (= (alc-test--entity-count "LWPOLYLINE") 8)
      (= (alc-test--entity-count "HATCH") 7)
      (= (length totals) 3)
      (equal (alc-test--schedule-group-length totals 100.0) 3000.0 1e-6)
      (equal (alc-test--schedule-group-length totals 150.0) 2000.0 1e-6)
      (equal (alc-test--schedule-group-length totals 200.0) 4000.0 1e-6)))
  (princ))

(princ)
