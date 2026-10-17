(setq *alc-module-version* "3.3.6")
(defun alc--length-dimension-type-code-p (type-value / base-type)
  (if (numberp type-value)
    (progn
      (setq base-type (logand type-value 7))
      (member base-type '(0 1 3 4))
    )
  )
)

(defun alc--length-dimension-type-p (entity / data type-value)
  (setq data (entget entity)
        type-value (cdr (assoc 70 data)))
  (alc--length-dimension-type-code-p type-value)
)

(defun alc--dimension-measurement (entity / object result data)
  (if (alc--length-dimension-type-p entity)
    (progn
      (setq object (alc--block-object entity))
      (if object
        (setq result
          (vl-catch-all-apply 'vla-get-Measurement (list object)))
      )
      (if (or (not result) (vl-catch-all-error-p result))
        (progn
          (setq data (entget entity)
                result (cdr (assoc 42 data)))
        )
      )
      (if (and (numberp result) (>= result 0.0))
        result
      )
    )
  )
)

(defun alc--collect-dimension-values
  (selection / index entity value rows ignored)
  (setq index 0 ignored 0)
  (while (< index (sslength selection))
    (setq entity (ssname selection index)
          value (alc--dimension-measurement entity))
    (if value
      (setq rows (cons (list entity value) rows))
      (setq ignored (1+ ignored))
    )
    (setq index (1+ index))
  )
  (list (reverse rows) ignored)
)

(defun alc--total-dimension-values (rows / row result)
  (setq result 0.0)
  (foreach row rows
    (setq result (+ result (cadr row)))
  )
  result
)

(defun alc--add-dimension-table
  (rows insertion text-height
    / space table table-ename row-count data-row-height row-index
      table-row dimension-row total-value)
  (setq row-count (+ (length rows) 3)
        data-row-height (* text-height 1.8)
        space (alc--current-space)
        table
          (vla-AddTable
            space
            (vlax-3d-point insertion)
            row-count
            2
            data-row-height
            (* text-height 12.0)))
  (setq table-ename (alc--vla-object-ename table))
  (if table-ename
    (alc--track-temp table-ename)
  )

  (vla-put-RegenerateTableSuppressed table :vlax-true)
  (vla-put-TitleSuppressed table :vlax-false)
  (vla-put-HeaderSuppressed table :vlax-false)

  (vla-SetColumnWidth table 0 (* text-height 5.0))
  (vla-SetColumnWidth table 1 (* text-height 18.0))

  (vla-SetRowHeight table 0 (* text-height 2.2))
  (vla-SetRowHeight table 1 (* text-height 2.0))
  (setq row-index 2)
  (while (< row-index row-count)
    (vla-SetRowHeight table row-index data-row-height)
    (setq row-index (1+ row-index))
  )

  (vla-SetTextHeight table 1 (* text-height 1.2))
  (vla-SetTextHeight table 2 text-height)
  (vla-SetTextHeight table 4 text-height)
  (vla-SetAlignment table 1 5)
  (vla-SetAlignment table 2 5)
  (vla-SetAlignment table 4 5)

  (vla-MergeCells table 0 0 0 1)
  (alc--set-table-text table 0 0 "BẢNG TỔNG HỢP DIM")
  (alc--set-table-text table 1 0 "STT")
  (alc--set-table-text table 1 1 "CHIỀU DÀI")

  (setq row-index 1 table-row 2 total-value 0.0)
  (foreach dimension-row rows
    (alc--set-table-text table table-row 0 (itoa row-index))
    (alc--set-table-text
      table table-row 1
      (alc--schedule-value-string (cadr dimension-row)))
    (setq total-value (+ total-value (cadr dimension-row))
          row-index (1+ row-index)
          table-row (1+ table-row))
  )

  (alc--set-table-text table table-row 0 "TỔNG")
  (alc--set-table-text
    table table-row 1 (alc--schedule-value-string total-value))

  (vla-put-RegenerateTableSuppressed table :vlax-false)
  (vla-Update table)
  (alc--untrack-temp table-ename)
  table
)

(defun alc--dimension-stat-loop
  (/ text-height selection collection rows ignored insertion result total-value)
  (setq text-height (alc--ask-stat-text-height))
  (prompt "\nChon cac DIM can tinh tong: ")
  (setq selection (ssget '((0 . "DIMENSION"))))
  (if selection
    (progn
      (setq collection (alc--collect-dimension-values selection)
            rows (car collection)
            ignored (cadr collection))
      (if rows
        (if (setq insertion (getpoint "\nChon diem chen bang DIM: "))
          (progn
            (setq result
              (vl-catch-all-apply
                'alc--add-dimension-table
                (list rows (trans insertion 1 0) text-height)))
            (if (vl-catch-all-error-p result)
              (prompt
                (strcat
                  "\nKhong the tao bang DIM: "
                  (vl-catch-all-error-message result)))
              (progn
                (setq total-value (alc--total-dimension-values rows))
                (prompt
                  (strcat
                    "\nDa tao bang cho "
                    (itoa (length rows))
                    " DIM. Tong="
                    (alc--schedule-value-string total-value)
                    "."
                    (if (> ignored 0)
                      (strcat " Bo qua " (itoa ignored) " DIM khong phai chieu dai.")
                      "")))
              )
            )
          )
        )
        (prompt "\nKhong co DIM chieu dai hop le trong tap chon.")
      )
    )
  )
)

;;; --------------------------------------------------------------------------
;;; Sequential framed labels

