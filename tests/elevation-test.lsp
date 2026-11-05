(defun alc-test--mc-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "elevation-test.log")))
  (alc-test--write-lines "elevation-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))
(defun alc-test--mc-sum (values joint) (+ (apply '+ values) (* joint (1- (length values)))))
(defun alc-test-run-elevation (/ cfg plan stats valid piece lower upper saved count result normal a b selection area)
  (alc-test--clear)
  (setq cfg (alc--mc-defaults))
  (alc-test--mc-check "single-full-course" (equal (alc--mc-heights 600.0) '(600.0) 1e-6))
  (alc-test--mc-check "too-small-course-rejected" (not (alc--mc-heights 99.0)))
  (alc-test--mc-check "tiny-last-course-distributed-into-two-valid-cuts"
    (and (equal (alc--mc-heights 605.0) '(300.0 300.0) 1e-6)
      (equal (alc-test--mc-sum (alc--mc-heights 605.0) 5.0) 605.0 1e-6)))
  (alc-test--mc-check "full-row-two-bricks-with-5mm-joint"
    (equal (alc--mc-widths 2205.0 1100.0) '(1100.0 1100.0) 1e-6))
  (alc-test--mc-check "end-cut-below-200-adjusts-start-cut"
    (equal (alc--mc-widths 1200.0 1100.0) '(995.0 200.0) 1e-6))
  (alc-test--mc-check "narrow-bay-under-200-rejected" (not (alc--mc-widths 199.0 1100.0)))
  (alc-test--mc-check "range-includes-non-step-upper-bound" (= (last (alc--mc-ranges 203.0)) 203.0))
  (setq stats (alc--mc-cutting '((0.0 0.0 550.0 600.0) (555.0 0.0 550.0 600.0))))
  (alc-test--mc-check "two-halves-reuse-one-stock-brick"
    (and (= (alc--mc-v 'stock stats) 1) (= (alc--mc-v 'reused stats) 1)
      (= (alc--mc-v 'scrap stats) 0.0) (= (alc--mc-v 'reusable-area stats) 0.0)))
  (setq plan (alc--mc-plan cfg))
  (alc-test--mc-check "default-plan-feasible" plan)
  (alc-test--mc-check "tie-and-foam-within-approved-study-input-bounds"
    (and (<= 100.0 (alc--mc-v 'tie plan) 200.0) (<= 100.0 (alc--mc-v 'foam plan) 150.0)))
  (alc-test--mc-check "lower-zone-exact-with-both-10mm-clearances"
    (equal (+ 20.0 (alc-test--mc-sum (alc--mc-v 'lower plan) 5.0))
      (- (alc--mc-v 'tie-base cfg) (alc--mc-v 'floor cfg)) 1e-6))
  (alc-test--mc-check "upper-zone-exact-with-10mm-base-and-one-foam-gap"
    (equal (+ (alc--mc-v 'tie-base cfg) (alc--mc-v 'tie plan) 10.0
      (alc-test--mc-sum (alc--mc-v 'upper plan) 5.0) (alc--mc-v 'foam plan))
      (alc--mc-v 'top cfg) 1e-6))
  (setq valid T)
  (foreach piece (alc--mc-v 'pieces plan)
    (if (not (and (<= 199.999999 (nth 2 piece) 1100.000001)
                  (<= 99.999999 (nth 3 piece) 600.000001))) (setq valid nil)))
  (alc-test--mc-check "all-pieces-obey-minimum-cut-sizes-and-stock-size" valid)
  (alc-test--mc-check "cutting-area-conserved-no-overlapping-reuse"
    (equal (* 660000.0 (alc--mc-v 'stock plan))
      (+ (alc--mc-v 'used-area plan) (alc--mc-v 'scrap plan) (alc--mc-v 'reusable-area plan)) 1e-3))
  (setq saved (subst '(foam-max . 99.0) (assoc 'foam-max cfg) cfg))
  (alc-test--mc-check "invalid-foam-bound-has-no-plan" (not (alc--mc-plan saved)))
  (setq saved (subst '(top . 1700.0) (assoc 'top cfg) cfg))
  (alc-test--mc-check "infeasible-elevations-have-no-plan" (not (alc--mc-plan saved)))
  (setq count (alc-test--entity-count "LWPOLYLINE"))
  (alc-test--mc-check "planning-is-read-only" (= count 0))
  (alc-test--mc-check "draw-one-bay" (alc--mc-create cfg plan '(0.0 0.0 0.0)))
  (if *alc-mc-last-error* (alc-test--write-lines "elevation-error.log" (list *alc-mc-last-error*)))
  (alc-test--mc-check "brick-outlines-count-and-size"
    (= (sslength (ssget "_X" '((0 . "LWPOLYLINE") (8 . "ALC_MC_GACH"))))
       (length (alc--mc-v 'pieces plan))))
  (alc-test--mc-check "four-concrete-hatches-and-one-foam-hatch"
    (and (= (sslength (ssget "_X" '((0 . "HATCH") (8 . "ALC_MC_BETONG")))) 4)
         (= (sslength (ssget "_X" '((0 . "HATCH") (8 . "ALC_MC_FOAM")))) 1)))
  (setq valid T)
  (vlax-for object (alc--current-space)
    (if (and (= (vla-get-ObjectName object) "AcDbHatch") (= (vla-get-Layer object) "ALC_MC_BETONG"))
      (if (/= (vla-get-PatternName object) "AR-CONC") (setq valid nil))))
  (alc-test--mc-check "concrete-pattern-is-AR-CONC" valid)
  (alc-test--mc-check "two-axis-circles-and-two-dimensions"
    (and (= (alc-test--entity-count "CIRCLE") 2) (= (alc-test--entity-count "DIMENSION") 2)))
  (alc-test--mc-check "ceiling-is-a-reference-line-not-wall-end"
    (and (= (sslength (ssget "_X" '((0 . "LINE") (8 . "ALC_MC_TRAN")))) 1)
         (equal (+ (alc--mc-v 'tie-base cfg) (alc--mc-v 'tie plan) 10.0
           (alc-test--mc-sum (alc--mc-v 'upper plan) 5.0) (alc--mc-v 'foam plan)) 3300.0 1e-6)))
  (alc-test--mc-check "successful-render-leaves-no-temporary-entities" (not *alc-temp-entities*))
  (alc-test--clear)
  (command-s "_.UCS" "_Z" "30")
  (alc-test--mc-check "rotated-UCS-render" (alc--mc-create cfg plan '(500.0 1000.0 0.0)))
  (setq selection (ssget "_X" '((0 . "LWPOLYLINE") (8 . "ALC_MC_GACH"))) area 0.0 a 0)
  (repeat (sslength selection)
    (setq area (+ area (vla-get-Area (vlax-ename->vla-object (ssname selection a)))) a (1+ a)))
  (alc-test--mc-check "rotated-UCS-bricks-keep-exact-plan-area"
    (equal area (alc--mc-v 'used-area plan) 1e-3))
  (alc-test--clear)
  (defun alc--mc-hatched (origin y width height layer pattern scale / boundary)
    (setq boundary (alc--mc-rect origin 0.0 y width height layer)) (car 1))
  (setq result (alc--mc-create cfg plan '(0.0 0.0 0.0)))
  (alc-test--mc-check "hatch-failure-rolls-back-partial-geometry"
    (and (not result) (= (alc-test--entity-count "LWPOLYLINE") 0) (not *alc-temp-entities*)))
  (load (strcat *alc-resource-root* "/src/alc-elevation.lsp"))
  (princ))

(defun alc-test-mc-prepare ()
  (alc-test--clear) (setvar "OSMODE" 0) (setvar "ORTHOMODE" 0) (princ))
(defun alc-test-mc-public-check ()
  (alc-test--mc-check "VVMC-public-command-creates-bay"
    (and (> (alc-test--entity-count "LWPOLYLINE") 20) (= (alc-test--entity-count "HATCH") 5))))
(defun alc-test-mc-undo-check ()
  (alc-test--mc-check "one-undo-removes-entire-elevation"
    (and (= (alc-test--entity-count "LWPOLYLINE") 0) (= (alc-test--entity-count "HATCH") 0)
      (= (alc-test--entity-count "TEXT") 0) (= (alc-test--entity-count "DIMENSION") 0))))

(defun alc-test-mc-sample (/ cfg plan)
  (setq cfg (alc--mc-defaults) plan (alc--mc-plan cfg))
  (alc-test--mc-check "sample-drawing-created" (alc--mc-create cfg plan '(0.0 0.0 0.0)))
  (alc-test--mc-check "sample-includes-labels-and-all-brick-outlines"
    (and (>= (alc-test--entity-count "TEXT") 11)
      (= (sslength (ssget "_X" '((0 . "LWPOLYLINE") (8 . "ALC_MC_GACH")))) (length (alc--mc-v 'pieces plan)))))
  (alc-test--write-lines "elevation-plan.txt" (list (vl-prin1-to-string cfg) (vl-prin1-to-string plan)))
  (command-s "_.ZOOM" "_Extents")
  (command-s "_.REGEN")
  (command-s "_.DELAY" "1500")
  (command-s "_.PNGOUT" (strcat (getenv "ALCWALL_TEST_RUN") "/elevation-default.png") "_All" "")
  (princ))

