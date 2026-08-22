;;; Generates and validates ALCWALL DWG fixtures in ZWCAD 2027.

(vl-load-com)

(defun alc-test--root ()
  (vl-string-translate "\\" "/" (getenv "ALCWALL_TEST_ROOT"))
)

(defun alc-test--write-lines (path lines / stream line)
  (if (setq stream (open path "w"))
    (progn
      (foreach line lines (write-line line stream))
      (close stream)
      T
    )
  )
)

(defun alc-test--clear (/ selection index entity entities)
  (vl-catch-all-apply 'vl-cmdf (list "_.UCS" "_World"))
  (if (setq selection (ssget "_X"))
    (progn
      ;; Snapshot the entity names before deleting anything. AutoCAD may
      ;; invalidate entries in a selection set while its entities are erased.
      (setq index 0
            entities nil)
      (repeat (sslength selection)
        (if (setq entity (ssname selection index))
          (setq entities (cons entity entities))
        )
        (setq index (1+ index))
      )
      (foreach entity entities
        (if (entget entity) (entdel entity))
      )
    )
  )
  (setq *alc-temp-entities* nil)
  T
)

(defun alc-test--entity-count (type-name / selection)
  (if (setq selection (ssget "_X" (list (cons 0 type-name))))
    (sslength selection)
    0
  )
)

(defun alc-test--hatch-settings-ok
  (/ selection index settings all-valid)
  (setq all-valid T)
  (if (setq selection (ssget "_X" '((0 . "HATCH"))))
    (progn
      (setq index 0)
      (repeat (sslength selection)
        (setq settings
          (alc--read-hatch-settings (ssname selection index)))
        (if (not
              (and settings
                   (equal (strcase (car settings)) (strcase *alc-pattern*))
                   (= (cadr settings) *alc-color*)
                   (equal (caddr settings) *alc-scale* 1e-9)
                   (= (cadddr settings) *alc-background-color*)))
          (setq all-valid nil)
        )
        (setq index (1+ index))
      )
      all-valid
    )
    nil
  )
)

(defun alc-test--create-wall (points / boundary hatch)
  (setq boundary
    (alc--create-lwpolyline-wcs-on-layer
      points T '(0.0 0.0 1.0) (getvar "CLAYER")))
  (if boundary
    (setq hatch (alc--make-hatch boundary))
  )
  (if (and boundary hatch) boundary)
)

(defun alc-test--save (name / path document result)
  (setq path (strcat (alc-test--root) "/tests/fixtures/" name)
        document (alc--get-active-document))
  (vl-catch-all-apply 'vl-cmdf (list "_.ZOOM" "_Extents"))
  (setq result
    (vl-catch-all-apply 'vla-SaveAs (list document path)))
  (not (vl-catch-all-error-p result))
)

(defun alc-test--fixture-ok (expected-polylines expected-hatches)
  (and
    (= (alc-test--entity-count "LWPOLYLINE") expected-polylines)
    (= (alc-test--entity-count "HATCH") expected-hatches)
    (alc-test--hatch-settings-ok))
)

(defun alc-test--record (name passed results)
  (cons (strcat (if passed "PASS " "FAIL ") name) results)
)

(defun alc-test-run-fixtures
  (/ root load-result results boundary valid-result edge-wall edge-result
    transaction-wall transaction-result restore-result
    edge-polyline-count edge-hatch-count edge-pass
    local-points wcs-points normal all-passed item)
  (setq root (alc-test--root)
        results nil
        load-result
          (vl-catch-all-apply
            'load (list (strcat root "/ALCWALL.lsp"))))
  (if (vl-catch-all-error-p load-result)
    (setq results
      (list
        (strcat "FAIL LOAD_ERROR="
          (vl-catch-all-error-message load-result))))
    (progn
      (alc--load-settings)

      ;; Straight wall.
      (alc-test--clear)
      (setq boundary
        (alc-test--create-wall
          '((0.0 -50.0 0.0) (3000.0 -50.0 0.0)
            (3000.0 50.0 0.0) (0.0 50.0 0.0))))
      (setq results
        (alc-test--record "straight-wall.dwg"
          (and boundary
               (alc-test--fixture-ok 1 1)
               (alc-test--save "straight-wall.dwg"))
          results))

      ;; L-shaped wall.
      (alc-test--clear)
      (setq boundary
        (alc-test--create-wall
          '((0.0 -50.0 0.0) (2050.0 -50.0 0.0)
            (2050.0 1500.0 0.0) (1950.0 1500.0 0.0)
            (1950.0 50.0 0.0) (0.0 50.0 0.0))))
      (setq results
        (alc-test--record "l-wall.dwg"
          (and boundary
               (alc-test--fixture-ok 1 1)
               (alc-test--save "l-wall.dwg"))
          results))

      ;; U-shaped wall.
      (alc-test--clear)
      (setq boundary
        (alc-test--create-wall
          '((0.0 -50.0 0.0) (2050.0 -50.0 0.0)
            (2050.0 1550.0 0.0) (0.0 1550.0 0.0)
            (0.0 1450.0 0.0) (1950.0 1450.0 0.0)
            (1950.0 50.0 0.0) (0.0 50.0 0.0))))
      (setq results
        (alc-test--record "u-wall.dwg"
          (and boundary
               (alc-test--fixture-ok 1 1)
               (alc-test--save "u-wall.dwg"))
          results))

      ;; Wall created in a UCS rotated 30 degrees and saved with that UCS active.
      (alc-test--clear)
      (vl-catch-all-apply 'vl-cmdf (list "_.UCS" "_Z" 30.0))
      (setq local-points
          '((0.0 -50.0 0.0) (3000.0 -50.0 0.0)
            (3000.0 50.0 0.0) (0.0 50.0 0.0))
        wcs-points (mapcar '(lambda (point) (trans point 1 0)) local-points)
        normal (trans '(0.0 0.0 1.0) 1 0 T)
        boundary
          (alc--create-lwpolyline-wcs-on-layer
            wcs-points T normal (getvar "CLAYER")))
      (if boundary (setq valid-result (alc--make-hatch boundary)))
      (setq results
        (alc-test--record "rotated-ucs-wall.dwg"
          (and boundary valid-result
               (alc-test--fixture-ok 1 1)
               (alc-test--save "rotated-ucs-wall.dwg"))
          results))

      ;; Valid near-edge opening plus an exact-edge rejection that must preserve
      ;; the original second wall and its hatch.
      (alc-test--clear)
      (setq *alc-door-width* 900.0
            boundary
              (alc-test--create-wall
                '((0.0 -50.0 0.0) (3000.0 -50.0 0.0)
                  (3000.0 50.0 0.0) (0.0 50.0 0.0)))
            valid-result
              (if boundary
                (alc--draw-door-opening
                  boundary '(-100.0 0.0 0.0) '(50.0 0.0 0.0)))
            edge-wall
              (alc-test--create-wall
                '((0.0 950.0 0.0) (3000.0 950.0 0.0)
                  (3000.0 1050.0 0.0) (0.0 1050.0 0.0)))
            edge-result
              (if edge-wall
                (alc--draw-door-opening
                  edge-wall '(-100.0 1000.0 0.0) '(0.0 1000.0 0.0)))
            transaction-wall
              (alc--create-lwpolyline-wcs-on-layer
                '((0.0 1950.0 0.0) (3000.0 1950.0 0.0)
                  (3000.0 2050.0 0.0) (0.0 2050.0 0.0))
                T '(0.0 0.0 1.0) (getvar "CLAYER")))
      ;; Force the replacement-hatch stage to fail, then restore production
      ;; behavior by reloading the wall module.
      (defun alc--make-hatch-with-settings
        (boundary pattern color scale background-color)
        nil
      )
      (setq transaction-result
          (if transaction-wall
            (alc--draw-door-opening
              transaction-wall
              '(-100.0 2000.0 0.0) '(1200.0 2000.0 0.0)))
        restore-result
          (vl-catch-all-apply
            'load (list (strcat root "/src/alc-wall.lsp")))
            edge-polyline-count (alc-test--entity-count "LWPOLYLINE")
            edge-hatch-count (alc-test--entity-count "HATCH")
            edge-pass
              (and valid-result
                   (not edge-result)
                   edge-wall
                   (entget edge-wall)
                   (not transaction-result)
                   transaction-wall
                   (entget transaction-wall)
                   (not (vl-catch-all-error-p restore-result))
                   (= edge-polyline-count 4)
                   (= edge-hatch-count 3)))
      (setq results
        (cons
          (strcat
            "INFO edge-door valid=" (if valid-result "T" "nil")
            " exact-edge=" (if edge-result "T" "nil")
            " exact-edge-wall="
              (if (and edge-wall (entget edge-wall)) "kept" "missing")
            " transaction=" (if transaction-result "T" "nil")
            " transaction-wall="
              (if (and transaction-wall (entget transaction-wall))
                "kept" "missing")
            " restore="
              (if (vl-catch-all-error-p restore-result) "failed" "ok")
            " polylines=" (itoa edge-polyline-count)
            " hatches=" (itoa edge-hatch-count))
          results))
      (setq results
        (alc-test--record "edge-door-opening.dwg"
          (and edge-pass (alc-test--save "edge-door-opening.dwg"))
          results))
    )
  )

  (setq results (reverse results)
        all-passed T)
  (foreach item results
    (if (wcmatch item "FAIL*") (setq all-passed nil))
  )
  (alc-test--write-lines
    (strcat root "/tests/results/fixture-test.log")
    (cons (if all-passed "PASS" "FAIL") results))
  (prompt
    (strcat "\nALCWALL_FIXTURE_TEST_" (if all-passed "PASS" "FAIL")))
  all-passed
)

(princ)
