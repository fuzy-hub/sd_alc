(defun alc-test--standard-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "standard-wall-test.log")))
  (alc-test--write-lines "standard-wall-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test--standard-source (points)
  (alc--create-lwpolyline-wcs-on-layer points T '(0.0 0.0 1.0) "ALC_wall default"))

(defun alc-test--standard-lengths (entries)
  (vl-sort (mapcar '(lambda (entry) (distance (cadr entry) (caddr entry))) entries) '<))

(defun alc-test-run-standard-wall (/ lp up zp wall entries saved points valid k output before normal)
  (alc-test--clear)
  (setvar "CLAYER" "0")
  (setq lp '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0)
             (900.0 1000.0 0.0) (900.0 100.0 0.0) (0.0 100.0 0.0))
        up '((0.0 0.0 0.0) (100.0 0.0 0.0) (100.0 880.0 0.0) (1355.0 880.0 0.0)
             (1355.0 390.0 0.0) (1455.0 390.0 0.0) (1455.0 980.0 0.0) (0.0 980.0 0.0))
        wall (alc-test--standard-source lp) before (entget wall '("*"))
        entries (alc--match-entries wall))
  (alc-test--standard-check "L-horizontal-owns-corner"
    (and (= (length entries) 2)
      (or (member '(100.0 (0.0 50.0 0.0) (1000.0 50.0 0.0)) entries)
          (member '(100.0 (1000.0 50.0 0.0) (0.0 50.0 0.0)) entries))))
  (alc-test--standard-check "L-vertical-stops-at-horizontal-edge"
    (or (member '(100.0 (950.0 100.0 0.0) (950.0 1000.0 0.0)) entries)
        (member '(100.0 (950.0 1000.0 0.0) (950.0 100.0 0.0)) entries)))
  (alc-test--standard-check "L-creates-two-centered-width-100-polylines"
    (and (alc--match-wall wall) (alc--match-all-existing-p wall entries)
         (= (alc-test--entity-count "LWPOLYLINE") 3)))
  (alc-test--standard-check "L-second-run-does-not-duplicate" (eq (alc--match-wall wall) 'existing))
  (alc-test--standard-check "source-boundary-unchanged" (equal before (entget wall '("*"))))
  (setq wall (alc-test--standard-source up) entries (alc--match-entries wall))
  (alc-test--standard-check "U-lengths-match-example-490-880-1455"
    (equal (alc-test--standard-lengths entries) '(490.0 880.0 1455.0) 1e-5))
  (alc-test--standard-check "U-infers-real-width" (equal (mapcar 'car entries) '(100.0 100.0 100.0) 1e-5))
  (alc-test--standard-check "U-creates-three-separate-centered-polylines"
    (and (setq output (alc--match-wall wall)) (alc--match-all-existing-p wall entries)))
  (entdel output)
  (alc-test--standard-check "U-recreates-only-missing-segment"
    (and (alc--match-wall wall) (alc--match-all-existing-p wall entries)
         (eq (alc--match-wall wall) 'existing)))
  (setq points up valid T k 0)
  (repeat 8
    (foreach saved (list points (reverse points))
      (setq wall (alc-test--standard-source saved))
      (if (not (equal (alc-test--standard-lengths (alc--match-entries wall)) '(490.0 880.0 1455.0) 1e-5))
        (setq valid nil)))
    (setq points (append (cdr points) (list (car points))) k (1+ k)))
  (alc-test--standard-check "U-all-start-vertices-and-both-windings" valid)
  (setq wall (alc-test--standard-source (mapcar '(lambda (p) (list (- (car p)) (cadr p) 0.0)) up)))
  (alc-test--standard-check "mirrored-U-supported"
    (equal (alc-test--standard-lengths (alc--match-entries wall)) '(490.0 880.0 1455.0) 1e-5))
  (command-s "_.UCS" "_Z" "90")
  (setq wall (alc-test--standard-source lp))
  (alc-test--standard-check "L-priority-follows-current-UCS-X"
    (equal (alc-test--standard-lengths (alc--match-entries wall)) '(900.0 1000.0) 1e-5))
  (command-s "_.UCS" "_World")
  (setq wall (alc-test--standard-source (mapcar '(lambda (p) (list (* 1.5 (car p)) (* 1.5 (cadr p)) 0.0)) up)))
  (alc-test--standard-check "width-inferred-without-layer-or-tag-hint"
    (equal (mapcar 'car (alc--match-entries wall)) '(150.0 150.0 150.0) 1e-5))
  (setq wall (alc-test--standard-source up))
  (alc--wall-write-tag wall 200.0 2)
  (alc-test--standard-check "bent-wall-uses-geometry-despite-stale-width-tag"
    (equal (mapcar 'car (alc--match-entries wall)) '(100.0 100.0 100.0) 1e-5))
  (setq wall (alc-test--standard-source '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0)
    (800.0 1000.0 0.0) (800.0 100.0 0.0) (0.0 100.0 0.0))))
  (alc-test--standard-check "unequal-branch-width-rejected" (not (alc--match-entries wall)))
  (setq zp '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0) (2000.0 1000.0 0.0)
             (2000.0 1100.0 0.0) (900.0 1100.0 0.0) (900.0 100.0 0.0) (0.0 100.0 0.0)))
  (alc-test--standard-check "Z-boundary-rejected" (not (alc--match-entries (alc-test--standard-source zp))))
  (setq wall (alc-test--standard-source lp))
  (vla-SetBulge (vlax-ename->vla-object wall) 0 0.1)
  (alc-test--standard-check "curved-L-rejected" (not (alc--match-entries wall)))
  (alc-test--standard-check "path-straight-with-extra-collinear-points-accepted"
    (= (length (alc--standard-wall-path '((0.0 0.0 0.0) (500.0 0.0 0.0) (1000.0 0.0 0.0)) '(0.0 0.0 1.0))) 2))
  (alc-test--standard-check "path-U-accepted"
    (alc--standard-wall-path '((0.0 0.0 0.0) (0.0 1000.0 0.0) (1500.0 1000.0 0.0) (1500.0 200.0 0.0)) '(0.0 0.0 1.0)))
  (alc-test--standard-check "path-Z-rejected"
    (not (alc--standard-wall-path '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0) (2000.0 1000.0 0.0)) '(0.0 0.0 1.0))))
  (alc-test--standard-check "path-four-segments-rejected"
    (not (alc--standard-wall-path '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0) (0.0 1000.0 0.0) (0.0 500.0 0.0)) '(0.0 0.0 1.0))))
  (alc-test--standard-check "path-non-right-angle-rejected"
    (not (alc--standard-wall-path '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1500.0 500.0 0.0)) '(0.0 0.0 1.0))))
  (alc-test--standard-check "path-reversal-rejected"
    (not (alc--standard-wall-path '((0.0 0.0 0.0) (1000.0 0.0 0.0) (500.0 0.0 0.0)) '(0.0 0.0 1.0))))
  (alc-test--standard-check "path-nonplanar-rejected"
    (not (alc--standard-wall-path '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 10.0)) '(0.0 0.0 1.0))))
  (setq wall (alc-test--standard-source '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 100.0 0.0)
    (550.0 100.0 0.0) (550.0 1000.0 0.0) (450.0 1000.0 0.0) (450.0 100.0 0.0) (0.0 100.0 0.0))))
  (alc-test--standard-check "T-boundary-rejected" (not (alc--match-entries wall)))
  (setq wall (alc-test--standard-source (mapcar '(lambda (p)
    (list (- (* (car p) (cos 0.37)) (* (cadr p) (sin 0.37)))
          (+ (* (car p) (sin 0.37)) (* (cadr p) (cos 0.37))) 0.0)) up)))
  (alc-test--standard-check "rotated-U-keeps-example-lengths"
    (equal (alc-test--standard-lengths (alc--match-entries wall)) '(490.0 880.0 1455.0) 1e-5))
  (setq wall (alc--create-lwpolyline-wcs-on-layer
    (mapcar '(lambda (p) (list (car p) 0.0 (+ 25.0 (cadr p)))) up)
    T '(0.0 -1.0 0.0) "ALC_wall default"))
  (alc-test--standard-check "tilted-plane-U-keeps-width-and-lengths"
    (and (equal (alc-test--standard-lengths (alc--match-entries wall)) '(490.0 880.0 1455.0) 1e-5)
         (alc--match-wall wall) (alc--match-all-existing-p wall (alc--match-entries wall))))
  (setq points (mapcar '(lambda (p)
    (list (- (* (car p) (cos (/ pi 4.0))) (* (cadr p) (sin (/ pi 4.0))))
          (+ (* (car p) (sin (/ pi 4.0))) (* (cadr p) (cos (/ pi 4.0)))) 0.0)) lp)
        wall (alc-test--standard-source points))
  (alc--match-wall wall)
  (setq wall (alc-test--standard-source (reverse points)))
  (alc-test--standard-check "L-at-45-degrees-has-stable-priority-for-reversed-boundary"
    (eq (alc--match-wall wall) 'existing))
  (setq wall (alc-test--standard-source (mapcar '(lambda (p) (list (+ 20000.0 (car p)) (cadr p) 0.0)) up))
        before (alc-test--entity-count "LWPOLYLINE") k 0)
  (defun alc--match-segment (wall entry / output)
    (setq k (1+ k))
    (if (= k 2) (car 1)
      (alc--track-temp (alc--create-lwpolyline-wcs-on-layer (cdr entry) nil '(0.0 0.0 1.0) "0"))))
  (setq output (alc--match-wall wall))
  (alc-test--standard-check "partial-failure-rolls-back-all-new-segments"
    (and (not output) (= before (alc-test--entity-count "LWPOLYLINE"))
         (not *alc-temp-entities*) (entget wall)))
  (load (strcat *alc-resource-root* "/src/alc-commands.lsp"))
  (princ))

(defun alc-test-standard-prepare ()
  (alc-test--clear)
  (setvar "CLAYER" "ALC_wall default") (setvar "OSMODE" 0) (setvar "ORTHOMODE" 0)
  (setq *alc-thickness* 100.0 *alc-pattern* "ANSI37")
  (princ))

(defun alc-test-standard-draw-check (/ selection wall)
  (setq selection (ssget "_X" '((0 . "LWPOLYLINE"))))
  (if selection (setq wall (ssname selection 0)))
  (alc-test--standard-check "VV-or-VVC-rejects-diagonal-Z-and-fourth-leg-but-keeps-U"
    (and selection (= (sslength selection) 1) (= (alc-test--entity-count "HATCH") 1)
      (= (length (alc--match-entries wall)) 3) (not *alc-temp-entities*))))

(defun alc-test-standard-empty-check ()
  (alc-test--standard-check "one-undo-removes-only-new-wall-and-hatch"
    (and (= (alc-test--entity-count "LWPOLYLINE") 0) (= (alc-test--entity-count "HATCH") 0))))

(defun alc-test-standard-match-prepare ()
  (alc-test-standard-prepare)
  (setq *alc-standard-a* (alc-test--standard-source
    '((0.0 0.0 0.0) (100.0 0.0 0.0) (100.0 880.0 0.0) (1355.0 880.0 0.0)
      (1355.0 390.0 0.0) (1455.0 390.0 0.0) (1455.0 980.0 0.0) (0.0 980.0 0.0)))
    *alc-standard-b* (alc-test--standard-source
    '((5000.0 0.0 0.0) (6000.0 0.0 0.0) (6000.0 1000.0 0.0)
      (5900.0 1000.0 0.0) (5900.0 100.0 0.0) (5000.0 100.0 0.0))))
  (setq *alc-standard-before* (mapcar 'entget (list *alc-standard-a* *alc-standard-b*)))
  (setvar "PICKFIRST" 1)
  (sssetfirst nil (ssadd *alc-standard-a* (ssadd *alc-standard-b*)))
  (princ))

(defun alc-test-standard-match-check ()
  (alc-test--standard-check "VVM-alias-batch-creates-five-centered-polylines-without-duplicates"
    (and (= (alc-test--entity-count "LWPOLYLINE") 7)
      (alc--match-all-existing-p *alc-standard-a* (alc--match-entries *alc-standard-a*))
      (alc--match-all-existing-p *alc-standard-b* (alc--match-entries *alc-standard-b*))
      (equal *alc-standard-before* (mapcar 'entget (list *alc-standard-a* *alc-standard-b*))))))

(defun alc-test-standard-match-undo-check ()
  (alc-test--standard-check "one-undo-removes-five-plines-and-keeps-two-sources"
    (and (= (alc-test--entity-count "LWPOLYLINE") 2)
      (equal *alc-standard-before* (mapcar 'entget (list *alc-standard-a* *alc-standard-b*))))))
