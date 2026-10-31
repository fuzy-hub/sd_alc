(defun alc-test--assign-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "assign-test.log")))
  (alc-test--write-lines "assign-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test-run-assign (/ old-layer old-width catalog picked answer id index before)
  (setq old-layer (getvar "CLAYER") old-width (getvar "PLINEWID"))
  (alc--create-current-wall-layer "ALC_wall_Assign_100" 3)
  (alc--create-current-wall-layer "alc_Assign_150" 4)
  (alc--create-current-wall-layer "ALC_AssignTang1" 5)
  (alc--create-current-wall-layer "CodexNotAlc" 6)
  (setq catalog (alc--assign-catalog))
  (alc-test--assign-check "filter-ALC-case-insensitive"
    (and (member "ALC_wall_Assign_100" catalog) (member "alc_Assign_150" catalog)
      (not (member "CodexNotAlc" catalog))))
  (alc-test--assign-check "default-width-from-name-100-150"
    (and (= (alc--assign-width "ALC_wall_Assign_100") 100.0)
         (= (alc--assign-width "alc_Assign_150") 150.0)))
  (alc-test--assign-check "unrelated-floor-number-not-inferred"
    (not (alc--assign-width "ALC_AssignTang1")))
  (alc-test--assign-check "apply-switches-current-and-PLINEWID"
    (and (alc--apply-assign-layer "alc_Assign_150" 150.0)
      (= (getvar "CLAYER") "alc_Assign_150") (= (getvar "PLINEWID") 150.0)))
  (alc-test--assign-check "saved-width-overrides-name"
    (and (alc--apply-assign-layer "ALC_wall_Assign_100" 125.0)
      (= (alc--assign-width "ALC_wall_Assign_100") 125.0)))
  (setq before (list (getvar "CLAYER") (getvar "PLINEWID")))
  (alc-test--assign-check "invalid-width-or-nonALC-preserves-current"
    (and (not (alc--apply-assign-layer "alc_Assign_150" -1.0))
      (not (alc--apply-assign-layer "CodexNotAlc" 100.0))
      (equal before (list (getvar "CLAYER") (getvar "PLINEWID")))))
  (alc-test--assign-check "zero-width-is-supported-and-persisted"
    (and (alc--apply-assign-layer "ALC_AssignTang1" 0.0)
      (= (getvar "PLINEWID") 0.0) (= (alc--assign-width "ALC_AssignTang1") 0.0)))
  (defun alc--choose-assign-layer (catalog) (list "alc_Assign_150" 150.0))
  (c:ALCASSIGN)
  (alc-test--assign-check "ALCASSIGN-public-command"
    (and (= (getvar "CLAYER") "alc_Assign_150") (= (getvar "PLINEWID") 150.0)))
  (c:VVA)
  (alc-test--assign-check "VVA-public-alias"
    (and (= (getvar "CLAYER") "alc_Assign_150") (= (getvar "PLINEWID") 150.0)))
  (defun alc--choose-assign-layer (catalog) (list "ALC_wall_Assign_100" 100.0))
  (c:VVASSIGN)
  (alc-test--assign-check "VVASSIGN-public-alias"
    (and (= (getvar "CLAYER") "ALC_wall_Assign_100") (= (getvar "PLINEWID") 100.0)))
  (defun alc--choose-assign-layer (catalog) nil)
  (setq before (list (getvar "CLAYER") (getvar "PLINEWID")))
  (c:ALCASSIGN)
  (alc-test--assign-check "cancel-preserves-current-and-width"
    (equal before (list (getvar "CLAYER") (getvar "PLINEWID"))))
  ;; Restore real dialog and ensure the layer's value survives reloading Lisp.
  (load (strcat *alc-resource-root* "/src/alc-commands.lsp"))
  (alc-test--assign-check "width-survives-module-reload"
    (= (alc--assign-width "alc_Assign_150") 150.0))
  (setvar "CLAYER" old-layer) (setvar "PLINEWID" old-width)
  (princ))
(princ)

(defun alc-test-enter-prepare ()
  (alc--create-current-wall-layer "ALC_Enter_100" 3)
  (alc--create-current-wall-layer "ALC_Enter_150" 4)
  (alc--apply-assign-layer "ALC_Enter_100" 100.0)
  (princ))

(defun alc-test-enter-check (name layer width / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "assign-enter-test.log")))
  (alc-test--write-lines "assign-enter-test.log"
    (append lines (list (strcat
      (if (and (= (getvar "CLAYER") layer) (equal (getvar "PLINEWID") width 1e-6)) "PASS " "FAIL ") name)))))
