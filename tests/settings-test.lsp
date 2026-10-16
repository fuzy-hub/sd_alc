;;; AutoCAD 2027 regression checks for version 2.6 settings.
(defun alc-test--check (name passed)
  (setq checks (cons (strcat (if passed "PASS " "FAIL ") name) checks))
  (alc-test--write-lines (strcat (alc-test--root) "/tests/results/settings-test.log")
    (reverse checks))
)

(defun alc-test--seed-scale-record (schema scale / old data new)
  (setq old (alc--settings-ename)
        data (vl-remove-if '(lambda (pair) (member (car pair) '(-1 5 330))) (entget old))
        data (subst (cons 92 schema) (assoc 92 data) data)
        data (subst (cons 40 scale) (assoc 40 data) data)
        new (entmakex data))
  (if new
    (progn
      (dictremove (namedobjdict) "ALCWALL_SETTINGS_V1")
      (dictadd (namedobjdict) "ALCWALL_SETTINGS_V1" new)
      (entdel old)))
)

(defun alc-test-run-settings (/ checks layer old-layer old-angle old-scale data
    catalog boundary hatch old-hatch-angle door-result selection index result dialog-id entry)
  (setq checks nil old-layer (getvar "CLAYER") old-angle *alc-angle* old-scale *alc-scale*)
  (alc--save-settings)
  (alc--defaults)
  (alc-test--check "default-hatch-scale-25" (= *alc-scale* 25.0))
  (alc-test--seed-scale-record 3 250.0)
  (alc--load-settings)
  (alc-test--check "legacy-default-scale-upgrades-to-25"
    (and (= *alc-scale* 25.0) (= (cdr (assoc 92 (entget (alc--settings-ename)))) 4)))
  (alc-test--seed-scale-record 3 80.0)
  (alc--load-settings)
  (alc-test--check "legacy-custom-scale-kept" (= *alc-scale* 80.0))
  (alc-test--seed-scale-record 4 250.0)
  (alc--load-settings)
  (alc-test--check "new-custom-scale-250-kept" (= *alc-scale* 250.0))
  (setq *alc-scale* old-scale)
  (alc--save-settings)
  (setq layer (if (tblobjname "LAYER" "0. Tuong ALC")
                (entget (tblobjname "LAYER" "0. Tuong ALC"))))
  (alc-test--check "startup-layer"
    (and layer (= (cdr (assoc 62 layer)) 4)
         (= (strcase (cdr (assoc 6 layer))) "CONTINUOUS")
         (= (cdr (assoc 370 layer)) 9)))
  (alc--ensure-wall-layer)
  (alc-test--check "current-layer-preserved" (= old-layer (getvar "CLAYER")))
  (alc-test--check "angle-normalization"
    (and (equal (alc--normalize-angle (- (/ pi 2))) (* pi 1.5) 1e-9)
         (equal (alc--normalize-angle (* pi 4)) 0.0 1e-9)))
  (setq *alc-angle* (/ pi 6) *alc-scale* 13.0)
  (alc--save-settings)
  (alc--load-settings)
  (alc-test--check "angle-persistence"
    (and (equal *alc-angle* (/ pi 6) 1e-9) (= *alc-scale* 13.0)))
  ;; Simulate a V2 drawing: remove angle and set schema marker to 2.
  (setq data (entget (alc--settings-ename)))
  (dictremove (namedobjdict) "ALCWALL_SETTINGS_V1")
  (entdel (cdr (assoc -1 data)))
  (setq data (vl-remove-if '(lambda (pair) (member (car pair) '(-1 5 330 44))) data)
        data (subst '(92 . 2) (assoc 92 data) data))
  (dictadd (namedobjdict) "ALCWALL_SETTINGS_V1" (entmakex data))
  (alc--load-settings)
  (alc-test--check "v2-migration-keeps-scale" (and (= *alc-angle* 0.0) (= *alc-scale* 13.0)))
  (setq catalog (alc--pattern-catalog))
  (alc-test--check "installed-pattern-catalog"
    (and (> (length catalog) 10) (assoc "ANSI31" catalog) (assoc "ANSI37" catalog)
         (assoc "SOLID" catalog) (caddr (assoc "ANSI37" catalog))))
  (alc-test--check "dashed-preview"
    (and (alc--preview-dash-p 1.0 '(2.0 -2.0))
         (not (alc--preview-dash-p 3.0 '(2.0 -2.0)))))
  (setq dialog-id (load_dialog (strcat *alc-resource-root* "/src/alc-patterns.dcl")))
  (alc-test--check "pattern-dialog-load" (> dialog-id 0))
  (unload_dialog dialog-id)
  (alc-test--clear)
  (setq *alc-angle* (/ pi 6)
        *alc-scale* 13.0
        boundary (alc--create-lwpolyline-wcs-on-layer
          '((0.0 0.0 0.0) (4000.0 0.0 0.0) (4000.0 100.0 0.0) (0.0 100.0 0.0))
          T '(0.0 0.0 1.0) old-layer)
        hatch (alc--make-hatch boundary))
  (alc-test--check "configured-hatch-angle"
    (and hatch (equal (vla-get-PatternAngle hatch) (/ pi 6) 1e-9)))
  ;; Existing hatch rotation survives even when current defaults change.
  (setq *alc-angle* (/ pi 2) *alc-temp-entities* nil
        door-result (alc--draw-door-opening boundary '(-100.0 0.0 0.0) '(1000.0 0.0 0.0)))
  (setq selection (ssget "_X" '((0 . "HATCH"))) index 0 result door-result)
  (if selection
    (repeat (sslength selection)
      (setq data (entget (ssname selection index)))
      (if (and (assoc 52 data) (not (equal (cdr (assoc 52 data)) (/ pi 6) 1e-9)))
        (setq result nil))
      (setq index (1+ index))))
  (alc-test--check "door-preserves-original-angle" result)
  (setq *alc-angle* old-angle *alc-scale* old-scale)
  (alc--save-settings)
  (alc-test--write-lines (strcat (alc-test--root) "/tests/results/settings-test.log")
    (reverse checks))
  (princ)
)
