;;; Sum the displayed VVTK totals, one selected source table per output row.
(defun alc-test--sumtable-check (name pass / lines)
  (setq lines (alc-test--read-lines (alc-test--result-path "sumtable-test.log")))
  (alc-test--write-lines "sumtable-test.log"
    (append lines (list (strcat (if pass "PASS " "FAIL ") name)))))

(defun alc-test--sumtable-cells (table / row column cells)
  (setq row 0)
  (repeat (vla-get-Rows table)
    (setq column 0)
    (repeat (vla-get-Columns table)
      (setq cells (cons (vla-GetText table row column) cells) column (1+ column)))
    (setq row (1+ row)))
  (reverse cells))

(defun alc-test-run-sumtable (/ a b c d zero unrelated summary rows selection before
    result row item valid cells last-row original-total)
  (alc-test--clear)
  (setvar "CLAYER" "0")
  (setq a (alc--add-length-detail-table '(("A" . 1234.4) ("A" . 4321.4)) '(50000.0 0.0 0.0) 100.0)
        b (alc--add-length-detail-table '(("B" . 2500.4)) '(0.0 10000.0 0.0) 100.0)
        c (alc--add-length-table '(("C" . 11000.0)) '(0.0 0.0 0.0) 100.0)
        d (alc--add-length-detail-table '(("D" . 2500.4)) '(80000.0 0.0 0.0) 100.0)
        zero (alc--add-length-detail-table '(("Zero" . 0.0)) '(100000.0 0.0 0.0) 100.0)
        unrelated (vla-Copy a))
  (vla-SetText b 0 0 "THỐNG KÊ TẦNG 2")
  (vla-SetText unrelated 1 1 "LOẠI TƯỜNG ALC")
  (alc-test--sumtable-check "whole-decimal-parser-supports-dot-comma-sign-and-zero"
    (and (equal (alc--sumtable-number " 12.345 ") 12.345 1e-9)
      (equal (alc--sumtable-number "1,250") 1.25 1e-9)
      (= (alc--sumtable-number "0") 0.0) (= (alc--sumtable-number "-1.5") -1.5)))
  (setq valid T)
  (foreach item '("12abc" "" "." "1.2.3" "1,2.3" "1 234" "-")
    (if (alc--sumtable-number item) (setq valid nil)))
  (alc-test--sumtable-check "invalid-total-text-is-not-silently-truncated" valid)
  (alc-test--sumtable-check "source-total-is-visible-rounded-final-cell"
    (equal (cdr (cadddr (alc--sumtable-source-entry (vlax-vla-object->ename a)))) 5556.0 1e-6))
  (alc-test--sumtable-check "legacy-layer-summary-VVTK-table-is-accepted"
    (equal (cdr (cadddr (alc--sumtable-source-entry (vlax-vla-object->ename c)))) 11000.0 1e-6))
  (alc-test--sumtable-check "custom-source-title-and-handle-label-are-preserved"
    (vl-string-search "THỐNG KÊ TẦNG 2 ["
      (car (cadddr (alc--sumtable-source-entry (vlax-vla-object->ename b))))))
  (alc-test--sumtable-check "zero-source-total-is-valid"
    (= (cdr (cadddr (alc--sumtable-source-entry (vlax-vla-object->ename zero)))) 0.0))
  (setq selection (ssadd) before (mapcar 'alc-test--sumtable-cells (list a b c d)))
  (foreach item (list d a c b) (ssadd (vlax-vla-object->ename item) selection))
  (setq rows (alc--sumtable-rows selection))
  (alc-test--sumtable-check "one-output-row-per-selected-source-table" (= (length rows) 4))
  (alc-test--sumtable-check "equal-source-totals-remain-separate-rows"
    (= (length (vl-remove-if-not '(lambda (item) (equal (cdr item) 2500.0 1e-6)) rows)) 2))
  (alc-test--sumtable-check "rows-use-VVTK-spatial-order-independent-of-pick-order"
    (equal (mapcar 'cdr rows) '(2500.0 11000.0 5556.0 2500.0) 1e-6))
  (alc-test--sumtable-check "sum-matches-visible-totals-without-rounding-or-unit-drift"
    (equal (alc--total-layer-length rows) 21556.0 1e-6))
  (ssadd (vlax-vla-object->ename unrelated) selection)
  (alc-test--sumtable-check "unrelated-table-is-skipped" (= (length (alc--sumtable-rows selection)) 4))
  (setq summary (alc--add-length-table-rows rows '(0.0 -20000.0 0.0) 100.0 'sumtables))
  (alc-test--sumtable-check "output-keeps-four-columns-and-source-table-header"
    (and (= (vla-get-Columns summary) 4) (= (vla-GetText summary 1 1) "TÊN BẢNG")
      (= (vla-GetText summary 1 3) "CHIỀU DÀI (m)")))
  (alc-test--sumtable-check "output-has-four-source-rows-plus-header-title-total"
    (= (vla-get-Rows summary) 7))
  (setq row 2 valid T)
  (foreach item rows
    (if (not (and (= (vla-GetText summary row 1) (car item))
      (= (vla-GetText summary row 3) (rtos (/ (cdr item) 1000.0) 2 3)))) (setq valid nil))
    (setq row (1+ row)))
  (alc-test--sumtable-check "each-output-row-displays-its-own-source-total" valid)
  (setq row 2 valid T)
  (repeat 4
    (if (not (and (= (vla-GetText summary row 0) (itoa (1- row)))
      (= (vla-GetText summary row 2) "m"))) (setq valid nil))
    (setq row (1+ row)))
  (alc-test--sumtable-check "row-numbers-and-metre-units-match-VVTK" valid)
  (alc-test--sumtable-check "output-uses-VVTK-column-widths-text-height-and-readable-rows"
    (and (equal (vla-GetColumnWidth summary 0) (vla-GetColumnWidth a 0) 1e-6)
      (equal (vla-GetColumnWidth summary 2) (vla-GetColumnWidth a 2) 1e-6)
      (equal (vla-GetColumnWidth summary 3) (vla-GetColumnWidth a 3) 1e-6)
      (equal (vla-GetTextHeight summary 4) (vla-GetTextHeight a 4) 1e-6)
      (>= (vla-GetRowHeight summary 2) (vla-GetRowHeight a 2))
      (< (vla-GetRowHeight summary 2) (* 2.0 (vla-GetRowHeight a 2)))))
  (alc-test--write-lines "sumtable-dimensions.log"
    (list (strcat "VVTK: " (vl-princ-to-string (list (vla-GetColumnWidth a 0)
      (vla-GetColumnWidth a 2) (vla-GetColumnWidth a 3) (vla-GetRowHeight a 2))))
      (strcat "VVSUMTABLE: " (vl-princ-to-string (list (vla-GetColumnWidth summary 0)
        (vla-GetColumnWidth summary 2) (vla-GetColumnWidth summary 3) (vla-GetRowHeight summary 2))))))
  (alc-test--sumtable-check "final-total-does-not-double-count-source-detail-rows"
    (and (= (vla-GetText summary 6 1) "TỔNG CỘNG")
      (= (vla-GetText summary 6 3) (rtos 21.556 2 3))))
  (alc-test--sumtable-check "summary-table-is-not-accepted-as-a-VVTK-source"
    (not (alc--sumtable-source-entry (vlax-vla-object->ename summary))))
  (alc-test--sumtable-check "reading-totals-leaves-source-table-cells-unchanged"
    (equal before (mapcar 'alc-test--sumtable-cells (list a b c d))))
  (setq last-row (1- (vla-get-Rows a)) original-total (vla-GetText a last-row 3))
  (vla-SetText a last-row 3 "99.125")
  (alc-test--sumtable-check "edited-visible-total-is-used-instead-of-recomputing-detail"
    (equal (cdr (cadddr (alc--sumtable-source-entry (vlax-vla-object->ename a)))) 99125.0 1e-6))
  (vla-SetText a last-row 3 "12abc")
  (alc-test--sumtable-check "malformed-source-total-is-rejected"
    (not (alc--sumtable-source-entry (vlax-vla-object->ename a))))
  (vla-SetText a last-row 3 original-total) (vla-SetText a last-row 2 "mm")
  (alc-test--sumtable-check "wrong-source-unit-is-rejected"
    (not (alc--sumtable-source-entry (vlax-vla-object->ename a))))
  (vla-SetText a last-row 2 "m")
  (alc-test--sumtable-check "invalid-only-selection-has-no-summary-rows"
    (not (alc--sumtable-rows (ssadd (vlax-vla-object->ename unrelated)))))
  (alc-test--sumtable-check "empty-selection-has-no-summary-rows" (not (alc--sumtable-rows nil)))
  (setq rows (alc--sumtable-rows (ssadd (vlax-vla-object->ename zero)))
        result (alc--add-length-table-rows rows '(0.0 -30000.0 0.0) 100.0 'sumtables))
  (alc-test--sumtable-check "zero-total-source-produces-one-row-and-zero-grand-total"
    (and (= (vla-get-Rows result) 4) (= (vla-GetText result 3 3) (rtos 0.0 2 3))))
  (princ))

(defun alc-test-sumtable-prepare ()
  (alc-test--clear)
  (setvar "CLAYER" "0") (setvar "OSMODE" 0)
  (setq *alc-sumtable-test-a* (alc--add-length-detail-table '(("A" . 12340.0)) '(0.0 0.0 0.0) 100.0)
        *alc-sumtable-test-b* (alc--add-length-detail-table '(("B" . 56780.0)) '(10000.0 0.0 0.0) 100.0)
        *alc-sumtable-test-before* (mapcar 'alc-test--sumtable-cells (list *alc-sumtable-test-a* *alc-sumtable-test-b*)))
  (princ))

(defun alc-test-sumtable-public-check (/ selection index table found)
  (setq selection (ssget "_X" '((0 . "ACAD_TABLE"))) index 0)
  (repeat (sslength selection)
    (setq table (vlax-ename->vla-object (ssname selection index)) index (1+ index))
    (if (and (= (vla-GetText table 1 1) "TÊN BẢNG") (= (vla-get-Rows table) 5)
             (= (vla-GetText table 4 3) (rtos 69.12 2 3))) (setq found T)))
  (alc-test--sumtable-check "native-VVSUMTABLE-creates-two-source-rows-and-correct-grand-total"
    (and (= (sslength selection) 3) found
      (equal *alc-sumtable-test-before* (mapcar 'alc-test--sumtable-cells (list *alc-sumtable-test-a* *alc-sumtable-test-b*))))))

(defun alc-test-sumtable-undo-check ()
  (alc-test--sumtable-check "one-Undo-or-cancel-leaves-both-source-tables-unchanged"
    (and (= (alc-test--entity-count "ACAD_TABLE") 2)
      (equal *alc-sumtable-test-before* (mapcar 'alc-test--sumtable-cells (list *alc-sumtable-test-a* *alc-sumtable-test-b*))))))
(princ)
