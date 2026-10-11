;;; AutoCAD 2027 tests: geometry, hatch area/settings, UCS and refusal paths.
(defun alc-test--trim-check (name pass)
  (setq checks (cons (strcat (if pass "PASS " "FAIL ") name) checks))
  (alc-test--write-lines (strcat (alc-test--root) "/tests/results/trim-test.log")
    (reverse checks)))

(defun alc-test--trim-case (name points pick expected / wall hatch settings before-area)
  (setq wall (alc--create-lwpolyline-wcs points T '(0.0 0.0 1.0))
        hatch (alc--make-hatch-with-angle wall "ANSI31" 4 25.0 256 0.37)
        settings (alc--read-hatch-settings (alc--vla-object-ename hatch))
        before-area (vla-get-Area hatch))
  (alc-test--trim-check (strcat name "-success") (alc--shorten-wall-20 wall pick))
  (alc-test--trim-check (strcat name "-vertices")
    (equal (alc--clean-polygon-points (alc--lwp-points wall)) expected 1e-6))
  (alc-test--trim-check (strcat name "-area")
    (and (equal (- before-area (vla-get-Area hatch)) 4000.0 1e-5)
         (equal (vla-get-Area hatch) (vla-get-Area (vlax-ename->vla-object wall)) 1e-5)))
  (alc-test--trim-check (strcat name "-hatch-preserved")
    (and (equal settings (alc--read-hatch-settings (alc--vla-object-ename hatch)) 1e-8)
         (equal wall (alc--resolve-wall (alc--vla-object-ename hatch))))))

(defun alc-test--trim-invoke ()
  (alc--shorten-wall-20 wall '(0.0 100.0 0.0)))

(defun alc-test-run-trim (/ checks wall before layer-data layer points expected hatch hatch-before)
  (setq checks nil)
  (alc-test--clear)
  (alc-test--trim-case "straight-start"
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (0.0 200.0 0.0))
    '(0.0 100.0 0.0)
    '((20.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (20.0 200.0 0.0)))
  (alc-test--trim-case "straight-end"
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (0.0 200.0 0.0))
    '(1000.0 100.0 0.0)
    '((0.0 0.0 0.0) (980.0 0.0 0.0) (980.0 200.0 0.0) (0.0 200.0 0.0)))
  (alc-test--trim-case "L-end"
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0)
      (800.0 1000.0 0.0) (800.0 200.0 0.0) (0.0 200.0 0.0))
    '(900.0 1000.0 0.0)
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 980.0 0.0)
      (800.0 980.0 0.0) (800.0 200.0 0.0) (0.0 200.0 0.0)))
  (alc-test--trim-case "U-start"
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0) (0.0 1000.0 0.0)
      (0.0 800.0 0.0) (800.0 800.0 0.0) (800.0 200.0 0.0) (0.0 200.0 0.0))
    '(0.0 100.0 0.0)
    '((20.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0) (0.0 1000.0 0.0)
      (0.0 800.0 0.0) (800.0 800.0 0.0) (800.0 200.0 0.0) (20.0 200.0 0.0)))
  (vl-cmdf "_.UCS" "_Z" 37.0)
  (setq points (mapcar '(lambda (p) (trans p 1 0))
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (0.0 200.0 0.0)))
    expected (mapcar '(lambda (p) (trans p 1 0))
    '((20.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (20.0 200.0 0.0))))
  (alc-test--trim-case "rotated-UCS" points (trans '(0.0 100.0 0.0) 1 0) expected)
  (vl-cmdf "_.UCS" "_World")
  (setq wall (alc--create-lwpolyline-wcs
    '((0.0 0.0 0.0) (20.0 0.0 0.0) (20.0 200.0 0.0) (0.0 200.0 0.0)) T '(0.0 0.0 1.0))
    before (entget wall))
  (alc-test--trim-check "too-short-kept"
    (and (not (alc--shorten-wall-20 wall '(0.0 100.0 0.0))) (equal before (entget wall))))
  (setq wall (alc--create-lwpolyline-wcs
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (0.0 200.0 0.0)) T '(0.0 0.0 1.0))
    before (entget wall) layer (tblobjname "LAYER" (getvar "CLAYER"))
    layer-data (entget layer))
  (entmod (subst (cons 70 (logior 4 (cdr (assoc 70 layer-data)))) (assoc 70 layer-data) layer-data))
  (alc-test--trim-check "locked-wall-kept"
    (and (not (alc--shorten-wall-20 wall '(0.0 100.0 0.0))) (equal before (entget wall))))
  (entmod layer-data)
  (setq hatch (alc--make-hatch wall)
        before (entget wall)
        hatch-before (entget (alc--vla-object-ename hatch)))
  (alc--run-command 'alc-test--trim-invoke "ALCTRIM test")
  (alc-test--trim-check "command-shortens-wall"
    (equal (car (alc--lwp-points wall)) '(20.0 0.0 0.0) 1e-6))
  (vl-cmdf "_.UNDO" 1)
  (alc-test--trim-check "undo-wall-record" (equal before (entget wall)))
  (alc-test--trim-check "undo-hatch-area" (equal (vla-get-Area hatch) 200000.0 1e-5))
  (alc-test--trim-check "one-undo-restores-wall-and-hatch"
    (and (equal before (entget wall))
         (equal hatch-before (entget (alc--vla-object-ename hatch)))
         (equal (vla-get-Area hatch) 200000.0 1e-5)))
  (setq alc-test-trim-checks checks)
  (princ))

(defun alc-test-trim-prepare-interactive ()
  (alc-test--clear)
  (setq alc-test-trim-wall-a (alc-test--create-wall
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (0.0 200.0 0.0)))
    alc-test-trim-wall-b (alc-test--create-wall
    '((2000.0 0.0 0.0) (3000.0 0.0 0.0) (3000.0 200.0 0.0) (2000.0 200.0 0.0))))
  (vl-cmdf "_.ZOOM" "_Extents")
  (princ))

(defun alc-test-trim-check-multi (/ checks)
  (setq checks alc-test-trim-checks)
  (alc-test--trim-check "multi-M-trims-two-walls"
    (and (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(20.0 0.0 0.0) 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(2020.0 0.0 0.0) 1e-6)))
  (vl-cmdf "_.UNDO" 1)
  (alc-test--trim-check "multi-one-undo-restores-both"
    (and (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(0.0 0.0 0.0) 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(2000.0 0.0 0.0) 1e-6)))
  (setq alc-test-trim-checks checks)
  (princ))

(defun alc-test-trim-check-single (/ checks)
  (setq checks alc-test-trim-checks)
  (alc-test--trim-check "single-click-finishes-command"
    (and (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(20.0 0.0 0.0) 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(2000.0 0.0 0.0) 1e-6)))
  (setq alc-test-trim-checks checks)
  (princ))

(defun alc-test-trim-check-length (/ checks wall before)
  (setq checks alc-test-trim-checks)
  (alc-test--trim-check "L-before-M-trims-50"
    (and (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(50.0 0.0 0.0) 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(2050.0 0.0 0.0) 1e-6)))
  (alc-test--trim-check "L-in-M-changes-next-cut-to-25"
    (equal (nth 1 (alc--lwp-points alc-test-trim-wall-b)) '(2975.0 0.0 0.0) 1e-6))
  (alc-test--trim-check "custom-length-hatch-area"
    (equal (vla-get-Area (vlax-ename->vla-object
      (car (alc--find-boundary-hatches alc-test-trim-wall-b)))) 185000.0 1e-5))
  (setq wall alc-test-trim-wall-a before (entget wall))
  (alc-test--trim-check "custom-length-zero-negative-kept"
    (and (not (alc--shorten-wall wall '(50.0 100.0 0.0) 0.0))
         (not (alc--shorten-wall wall '(50.0 100.0 0.0) -5.0))
         (equal before (entget wall))))
  (alc-test--trim-check "custom-length-too-long-kept"
    (and (not (alc--shorten-wall wall '(50.0 100.0 0.0) 950.0))
         (equal before (entget wall))))
  (vl-cmdf "_.UNDO" 1)
  (alc-test--trim-check "custom-length-multi-undo"
    (and (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(0.0 0.0 0.0) 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(2000.0 0.0 0.0) 1e-6)
         (equal (nth 1 (alc--lwp-points alc-test-trim-wall-b)) '(3000.0 0.0 0.0) 1e-6)))
  (setq alc-test-trim-checks checks)
  (princ))

(defun alc-test-trim-check-length-single (/ checks)
  (setq checks alc-test-trim-checks)
  (alc-test--trim-check "single-L-decimal-length"
    (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(12.5 0.0 0.0) 1e-6))
  (setq alc-test-trim-checks checks)
  (princ))

(defun alc-test-trim-check-session-length (/ checks)
  (setq checks alc-test-trim-checks)
  (alc-test--trim-check "length-retained-after-reload-enter"
    (and (equal *alc-trim-distance* 12.5 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(25.0 0.0 0.0) 1e-6)))
  (alc-test--trim-check "retained-length-used-in-next-multi"
    (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(2012.5 0.0 0.0) 1e-6))
  (alc-test--trim-check "retained-length-hatch-updated"
    (equal (vla-get-Area (vlax-ename->vla-object
      (car (alc--find-boundary-hatches alc-test-trim-wall-a)))) 195000.0 1e-5))
  (princ))
