;;; Layer scope is independent from the spatial selection.
(defun alc-test--stat-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "stat-layer-test.log")))
  (alc-test--write-lines "stat-layer-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test-run-stat-layer (/ samples selection a b c d totals subset before region-called name entity sample-points sample-picks sample-box corner-calls old-osmode result stat-events *alc-stat-last-layers* saved-layers sample-entity)
  (foreach name '("ALC_Filter_A" "ALC_Filter_B" "Other_Filter_C")
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
      '(100 . "AcDbLayerTableRecord") (cons 2 name) '(70 . 0) '(62 . 7) '(6 . "Continuous"))))
  (setq a (entmakex '((0 . "LINE") (8 . "ALC_Filter_A") (10 0.0 0.0 0.0) (11 1000.0 0.0 0.0)))
        b (entmakex '((0 . "LINE") (8 . "ALC_Filter_B") (10 0.0 10.0 0.0) (11 2000.0 10.0 0.0)))
        c (entmakex '((0 . "LINE") (8 . "Other_Filter_C") (10 0.0 20.0 0.0) (11 3000.0 20.0 0.0)))
        selection (ssadd))
  (foreach entity (list a b c) (ssadd entity selection))
  (setq d (entmakex '((0 . "TEXT") (8 . "ALC_Filter_A") (10 0.0 30.0 0.0) (40 . 10.0) (1 . "Layer sample")))
        samples (ssadd))
  (foreach entity (list a c d) (ssadd entity samples))
  (alc-test--stat-check "sample-objects-determine-layer-list"
    (equal (alc--stat-sample-layers samples) '("ALC_Filter_A" "Other_Filter_C")))
  (alc-test--stat-check "duplicate-layer-samples-are-deduplicated"
    (= (length (alc--stat-sample-layers samples)) 2))
  (setq subset (ssadd)) (ssadd d subset)
  (alc-test--stat-check "non-curve-object-can-identify-layer"
    (equal (alc--stat-sample-layers subset) '("ALC_Filter_A")))
  (alc-test--stat-check "empty-sample-selection-cancels"
    (not (alc--stat-sample-layers nil)))
  (setq subset (alc--stat-filter-selection selection '("alc_filter_a" "Other_Filter_C"))
        totals (alc--collect-layer-lengths subset))
  (alc-test--stat-check "only-selected-layer-rows-and-total"
    (and (= (length totals) 2) (not (assoc "ALC_Filter_B" totals))
      (equal (alc--total-layer-length totals) 4000.0 1e-6)))
  (setq totals (alc--collect-layer-lengths (alc--stat-filter-selection selection 'all)))
  (alc-test--stat-check "All-preserves-previous-region-total"
    (and (= (length totals) 3) (equal (alc--total-layer-length totals) 6000.0 1e-6)))
  (alc-test--stat-check "absent-layer-produces-no-selection"
    (not (alc--stat-filter-selection selection '("MissingLayer"))))
  (alc-test--stat-check "empty-region-produces-no-selection"
    (not (alc--stat-filter-selection nil '("ALC_Filter_A"))))
  ;; A single selected entity stands in for a small region: never expand to _X.
  (setq subset (ssadd)) (ssadd a subset)
  (alc-test--stat-check "scope-does-not-expand-beyond-region"
    (= (sslength (alc--stat-filter-selection subset 'all)) 1))
  (defun alc--stat-select-layer-objects ()
    (setq stat-events (append stat-events '(layers))) samples)
  (alc-test--stat-check "mouse-sample-choice-returns-sampled-layers"
    (equal (alc--stat-choose-layers) '("ALC_Filter_A" "Other_Filter_C")))
  (setq saved-layers '("ALC_Filter_A" "Other_Filter_C"))
  (alc-test--stat-check "explicit-pick-caches-layer-names"
    (equal *alc-stat-last-layers* saved-layers))
  (setq samples nil)
  (alc-test--stat-check "empty-confirmation-reuses-last-layer-pick"
    (equal (alc--stat-choose-layers) saved-layers))
  (setq samples 'all)
  (alc--stat-choose-layers)
  (setq samples nil)
  (alc-test--stat-check "All-is-reused-without-converting-to-a-fixed-layer-list"
    (eq (alc--stat-choose-layers) 'all))
  (setq samples (ssadd)) (ssadd b samples)
  (alc--stat-choose-layers)
  (setq samples nil)
  (alc-test--stat-check "new-object-pick-replaces-previous-All"
    (equal (alc--stat-choose-layers) '("ALC_Filter_B")))
  (setq *alc-stat-last-layers* '("ALC_Filter_A" "MissingLayer"))
  (alc-test--stat-check "reuse-skips-deleted-layers-without-selecting-All"
    (equal (alc--stat-choose-layers) '("ALC_Filter_A")))
  (setq *alc-stat-last-layers* '("MissingLayer"))
  (alc-test--stat-check "all-deleted-last-layers-cancel-instead-of-expanding-filter"
    (not (alc--stat-choose-layers)))
  (setq sample-entity (entmakex '((0 . "LINE") (8 . "ALC_Filter_A")
    (10 0.0 50.0 0.0) (11 100.0 50.0 0.0))) samples (ssadd))
  (ssadd sample-entity samples)
  (alc--stat-choose-layers)
  (entdel sample-entity)
  (setq samples nil)
  (alc-test--stat-check "deleting-sample-object-does-not-delete-last-layer-pick"
    (equal (alc--stat-choose-layers) '("ALC_Filter_A")))
  (setq *alc-stat-last-layers* nil)
  (alc-test--stat-check "first-use-empty-confirmation-has-no-implicit-All"
    (not (alc--stat-choose-layers)))
  (setq before (list (getvar "CLAYER") (getvar "PLINEWID") (entlast))
        samples nil region-called nil stat-events nil)
  (defun alc--ask-stat-text-height ()
    (setq stat-events (append stat-events '(height))) 150.0)
  (defun alc--stat-select-region (layers)
    (setq stat-events (append stat-events '(region)) region-called T) nil)
  (alc--stat-loop)
  (alc-test--stat-check "cancel-layer-choice-skips-region-and-preserves-drawing"
    (and (not region-called) (equal before (list (getvar "CLAYER") (getvar "PLINEWID") (entlast)))))
  (alc-test--stat-check "height-is-asked-before-layer-selection-even-if-cancelled"
    (equal stat-events '(height layers)))
  (setq samples (ssadd) stat-events nil region-called nil)
  (ssadd a samples)
  (alc--stat-loop)
  (alc-test--stat-check "prompt-order-height-then-layer-then-region"
    (and region-called (equal stat-events '(height layers region))))
  (load (strcat (getenv "ALCWALL_TEST_ROOT") "/src/alc-schedule.lsp"))
  (alc-test--stat-check "last-layer-pick-survives-module-reload"
    (equal *alc-stat-last-layers* '("ALC_Filter_A")))
  ;; Exercise the real picker; only the mouse/keyboard input boundary is stubbed.
  (defun alc--stat-read-sample-point (/ value)
    (setq value (car sample-points) sample-points (cdr sample-points)) value)
  (defun alc--stat-sample-at-point (point / value)
    (setq value (car sample-picks) sample-picks (cdr sample-picks)) value)
  (defun alc--stat-read-sample-corner (point)
    (setq corner-calls (1+ corner-calls)) '(20.0 20.0 0.0))
  (defun alc--stat-sample-in-box (first second) sample-box)
  (setq old-osmode (getvar "OSMODE") sample-box (ssadd) corner-calls 0)
  (ssadd a sample-box) (ssadd c sample-box)
  (setq sample-points '((0.0 0.0 0.0) nil) sample-picks '(nil))
  (setq result (alc--stat-select-layer-objects))
  (alc-test--stat-check "empty-space-click-starts-box-without-W"
    (and (= corner-calls 1)
      (equal (alc--stat-sample-layers result) '("ALC_Filter_A" "Other_Filter_C"))))
  (alc-test--stat-check "box-selection-restores-object-snaps"
    (= old-osmode (getvar "OSMODE")))
  (setq subset (ssadd)) (ssadd a subset)
  (setq sample-points '((1.0 1.0 0.0) (2.0 2.0 0.0) (0.0 0.0 0.0) nil)
        sample-picks (list subset subset nil) corner-calls 0)
  (setq result (alc--stat-select-layer-objects))
  (alc-test--stat-check "point-picks-and-box-accumulate-without-duplicates"
    (and (= (sslength result) 2) (= corner-calls 1)))
  (setq sample-points '((1.0 1.0 0.0) "All") sample-picks (list subset))
  (alc-test--stat-check "A-bypasses-layer-filter-after-picking-samples"
    (and (eq (alc--stat-select-layer-objects) 'all) (= old-osmode (getvar "OSMODE"))))
  (setq sample-points '(nil))
  (alc-test--stat-check "empty-Enter-cancels-with-snaps-preserved"
    (and (not (alc--stat-select-layer-objects)) (= old-osmode (getvar "OSMODE"))))
  (load (strcat (getenv "ALCWALL_TEST_ROOT") "/src/alc-schedule.lsp"))
  (foreach entity (list a b c d) (entdel entity))
  (princ))
(princ)
