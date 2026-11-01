;;; Per-cell source links and native VVTK/Find interaction.
(defun alc-test--find-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "stat-find-test.log")))
  (alc-test--write-lines "stat-find-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test--find-point (table row column / point index)
  (setq point (vlax-safearray->list (vlax-variant-value (vla-get-InsertionPoint table))) index 0)
  (repeat column
    (setq point (list (+ (car point) (vla-GetColumnWidth table index)) (cadr point) (caddr point))
          index (1+ index)))
  (setq point (list (+ (car point) (/ (vla-GetColumnWidth table column) 2.0)) (cadr point) (caddr point)) index 0)
  (repeat row
    (setq point (list (car point) (- (cadr point) (vla-GetRowHeight table index)) (caddr point)) index (1+ index)))
  (list (car point) (- (cadr point) (/ (vla-GetRowHeight table row) 2.0)) (caddr point)))

(defun alc-test--find-pick (table row column)
  (list (vlax-vla-object->ename table) (trans (alc-test--find-point table row column) 0 1)))

(defun alc-test-stat-find-prepare (/ selection)
  (alc-test--clear)
  (setvar "CLAYER" "0") (setvar "OSMODE" 0)
  (setq *alc-find-test-a* (entmakex '((0 . "LINE") (8 . "0") (10 0.0 0.0 0.0) (11 1000.0 0.0 0.0)))
        *alc-find-test-b* (alc--create-lwpolyline-wcs-on-layer
          '((0.0 100.0 0.0) (1000.0 100.0 0.0)) nil '(0.0 0.0 1.0) "0")
        selection (ssadd))
  (ssadd *alc-find-test-a* selection) (ssadd *alc-find-test-b* selection)
  (setq *alc-find-test-entries* (alc--collect-length-entries selection)
        *alc-find-test-table* (alc--add-length-source-table *alc-find-test-entries* '(5000.0 0.0 0.0) 100.0))
  (command-s "_.ZOOM" "_Extents")
  (alc-test--write-lines "stat-find-points.log"
    (list (vl-princ-to-string (alc-test--find-point *alc-find-test-table* 2 3))
          (vl-princ-to-string (alc-test--find-point *alc-find-test-table* 3 0))))
  (princ))

(defun alc-test-run-stat-find (/ table a b row original data point angle rotated source legacy copy
    selection closed entities before path original-path document)
  (alc-test-stat-find-prepare)
  (setq table *alc-find-test-table* a *alc-find-test-a* b *alc-find-test-b*
        entities (list a b) before (mapcar 'entget entities))
  (alc-test--find-check "equal-length-rows-keep-distinct-source-handles-in-spatial-order"
    (equal (mapcar 'caddr *alc-find-test-entries*) (list (cdr (assoc 5 (entget b))) (cdr (assoc 5 (entget a))))))
  (alc-test--find-check "linked-table-keeps-four-columns-and-original-data-values"
    (and (= (vla-get-Columns table) 4) (= (vla-get-Rows table) 5)
      (= (vla-GetText table 2 3) (rtos 1.0 2 3)) (= (vla-GetText table 3 3) (rtos 1.0 2 3))))
  (alc-test--find-check "first-data-row-resolves-exact-upper-polyline" (equal (alc--stat-row-source table 2) b))
  (alc-test--find-check "second-data-row-resolves-exact-lower-LINE" (equal (alc--stat-row-source table 3) a))
  (alc-test--find-check "headers-and-grand-total-never-resolve-a-source"
    (and (not (alc--stat-row-source table 0)) (not (alc--stat-row-source table 1))
      (not (alc--stat-row-source table 4))))
  (alc-test--find-check "HitTest-on-length-cell-resolves-the-row-source"
    (equal (alc--stat-find-at-pick (alc-test--find-pick table 2 3)) b))
  (alc-test--find-check "HitTest-on-STT-cell-resolves-the-same-source"
    (equal (alc--stat-find-at-pick (alc-test--find-pick table 2 0)) b))
  (vla-Move table (vlax-3d-point '(0.0 0.0 0.0)) (vlax-3d-point '(500.0 300.0 0.0)))
  (alc-test--find-check "moved-table-uses-new-cell-position-with-same-source"
    (equal (alc--stat-find-at-pick (alc-test--find-pick table 2 3)) b))
  (vla-Move table (vlax-3d-point '(500.0 300.0 0.0)) (vlax-3d-point '(0.0 0.0 0.0)))
  (setq point (alc-test--find-point table 2 3) angle 0.3
        rotated (list (- (* (car point) (cos angle)) (* (cadr point) (sin angle)))
          (+ (* (car point) (sin angle)) (* (cadr point) (cos angle))) 0.0))
  (vla-Rotate table (vlax-3d-point '(0.0 0.0 0.0)) angle)
  (alc-test--find-check "rotated-table-HitTest-keeps-the-correct-row"
    (equal (alc--stat-find-at-pick (list (vlax-vla-object->ename table) rotated)) b))
  (vla-Rotate table (vlax-3d-point '(0.0 0.0 0.0)) (- angle))
  (command-s "_.UCS" "_Z" 30.0)
  (alc-test--find-check "rotated-UCS-pick-is-converted-to-WCS"
    (equal (alc--stat-find-at-pick (alc-test--find-pick table 2 3)) b))
  (command-s "_.UCS" "_World")
  (vla-InsertRows table 2 180.0 1)
  (alc-test--find-check "source-link-follows-its-cell-after-row-insertion"
    (equal (alc--stat-row-source table 3) b))
  (vla-DeleteRows table 2 1)
  (vla-Move (vlax-ename->vla-object b) (vlax-3d-point '(0.0 0.0 0.0)) (vlax-3d-point '(200.0 500.0 0.0)))
  (alc-test--find-check "moved-source-is-found-by-identity-instead-of-length-or-position"
    (equal (alc--stat-row-source table 2) b))
  (vla-Move (vlax-ename->vla-object b) (vlax-3d-point '(200.0 500.0 0.0)) (vlax-3d-point '(0.0 0.0 0.0)))
  (entdel b)
  (alc-test--find-check "deleted-source-is-reported-without-guessing-a-same-length-object"
    (not (alc--stat-row-source table 2)))
  (entdel b)
  (setq original (vla-GetText table 2 3)) (vla-SetText table 2 3 "999.999")
  (alc-test--find-check "edited-row-is-rejected-instead-of-following-a-stale-link"
    (not (alc--stat-row-source table 2)))
  (vla-SetText table 2 3 original)
  (setq data (alc--stat-cell-link-value table 2))
  (vla-SetCustomData table 2 0 "ALC_VVTK_ROW"
    (vlax-make-variant (vl-prin1-to-string (subst "OTHER_DRAWING" (cadr data) data)) vlax-vbString))
  (alc-test--find-check "foreign-drawing-link-is-rejected" (not (alc--stat-row-source table 2)))
  (vla-SetCustomData table 2 0 "ALC_VVTK_ROW" (vlax-make-variant (vl-prin1-to-string data) vlax-vbString))
  (setq legacy (alc--add-length-detail-table '(("0" . 1000.0)) '(10000.0 0.0 0.0) 100.0))
  (alc-test--find-check "old-untagged-tables-are-not-guessed-from-equal-lengths"
    (not (alc--stat-row-source legacy 2)))
  (setq copy (vla-Copy table))
  (alc-test--find-check "table-copy-in-same-drawing-retains-original-source-links"
    (equal (alc--stat-row-source copy 2) b))
  (vla-Delete copy)
  (alc-test--find-check "linked-VVTK-table-remains-valid-for-VVSUMTABLE"
    (equal (cdr (cadddr (alc--sumtable-source-entry (vlax-vla-object->ename table)))) 2000.0 1e-6))
  (alc-test--find-check "lookup-does-not-modify-source-entity-data" (equal before (mapcar 'entget entities)))
  (alc-test-run-stat-find-colors)
  ;; Save an independent snapshot, then restore the runner's active file path.
  (setq document (alc--get-active-document) original-path (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))
        path (strcat (getenv "ALCWALL_TEST_RUN") "/stat-find-persist.dwg"))
  (vla-SetText table 0 0 "VVTK FIND PERSISTENCE")
  (vla-SaveAs document path)
  (vla-SaveAs document original-path)
  (alc-test--find-check "persistent-source-links-are-written-to-independent-DWG" (findfile path))
  (princ))

(defun alc-test-stat-find-selected (expected / selected)
  (setq selected (cadr (ssgetfirst)))
  (alc-test--find-check "native-VVTK-Find-selects-exact-original-object"
    (and selected (= (sslength selected) 1) (equal (ssname selected 0) expected)
      (= (getvar "OSMODE") 3))))

(defun alc-test-run-stat-find-colors (/ effect color snaps before trace queue choice
    *alc-stat-find-color* *alc-stat-find-highlight*)
  (setq effect (getvar "SELECTIONEFFECT") color (getvar "SELECTIONEFFECTCOLOR")
        snaps (getvar "OSMODE") before (mapcar 'entget (list *alc-find-test-a* *alc-find-test-b*)))
  (alc-test--find-check "Find-default-color-is-red-ACI-1" (= (alc--stat-find-color) 1))
  (setq *alc-stat-find-color* 4)
  (load (strcat *alc-resource-root* "/src/alc-schedule.lsp"))
  (alc-test--find-check "Find-choice-survives-module-reload" (= (alc--stat-find-color) 4))
  (setq *alc-stat-find-color* 256)
  (alc-test--find-check "invalid-saved-color-resets-to-red" (= (alc--stat-find-color) 1))
  (defun alc--stat-find-pick-color () choice)
  (setq *alc-stat-find-color* 5 choice nil)
  (alc--stat-find-change-color)
  (alc-test--find-check "cancel-color-picker-keeps-previous-choice" (= (alc--stat-find-color) 5))
  (setq choice 256) (alc--stat-find-change-color)
  (alc-test--find-check "ByLayer-color-is-rejected" (= (alc--stat-find-color) 5))
  (setq choice 2) (alc--stat-find-change-color)
  (alc-test--find-check "valid-color-updates-session-choice-and-selection-effect"
    (and (= (alc--stat-find-color) 2) (= (getvar "SELECTIONEFFECTCOLOR") 2)))
  (setq *alc-stat-find-color* 1 trace nil queue (list (alc-test--find-point *alc-find-test-table* 2 3)
    "Color" (alc-test--find-point *alc-find-test-table* 3 0) nil))
  (defun alc--stat-find-read-point (/ point)
    (setq trace (append trace (list (list (getvar "SELECTIONEFFECT") (getvar "SELECTIONEFFECTCOLOR"))))
          point (car queue) queue (cdr queue)) point)
  (setvar "SELECTIONEFFECT" 0) (setvar "SELECTIONEFFECTCOLOR" 4) (setvar "OSMODE" 3)
  (alc--stat-find-loop)
  (alc-test--find-check "Find-applies-red-glow-before-first-row-pick" (equal (car trace) '(1 1)))
  (alc-test--find-check "Color-option-updates-highlight-within-the-same-Find"
    (and (equal (nth 2 trace) '(1 2)) (equal (nth 3 trace) '(1 2))))
  (alc-test--find-check "Find-restores-global-effects-color-and-snaps-on-exit"
    (and (= (getvar "SELECTIONEFFECT") 0) (= (getvar "SELECTIONEFFECTCOLOR") 4) (= (getvar "OSMODE") 3)))
  (alc-test--find-check "color-highlight-does-not-change-source-entity-properties"
    (equal before (mapcar 'entget (list *alc-find-test-a* *alc-find-test-b*))))
  (load (strcat *alc-resource-root* "/src/alc-schedule.lsp"))
  (alc-test--find-check "chosen-color-is-remembered-after-Find-and-reload" (= (alc--stat-find-color) 2))
  (defun alc--stat-find-read-point () (car 1))
  (alc--stat-find-loop)
  (alc-test--find-check "error-cleanup-restores-effects-and-snaps"
    (and (= (getvar "SELECTIONEFFECT") 0) (= (getvar "SELECTIONEFFECTCOLOR") 4) (= (getvar "OSMODE") 3)))
  (load (strcat *alc-resource-root* "/src/alc-schedule.lsp"))
  (setvar "SELECTIONEFFECT" effect) (setvar "SELECTIONEFFECTCOLOR" color) (setvar "OSMODE" snaps)
  (princ))

(defun alc-test-stat-find-native-color ()
  (alc-test--find-check "native-Color-option-remembers-choice-and-restores-global-settings"
    (and (= (alc--stat-find-color) 2)
      (= (getvar "SELECTIONEFFECT") *alc-find-test-effect*)
      (= (getvar "SELECTIONEFFECTCOLOR") *alc-find-test-effect-color*))))

(defun alc-test-stat-find-created (/ selection index table found)
  (setq selection (ssget "_X" '((0 . "ACAD_TABLE"))) index 0)
  (repeat (sslength selection)
    (setq table (vlax-ename->vla-object (ssname selection index)) index (1+ index))
    (if (and (not (equal (vlax-vla-object->ename table) (vlax-vla-object->ename *alc-find-test-table*)))
             (equal (alc--stat-row-source table 2) *alc-find-test-b*)
             (equal (alc--stat-row-source table 3) *alc-find-test-a*)) (setq found T)))
  (alc-test--find-check "native-VVTK-create-saves-the-source-link-for-each-row"
    (and (= (sslength selection) 2) found)))

(defun alc-test-stat-find-create-undo ()
  (alc-test--find-check "one-Undo-removes-created-linked-table-and-keeps-source-objects"
    (and (= (alc-test--entity-count "ACAD_TABLE") 1)
      (entget *alc-find-test-a*) (entget *alc-find-test-b*))))

(defun alc-test-run-stat-find-reopen (/ selection index table sources valid source)
  (setq selection (ssget "_X" '((0 . "ACAD_TABLE"))) index 0)
  (repeat (sslength selection)
    (setq source (vlax-ename->vla-object (ssname selection index)) index (1+ index))
    (if (= (vla-GetText source 0 0) "VVTK FIND PERSISTENCE") (setq table source)))
  (setq valid (and table (alc--stat-row-source table 2) (alc--stat-row-source table 3)))
  (alc-test--write-lines "stat-find-reopen-test.log"
    (list (strcat (if valid "PASS " "FAIL ") "saved-DWG-reopened-source-links-resolve")))
  (if valid
    (alc-test--write-lines "stat-find-reopen-test.log"
      (list "PASS saved-DWG-reopened-source-links-resolve"
        (strcat (if (equal (alc--stat-find-at-pick (alc-test--find-pick table 2 3))
                          (alc--stat-row-source table 2)) "PASS " "FAIL ") "reopened-table-HitTest-resolves-original"))))
  (princ))
(princ)
