;;; Real layer writes/current/Undo; the color dialog response is injected.
(defun alc-test--layer-50-p (name / encoded record)
  (setq record (assoc -3 (entget (tblobjname "LAYER" name) '("AcCmTransparency")))
        encoded (cdr (assoc 1071 (cdr (cadr record)))))
  (and (numberp encoded) (/= 0 (logand encoded 33554432))
    (< (abs (- (* 100.0 (- 1.0 (/ (logand encoded 255) 255.0))) 50.0)) 0.5)))

(defun alc-test--layer-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "layer-test.log")))
  (alc-test--write-lines "layer-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test-run-layer (/ name before)
  (setq *alc-layer-test-old* (getvar "CLAYER")
        *alc-layer-test-color* 30 *alc-layer-test-picks* 0)
  (defun alc--pick-wall-layer-color ()
    (setq *alc-layer-test-picks* (1+ *alc-layer-test-picks*))
    *alc-layer-test-color*)
  (alc-test--layer-check "prefix-added"
    (= (alc--wall-layer-name " Tang 1 ") "ALC_wall_Tang 1"))
  (alc-test--layer-check "full-prefix-not-repeated"
    (= (alc--wall-layer-name "alc_WALL_Test") "ALC_wall_Test"))
  (alc-test--layer-check "blank-name-cancels" (not (alc--wall-layer-name "  ")))
  (setq name "ALC_wall_CodexInternal")
  (alc-test--layer-check "create-sets-color-and-current"
    (and (alc--create-current-wall-layer name 32) (= (getvar "CLAYER") name)
      (= (cdr (assoc 62 (tblsearch "LAYER" name))) 32)))
  (alc-test--layer-check "new-layer-default-transparency-50"
    (alc-test--layer-50-p name))
  ;; A duplicate-name attempt must preserve an existing custom transparency.
  (command-s "_.-LAYER" "_Transparency" "20" "" "")
  (setq before (entget (tblobjname "LAYER" name) '("*")))
  (alc-test--layer-check "existing-layer-never-overwritten"
    (and (not (alc--create-current-wall-layer name 1))
      (equal before (entget (tblobjname "LAYER" name) '("*")))))
  (alc-test--layer-check "invalid-color-does-not-create-layer"
    (and (not (alc--create-current-wall-layer "ALC_wall_BadColor" 256))
      (not (tblsearch "LAYER" "ALC_wall_BadColor"))))
  (setvar "CLAYER" *alc-layer-test-old*)
  (princ))

(defun alc-test-layer-check-a ()
  (alc-test--layer-check "ALCLAYER-command-uses-picker-and-sets-current"
    (and (= (getvar "CLAYER") "ALC_wall_CodexLayerA")
      (= (cdr (assoc 62 (tblsearch "LAYER" "ALC_wall_CodexLayerA"))) 30)
      (= *alc-layer-test-picks* 1)))
  (alc-test--layer-check "ALCLAYER-default-transparency-50"
    (alc-test--layer-50-p "ALC_wall_CodexLayerA")))

(defun alc-test-layer-check-undo ()
  (alc-test--layer-check "one-undo-restores-current-and-removes-layer"
    (and (= (getvar "CLAYER") *alc-layer-test-old*)
      (not (tblsearch "LAYER" "ALC_wall_CodexLayerA")))))

(defun alc-test-layer-check-b ()
  (alc-test--layer-check "VVLAYER-alias-accepts-full-name"
    (and (= (getvar "CLAYER") "ALC_wall_CodexLayerB")
      (= (cdr (assoc 62 (tblsearch "LAYER" "ALC_wall_CodexLayerB"))) 5)))
  (alc-test--layer-check "VVLAYER-default-transparency-50"
    (alc-test--layer-50-p "ALC_wall_CodexLayerB")))

(defun alc-test-layer-check-cancel ()
  (alc-test--layer-check "palette-cancel-does-not-create-or-change-current"
    (and (= (getvar "CLAYER") "ALC_wall_CodexLayerB")
      (not (tblsearch "LAYER" "ALC_wall_CodexCancelled"))))
  (princ))

(defun alc-test-layer-check-blank ()
  (alc-test--layer-check "blank-command-name-skips-picker"
    (and (= *alc-layer-test-picks* 3) (= (getvar "CLAYER") "ALC_wall_CodexLayerB"))))

(defun alc-test-layer-check-duplicate ()
  (alc-test--layer-check "duplicate-name-reprompts-without-changing-existing-color"
    (and (= (getvar "CLAYER") "ALC_wall_CodexLayerC")
      (= (cdr (assoc 62 (tblsearch "LAYER" "ALC_wall_CodexLayerB"))) 5)
      (= (cdr (assoc 62 (tblsearch "LAYER" "ALC_wall_CodexLayerC"))) 1)))
  (setvar "CLAYER" *alc-layer-test-old*)
  (defun alc--pick-wall-layer-color () (acad_colordlg 7 nil))
  (princ))
(princ)
