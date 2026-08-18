;;; Regression test for ALCGT side selection on vertical reference lines.

(vl-load-com)

(defun alc-tie-test--near (actual expected)
  (< (abs (- actual expected)) 1e-6)
)

(defun alc-tie-test--bounds (/ selection entity points xs ys)
  (if (and
        (setq selection (ssget "_X" '((0 . "LWPOLYLINE"))))
        (= (sslength selection) 1))
    (progn
      (setq entity (ssname selection 0)
            points (alc--lwp-points entity)
            xs (mapcar 'car points)
            ys (mapcar 'cadr points))
      (list (apply 'min xs) (apply 'max xs)
            (apply 'min ys) (apply 'max ys))
    )
  )
)

(defun alc-tie-test--case
  (name start end side-point expected-min-x expected-max-x / result bounds pass)
  (alc-test--clear)
  (setq result
      (alc--draw-wall-tie start end side-point 150.0 4)
    bounds (alc-tie-test--bounds)
    pass
      (and result bounds
           (alc-tie-test--near (car bounds) expected-min-x)
           (alc-tie-test--near (cadr bounds) expected-max-x)
           (alc-tie-test--near (caddr bounds) 0.0)
           (alc-tie-test--near (cadddr bounds) 1000.0)
           (= (alc-test--entity-count "HATCH") 1)))
  (strcat (if pass "PASS " "FAIL ") name)
)

(defun alc-test-run-wall-tie-side (/ root lines ambiguous-result all-passed item)
  (setq root (alc-test--root)
        lines
          (list
            (alc-tie-test--case
              "vertical-up-right"
              '(0.0 0.0 0.0) '(0.0 1000.0 0.0) '(100.0 500.0 0.0)
              50.0 200.0)
            (alc-tie-test--case
              "vertical-up-left"
              '(0.0 0.0 0.0) '(0.0 1000.0 0.0) '(-100.0 500.0 0.0)
              -200.0 -50.0)
            (alc-tie-test--case
              "vertical-down-right"
              '(0.0 1000.0 0.0) '(0.0 0.0 0.0) '(100.0 500.0 0.0)
              50.0 200.0)
            (alc-tie-test--case
              "vertical-down-left"
              '(0.0 1000.0 0.0) '(0.0 0.0 0.0) '(-100.0 500.0 0.0)
              -200.0 -50.0)))

  ;; A point snapped onto the reference line is ambiguous and must not create
  ;; a tie on an arbitrary side.
  (alc-test--clear)
  (setq ambiguous-result
      (alc--draw-wall-tie
        '(0.0 0.0 0.0) '(0.0 1000.0 0.0) '(0.0 500.0 0.0)
        150.0 4)
    lines
      (append lines
        (list
          (strcat
            (if (and (not ambiguous-result)
                     (= (alc-test--entity-count "LWPOLYLINE") 0)
                     (= (alc-test--entity-count "HATCH") 0))
              "PASS " "FAIL ")
            "vertical-ambiguous-point")))
    all-passed T)

  (foreach item lines
    (if (wcmatch item "FAIL*") (setq all-passed nil))
  )
  (alc-test--write-lines
    (strcat root "/tests/results/wall-tie-side-test.log")
    (cons (if all-passed "PASS" "FAIL") lines))
  (prompt
    (strcat "\nALCGT_SIDE_TEST_" (if all-passed "PASS" "FAIL")))
  all-passed
)

(princ)
