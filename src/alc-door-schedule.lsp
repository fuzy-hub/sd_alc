(setq *alc-module-version* "3.3.5")
(defun alc--raw-variant-value (value)
  (while (eq (type value) 'VARIANT)
    (setq value (vlax-variant-value value))
  )
  value
)

(defun alc--schedule-value-string (value)
  (setq value (alc--raw-variant-value value))
  (cond
    ((eq (type value) 'STR)
      (vl-string-trim " \t\r\n" value)
    )
    ((eq (type value) 'INT)
      (itoa value)
    )
    ((eq (type value) 'REAL)
      (if (equal value (fix value) 1e-9)
        (itoa (fix value))
        (rtos value 2 3)
      )
    )
    ((null value) "")
    (T (vl-princ-to-string value))
  )
)

(defun alc--door-field-name (name / normalized)
  (if (eq (type name) 'STR)
    (progn
      (setq normalized
        (strcase (vl-string-trim " \t\r\n" name)))
      (if (member normalized '("KTHUOC" "TENCUA" "COTE1" "COTE2"))
        normalized
      )
    )
  )
)

(defun alc--named-value-put (values name value / item)
  (if (setq item (assoc name values))
    (subst (cons name value) item values)
    (cons (cons name value) values)
  )
)

(defun alc--block-attribute-values
  (entity / data next-entity next-data field-name result)
  (setq data (entget entity))
  (if (and (assoc 66 data)
           (= 1 (cdr (assoc 66 data))))
    (progn
      (setq next-entity (entnext entity))
      (while (and next-entity
                  (setq next-data (entget next-entity))
                  (not (equal (cdr (assoc 0 next-data)) "SEQEND")))
        (if (and (equal (cdr (assoc 0 next-data)) "ATTRIB")
                 (setq field-name
                   (alc--door-field-name (cdr (assoc 2 next-data)))))
          (setq result
            (alc--named-value-put
              result
              field-name
              (alc--schedule-value-string (cdr (assoc 1 next-data)))))
        )
        (setq next-entity (entnext next-entity))
      )
    )
  )
  result
)

(defun alc--object-list (value / raw result)
  (setq raw (alc--raw-variant-value value))
  (cond
    ((null raw) nil)
    ((eq (type raw) 'SAFEARRAY)
      (setq result
        (vl-catch-all-apply 'vlax-safearray->list (list raw)))
      (if (not (vl-catch-all-error-p result)) result)
    )
    ((listp raw) raw)
    ((eq (type raw) 'VLA-OBJECT) (list raw))
  )
)

(defun alc--block-object (entity / result)
  (setq result
    (vl-catch-all-apply 'vlax-ename->vla-object (list entity)))
  (if (not (vl-catch-all-error-p result)) result)
)

(defun alc--dynamic-property-values
  (block-object / properties property name-result value-result field-name result)
  (if block-object
    (progn
      (setq properties
        (vl-catch-all-apply
          'vlax-invoke
          (list block-object 'GetDynamicBlockProperties)))
      (if (not (vl-catch-all-error-p properties))
        (foreach property (alc--object-list properties)
          (setq name-result
            (vl-catch-all-apply 'vla-get-PropertyName (list property)))
          (if (and (not (vl-catch-all-error-p name-result))
                   (setq field-name
                     (alc--door-field-name name-result)))
            (progn
              (setq value-result
                (vl-catch-all-apply
                  'vlax-get-property
                  (list property 'Value)))
              (if (not (vl-catch-all-error-p value-result))
                (setq result
                  (alc--named-value-put
                    result
                    field-name
                    (alc--schedule-value-string value-result)))
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun alc--attribute-object-values
  (block-object method-name / attributes attribute tag-result text-result field-name result)
  (if block-object
    (progn
      (setq attributes
        (vl-catch-all-apply
          'vlax-invoke
          (list block-object method-name)))
      (if (not (vl-catch-all-error-p attributes))
        (foreach attribute (alc--object-list attributes)
          (setq tag-result
            (vl-catch-all-apply 'vla-get-TagString (list attribute)))
          (if (and (not (vl-catch-all-error-p tag-result))
                   (setq field-name
                     (alc--door-field-name tag-result)))
            (progn
              (setq text-result
                (vl-catch-all-apply 'vla-get-TextString (list attribute)))
              (if (not (vl-catch-all-error-p text-result))
                (setq result
                  (alc--named-value-put
                    result
                    field-name
                    (alc--schedule-value-string text-result)))
              )
            )
          )
        )
      )
    )
  )
  result
)

(defun alc--merge-named-values (base additions / item)
  (foreach item additions
    (setq base (alc--named-value-put base (car item) (cdr item)))
  )
  base
)

(defun alc--door-block-record
  (entity / block-object values name-value size-value cote1-value cote2-value)
  (setq block-object (alc--block-object entity)
        values (alc--dynamic-property-values block-object)
        values
          (alc--merge-named-values
            values
            (alc--attribute-object-values
              block-object 'GetConstantAttributes))
        values
          (alc--merge-named-values
            values
            (alc--attribute-object-values block-object 'GetAttributes))
        values
          (alc--merge-named-values
            values
            (alc--block-attribute-values entity))
        name-value (cdr (assoc "TENCUA" values))
        size-value (cdr (assoc "KTHUOC" values))
        cote1-value (cdr (assoc "COTE1" values))
        cote2-value (cdr (assoc "COTE2" values)))
  (if (and name-value (/= name-value "")
           size-value (/= size-value "")
           cote1-value (/= cote1-value "")
           cote2-value (/= cote2-value ""))
    (list name-value size-value cote1-value cote2-value)
  )
)

(defun alc--door-record-key (record)
  (strcat
    (strcase (nth 0 record)) (chr 31)
    (strcase (nth 1 record)) (chr 31)
    (strcase (nth 2 record)) (chr 31)
    (strcase (nth 3 record)))
)

(defun alc--insert-count (entity / data columns rows)
  (setq data (entget entity)
        columns (cdr (assoc 70 data))
        rows (cdr (assoc 71 data)))
  (if (not (and (numberp columns) (> columns 0)))
    (setq columns 1)
  )
  (if (not (and (numberp rows) (> rows 0)))
    (setq rows 1)
  )
  (* columns rows)
)

(defun alc--add-door-group (groups record count-value / key item)
  (setq key (alc--door-record-key record))
  (if (setq item (assoc key groups))
    (subst
      (list key (cadr item) (+ (caddr item) count-value))
      item
      groups)
    (cons (list key record count-value) groups)
  )
)

(defun alc--collect-door-groups
  (selection / index entity record count-value groups accepted ignored)
  (setq index 0 accepted 0 ignored 0)
  (while (< index (sslength selection))
    (setq entity (ssname selection index)
          record (alc--door-block-record entity)
          count-value (alc--insert-count entity))
    (if record
      (setq groups (alc--add-door-group groups record count-value)
            accepted (+ accepted count-value))
      (setq ignored (+ ignored count-value))
    )
    (setq index (1+ index))
  )
  (list groups accepted ignored)
)

(defun alc--sort-door-groups (groups / keys)
  (setq keys (acad_strlsort (mapcar 'car groups)))
  (mapcar '(lambda (key) (assoc key groups)) keys)
)

(defun alc--door-column-width
  (groups record-index minimum-width text-height / item record maximum-length)
  (setq maximum-length 0)
  (foreach item groups
    (setq record (cadr item))
    (if (> (strlen (nth record-index record)) maximum-length)
      (setq maximum-length (strlen (nth record-index record)))
    )
  )
  (max
    (* text-height minimum-width)
    (* text-height (+ 2.0 (* 0.8 maximum-length))))
)

(defun alc--add-door-table
  (groups insertion text-height
    / space table table-ename row-count data-row-height row table-row
      item record total-count)
  (setq groups (alc--sort-door-groups groups)
        row-count (+ (length groups) 3)
        data-row-height (* text-height 1.8)
        space (alc--current-space)
        table
          (vla-AddTable
            space
            (vlax-3d-point insertion)
            row-count
            6
            data-row-height
            (* text-height 10.0)))
  (setq table-ename (alc--vla-object-ename table))
  (if table-ename
    (alc--track-temp table-ename)
  )

  (vla-put-RegenerateTableSuppressed table :vlax-true)
  (vla-put-TitleSuppressed table :vlax-false)
  (vla-put-HeaderSuppressed table :vlax-false)

  (vla-SetColumnWidth table 0 (* text-height 5.0))
  (vla-SetColumnWidth
    table 1 (alc--door-column-width groups 0 12.0 text-height))
  (vla-SetColumnWidth
    table 2 (alc--door-column-width groups 1 14.0 text-height))
  (vla-SetColumnWidth
    table 3 (alc--door-column-width groups 2 8.0 text-height))
  (vla-SetColumnWidth
    table 4 (alc--door-column-width groups 3 8.0 text-height))
  (vla-SetColumnWidth table 5 (* text-height 9.0))

  (vla-SetRowHeight table 0 (* text-height 2.2))
  (vla-SetRowHeight table 1 (* text-height 2.0))
  (setq row 2)
  (while (< row row-count)
    (vla-SetRowHeight table row data-row-height)
    (setq row (1+ row))
  )

  (vla-SetTextHeight table 1 (* text-height 1.2))
  (vla-SetTextHeight table 2 text-height)
  (vla-SetTextHeight table 4 text-height)
  (vla-SetAlignment table 1 5)
  (vla-SetAlignment table 2 5)
  (vla-SetAlignment table 4 5)

  (vla-MergeCells table 0 0 0 5)
  (alc--set-table-text table 0 0 "BẢNG THỐNG KÊ CỬA")
  (alc--set-table-text table 1 0 "STT")
  (alc--set-table-text table 1 1 "TÊN CỬA")
  (alc--set-table-text table 1 2 "KÍCH THƯỚC")
  (alc--set-table-text table 1 3 "COTE1")
  (alc--set-table-text table 1 4 "COTE2")
  (alc--set-table-text table 1 5 "SỐ LƯỢNG")

  (setq row 1 table-row 2 total-count 0)
  (foreach item groups
    (setq record (cadr item))
    (alc--set-table-text table table-row 0 (itoa row))
    (alc--set-table-text table table-row 1 (nth 0 record))
    (alc--set-table-text table table-row 2 (nth 1 record))
    (alc--set-table-text table table-row 3 (nth 2 record))
    (alc--set-table-text table table-row 4 (nth 3 record))
    (alc--set-table-text table table-row 5 (itoa (caddr item)))
    (setq total-count (+ total-count (caddr item))
          row (1+ row)
          table-row (1+ table-row))
  )

  (alc--set-table-text table table-row 0 "")
  (alc--set-table-text table table-row 1 "TỔNG CỘNG")
  (alc--set-table-text table table-row 2 "")
  (alc--set-table-text table table-row 3 "")
  (alc--set-table-text table table-row 4 "")
  (alc--set-table-text table table-row 5 (itoa total-count))

  (vla-put-RegenerateTableSuppressed table :vlax-false)
  (vla-Update table)
  (alc--untrack-temp table-ename)
  table
)

(defun alc--door-stat-loop
  (/ text-height selection collection groups accepted ignored insertion result)
  (setq text-height (alc--ask-stat-text-height))
  (prompt "\nChon cac block cua can thong ke: ")
  (setq selection (ssget '((0 . "INSERT"))))
  (if selection
    (progn
      (setq collection (alc--collect-door-groups selection)
            groups (car collection)
            accepted (cadr collection)
            ignored (caddr collection))
      (if groups
        (if (setq insertion (getpoint "\nChon diem chen bang cua: "))
          (progn
            (setq result
              (vl-catch-all-apply
                'alc--add-door-table
                (list groups (trans insertion 1 0) text-height)))
            (if (vl-catch-all-error-p result)
              (prompt
                (strcat
                  "\nKhong the tao bang thong ke cua: "
                  (vl-catch-all-error-message result)))
              (prompt
                (strcat
                  "\nDa tao bang "
                  (itoa (length groups))
                  " loai cua, tong so "
                  (itoa accepted)
                  " bo."
                  (if (> ignored 0)
                    (strcat " Bo qua " (itoa ignored) " block thieu tham so.")
                    "")))
            )
          )
        )
        (prompt
          "\nKhong tim thay block co du KTHUOC, TENCUA, COTE1 va COTE2.")
      )
    )
  )
)

;;; --------------------------------------------------------------------------
;;; Dimension total schedule

