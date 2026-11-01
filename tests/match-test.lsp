(defun alc-test--match-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "match-test.log")))
  (alc-test--write-lines "match-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test--match-wall (points width tagged layer normal / boundary *alc-thickness*)
  (setq *alc-thickness* width
        boundary (alc--create-lwpolyline-wcs-on-layer points T normal layer))
  (if tagged (alc--commit-wall (alc--track-temp boundary)) (alc--make-hatch boundary))
  boundary)

(defun alc-test--match-rectangle (x y wall-length width tagged)
  (alc-test--match-wall (list (list x y 0.0) (list (+ x wall-length) y 0.0)
    (list (+ x wall-length) (+ y width) 0.0) (list x (+ y width) 0.0))
    width tagged "ALC_wall default" '(0.0 0.0 1.0)))

(defun alc-test--match-output-p (entity start end width / points)
  (and entity (not (alc--closed-lwpolyline-p entity))
    (= (cdr (assoc 90 (entget entity))) 2)
    (equal (vla-get-ConstantWidth (vlax-ename->vla-object entity)) width 1e-5)
    (setq points (alc--lwp-points entity))
    (or (and (equal (car points) start 1e-5) (equal (last points) end 1e-5))
        (and (equal (car points) end 1e-5) (equal (last points) start 1e-5)))))

(defun alc-test--match-local-p (wall output width / low high)
  (vla-GetBoundingBox (vlax-ename->vla-object wall) 'low 'high)
  (setq low (vlax-safearray->list low) high (vlax-safearray->list high))
  (alc-test--match-output-p output
    (list (car low) (/ (+ (cadr low) (cadr high)) 2.0) (caddr low))
    (list (car high) (/ (+ (cadr low) (cadr high)) 2.0) (caddr high)) width))

(defun alc-test-run-match (/ old-layer old-pattern old-width old-door wall output data hatch
    selection index candidate other normal points transform)
  (setq old-layer (getvar "CLAYER") old-pattern *alc-pattern* old-door *alc-door-width*
        old-width (getvar "PLINEWID") *alc-pattern* "ANSI37")
  (alc-test--clear)
  (setvar "CLAYER" "ALC_wall default")
  (setq wall (alc-test--match-rectangle 0.0 0.0 3000.0 100.0 T)
        data (entget wall '("*")) hatch (car (alc--find-boundary-hatches wall)))
  (setvar "CLAYER" "0") (setvar "PLINEWID" 17.0)
  (setq output (alc--match-wall wall))
  (alc-test--match-check "straight-100-centerline-width-length"
    (alc-test--match-output-p output '(0.0 50.0 0.0) '(3000.0 50.0 0.0) 100.0))
  (alc-test--match-check "original-wall-and-hatch-preserved"
    (and (equal data (entget wall '("*"))) (entget hatch)))
  (alc-test--match-check "current-layer-ByLayer-color-and-transparency"
    (and (= (cdr (assoc 8 (entget output))) "0")
      (= (vla-get-Color (vlax-ename->vla-object output)) 256)
      (= (strcase (vla-get-EntityTransparency (vlax-ename->vla-object output))) "BYLAYER")))
  (alc-test--match-check "current-layer-and-PLINEWID-preserved"
    (and (= (getvar "CLAYER") "0") (= (getvar "PLINEWID") 17.0)))
  (alc-test--match-check "output-not-tagged-as-wall-and-index-released"
    (and (not (alc--wall-tag-width output)) (not *alc-hatch-index*)))
  (defun alc--build-hatch-index () (setq *alc-match-test-scan* T) (vl-exit-with-error "Unexpected global scan"))
  (defun alc--scan-boundary-hatches (entity) (setq *alc-match-test-scan* T) (vl-exit-with-error "Unexpected hatch scan"))
  (setq *alc-match-test-scan* nil)
  (alc-test--match-check "tagged-and-legacy-match-never-scan-hatches"
    (and (alc--match-wall wall)
      (progn
        (setq data (entget wall '("ALCWALL")))
        (entmod (append (vl-remove (assoc -3 data) data) '((-3 ("ALCWALL")))))
        (alc--match-wall wall))
      (not *alc-match-test-scan*)))
  (load (strcat *alc-resource-root* "/src/alc-geometry.lsp"))
  (load (strcat *alc-resource-root* "/src/alc-safety.lsp"))
  (alc-test--clear)
  (alc--create-current-wall-layer "ALC_wall_Match_150" 4)
  (setq wall (alc-test--match-wall '((0.0 0.0 0.0) (2000.0 0.0 0.0)
    (2000.0 150.0 0.0) (0.0 150.0 0.0)) 150.0 T "ALC_wall_Match_150" '(0.0 0.0 1.0)))
  (setvar "CLAYER" "0")
  (alc-test--match-check "source-150-output-on-current-layer"
    (and (setq output (alc--match-wall wall))
      (= (cdr (assoc 8 (entget output))) "0")
      (alc-test--match-output-p output '(0.0 75.0 0.0) '(2000.0 75.0 0.0) 150.0)))
  (alc-test--clear)
  (setvar "CLAYER" "ALC_wall default")
  (setq wall (alc-test--match-rectangle 0.0 0.0 6000.0 100.0 T) *alc-door-width* 900.0)
  (alc--draw-door-opening wall '(0.0 50.0 0.0) '(1000.0 50.0 0.0))
  (setq selection (ssget "_X" '((0 . "LWPOLYLINE"))) index 0)
  (repeat (sslength selection)
    (setq candidate (ssname selection index) index (1+ index))
    (if (> (cadr (alc--wall-type-metrics candidate)) 3000.0) (setq wall candidate)))
  (setq *alc-door-width* 1200.0)
  (alc--draw-door-opening wall '(1900.0 50.0 0.0) '(3500.0 50.0 0.0))
  (setq selection (ssget "_X" '((0 . "LWPOLYLINE"))))
  (alc-test--match-check "recorded-doors-do-not-expand-selected-remnant"
    (and (alc-test--match-local-p (ssname selection 0) (alc--match-wall (ssname selection 0)) 100.0)
         (alc-test--match-local-p (ssname selection 2) (alc--match-wall (ssname selection 2)) 100.0)))
  (alc-test--clear)
  (setq wall (alc-test--match-rectangle 0.0 0.0 1000.0 100.0 nil))
  (alc-test--match-rectangle 1900.0 0.0 2000.0 100.0 nil)
  (alc-test--match-rectangle 5100.0 0.0 900.0 100.0 nil)
  (alc-test--match-check "legacy-gap-does-not-expand-selected-wall"
    (alc-test--match-output-p (alc--match-wall wall) '(0.0 50.0 0.0) '(1000.0 50.0 0.0) 100.0))
  (alc-test--clear)
  (setq wall (alc-test--match-rectangle 0.0 0.0 50.0 200.0 T))
  (alc-test--match-rectangle 950.0 0.0 2050.0 200.0 nil)
  (alc-test--match-check "short-tagged-stub-does-not-extend-to-neighbor"
    (alc-test--match-output-p (alc--match-wall wall) '(0.0 100.0 0.0) '(50.0 100.0 0.0) 200.0))
  (alc-test--clear)
  (setq wall (alc-test--match-rectangle 0.0 0.0 1000.0 100.0 T))
  (alc-test--match-rectangle 1900.0 0.0 2000.0 100.0 T)
  (alc-test--match-check "new-independent-aligned-wall-not-joined"
    (alc-test--match-output-p (alc--match-wall wall) '(0.0 50.0 0.0) '(1000.0 50.0 0.0) 100.0))
  (alc-test--clear)
  (setq points '((0.0 0.0 0.0) (3000.0 0.0 0.0) (3000.0 100.0 0.0) (0.0 100.0 0.0))
        transform '(lambda (p) (list (- (* (car p) (cos 0.37)) (* (cadr p) (sin 0.37)))
          (+ (* (car p) (sin 0.37)) (* (cadr p) (cos 0.37))) 0.0))
        wall (alc-test--match-wall (mapcar transform points) 100.0 T "ALC_wall default" '(0.0 0.0 1.0)))
  (alc-test--match-check "rotated-wall-centerline"
    (alc-test--match-output-p (alc--match-wall wall)
      (apply transform (list '(0.0 50.0 0.0))) (apply transform (list '(3000.0 50.0 0.0))) 100.0))
  (alc-test--clear)
  (setq wall (alc-test--match-wall '((0.0 0.0 0.0) (3000.0 0.0 0.0)
    (3000.0 0.0 100.0) (0.0 0.0 100.0)) 100.0 T "ALC_wall default" '(0.0 -1.0 0.0)))
  (alc-test--match-check "tilted-plane-normal-and-elevation"
    (and (setq output (alc--match-wall wall))
      (equal (cdr (assoc 210 (entget output))) '(0.0 -1.0 0.0) 1e-6)
      (alc-test--match-output-p output '(0.0 0.0 50.0) '(3000.0 0.0 50.0) 100.0)))
  (alc-test--clear)
  (setq wall (alc-test--match-wall '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0)
    (900.0 1000.0 0.0) (900.0 100.0 0.0) (0.0 100.0 0.0)) 100.0 T "ALC_wall default" '(0.0 0.0 1.0)))
  (alc-test--match-check "bent-wall-rejected" (not (alc--match-wall wall)))
  (alc-test-run-match-existing)
  (setq *alc-pattern* old-pattern *alc-door-width* old-door)
  (setvar "CLAYER" old-layer) (setvar "PLINEWID" old-width)
  (princ))

(defun alc-test--match-centerline (points width normal / output)
  ;; Untagged output also represents polylines made by older releases.
  (setq output (alc--create-lwpolyline-wcs-on-layer points nil normal "0"))
  (vla-put-ConstantWidth (vlax-ename->vla-object output) width)
  output)

(defun alc-test-run-match-existing (/ wall output replacement points)
  (alc-test--clear)
  (setvar "CLAYER" "0")
  (setq wall (alc-test--match-rectangle 0.0 0.0 3000.0 100.0 T)
        output (alc--match-wall wall)
        points '((0.0 50.0 0.0) (3000.0 50.0 0.0)))
  (alc-test--match-check "second-call-skips-existing-centerline"
    (and (eq (alc--match-wall wall) 'existing) (= (alc-test--entity-count "LWPOLYLINE") 2)))
  (load (strcat *alc-resource-root* "/src/alc-commands.lsp"))
  (alc-test--match-check "reload-still-recognizes-existing-centerline"
    (and (eq (alc--match-wall wall) 'existing) (= (alc-test--entity-count "LWPOLYLINE") 2)))
  (setvar "CLAYER" "ALC_wall default")
  (alc-test--match-check "different-current-layer-does-not-duplicate-existing-centerline"
    (eq (alc--match-wall wall) 'existing))
  (setvar "CLAYER" "0")
  (entdel output)
  (setq output (alc-test--match-centerline (reverse points) 100.0 '(0.0 0.0 1.0)))
  (alc-test--match-check "reversed-untagged-legacy-centerline-is-recognized"
    (eq (alc--match-wall wall) 'existing))
  (vla-Move (vlax-ename->vla-object output) (vlax-3d-point '(0.0 0.0 0.0))
    (vlax-3d-point '(0.0 20.0 0.0)))
  (setq replacement (alc--match-wall wall))
  (alc-test--match-check "moved-centerline-allows-new-output-without-changing-old-one"
    (and (alc-test--match-output-p replacement (car points) (cadr points) 100.0)
      (alc-test--match-output-p output '(0.0 70.0 0.0) '(3000.0 70.0 0.0) 100.0)))
  (entdel output) (entdel replacement)
  (setq output (alc--match-wall wall))
  (alc-test--match-check "deleted-centerline-can-be-recreated"
    (alc-test--match-output-p output (car points) (cadr points) 100.0))
  (vla-put-ConstantWidth (vlax-ename->vla-object output) 80.0)
  (setq replacement (alc--match-wall wall))
  (alc-test--match-check "wrong-width-does-not-block-new-output"
    (alc-test--match-output-p replacement (car points) (cadr points) 100.0))
  (entdel output) (entdel replacement)
  (setq output (alc-test--match-centerline '((0.0 50.0 0.0) (2900.0 50.0 0.0)) 100.0 '(0.0 0.0 1.0))
        replacement (alc--match-wall wall))
  (alc-test--match-check "shorter-centerline-does-not-block-new-output"
    (alc-test--match-output-p replacement (car points) (cadr points) 100.0))
  (entdel output) (entdel replacement)
  (setq output (alc-test--match-centerline points 100.0 '(0.0 0.0 1.0)))
  (vla-SetBulge (vlax-ename->vla-object output) 0 0.5)
  (setq replacement (alc--match-wall wall))
  (alc-test--match-check "curved-centerline-does-not-block-new-output"
    (alc-test--match-output-p replacement (car points) (cadr points) 100.0))
  (entdel output) (entdel replacement)
  (setq output (alc-test--match-centerline '((0.0 50.0 10.0) (3000.0 50.0 10.0)) 100.0 '(0.0 0.0 1.0))
        replacement (alc--match-wall wall))
  (alc-test--match-check "different-elevation-does-not-block-new-output"
    (alc-test--match-output-p replacement (car points) (cadr points) 100.0))
  (entdel output) (entdel replacement)
  (setq output (alc-test--match-centerline points 100.0 '(0.0 -1.0 0.0))
        replacement (alc--match-wall wall))
  (alc-test--match-check "different-plane-normal-does-not-block-new-output"
    (alc-test--match-output-p replacement (car points) (cadr points) 100.0))
  (entdel output) (entdel replacement)
  (setq output (alc-test--match-centerline points 100.0 '(0.0 0.0 1.0)))
  (vla-put-Closed (vlax-ename->vla-object output) :vlax-true)
  (setq replacement (alc--match-wall wall))
  (alc-test--match-check "closed-polyline-does-not-block-new-output"
    (alc-test--match-output-p replacement (car points) (cadr points) 100.0))
  (entdel output) (entdel replacement)
  (setvar "TILEMODE" 0) (command-s "_.PSPACE")
  (setq output (alc-test--match-centerline points 100.0 '(0.0 0.0 1.0)))
  (setvar "TILEMODE" 1)
  (setq replacement (alc--match-wall wall))
  (alc-test--match-check "paperspace-centerline-does-not-block-modelspace-wall"
    (and (not (equal (cdr (assoc 330 (entget output))) (cdr (assoc 330 (entget replacement)))))
      (alc-test--match-output-p replacement (car points) (cadr points) 100.0)))
  (entdel output)
  (princ))

(defun alc-test-match-prepare ()
  (alc-test--clear)
  (setvar "CLAYER" "ALC_wall default") (setvar "OSMODE" 0)
  (setq *alc-pattern* "ANSI37" *alc-door-width* 900.0 *alc-thickness* 100.0)
  (command-s "_.ZOOM" "_Window" '(-1000.0 -1000.0 0.0) '(8000.0 3000.0 0.0))
  (princ))

(defun alc-test-match-public-check (/ selection i entity output)
  (setq selection (ssget "_X" '((0 . "LWPOLYLINE"))) i 0)
  (repeat (sslength selection)
    (setq entity (ssname selection i) i (1+ i))
    (if (not (alc--closed-lwpolyline-p entity)) (setq output entity)))
  (alc-test--match-check "VVMATCH-public-selection-output"
    (and (= (sslength selection) 3)
      (alc-test--match-output-p output '(0.0 50.0 0.0) '(1000.0 50.0 0.0) 100.0))))

(defun alc-test-match-undo-check ()
  (alc-test--match-check "one-undo-keeps-both-original-walls-and-hatches"
    (and (= (alc-test--entity-count "LWPOLYLINE") 2) (= (alc-test--entity-count "HATCH") 2))))

(defun alc-test-match-add-invalid ()
  (entmakex '((0 . "LINE") (100 . "AcDbEntity") (100 . "AcDbLine")
    (10 6000.0 2000.0 0.0) (11 7000.0 2000.0 0.0)))
  (princ))

(defun alc-test-match-multi-check (/ selection i entity outputs left right)
  (setq selection (ssget "_X" '((0 . "LWPOLYLINE"))) i 0 outputs 0)
  (repeat (sslength selection)
    (setq entity (ssname selection i) i (1+ i))
    (if (not (alc--closed-lwpolyline-p entity))
      (progn
        (setq outputs (1+ outputs))
        (if (alc-test--match-output-p entity '(0.0 50.0 0.0) '(1000.0 50.0 0.0) 100.0) (setq left T))
        (if (alc-test--match-output-p entity '(1900.0 50.0 0.0) '(6000.0 50.0 0.0) 100.0) (setq right T)))))
  (alc-test--match-check "batch-creates-two-local-polylines-in-one-command"
    (and (= outputs 2) left right))
  (alc-test--match-check "batch-invalid-and-boundary-hatch-selection-do-not-add-extra-output"
    (and (= (sslength selection) 4) (= (alc-test--entity-count "HATCH") 2)
      (= (alc-test--entity-count "LINE") 1))))
(princ)
