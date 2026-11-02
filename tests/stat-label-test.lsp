;;; Visible row numbers are separate text; original curves remain untouched.
(defun alc-test--label-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "stat-label-test.log")))
  (alc-test--write-lines "stat-label-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test--label-number (selection value / index entity found)
  (setq index 0)
  (repeat (sslength selection)
    (setq entity (ssname selection index) index (1+ index))
    (if (= (cdr (assoc 1 (entget entity))) value) (setq found entity)))
  found)

(defun alc-test-run-stat-label (/ a b entries selection before table labels first second
    point layer-data changed result index old-layer replacement outside outside-label
    old-number old-color entity)
  (load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/generate-fixtures.lsp"))
  (alc-test--clear)
  (setq old-layer (getvar "CLAYER") old-number *alc-stat-number-sources*
        old-color *alc-stat-find-color*)
  (setvar "CLAYER" "0")
  (setq a (entmakex '((0 . "LINE") (8 . "0") (10 0.0 0.0 0.0) (11 1000.0 0.0 0.0)))
        b (entmakex '((0 . "LWPOLYLINE") (100 . "AcDbEntity") (8 . "0")
          (100 . "AcDbPolyline") (90 . 2) (70 . 0)
          (10 0.0 1000.0) (42 . 1.0) (10 1000.0 1000.0)))
        selection (ssadd) before (mapcar 'entget (list a b)))
  (ssadd a selection) (ssadd b selection)
  (setq entries (alc--collect-length-entries selection)
        table (alc--stat-create-output entries '(5000.0 0.0 0.0) 100.0 nil))
  (alc-test--label-check "No-mode-creates-linked-table-without-text"
    (and (not (vl-catch-all-error-p table))
      (not (ssget "_X" '((0 . "TEXT") (8 . "ALC_VVTK_STT"))))
      (equal (alc--stat-row-source table 2) b)))
  (vla-Delete table)
  (setq table (alc--stat-create-output entries '(5000.0 0.0 0.0) 100.0 T)
        labels (ssget "_X" '((0 . "TEXT") (8 . "ALC_VVTK_STT")))
        first (alc-test--label-number labels "1") second (alc-test--label-number labels "2"))
  (alc-test--label-check "Yes-mode-creates-one-text-per-source" (= (sslength labels) 2))
  (alc-test--label-check "text-numbers-match-table-STT"
    (and (= (cdr (assoc 1 (entget first))) (vla-GetText table 2 0))
         (= (cdr (assoc 1 (entget second))) (vla-GetText table 3 0))))
  (setq point (vlax-curve-getPointAtDist b (/ (alc--curve-length b) 2.0)))
  (alc-test--label-check "curved-pline-label-uses-half-arc-length-plus-offset"
    (equal (cdr (assoc 11 (entget first))) (mapcar '+ point '(0.0 80.0 0.0)) 1e-6))
  (alc-test--label-check "LINE-label-uses-midpoint-plus-offset"
    (equal (cdr (assoc 11 (entget second))) '(500.0 80.0 0.0) 1e-6))
  (alc-test--label-check "labels-use-dedicated-red-layer-and-ByLayer-color"
    (and (= (abs (cdr (assoc 62 (tblsearch "LAYER" "ALC_VVTK_STT")))) 1)
      (= (vla-get-Color (vlax-ename->vla-object first)) 256)))
  (alc-test--label-check "labels-use-requested-height-and-centered-alignment"
    (and (equal (vla-get-Height (vlax-ename->vla-object first)) 100.0 1e-6)
         (= (vla-get-Alignment (vlax-ename->vla-object first)) 10)))
  (alc-test--label-check "source-curves-are-not-modified"
    (equal before (mapcar 'entget (list a b))))
  (alc-test--label-check "Find-links-still-resolve-original-curves"
    (and (equal (alc--stat-row-source table 2) b) (equal (alc--stat-row-source table 3) a)))
  (alc-test--label-check "successful-output-leaves-no-temporary-entities" (not *alc-temp-entities*))
  (setq outside (entmakex '((0 . "LINE") (8 . "0") (10 90000.0 90000.0 0.0) (11 91000.0 90000.0 0.0)))
        outside-label (alc--stat-add-label (alc--stat-length-entry outside "0" 1000.0) 99 100.0 "ALC_VVTK_STT"))
  (alc--untrack-temp outside-label)
  (setq replacement (alc--stat-create-output entries '(9000.0 0.0 0.0) 100.0 T))
  (alc-test--label-check "renumber-removes-old-labels-for-selected-sources-only"
    (and (not (entget first)) (not (entget second)) (entget outside-label)))
  (alc-test--label-check "renumber-keeps-previous-table"
    (and (entget (vlax-vla-object->ename table))
      (= (vla-GetText replacement 2 0) "1")))
  (entdel outside-label) (entdel outside) (vla-Delete table)
  (setq table replacement labels (ssget "_X" '((0 . "TEXT") (8 . "ALC_VVTK_STT")))
        first (alc-test--label-number labels "1") second (alc-test--label-number labels "2"))
  (alc-test--label-check "renumber-does-not-accumulate-extra-text" (= (sslength labels) 2))
  ;; Strip the source tags to reproduce numbers created by the previous version.
  (foreach entity (list first second)
    (entmod (append (entget entity) (list (list -3 (list "ALC_VVTK_LABEL"))))))
  (setq replacement (alc--stat-create-output entries '(13000.0 0.0 0.0) 100.0 T))
  (alc-test--label-check "previous-untagged-labels-are-replaced-without-picking-sources"
    (and (not (entget first)) (not (entget second))
      (= (sslength (ssget "_X" '((0 . "TEXT") (8 . "ALC_VVTK_STT")))) 2)))
  (vla-Delete table)
  (setq table replacement labels (ssget "_X" '((0 . "TEXT") (8 . "ALC_VVTK_STT")))
        first (alc-test--label-number labels "1") second (alc-test--label-number labels "2"))
  (entdel first) (entdel second) (vla-Delete table)
  (command-s "_.UCS" "_Z" "90")
  (setq table (alc--stat-create-output entries '(5000.0 0.0 0.0) 100.0 T)
        labels (ssget "_X" '((0 . "TEXT") (8 . "ALC_VVTK_STT")))
        second (alc-test--label-number labels "2"))
  (alc-test--label-check "rotated-UCS-controls-label-offset-and-text-direction"
    (and (equal (cdr (assoc 11 (entget second))) '(420.0 0.0 0.0) 1e-6)
      (equal (vla-get-Rotation (vlax-ename->vla-object second)) (/ pi 2.0) 1e-6)))
  (command-s "_.UCS" "_Previous")
  (entdel (alc-test--label-number labels "1")) (entdel second) (vla-Delete table)
  ;; A real failure on label 2 must remove label 1 and the completed table too.
  (setq table (alc--stat-create-output entries '(5000.0 0.0 0.0) 100.0 T)
        labels (ssget "_X" '((0 . "TEXT") (8 . "ALC_VVTK_STT")))
        first (alc-test--label-number labels "1") second (alc-test--label-number labels "2"))
  (setq index 0)
  (defun alc--stat-add-label (entry number height layer / text)
    (setq index (1+ index))
    (if (= index 2) (car 1)
      (progn
        (setq text (vla-AddText (alc--current-space) "1" (vlax-3d-point '(0.0 0.0 0.0)) height))
        (vla-put-Layer text layer)
        (alc--track-temp (vlax-vla-object->ename text)))))
  (setq result (alc--stat-create-output entries '(5000.0 0.0 0.0) 100.0 T))
  (alc-test--label-check "label-failure-rolls-back-table-and-partial-labels"
    (and (vl-catch-all-error-p result) (= (sslength (ssget "_X" '((0 . "ACAD_TABLE")))) 1)
      (= (sslength (ssget "_X" '((0 . "TEXT") (8 . "ALC_VVTK_STT")))) 2)
      (entget first) (entget second) (not *alc-temp-entities*)))
  (alc-test--label-check "failure-preserves-source-curves" (equal before (mapcar 'entget (list a b))))
  (load (strcat *alc-resource-root* "/src/alc-schedule.lsp"))
  (entdel first) (entdel second) (vla-Delete table)
  (setq *alc-stat-number-sources* nil *alc-stat-find-color* 6)
  (alc--save-settings)
  (setq *alc-stat-number-sources* T *alc-stat-find-color* 1)
  (alc--load-settings)
  (alc-test--label-check "number-and-Find-color-preferences-survive-settings-reload"
    (and (not *alc-stat-number-sources*) (= *alc-stat-find-color* 6)))
  (setq *alc-stat-number-sources* old-number *alc-stat-find-color* old-color)
  (alc--save-settings)
  (entdel a) (entdel b)
  (setvar "CLAYER" old-layer)
  (princ))
