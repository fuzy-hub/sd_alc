;;; ALCWALL v2.2.0 - schedule module

;;; --------------------------------------------------------------------------
;;; Length schedule

(defun alc--ask-stat-text-height (/ value)
  (initget 6)
  (setq value
    (getdist
      (strcat
        "\nChieu cao chu <"
        (rtos *alc-stat-text-height* 2 0)
        ">: ")))
  (if value
    (progn
      (setq *alc-stat-text-height* value)
      (alc--save-settings)
    )
  )
  *alc-stat-text-height*
)

(defun alc--curve-length-value (entity)
  (vlax-curve-getDistAtParam
    entity
    (vlax-curve-getEndParam entity))
)

(defun alc--curve-length (entity / result)
  (setq result
    (vl-catch-all-apply 'alc--curve-length-value (list entity)))
  (if (and (not (vl-catch-all-error-p result))
           (numberp result)
           (> result 1e-9))
    result
  )
)

(defun alc--add-layer-length (totals layer length-value / item)
  (if (setq item (assoc layer totals))
    (subst
      (cons layer (+ (cdr item) length-value))
      item
      totals)
    (cons (cons layer length-value) totals)
  )
)

(defun alc--collect-layer-lengths
  (selection / index entity layer length-value totals)
  (setq index 0)
  (while (< index (sslength selection))
    (setq entity (ssname selection index)
          layer (cdr (assoc 8 (entget entity)))
          length-value (alc--curve-length entity))
    (if (and layer length-value)
      (setq totals
        (alc--add-layer-length totals layer length-value))
    )
    (setq index (1+ index))
  )
  totals
)

(defun alc--sort-layer-lengths (totals / names)
  (setq names (acad_strlsort (mapcar 'car totals)))
  (mapcar '(lambda (name) (assoc name totals)) names)
)

(defun alc--maximum-layer-name-length (totals / item result)
  (setq result (strlen "TEN LAYER"))
  (foreach item totals
    (if (> (strlen (car item)) result)
      (setq result (strlen (car item)))
    )
  )
  result
)

(defun alc--total-layer-length (totals / item result)
  (setq result 0.0)
  (foreach item totals
    (setq result (+ result (cdr item)))
  )
  result
)

(defun alc--current-space (/ document)
  (setq document (alc--get-active-document))
  (if (= (getvar "CVPORT") 1)
    (vla-get-PaperSpace document)
    (vla-get-ModelSpace document)
  )
)

(defun alc--set-table-text (table row column value)
  (vla-SetText table row column value)
)

(defun alc--add-length-table
  (totals insertion text-height
    / space table table-ename row-count row table-row item total-length
      layer-width data-row-height)
  (setq totals (alc--sort-layer-lengths totals)
        row-count (+ (length totals) 3)
        data-row-height (* text-height 1.8)
        layer-width
          (max
            (* text-height 16.0)
            (* text-height
               (+ 2.0 (* 0.8 (alc--maximum-layer-name-length totals)))))
        space (alc--current-space)
        table
          (vla-AddTable
            space
            (vlax-3d-point insertion)
            row-count
            4
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
  (vla-SetColumnWidth table 1 layer-width)
  (vla-SetColumnWidth table 2 (* text-height 6.0))
  (vla-SetColumnWidth table 3 (* text-height 25.0))

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

  (vla-MergeCells table 0 0 0 3)
  (alc--set-table-text table 0 0
    "BẢNG THỐNG KÊ CHIỀU DÀI TƯỜNG")
  (alc--set-table-text table 1 0 "STT")
  (alc--set-table-text table 1 1 "TÊN LAYER")
  (alc--set-table-text table 1 2 "ĐƠN VỊ")
  (alc--set-table-text table 1 3
    "CHIỀU DÀI TỔNG THEO LAYER")

  (setq row 1
        table-row 2
        total-length 0.0)
  (foreach item totals
    (alc--set-table-text table table-row 0 (itoa row))
    (alc--set-table-text table table-row 1 (car item))
    (alc--set-table-text table table-row 2 "m")
    (alc--set-table-text
      table table-row 3 (rtos (/ (cdr item) 1000.0) 2 3))
    (setq total-length (+ total-length (cdr item))
          row (1+ row)
          table-row (1+ table-row))
  )

  (alc--set-table-text table table-row 0 "")
  (alc--set-table-text table table-row 1 "TỔNG CỘNG")
  (alc--set-table-text table table-row 2 "m")
  (alc--set-table-text
    table table-row 3 (rtos (/ total-length 1000.0) 2 3))

  (vla-put-RegenerateTableSuppressed table :vlax-false)
  (vla-Update table)
  (alc--untrack-temp table-ename)
  table
)

(defun alc--stat-loop
  (/ text-height selection totals insertion result total-length)
  (setq text-height (alc--ask-stat-text-height))
  (prompt "\nChon LINE/POLYLINE can thong ke theo layer: ")
  (setq selection
    (ssget '((0 . "LINE,LWPOLYLINE,POLYLINE"))))
  (if selection
    (progn
      (setq totals (alc--collect-layer-lengths selection))
      (if totals
        (if (setq insertion (getpoint "\nChon diem chen bang: "))
          (progn
            (setq result
              (vl-catch-all-apply
                'alc--add-length-table
                (list totals (trans insertion 1 0) text-height)))
            (if (vl-catch-all-error-p result)
              (prompt
                (strcat
                  "\nKhong the tao bang thong ke: "
                  (vl-catch-all-error-message result)))
              (progn
                (setq total-length (alc--total-layer-length totals))
                (prompt
                  (strcat
                    "\nDa tao bang cho "
                    (itoa (length totals))
                    " layer. Tong chieu dai="
                    (rtos (/ total-length 1000.0) 2 3)
                    " m."))
              )
            )
          )
        )
        (prompt "\nKhong tim thay LINE/POLYLINE co chieu dai hop le.")
      )
    )
  )
)

;;; --------------------------------------------------------------------------
;;; Door-block schedule

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

(defun alc--trim-trailing-hyphens (value)
  (while (and (> (strlen value) 0)
              (equal (substr value (strlen value) 1) "-"))
    (setq value (substr value 1 (1- (strlen value))))
  )
  value
)

(defun alc--ask-count-prefix (/ value normalized)
  (setq value
    (getstring T
      (strcat "\nMa dem/tien to <" *alc-count-prefix* ">: "))
        normalized
          (alc--trim-trailing-hyphens
            (vl-string-trim " \t\r\n" value)))
  (if (/= normalized "")
    (progn
      (setq *alc-count-prefix* normalized)
      (alc--save-settings)
    )
  )
  *alc-count-prefix*
)

(defun alc--two-digit-number (value / result)
  (setq result (itoa value))
  (if (< value 10)
    (setq result (strcat "0" result))
  )
  result
)

(defun alc--count-label (prefix index)
  (strcat prefix "-" (alc--two-digit-number index))
)

(defun alc--count-label-size
  (label text-height / bounds lower upper width-value height-value)
  (setq bounds
    (textbox
      (list
        '(0 . "TEXT")
        (cons 1 label)
        (cons 7 (getvar "TEXTSTYLE"))
        (cons 40 text-height)
        '(41 . 1.0))))
  (if (and bounds (car bounds) (cadr bounds))
    (progn
      (setq lower (car bounds)
            upper (cadr bounds)
            width-value (abs (- (car upper) (car lower)))
            height-value (abs (- (cadr upper) (cadr lower))))
    )
  )
  (if (not (and (numberp width-value) (> width-value 1e-9)))
    (setq width-value
      (* text-height (max 2.0 (* 0.7 (strlen label)))))
  )
  (if (not (and (numberp height-value) (> height-value 1e-9)))
    (setq height-value text-height)
  )
  (list width-value height-value)
)

(defun alc--create-centered-text
  (point label text-height
    / normal x-axis-wcs x-axis-ocs rotation wcs-point ocs-point entity)
  (setq normal (trans '(0.0 0.0 1.0) 1 0 T)
        x-axis-wcs (trans '(1.0 0.0 0.0) 1 0 T)
        x-axis-ocs (trans x-axis-wcs 0 normal T)
        rotation (angle '(0.0 0.0 0.0) x-axis-ocs)
        wcs-point (trans point 1 0)
        ocs-point (trans wcs-point 0 normal)
        entity
          (entmakex
            (list
              '(0 . "TEXT")
              '(100 . "AcDbEntity")
              (cons 8 (getvar "CLAYER"))
              '(100 . "AcDbText")
              (cons 10 ocs-point)
              (cons 40 text-height)
              (cons 1 label)
              (cons 50 rotation)
              '(41 . 1.0)
              '(51 . 0.0)
              (cons 7 (getvar "TEXTSTYLE"))
              '(71 . 0)
              '(72 . 1)
              (cons 11 ocs-point)
              (cons 210 normal)
              '(73 . 2))))
  (if entity (entupd entity))
  entity
)

(defun alc--count-frame-points
  (point width-value height-value text-height
    / x y z half-width half-height)
  (setq x (car point)
        y (cadr point)
        z (if (numberp (caddr point)) (caddr point) 0.0)
        half-width (+ (/ width-value 2.0) (* text-height 0.4))
        half-height (+ (/ height-value 2.0) (* text-height 0.3)))
  (list
    (list (- x half-width) (- y half-height) z)
    (list (+ x half-width) (- y half-height) z)
    (list (+ x half-width) (+ y half-height) z)
    (list (- x half-width) (+ y half-height) z))
)

(defun alc--create-count-frame
  (point label text-height / size points normal wcs-points)
  (setq size (alc--count-label-size label text-height)
        points
          (alc--count-frame-points
            point (car size) (cadr size) text-height)
        normal (trans '(0.0 0.0 1.0) 1 0 T)
        wcs-points (mapcar '(lambda (p) (trans p 1 0)) points))
  (alc--create-lwpolyline-wcs-on-layer
    wcs-points T normal (getvar "CLAYER"))
)

(defun alc--place-count-label
  (point label text-height / text-entity frame-entity)
  (setq text-entity
    (alc--track-temp
      (alc--create-centered-text point label text-height)))
  (if text-entity
    (setq frame-entity
      (alc--track-temp
        (alc--create-count-frame point label text-height)))
  )
  (if (and text-entity frame-entity)
    (progn
      (alc--untrack-temp text-entity)
      (alc--untrack-temp frame-entity)
      T
    )
    (progn
      (alc--cleanup-temp)
      nil
    )
  )
)

(defun alc--count-loop (/ prefix text-height index label point done)
  (setq prefix (alc--ask-count-prefix)
        text-height (alc--ask-stat-text-height)
        index 1)
  (while (not done)
    (setq label (alc--count-label prefix index)
          point
            (getpoint
              (strcat "\nChon diem dat " label " <Enter de ket thuc>: ")))
    (if point
      (if (alc--place-count-label point label text-height)
        (setq index (1+ index))
        (progn
          (prompt "\nKhong the tao text va khung dem.")
          (setq done T)
        )
      )
      (setq done T)
    )
  )
  (if (> index 1)
    (prompt
      (strcat
        "\nDa tao "
        (itoa (1- index))
        " ma, tu "
        (alc--count-label prefix 1)
        " den "
        (alc--count-label prefix (1- index))
        "."))
  )
)
