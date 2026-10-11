;;; AutoCAD 2027: extension, hatch preservation, Length/Multi and Undo.
(defun alc-test--xtend-check (name pass)
  (setq checks (cons (strcat (if pass "PASS " "FAIL ") name) checks))
  (alc-test--write-lines (strcat (alc-test--root) "/tests/results/xtend-test.log")
    (reverse checks)))

(defun alc-test--xtend-case (name points pick amount expected / wall hatch settings before-area)
  (setq wall (alc--create-lwpolyline-wcs points T '(0.0 0.0 1.0))
        hatch (alc--make-hatch-with-angle wall "ANSI31" 4 25.0 256 0.37)
        settings (alc--read-hatch-settings (alc--vla-object-ename hatch))
        before-area (vla-get-Area hatch))
  (alc-test--xtend-check (strcat name "-success") (alc--extend-wall wall pick amount))
  (alc-test--xtend-check (strcat name "-vertices")
    (equal (alc--clean-polygon-points (alc--lwp-points wall)) expected 1e-6))
  (alc-test--xtend-check (strcat name "-area")
    (and (equal (- (vla-get-Area hatch) before-area) (* amount 200.0) 1e-5)
         (equal (vla-get-Area hatch) (vla-get-Area (vlax-ename->vla-object wall)) 1e-5)))
  (alc-test--xtend-check (strcat name "-hatch-preserved")
    (and (equal settings (alc--read-hatch-settings (alc--vla-object-ename hatch)) 1e-8)
         (equal wall (alc--resolve-wall (alc--vla-object-ename hatch))))))

(defun alc-test-run-xtend (/ checks wall before layer layer-data points expected)
  (alc-test--clear)
  (alc-test--xtend-case "straight-start"
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (0.0 200.0 0.0))
    '(0.0 100.0 0.0) 20.0
    '((-20.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (-20.0 200.0 0.0)))
  (alc-test--xtend-case "straight-end-decimal"
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (0.0 200.0 0.0))
    '(1000.0 100.0 0.0) 12.5
    '((0.0 0.0 0.0) (1012.5 0.0 0.0) (1012.5 200.0 0.0) (0.0 200.0 0.0)))
  (alc-test--xtend-case "L-end"
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0)
      (800.0 1000.0 0.0) (800.0 200.0 0.0) (0.0 200.0 0.0))
    '(900.0 1000.0 0.0) 50.0
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1050.0 0.0)
      (800.0 1050.0 0.0) (800.0 200.0 0.0) (0.0 200.0 0.0)))
  (alc-test--xtend-case "U-start"
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0) (0.0 1000.0 0.0)
      (0.0 800.0 0.0) (800.0 800.0 0.0) (800.0 200.0 0.0) (0.0 200.0 0.0))
    '(0.0 100.0 0.0) 20.0
    '((-20.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0) (0.0 1000.0 0.0)
      (0.0 800.0 0.0) (800.0 800.0 0.0) (800.0 200.0 0.0) (-20.0 200.0 0.0)))
  (alc-test--xtend-case "short-wall-long-extension"
    '((0.0 0.0 0.0) (10.0 0.0 0.0) (10.0 200.0 0.0) (0.0 200.0 0.0))
    '(0.0 100.0 0.0) 50.0
    '((-50.0 0.0 0.0) (10.0 0.0 0.0) (10.0 200.0 0.0) (-50.0 200.0 0.0)))
  (vl-cmdf "_.UCS" "_Z" 37.0)
  (setq points (mapcar '(lambda (p) (trans p 1 0))
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (0.0 200.0 0.0)))
    expected (mapcar '(lambda (p) (trans p 1 0))
    '((-20.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (-20.0 200.0 0.0))))
  (alc-test--xtend-case "rotated-UCS" points (trans '(0.0 100.0 0.0) 1 0) 20.0 expected)
  (vl-cmdf "_.UCS" "_World")
  (setq wall (alc--create-lwpolyline-wcs
    '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 200.0 0.0) (0.0 200.0 0.0)) T '(0.0 0.0 1.0))
    before (entget wall))
  (alc-test--xtend-check "zero-negative-kept"
    (and (not (alc--extend-wall wall '(0.0 100.0 0.0) 0.0))
         (not (alc--extend-wall wall '(0.0 100.0 0.0) -5.0)) (equal before (entget wall))))
  (setq layer (tblobjname "LAYER" (getvar "CLAYER")) layer-data (entget layer))
  (entmod (subst (cons 70 (logior 4 (cdr (assoc 70 layer-data)))) (assoc 70 layer-data) layer-data))
  (alc-test--xtend-check "locked-wall-kept"
    (and (not (alc--extend-wall wall '(0.0 100.0 0.0) 20.0)) (equal before (entget wall))))
  (entmod layer-data)
  (setq alc-test-xtend-checks checks)
  (princ))

(defun alc-test-xtend-prepare ()
  (alc-test-trim-prepare-interactive)
  (princ))

(defun alc-test-xtend-check-multi (/ checks)
  (setq checks alc-test-xtend-checks)
  (alc-test--xtend-check "VVXTEND-L-before-and-in-Multi"
    (and (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(-50.0 0.0 0.0) 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(1950.0 0.0 0.0) 1e-6)
         (equal (nth 1 (alc--lwp-points alc-test-trim-wall-b)) '(3025.0 0.0 0.0) 1e-6)))
  (alc-test--xtend-check "multi-hatch-area"
    (equal (vla-get-Area (vlax-ename->vla-object
      (car (alc--find-boundary-hatches alc-test-trim-wall-b)))) 215000.0 1e-5))
  (vl-cmdf "_.UNDO" 1)
  (alc-test--xtend-check "one-undo-restores-both-walls-and-hatches"
    (and (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(0.0 0.0 0.0) 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(2000.0 0.0 0.0) 1e-6)
         (equal (nth 1 (alc--lwp-points alc-test-trim-wall-b)) '(3000.0 0.0 0.0) 1e-6)
         (equal (vla-get-Area (vlax-ename->vla-object
           (car (alc--find-boundary-hatches alc-test-trim-wall-a)))) 200000.0 1e-5)
         (equal (vla-get-Area (vlax-ename->vla-object
           (car (alc--find-boundary-hatches alc-test-trim-wall-b)))) 200000.0 1e-5)))
  (setq alc-test-xtend-checks checks)
  (princ))

(defun alc-test-xtend-check-single (/ checks)
  (setq checks alc-test-xtend-checks)
  (alc-test--xtend-check "ALCXTEND-single-decimal"
    (and (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(-12.5 0.0 0.0) 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(2000.0 0.0 0.0) 1e-6)))
  (setq alc-test-xtend-checks checks)
  (princ))

(defun alc-test-xtend-check-retained (/ checks)
  (setq checks alc-test-xtend-checks)
  (alc-test--xtend-check "reload-enter-retains-xtend-length"
    (and (equal *alc-xtend-distance* 12.5 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-a)) '(-25.0 0.0 0.0) 1e-6)))
  (alc-test--xtend-check "trim-and-xtend-length-independent"
    (and (equal *alc-trim-distance* 7.0 1e-6) (equal *alc-xtend-distance* 12.5 1e-6)
         (equal (car (alc--lwp-points alc-test-trim-wall-b)) '(2007.0 0.0 0.0) 1e-6)))
  (setq alc-test-xtend-checks checks)
  (princ))
