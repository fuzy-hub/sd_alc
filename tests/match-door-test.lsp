(defun alc-test--door-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "match-door-test.log")))
  (alc-test--write-lines "match-door-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test--door-wall (x y wall-length width / wall)
  (setq wall (alc-test--standard-source (list (list x y 0.0) (list (+ x wall-length) y 0.0)
    (list (+ x wall-length) (+ y width) 0.0) (list x (+ y width) 0.0))))
  (alc--wall-write-tag wall width 2)
  wall)

(defun alc-test--door-records (walls / wall entry records)
  (foreach wall walls
    (foreach entry (alc--match-entries wall) (setq records (cons (list wall entry) records))))
  (reverse records))

(defun alc-test--door-create (walls / *alc-match-index-ready* *alc-match-outputs* *alc-match-door-dims*
    *alc-match-pending* count dim-count replaced-count skipped)
  (setq *alc-match-index-ready* T *alc-match-outputs* (alc--match-existing-outputs)
        *alc-match-door-dims* (alc--match-door-dimensions)
        *alc-match-pending* (alc--match-jobs (alc-test--door-records walls))
        count 0 dim-count 0 replaced-count 0 skipped 0)
  (alc--match-create-loop)
  (list count dim-count replaced-count))

(defun alc-test-run-match-door (/ a b c jobs value result walls before outputs dim line points)
  (alc-test-standard-prepare)
  (setvar "CLAYER" "0")
  (foreach value '(899.0 900.0 2000.0 2001.0)
    (alc-test--clear)
    (setq a (alc-test--door-wall 0.0 0.0 1000.0 100.0)
          b (alc-test--door-wall (+ 1000.0 value) 0.0 1000.0 100.0)
          jobs (alc--match-jobs (alc-test--door-records (list a b))))
    (alc-test--door-check (strcat "door-boundary-" (rtos value 2 0))
      (= (length jobs) (if (<= 900.0 value 2000.0) 1 2))))
  (alc-test--clear)
  (setq a (alc-test--door-wall 0.0 0.0 1000.0 100.0)
        b (alc-test--door-wall 1900.0 0.0 1500.0 100.0)
        c (alc-test--door-wall 5400.0 0.0 1000.0 100.0)
        walls (list a b c) before (mapcar 'entget walls)
        jobs (alc--match-jobs (alc-test--door-records walls)))
  (alc-test--door-check "three-walls-two-doors-make-one-6400-axis"
    (and (= (length jobs) 1) (= (distance (cadr (cadar jobs)) (caddr (cadar jobs))) 6400.0)
         (= (length (cadddr (car jobs))) 2)))
  (alc--match-wall a) (alc--match-wall b) (alc--match-wall c)
  (setq result (alc-test--door-create walls))
  (alc-test--door-check "replaces-three-local-axes-with-one-through-both-doors"
    (and (equal result '(1 2 3)) (= (alc-test--entity-count "LWPOLYLINE") 4)
      (= (alc-test--entity-count "DIMENSION") 2)))
  (setq outputs (alc--match-existing-outputs))
  (alc-test--door-check "joined-axis-centered-and-width-preserved"
    (and (= (length outputs) 1)
      (alc-test--match-output-p (caar outputs) '(0.0 50.0 0.0) '(6400.0 50.0 0.0) 100.0)))
  (alc-test--door-check "source-walls-unchanged" (equal before (mapcar 'entget walls)))
  (alc-test--door-check "dimension-measurements-900-and-2000"
    (equal (vl-sort (mapcar '(lambda (d) (vla-get-Measurement (vlax-ename->vla-object (car d))))
      (alc--match-door-dimensions)) '<) '(900.0 2000.0) 1e-5))
  (alc-test--door-check "repeat-does-not-duplicate-axis-or-door-dims"
    (and (equal (alc-test--door-create (reverse walls)) '(0 0 0))
      (= (alc-test--entity-count "LWPOLYLINE") 4) (= (alc-test--entity-count "DIMENSION") 2)))
  (setq dim (caar (alc--match-door-dimensions))) (entdel dim)
  (alc-test--door-check "deleted-door-dimension-is-recreated-without-extra-axis"
    (and (equal (alc-test--door-create walls) '(0 1 0)) (= (alc-test--entity-count "DIMENSION") 2)))
  (alc-test--clear)
  (setq a (alc-test--door-wall 0.0 0.0 1000.0 100.0)
        b (alc-test--door-wall 1900.0 0.0 1000.0 150.0))
  (alc-test--door-check "different-widths-never-join"
    (= (length (alc--match-jobs (alc-test--door-records (list a b)))) 2))
  (setq b (alc-test--door-wall 1900.0 20.0 1000.0 100.0))
  (alc-test--door-check "parallel-but-offset-centers-never-join"
    (= (length (alc--match-jobs (alc-test--door-records (list a b)))) 2))
  (setq b (alc-test--door-wall 1900.0 0.0 1000.0 100.0))
  (vla-Move (vlax-ename->vla-object b) (vlax-3d-point '(0.0 0.0 0.0)) (vlax-3d-point '(0.0 0.0 20.0)))
  (alc-test--door-check "different-elevations-never-join"
    (= (length (alc--match-jobs (alc-test--door-records (list a b)))) 2))
  (alc-test--door-check "selecting-only-one-side-does-not-scan-or-extend-to-other-wall"
    (equal (alc-test--door-create (list a)) '(1 0 0)))
  (alc-test--clear)
  (setq a (alc-test--door-wall 0.0 0.0 1000.0 100.0)
        b (alc-test--door-wall 1900.0 0.0 1000.0 100.0)
        walls (list a b))
  (foreach line walls
    (vla-Rotate (vlax-ename->vla-object line) (vlax-3d-point '(0.0 0.0 0.0)) 0.37))
  (alc-test--door-check "rotated-walls-join-with-true-door-dimension"
    (and (equal (alc-test--door-create walls) '(1 1 0))
      (equal (vla-get-Measurement (vlax-ename->vla-object (caar (alc--match-door-dimensions)))) 900.0 1e-5)))
  (alc-test--clear)
  (setq a (alc-test--standard-source '((0.0 0.0 0.0) (1000.0 0.0 0.0) (1000.0 1000.0 0.0)
    (900.0 1000.0 0.0) (900.0 100.0 0.0) (0.0 100.0 0.0)))
    b (alc-test--door-wall 1900.0 0.0 1000.0 100.0))
  (alc-test--door-check "L-branch-can-join-straight-wall-across-door"
    (and (equal (alc-test--door-create (list a b)) '(2 1 0))
      (= (length (alc--match-existing-outputs)) 2)))
  (alc-test--clear)
  (setq a (alc-test--door-wall 0.0 0.0 1000.0 100.0)
        b (alc-test--door-wall 1900.0 0.0 1000.0 100.0) walls (list a b))
  (alc--match-wall a) (alc--match-wall b)
  (defun alc--match-add-door-dim (wall width gap) (car 1))
  (alc-test--door-check "dimension-failure-keeps-old-axes-and-rolls-back-new-joined-axis"
    (and (equal (alc-test--door-create walls) '(0 0 0))
      (= (alc-test--entity-count "LWPOLYLINE") 4) (= (alc-test--entity-count "DIMENSION") 0)
      (not *alc-temp-entities*)))
  (load (strcat *alc-resource-root* "/src/alc-commands.lsp"))
  (alc-test--clear)
  (setq a (alc-test--door-wall 0.0 0.0 1000.0 100.0)
        b (alc-test--door-wall 500.0 0.0 1000.0 100.0)
        c (alc-test--door-wall 2400.0 0.0 1000.0 100.0))
  (alc-test--door-check "overlapping-source-intervals-do-not-infer-door"
    (= (length (alc--match-jobs (alc-test--door-records (list a b c)))) 3))
  (alc-test--clear)
  (setq points '((0.0 0.0 0.0) (100.0 0.0 0.0) (100.0 1000.0 0.0) (0.0 1000.0 0.0))
        a (alc--create-lwpolyline-wcs-on-layer
          (mapcar '(lambda (p) (list (car p) 0.0 (cadr p))) points) T '(0.0 -1.0 0.0) "ALC_wall default")
        b (alc--create-lwpolyline-wcs-on-layer
          (mapcar '(lambda (p) (list (car p) 0.0 (+ 1900.0 (cadr p)))) points) T '(0.0 -1.0 0.0) "ALC_wall default"))
  (alc--wall-write-tag a 100.0 2) (alc--wall-write-tag b 100.0 2)
  (setq result (alc-test--door-create (list a b)))
  (alc-test--door-check "vertical-plane-door-dimension-has-true-900-measurement"
    (and (equal result '(1 1 0))
      (equal (vla-get-Measurement (vlax-ename->vla-object (caar (alc--match-door-dimensions)))) 900.0 1e-5)
      (equal (alc-test--door-create (list b a)) '(0 0 0))))
  (princ))

(defun alc-test-door-public-prepare ()
  (alc-test-standard-prepare)
  (setvar "CLAYER" "0")
  (setq *alc-door-a* (alc-test--door-wall 0.0 0.0 1000.0 100.0)
        *alc-door-b* (alc-test--door-wall 1900.0 0.0 1000.0 100.0)
        *alc-door-before* (mapcar 'entget (list *alc-door-a* *alc-door-b*)))
  ;; Existing local outputs must be restored by one Undo after replacement.
  (alc--match-wall *alc-door-a*) (alc--match-wall *alc-door-b*)
  (setvar "PICKFIRST" 1)
  (sssetfirst nil (ssadd *alc-door-a* (ssadd *alc-door-b*)))
  (princ))

(defun alc-test-door-public-check (/ axes dims)
  (setq axes (alc--match-existing-outputs) dims (alc--match-door-dimensions))
  (alc-test--door-check "native-VVM-one-joined-axis-and-one-door-dim"
    (and (= (length axes) 1) (= (length dims) 1)
      (alc-test--match-output-p (caar axes) '(0.0 50.0 0.0) '(2900.0 50.0 0.0) 100.0)
      (equal (vla-get-Measurement (vlax-ename->vla-object (caar dims))) 900.0 1e-5)))
  (alc-test--door-check "native-VVM-keeps-source-and-counts-door-in-total"
    (and (equal *alc-door-before* (mapcar 'entget (list *alc-door-a* *alc-door-b*)))
      (equal (alc--curve-length (caar axes)) 2900.0 1e-5))))

(defun alc-test-door-public-undo-check ()
  (alc-test--door-check "one-undo-restores-local-axes-and-removes-joined-axis-and-dim"
    (and (= (length (alc--match-existing-outputs)) 2)
      (= (alc-test--entity-count "DIMENSION") 0)
      (= (alc-test--entity-count "LWPOLYLINE") 4)
      (equal *alc-door-before* (mapcar 'entget (list *alc-door-a* *alc-door-b*))))))
