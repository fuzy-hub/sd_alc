(setq *alc-module-version* "3.4.0")
;;; ALCWALL v3.4.0 - schedule module

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
