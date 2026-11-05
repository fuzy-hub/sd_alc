(setq *alc-module-version* "3.4.6")
;;; ALCWALL v3.4.6 - schedule module

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

(defun alc--revcloud-p (entity / data value)
  (setq data (entget entity '("RevcloudProps")))
  (or (= (cdr (assoc 0 data)) "REVCLOUD")
      (and (member (cdr (assoc 0 data)) '("LWPOLYLINE" "POLYLINE"))
        (or (assoc -3 data)
            ;; AutoCAD's revcloud facet can identify clouds without relying on layer.
            (progn
              (setq value (vl-catch-all-apply 'getpropertyvalue
                (list entity "RevcloudArcLength")))
              (and (not (vl-catch-all-error-p value)) (numberp value) (> value 0.0)))))))

(defun alc--stat-curve-length (entity / data flags)
  (setq data (entget entity) flags (cdr (assoc 70 data)))
  (if (and
        (not (and (member (cdr (assoc 0 data)) '("LWPOLYLINE" "POLYLINE"))
                  flags (= (logand flags 1) 1)))
        (not (alc--revcloud-p entity)))
    (alc--curve-length entity)))

(defun alc--collect-layer-lengths
  (selection / index entity layer length-value totals)
  (setq index 0)
  (while (< index (sslength selection))
    (setq entity (ssname selection index)
          layer (cdr (assoc 8 (entget entity)))
          length-value (alc--stat-curve-length entity))
    (if (and layer length-value)
      (setq totals
        (alc--add-layer-length totals layer length-value))
    )
    (setq index (1+ index))
  )
  totals
)

(defun alc--stat-position-before-p (a b / ha hb)
  ;; Left-to-right inside a horizontal band; height and handle break X ties.
  (cond
    ((/= (car a) (car b)) (< (car a) (car b)))
    ((/= (cadr a) (cadr b)) (> (cadr a) (cadr b)))
    (T
      ;; Permanent handles make exact spatial ties independent of pick order.
      (setq ha (caddr a) hb (caddr b))
      (if (/= (strlen ha) (strlen hb)) (< (strlen ha) (strlen hb))
        (and (/= ha hb) (= ha (car (acad_strlsort (list ha hb)))))))))

(defun alc--stat-grid-size ()
  ;; Drawing-session preference; APPLOAD preserves a valid user setting.
  (if (not (and (boundp '*alc-stat-grid-size*)
                (numberp *alc-stat-grid-size*)
                (<= 1 *alc-stat-grid-size* 1000)
                (= *alc-stat-grid-size* (fix *alc-stat-grid-size*))))
    (setq *alc-stat-grid-size* 20))
  (fix *alc-stat-grid-size*))

(defun alc--stat-grid-index (offset span size)
  ;; Clamp the bottom boundary into the final band; zero height uses one band.
  (if (> span 0.0)
    (max 0 (min (1- size) (fix (* size (/ offset span)))))
    0))

(defun alc--stat-grid-before-p (a b)
  (if (/= (car a) (car b)) (< (car a) (car b))
    (alc--stat-position-before-p (cadr a) (cadr b))))

(defun alc--stat-sort-entries (entries / size ymin ymax bounds item keyed)
  ;; Only divide Y: equal-height bands across the full selection width.
  ;; Visit bands top-to-bottom, objects left-to-right (Z); no column divisions.
  (setq size (alc--stat-grid-size))
  (foreach item entries
    (setq bounds (nth 4 item))
    ;; Four-field entries remain usable as point anchors by internal callers.
    (if (not bounds)
      (setq bounds (list (list (car item) (cadr item))
                         (list (car item) (cadr item)))))
    (setq ymin (if ymin (min ymin (cadar bounds)) (cadar bounds))
          ymax (if ymax (max ymax (cadadr bounds)) (cadadr bounds))))
  (foreach item entries
    (setq keyed (cons (list
      (alc--stat-grid-index (- ymax (cadr item)) (- ymax ymin) size)
      item) keyed)))
  (mapcar 'cadr (vl-sort keyed 'alc--stat-grid-before-p)))

(defun alc--stat-view-bounds (bounds / point low high)
  ;; Project all corners: WCS axes may appear vertical/horizontal after a twist.
  ;; Never rotate/move the actual source entity just to determine reading order.
  (foreach point (alc--bounds-corners (car bounds) (cadr bounds))
    (setq point (trans point 0 2)
          low (if low (mapcar 'min low point) point)
          high (if high (mapcar 'max high point) point)))
  (list low high))

(defun alc--stat-length-entry (entity layer length-value / bounds)
  (setq bounds (alc--object-bounds entity))
  (if bounds
    (progn
    (setq bounds (alc--stat-view-bounds bounds))
    (list (caar bounds) (cadadr bounds) (cdr (assoc 5 (entget entity)))
      (cons layer length-value) bounds))
    ;; A start point is not an extent: never silently substitute it for Xmin/Ymax.
    (vl-exit-with-error
      (strcat "Khong doc duoc Xmin/Ymax cua doi tuong " (cdr (assoc 5 (entget entity)))
        "; dung thong ke de tranh sap xep sai."))))

(defun alc--collect-length-entries (selection / index entity layer length-value rows)
  ;; Screen-oriented bounds are independent of vertex direction and pick order.
  (setq index 0)
  (if selection
    (repeat (sslength selection)
      (setq entity (ssname selection index) index (1+ index)
            layer (cdr (assoc 8 (entget entity)))
            length-value (alc--stat-curve-length entity))
      (if (and layer length-value)
        (setq rows (cons (alc--stat-length-entry entity layer length-value) rows)))))
  (alc--stat-sort-entries rows))

(defun alc--collect-length-rows (selection)
  (mapcar 'cadddr (alc--collect-length-entries selection)))

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

;;; A TABLE fill has no drawing-background option. Use a real WIPEOUT,
;;; grouped with the editable table, rather than a fixed black/white fill.
(defun alc--mask-length-table (table / data origin width height mask object dict order group)
  (setq data (entget (vlax-vla-object->ename table))
        origin (vlax-safearray->list (vlax-variant-value (vla-get-InsertionPoint table)))
        width (vla-get-Width table)
        height (vla-get-Height table))
  ;; AddTable creates a WCS XY table. Use its final regenerated dimensions.
  (command-s "_.WIPEOUT"
    "_non" (trans origin 0 1)
    "_non" (trans (list (+ (car origin) width) (cadr origin) (caddr origin)) 0 1)
    "_non" (trans (list (+ (car origin) width) (- (cadr origin) height) (caddr origin)) 0 1)
    "_non" (trans (list (car origin) (- (cadr origin) height) (caddr origin)) 0 1)
    "_Close")
  (setq mask (entlast) object (vlax-ename->vla-object mask))
  (alc--track-temp mask)
  (vla-put-Layer object (vla-get-Layer table))
  ;; The mask must cover existing geometry; the table must cover the mask.
  (setq dict (vla-GetExtensionDictionary
               (vlax-ename->vla-object (cdr (assoc 330 data))))
        order (vl-catch-all-apply 'vla-Item (list dict "ACAD_SORTENTS")))
  (if (vl-catch-all-error-p order)
    (setq order (vla-AddObject dict "ACAD_SORTENTS" "AcDbSortentsTable")))
  (vlax-invoke order 'MoveToTop (list object))
  (vlax-invoke order 'MoveToTop (list table))
  (setq group (vla-Add (vla-get-Groups (alc--get-active-document))
                (strcat "ALC_VVTK_" (vla-get-Handle table))))
  (vlax-invoke group 'AppendItems (list table object))
  (alc--untrack-temp mask)
  mask)

(defun alc--add-length-table-rows
  (totals insertion text-height detail
    / space table table-ename row-count row table-row item total-length
      layer-width data-row-height source-handles)
  (if (and (listp detail) (eq (car detail) 'linked))
    (setq source-handles (cadr detail)))
  (setq row-count (+ (length totals) 3)
        data-row-height (* text-height 1.8)
        layer-width
          (max
            (* text-height 16.0)
            (* text-height
               (if (eq detail 'sumtables)
                 (+ 4.0 (* 1.2 (alc--maximum-layer-name-length totals)))
                 (+ 2.0 (* 0.8 (alc--maximum-layer-name-length totals))))))
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
  (vla-SetColumnWidth table 3 (* text-height (if detail 15.0 25.0)))

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
    (cond
      ((eq detail 'sumtables) "BẢNG TỔNG HỢP CHIỀU DÀI CÁC BẢNG VVTK")
      (detail "BẢNG THỐNG KÊ CHIỀU DÀI TỪNG ĐỐI TƯỢNG")
      (T "BẢNG THỐNG KÊ CHIỀU DÀI TƯỜNG")))
  (alc--set-table-text table 1 0 "STT")
  (alc--set-table-text table 1 1 (if (eq detail 'sumtables) "TÊN BẢNG" "TÊN LAYER"))
  (alc--set-table-text table 1 2 "ĐƠN VỊ")
  (alc--set-table-text table 1 3
    (if detail "CHIỀU DÀI (m)" "CHIỀU DÀI TỔNG THEO LAYER"))

  (setq row 1
        table-row 2
        total-length 0.0)
  (foreach item totals
    (alc--set-table-text table table-row 0 (itoa row))
    (alc--set-table-text table table-row 1 (car item))
    (alc--set-table-text table table-row 2 "m")
    (alc--set-table-text
      table table-row 3 (rtos (/ (cdr item) 1000.0) 2 3))
    (if source-handles
      (vla-SetCustomData table table-row 0 "ALC_VVTK_ROW"
        (vlax-make-variant
          (vl-prin1-to-string (list "VVTK1" (getvar "FINGERPRINTGUID")
            (nth (1- row) source-handles)
            (vla-GetText table table-row 0) (vla-GetText table table-row 1)
            (vla-GetText table table-row 3))) vlax-vbString)))
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
  (alc--mask-length-table table)
  (alc--untrack-temp table-ename)
  table
)

(defun alc--add-length-table (totals insertion text-height)
  (alc--add-length-table-rows (alc--sort-layer-lengths totals) insertion text-height nil))

(defun alc--add-length-detail-table (rows insertion text-height)
  (alc--add-length-table-rows rows insertion text-height T))

(defun alc--add-length-source-table (entries insertion text-height)
  (alc--add-length-table-rows (mapcar 'cadddr entries) insertion text-height
    (list 'linked (mapcar 'caddr entries))))

(defun alc--stat-label-layer (/ name data)
  (setq name "ALC_VVTK_STT")
  (if (not (tblsearch "LAYER" name))
    (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
      '(100 . "AcDbLayerTableRecord") (cons 2 name) '(70 . 0)
      '(62 . 1) '(6 . "Continuous"))))
  (setq data (tblsearch "LAYER" name))
  (if (and data (= 0 (logand (cdr (assoc 70 data)) 5))
           (> (cdr (assoc 62 data)) 0)) name
    (vl-exit-with-error "Hay bat, thaw va mo khoa layer ALC_VVTK_STT truoc khi ghi so.")))

(defun alc--stat-add-label (entry index text-height layer / entity point normal axis text)
  (setq entity (handent (caddr entry))
        point (vlax-curve-getPointAtDist entity (/ (cdr (cadddr entry)) 2.0))
        ;; Offset above the halfway point in the current UCS, not along the chord.
        point (trans (mapcar '+ (trans point 0 1) (list 0.0 (* text-height 0.8) 0.0)) 1 0)
        normal (trans '(0.0 0.0 1.0) 1 0 T)
        axis (trans '(1.0 0.0 0.0) 1 normal T)
        text (vla-AddText (alc--current-space) (itoa index)
               (vlax-3d-point point) text-height))
  (alc--track-temp (vlax-vla-object->ename text))
  (vla-put-Layer text layer)
  (vla-put-Color text 256)
  (vla-put-StyleName text "alc text note")
  (vla-put-Normal text (vlax-3d-point normal))
  (vla-put-Rotation text (atan (cadr axis) (car axis)))
  (vla-put-Alignment text 10)
  (vla-put-TextAlignmentPoint text (vlax-3d-point point))
  (regapp "ALC_VVTK_LABEL")
  (entmod (append (entget (vlax-vla-object->ename text))
    (list (list -3 (list "ALC_VVTK_LABEL" '(1000 . "1")
      (cons 1005 (caddr entry)))))))
  (vlax-vla-object->ename text))

(defun alc--stat-legacy-label-p (entity entries / data value codes valid point normal angle-value up middle match entry)
  ;; Earlier labels have no source tag. Match their known placement, not a row
  ;; number or an arbitrary text elsewhere in the drawing.
  (setq data (entget entity) value (cdr (assoc 1 data))
        codes (vl-string->list value) valid (/= value ""))
  (foreach code codes (if (or (< code 48) (> code 57)) (setq valid nil)))
  (if valid
    (progn
      (setq point (trans (cdr (assoc 11 data)) entity 0)
            normal (cdr (assoc 210 data)) angle-value (cdr (assoc 50 data))
            up (trans (list (- (sin angle-value)) (cos angle-value) 0.0) normal 0 T)
            point (mapcar '- point
              (mapcar '(lambda (value) (* value 0.8 (cdr (assoc 40 data)))) up)))
      (foreach entry entries
        (setq middle (vlax-curve-getPointAtDist (handent (caddr entry)) (/ (cdr (cadddr entry)) 2.0)))
        (if (equal point middle 1e-5) (setq match T)))))
  match)

(defun alc--stat-old-labels (entries / selection handles index entity data source result)
  (setq handles (mapcar 'caddr entries) index 0
        selection (ssget "_X" (list '(0 . "TEXT") '(8 . "ALC_VVTK_STT")
          (cons 410 (if (= (getvar "CVPORT") 1) (getvar "CTAB") "Model")))))
  (if selection
    (repeat (sslength selection)
      (setq entity (ssname selection index) index (1+ index)
            data (cdr (assoc "ALC_VVTK_LABEL"
              (cdr (assoc -3 (entget entity '("ALC_VVTK_LABEL"))))))
            source (cdr (assoc 1005 data)))
      (if (if data (member source handles) (alc--stat-legacy-label-p entity entries))
        (setq result (cons entity result)))))
  result)

(defun alc--stat-create-output (entries insertion text-height number-sources
    / table labels layer index result entity entry old-labels erased mask group)
  ;; Keep the table and all labels temporary until the entire batch succeeds.
  (setq result (vl-catch-all-apply
    '(lambda ()
      (if number-sources
        (setq layer (alc--stat-label-layer) old-labels (alc--stat-old-labels entries)))
      (setq table (alc--add-length-source-table entries insertion text-height))
      (alc--track-temp (vlax-vla-object->ename table))
      (setq group (vla-Item (vla-get-Groups (alc--get-active-document))
                    (strcat "ALC_VVTK_" (vla-get-Handle table)))
            mask (vlax-vla-object->ename (vla-Item group 1)))
      (alc--track-temp mask)
      (if number-sources
        (progn
          (setq index 0)
          (foreach entry entries
            (setq index (1+ index)
                  labels (cons (alc--stat-add-label entry index text-height layer) labels)))))
      ;; Replace old numbers only after every new number has been created.
      (foreach entity old-labels
        (if (entdel entity) (setq erased (cons entity erased))
          (vl-exit-with-error "Khong xoa duoc so STT cu; huy bo so moi.")))
      table) nil))
  (if (vl-catch-all-error-p result)
    (progn (alc--cleanup-temp)
      (if group (vla-Delete group))
      (foreach entity erased (entdel entity)))
    (progn
      (alc--untrack-temp (vlax-vla-object->ename table))
      (alc--untrack-temp mask)
      (foreach entity labels (alc--untrack-temp entity))))
  result)

(defun alc--stat-settings-loop (/ choice value color)
  (while (/= choice "Exit")
    (prompt (strcat "\nVVTK: Numbers=" (if *alc-stat-number-sources* "Yes" "No")
      " | Color=" (itoa (alc--stat-find-color))))
    (initget "Numbers Color Exit")
    (setq choice (getkword "\nVVTK settings [Numbers/Color/Exit] <Exit>: "))
    (cond
      ((= choice "Numbers")
        (initget "Yes No")
        (setq value (getkword (strcat "\nGhi so STT tren pline [Yes/No] <"
          (if *alc-stat-number-sources* "Yes" "No") ">: ")))
        (if value (progn (setq *alc-stat-number-sources* (= value "Yes")) (alc--save-settings))))
      ((= choice "Color")
        (if (and (setq color (alc--stat-find-pick-color)) (alc--valid-color-p color))
          (progn (setq *alc-stat-find-color* color) (alc--save-settings))))
      (T (setq choice "Exit"))))
  (princ))

(defun alc--stat-cell-link-value (table row / value)
  (vla-GetCustomData table row 0 "ALC_VVTK_ROW" 'value)
  (if (= (type value) 'VARIANT) (setq value (vlax-variant-value value)))
  (if (= (type value) 'STR) (read value)))

(defun alc--stat-row-source (table row / link entity data)
  (cond
    ((or (< row 2) (>= row (1- (vla-get-Rows table))))
      (prompt "\nHay bam vao dong chi tiet, khong phai tieu de hoac tong cong.") nil)
    (T
      (setq link (vl-catch-all-apply 'alc--stat-cell-link-value (list table row)))
      (cond
        ((or (vl-catch-all-error-p link) (not (listp link)) (/= (length link) 6)
             (not (equal (car link) "VVTK1")))
          (prompt "\nDong nay chua co lien ket doi tuong. Hay tao lai bang bang VVTK.") nil)
        ((not (equal (cadr link) (getvar "FINGERPRINTGUID")))
          (prompt "\nBang nay lien ket voi ban ve khac. Hay tao lai VVTK trong ban ve hien tai.") nil)
        ((not (equal (cdddr link) (list (vla-GetText table row 0)
                (vla-GetText table row 1) (vla-GetText table row 3))))
          (prompt "\nNoi dung dong da thay doi; hay tao lai VVTK de tranh tim sai doi tuong.") nil)
        (T
          (setq entity (vl-catch-all-apply 'handent (list (caddr link))))
          (if (and (not (vl-catch-all-error-p entity)) entity (setq data (entget entity))
                   (member (cdr (assoc 0 data)) '("LINE" "LWPOLYLINE" "POLYLINE")))
            entity
            (progn (prompt "\nDoi tuong goc khong con ton tai. Hay tao lai bang VVTK.") nil)))))))

(defun alc--stat-find-at-pick (picked / entity table row column hit source)
  (setq entity (car picked))
  (if (= (cdr (assoc 0 (entget entity))) "ACAD_TABLE")
    (progn
      (setq table (vlax-ename->vla-object entity)
            hit (vla-HitTest table (vlax-3d-point (trans (cadr picked) 1 0))
              (vlax-3d-point (trans '(0.0 0.0 1.0) 2 0 T)) 'row 'column))
      (if (= hit :vlax-true)
        (if (setq source (alc--stat-row-source table row))
          (if (= (cdr (assoc 410 (entget source)))
                 (if (= (getvar "CVPORT") 1) (getvar "CTAB") "Model"))
            source
            (progn (prompt "\nDoi tuong goc nam trong Model/Layout khac.") nil)))))
    (progn (prompt "\nHay chon mot dong cua bang VVTK.") nil)))

(defun alc--stat-find-color ()
  (if (not (and (boundp '*alc-stat-find-color*) (= (type *alc-stat-find-color*) 'INT)
                (>= *alc-stat-find-color* 1) (<= *alc-stat-find-color* 255)))
    (setq *alc-stat-find-color* 1))
  *alc-stat-find-color*)

(defun alc--stat-find-pick-color () (acad_colordlg (alc--stat-find-color) nil))

(defun alc--stat-find-change-color (/ color)
  (if (setq color (alc--stat-find-pick-color))
    (if (and (= (type color) 'INT) (>= color 1) (<= color 255))
      (progn
        (setq *alc-stat-find-color* color)
        (alc--save-settings)
        (setvar "SELECTIONEFFECTCOLOR" color)
        (if (and *alc-stat-find-highlight* (entget *alc-stat-find-highlight*))
          (progn (redraw *alc-stat-find-highlight* 4) (redraw *alc-stat-find-highlight* 3)))
        (prompt (strcat "\nMau Find: ACI " (itoa color) ".")))
      (prompt "\nHay chon mau ACI 1-255, khong dung ByLayer/ByBlock."))))

(defun alc--stat-find-read-point ()
  (initget "Color")
  (getpoint "\nBam dong VVTK hoac [Color] <Enter ket thuc>: "))

(defun alc--stat-find-picks (/ tables point index entity table row column picked source)
  ;; Test the cell area, including empty space between text and grid lines.
  (setq tables (ssget "_X" (list '(0 . "ACAD_TABLE")
    (cons 410 (if (= (getvar "CVPORT") 1) (getvar "CTAB") "Model")))))
  (while (setq point (alc--stat-find-read-point))
    (if (= (type point) 'STR)
      (alc--stat-find-change-color)
      (progn
    (setq index 0 picked nil source nil)
    (if tables
      (while (and (< index (sslength tables)) (not picked))
        (setq entity (ssname tables index) index (1+ index) table (vlax-ename->vla-object entity))
        (if (= (vla-HitTest table (vlax-3d-point (trans point 1 0))
                 (vlax-3d-point (trans '(0.0 0.0 1.0) 2 0 T)) 'row 'column) :vlax-true)
          (setq picked T source (alc--stat-find-at-pick (list entity point))))))
    (if source
      (progn
        (if (and *alc-stat-find-highlight* (entget *alc-stat-find-highlight*))
          (redraw *alc-stat-find-highlight* 4))
        (setq *alc-stat-find-highlight* source)
        (redraw source 3)
        (prompt "\nDa to sang doi tuong goc cua dong vua chon.")))
    (if (not picked) (prompt "\nKhong co o bang tai diem bam. Hay chon lai."))))))

(defun alc--stat-find-loop (/ result previous old-osmode old-effect old-color *alc-stat-find-highlight*)
  (setq previous (cadr (ssgetfirst)) old-osmode (getvar "OSMODE")
        old-effect (getvar "SELECTIONEFFECT") old-color (getvar "SELECTIONEFFECTCOLOR"))
  (sssetfirst nil nil)
  (setvar "OSMODE" 0)
  (setq result (vl-catch-all-apply
    '(lambda ()
      (setvar "SELECTIONEFFECT" 1)
      (setvar "SELECTIONEFFECTCOLOR" (alc--stat-find-color))
      (alc--stat-find-picks)) nil))
  (setvar "OSMODE" old-osmode)
  (if (and *alc-stat-find-highlight* (entget *alc-stat-find-highlight*))
    (redraw *alc-stat-find-highlight* 4))
  (setvar "SELECTIONEFFECTCOLOR" old-color)
  (setvar "SELECTIONEFFECT" old-effect)
  (if (vl-catch-all-error-p result)
    (progn (sssetfirst nil previous)
      (prompt (strcat "\nVVTK Find: " (vl-catch-all-error-message result))) nil)
    (sssetfirst nil (if *alc-stat-find-highlight* (ssadd *alc-stat-find-highlight*) previous))))

(defun alc--stat-command (/ value *alc-stat-command-height*)
  (setq value "Manage")
  (while (= value "Manage")
    (initget 6 "Find Manage")
    (setq value (getdist (strcat "\nChieu cao chu hoac [Find/Manage] <"
      (rtos *alc-stat-text-height* 2 0) ">: ")))
    (if (= value "Manage") (alc--run-command 'alc--stat-settings-loop "VVTK Settings")))
  (if (= (type value) 'STR)
    (alc--stat-find-loop)
    (progn
      (setq *alc-stat-command-height* (if value value *alc-stat-text-height*))
      (alc--run-command 'alc--stat-loop "ALCTK"))))

(defun alc--sumtable-number (text / codes code index digits separator valid)
  ;; Parse the whole displayed decimal, never silently accept a numeric prefix.
  (setq text (vl-string-trim " \t\r\n" text) codes (vl-string->list text)
        index 0 digits 0 valid T)
  (foreach code codes
    (cond
      ((and (>= code 48) (<= code 57)) (setq digits (1+ digits)))
      ((and (= index 0) (member code '(43 45))) nil)
      ((and (member code '(44 46)) (not separator)) (setq separator T))
      (T (setq valid nil)))
    (setq index (1+ index)))
  (if (and valid (> digits 0)) (distof (vl-string-translate "," "." text) 2)))

(defun alc--sumtable-cell (table row column)
  (vl-string-trim " \t\r\n" (vla-GetText table row column)))

(defun alc--sumtable-source-entry (entity / table last-row value title handle)
  (if (= (cdr (assoc 0 (entget entity))) "ACAD_TABLE")
    (progn
      (setq table (vlax-ename->vla-object entity) last-row (1- (vla-get-Rows table)))
      ;; Header recognition also supports existing, untagged VVTK tables.
      (if (and (= (vla-get-Columns table) 4) (>= last-row 3)
               (= (strcase (alc--sumtable-cell table 1 0)) "STT")
               (= (strcase (alc--sumtable-cell table 1 1)) "TÊN LAYER")
               (= (strcase (alc--sumtable-cell table 1 2)) "ĐƠN VỊ")
               (member (strcase (alc--sumtable-cell table 1 3))
                 '("CHIỀU DÀI (M)" "CHIỀU DÀI TỔNG THEO LAYER"))
               (= (strcase (alc--sumtable-cell table last-row 1)) "TỔNG CỘNG")
               (= (strcase (alc--sumtable-cell table last-row 2)) "M")
               (setq value (alc--sumtable-number (alc--sumtable-cell table last-row 3))))
        (progn
          (setq title (alc--sumtable-cell table 0 0) handle (cdr (assoc 5 (entget entity))))
          (if (member title '("" "BẢNG THỐNG KÊ CHIỀU DÀI TỪNG ĐỐI TƯỢNG" "BẢNG THỐNG KÊ CHIỀU DÀI TƯỜNG"))
            (setq title "BẢNG"))
          ;; The shared VVTK renderer expects millimetres and displays metres.
          (alc--stat-length-entry entity (strcat title " [" handle "]") (* value 1000.0)))))))

(defun alc--sumtable-rows (selection / index entity result entries)
  (setq index 0)
  (if selection
    (repeat (sslength selection)
      (setq entity (ssname selection index) index (1+ index)
            result (vl-catch-all-apply 'alc--sumtable-source-entry (list entity)))
      (if (and result (not (vl-catch-all-error-p result)))
        (setq entries (cons result entries))
        (prompt (strcat "\nBo qua bang [" (cdr (assoc 5 (entget entity)))
          "]: khong dung cau truc VVTK hoac tong khong phai so thap phan hop le.")))))
  (mapcar 'cadddr (alc--stat-sort-entries entries)))

(defun alc--sumtable-loop (/ text-height selection rows insertion)
  (setq text-height (alc--ask-stat-text-height))
  (prompt "\nPick hoac quet chon cac bang VVTK can cong <Enter xac nhan>: ")
  (if (setq selection (ssget '((0 . "ACAD_TABLE"))))
    (if (setq rows (alc--sumtable-rows selection))
      (if (setq insertion (getpoint "\nChon diem chen bang tong hop: "))
        (progn
          (alc--add-length-table-rows rows (trans insertion 1 0) text-height 'sumtables)
          (prompt (strcat "\nDa tong hop " (itoa (length rows)) " bang VVTK. Tong = "
            (rtos (/ (alc--total-layer-length rows) 1000.0) 2 3) " m."))))
      (prompt "\nKhong co bang VVTK hop le de tong hop."))))

(defun alc--stat-sample-layers (selection / index entity name names)
  (setq index 0)
  (if selection
    (repeat (sslength selection)
      (setq entity (ssname selection index) index (1+ index)
            name (cdr (assoc 8 (entget entity))))
      (if (and name (not (member name names))) (setq names (cons name names)))))
  (if names (acad_strlsort names)))

(defun alc--stat-sample-at-point (point)
  (ssget point))

(defun alc--stat-sample-in-box (first second)
  ;; Match the normal left-to-right Window / right-to-left Crossing gesture.
  (ssget (if (< (car (trans first 1 2)) (car (trans second 1 2))) "_W" "_C") first second))

(defun alc--stat-read-sample-point ()
  (initget "All")
  (getpoint "\nChon doi tuong lay layer [All(A)] <Enter/Space: xong / last pick>: "))

(defun alc--stat-read-sample-corner (first)
  (getcorner first "\nGoc doi dien: "))

(defun alc--stat-select-layer-objects-run (/ first second picked index entity done answer)
  (while (not done)
    (setq first (alc--stat-read-sample-point) picked nil)
    (cond
      ((equal first "All") (setq answer 'all done T))
      ((not first) (setq answer (if (> (sslength selection) 0) selection) done T))
      (T
        (setq picked (alc--stat-sample-at-point first))
        ;; Clicking empty space starts the selection rectangle immediately.
        (if (and (not picked) (setq second (alc--stat-read-sample-corner first)))
          (setq picked (alc--stat-sample-in-box first second)))
        (if picked
          (progn
            (setq index 0)
            (repeat (sslength picked)
              (setq entity (ssname picked index) index (1+ index))
              (if (not (ssmemb entity selection))
                (progn (ssadd entity selection) (redraw entity 3))))
            (prompt (strcat "\nDa chon " (itoa (sslength selection)) " doi tuong mau.")))))))
  answer)

(defun alc--stat-select-layer-objects (/ selection old-osmode result index)
  ;; Restore snaps and sample highlights on Enter, All, ESC, or any input error.
  (setq selection (ssadd) old-osmode (getvar "OSMODE"))
  (setvar "OSMODE" (logior old-osmode 16384))
  (setq result (vl-catch-all-apply 'alc--stat-select-layer-objects-run nil) index 0)
  (repeat (sslength selection)
    (redraw (ssname selection index) 4)
    (setq index (1+ index)))
  (setvar "OSMODE" old-osmode)
  (if (vl-catch-all-error-p result)
    (vl-exit-with-error (vl-catch-all-error-message result)) result))

(defun alc--stat-choose-layers (/ selection layers last name record)
  (setq selection (alc--stat-select-layer-objects))
  (cond
    ((eq selection 'all)
      (setq *alc-stat-last-layers* 'all)
      'all)
    (selection
      (setq layers (alc--stat-sample-layers selection))
      (if layers
        (progn
          ;; AutoLISP variables belong to this drawing; do not clear on reload.
          ;; Cache layer names, not sample entities, so deleted samples are safe.
          (setq *alc-stat-last-layers* layers)
          (prompt (strcat "\nDa chon " (itoa (length layers)) " layer lam bo loc."))))
      layers)
    (T
      (if (boundp '*alc-stat-last-layers*) (setq last *alc-stat-last-layers*))
      (cond
        ((eq last 'all)
          (prompt "\nDung lai last pick: All (khong loc layer).")
          'all)
        ((and last (listp last))
          (foreach name last
            (if (setq record (tblsearch "LAYER" name))
              (setq layers (cons (cdr (assoc 2 record)) layers))))
          (if layers
            (progn
              (setq layers (acad_strlsort layers))
              (prompt (strcat "\nDung lai last pick: " (itoa (length layers)) " layer.")))
            (prompt "\nCac layer trong last pick khong con ton tai. Hay chon mau moi."))
          layers)
        (T (prompt "\nChua co last pick layer. Huy lenh.") nil)))))

(defun alc--stat-filter-selection (selection layers / index entity result wanted)
  (setq index 0 result (ssadd))
  (if (= layers 'all) selection
    (progn
      (setq wanted (mapcar 'strcase layers))
      (if selection
        (repeat (sslength selection)
          (setq entity (ssname selection index) index (1+ index))
          (if (member (strcase (cdr (assoc 8 (entget entity)))) wanted)
            (ssadd entity result))))
      (if (> (sslength result) 0) result))))

(defun alc--stat-select-region (layers / selection)
  (prompt "\nChon vung LINE/POLYLINE can thong ke: ")
  (setq selection (ssget '((0 . "LINE,LWPOLYLINE,POLYLINE"))))
  (alc--stat-filter-selection selection layers))

(defun alc--stat-loop
  (/ text-height selection entries totals insertion result total-length layers number-sources)
  (setq text-height
    (if (and (boundp '*alc-stat-command-height*) (numberp *alc-stat-command-height*))
      *alc-stat-command-height* (alc--ask-stat-text-height)))
  (if (/= text-height *alc-stat-text-height*)
    (progn (setq *alc-stat-text-height* text-height) (alc--save-settings)))
  (if (setq layers (alc--stat-choose-layers))
    (setq selection (alc--stat-select-region layers)))
  (if (and layers (not selection))
    (prompt "\nKhong co LINE/POLYLINE thuoc layer da chon trong vung chon."))
  (if selection
    (progn
      (setq entries (alc--collect-length-entries selection) totals (mapcar 'cadddr entries))
      (if totals
        (progn
        (setq number-sources *alc-stat-number-sources*)
        (if (setq insertion (getpoint "\nChon diem chen bang: "))
          (progn
            (setq result
              (vl-catch-all-apply 'alc--stat-create-output
                (list entries (trans insertion 1 0) text-height number-sources)))
            (if (vl-catch-all-error-p result)
              (prompt (strcat "\nKhong the tao bang thong ke: "
                (vl-catch-all-error-message result)))
              (progn
                (setq total-length (alc--total-layer-length totals))
                (prompt (strcat "\nDa tao bang cho " (itoa (length totals))
                  " doi tuong. Tong chieu dai="
                  (rtos (/ total-length 1000.0) 2 3) " m.")))))))
        (prompt "\nKhong tim thay LINE/POLYLINE mo hop le (bo qua polyline khep kin va REVCLOUD).")))))

;;; --------------------------------------------------------------------------
;;; Door-block schedule

;;; --------------------------------------------------------------------------
;;; ALC wall types: one centerline length per actual boundary, never perimeter.

(defun alc--wall-strip-candidate (points / half side-a side-b width valid total
    a b next-a next-b ua ub separation previous)
  (setq half (/ (length points) 2) side-b points)
  (repeat half
    (setq side-a (cons (car side-b) side-a) side-b (cdr side-b)))
  (setq side-a (reverse side-a) side-b (reverse side-b)
        width (distance (car side-a) (car side-b))
        valid (> width 1e-6) total 0.0)
  (while (and valid (cdr side-a))
    (setq a (car side-a) b (car side-b)
          next-a (cadr side-a) next-b (cadr side-b)
          ua (alc--unit-vector (alc--vector-subtract next-a a))
          ub (alc--unit-vector (alc--vector-subtract next-b b))
          separation (alc--vector-subtract b a))
    (if (and ua ub (equal ua ub 1e-6)
             (equal (alc--vector-length
               (alc--vector-subtract separation
                 (alc--vector-scale ua (alc--vector-dot separation ua)))) width 1e-4)
             (or previous (< (abs (alc--vector-dot separation ua)) 1e-4))
             (or (cddr side-a)
               (< (abs (alc--vector-dot (alc--vector-subtract next-b next-a) ua)) 1e-4)))
      (setq total (+ total (distance
        (alc--vector-scale (alc--vector-add a b) 0.5)
        (alc--vector-scale (alc--vector-add next-a next-b) 0.5)))
        previous T)
      (setq valid nil))
    (setq side-a (cdr side-a) side-b (cdr side-b)))
  (if (and valid (> total 1e-6)) (list width total)))

(defun alc--wall-strip-metrics-for-width (points preferred / count index candidate best)
  (setq points (alc--clean-polygon-points points) count (length points) index 0)
  (if (and (>= count 4) (= (rem count 2) 0))
    (repeat count
      (setq candidate (alc--wall-strip-candidate points))
      (if (and candidate
               (or (not preferred) (equal preferred (car candidate) 1e-4))
               (or (not best) (< (car candidate) (car best))))
        (setq best candidate))
      (setq points (append (cdr points) (list (car points))))))
  best)

(defun alc--wall-strip-metrics (points)
  (alc--wall-strip-metrics-for-width points nil))

(defun alc--legacy-stat-wall-p (wall / hatches hatch data pattern)
  ;; Pre-marker drawings are recognizable only by their original layer/style.
  ;; ANSI31 is reserved here for lintels/ties and must never become a wall.
  (and (member (strcase (cdr (assoc 8 (entget wall))))
               '("0. TUONG ALC" "ALC_WALL DEFAULT"))
       (setq hatches (alc--find-boundary-hatches wall)) (= (length hatches) 1)
       (setq hatch (car hatches) data (entget hatch)
             pattern (strcase (cdr (assoc 2 data))))
       (= (cdr (assoc 71 data)) 1) (= (cdr (assoc 91 data)) 1)
       (equal (alc--hatch-source-boundaries hatch) (list wall))
       (/= pattern "ANSI31")
       (or (= pattern "ANSI37") (= pattern (strcase *alc-pattern*)))))

(defun alc--wall-type-metrics (wall / data points normal tagged valid item)
  (setq data (entget wall) valid (alc--closed-lwpolyline-p wall))
  (foreach item data
    (if (and (= (car item) 42) (not (equal (cdr item) 0.0 1e-10)))
      (setq valid nil)))
  (if (and valid
           (setq points (alc--clean-polygon-points (alc--lwp-points wall)))
           (alc--valid-polygon-p points
             (if (setq normal (cdr (assoc 210 data))) normal '(0.0 0.0 1.0)))
           (or (setq tagged (alc--wall-tag-width wall)) (alc--legacy-stat-wall-p wall)))
    (alc--wall-strip-metrics-for-width points tagged)))

(defun alc--wall-stat-caps (wall width / points count half candidate caps)
  (setq points (alc--clean-polygon-points (alc--lwp-points wall))
        count (length points) half (/ count 2))
  (repeat count
    (if (and (not caps) (setq candidate (alc--wall-strip-candidate points))
             (equal (car candidate) width 1e-4))
      (setq caps (list
        (list (alc--vector-scale (alc--vector-add (car points) (last points)) 0.5)
          (alc--unit-vector (alc--vector-subtract
            (alc--vector-add (car points) (last points))
            (alc--vector-add (cadr points) (nth (- count 2) points)))))
        (list (alc--vector-scale (alc--vector-add (nth (1- half) points) (nth half points)) 0.5)
          (alc--unit-vector (alc--vector-subtract
            (alc--vector-add (nth (1- half) points) (nth half points))
            (alc--vector-add (nth (- half 2) points) (nth (1+ half) points))))))))
    (setq points (append (cdr points) (list (car points)))))
  caps)

(defun alc--wall-opening-equal-p (a b)
  (or (equal a b 1e-4) (equal a (reverse b) 1e-4)))

(defun alc--wall-has-opening-p (wall pair / found other)
  (foreach other (alc--wall-openings wall)
    (if (alc--wall-opening-equal-p pair other) (setq found T)))
  found)

(defun alc--wall-opening-cap-p (entry point / found cap)
  (foreach cap (nth 2 entry)
    (if (equal (car cap) point 1e-4) (setq found T)))
  found)

(defun alc--record-stat-door (span inferred / key item updated)
  (setq key (/ (float (fix (+ (* span 1000.0) 0.5))) 1000.0)
        item (assoc key *alc-stat-door-types*))
  (if (not item) (setq item (list key 0 0)))
  (setq updated (list key (+ (cadr item) (if inferred 0 1))
                         (+ (caddr item) (if inferred 1 0))))
  (if (assoc key *alc-stat-door-types*)
    (setq *alc-stat-door-types* (subst updated item *alc-stat-door-types*))
    (setq *alc-stat-door-types* (cons updated *alc-stat-door-types*))))

(defun alc--add-recorded-opening-lengths (entries totals / entry other pair done found width)
  (foreach entry entries
    (setq width (caadr entry))
    (foreach pair (alc--wall-openings (car entry))
      (setq found nil)
      (if (not (vl-some '(lambda (p)
          (and (equal (car p) width 1e-4) (alc--wall-opening-equal-p (cadr p) pair))) done))
        (foreach other entries
          (if (and (not (equal (car entry) (car other)))
                   (equal width (caadr other) 1e-4)
                   (alc--wall-has-opening-p (car other) pair)
                   (or (and (alc--wall-opening-cap-p entry (car pair))
                            (alc--wall-opening-cap-p other (cadr pair)))
                       (and (alc--wall-opening-cap-p entry (cadr pair))
                            (alc--wall-opening-cap-p other (car pair)))))
            (setq found T))))
      (if found
        (progn
          (alc--record-stat-door (distance (car pair) (cadr pair)) nil)
          (setq totals (alc--add-layer-length totals width (distance (car pair) (cadr pair)))
                done (cons (list width pair) done))))))
  totals)

(defun alc--wall-gap-distance (cap other / vector span direction)
  (setq vector (alc--vector-subtract (car other) (car cap))
        span (alc--vector-length vector) direction (alc--unit-vector vector))
  (if (and direction (cadr cap) (cadr other) (> span 1e-4)
           (equal direction (cadr cap) 1e-6)
           (equal direction (alc--vector-scale (cadr other) -1.0) 1e-6)) span))

(defun alc--nearest-legacy-wall-cap (entry cap entries / other other-cap span nearest)
  (foreach other entries
    (if (and (not (equal (car entry) (car other)))
             (equal (caadr entry) (caadr other) 1e-4)
             (equal (strcase (cdr (assoc 8 (entget (car entry)))))
                    (strcase (cdr (assoc 8 (entget (car other))))))
             (alc--wall-legacy-openings-p (car other)))
      (foreach other-cap (nth 2 other)
        (if (and (setq span (alc--wall-gap-distance cap other-cap))
                 (or (not nearest) (< span (nth 2 nearest))))
          (setq nearest (list other other-cap span))))))
  nearest)

(defun alc--add-legacy-opening-lengths (entries totals / entry cap nearest back pair done width known)
  (setq *alc-stat-inferred-openings* 0)
  (foreach entry entries
    (if (alc--wall-legacy-openings-p (car entry))
      (foreach cap (nth 2 entry)
        (setq nearest (alc--nearest-legacy-wall-cap entry cap entries))
        (if nearest
          (progn
            (setq back (alc--nearest-legacy-wall-cap (car nearest) (cadr nearest) entries)
                  pair (list (car cap) (car (cadr nearest))) width (caadr entry)
                  known (and (alc--wall-has-opening-p (car entry) pair)
                             (alc--wall-has-opening-p (caar nearest) pair)))
            (if (and back (equal (caar back) (car entry))
                     (equal (car (cadr back)) (car cap) 1e-4)
                     (not known)
                     (not (vl-some '(lambda (p)
                       (and (equal (car p) width 1e-4)
                            (alc--wall-opening-equal-p (cadr p) pair))) done)))
              (progn
                (alc--record-stat-door (nth 2 nearest) T)
                (setq totals (alc--add-layer-length totals width (nth 2 nearest))
                      done (cons (list width pair) done)
                      *alc-stat-inferred-openings* (1+ *alc-stat-inferred-openings*)))))))))
  totals)

(defun alc--legacy-fit-wall-neighbors (entries / entry points candidate trial best best-span cap nearest result)
  ;; An old 50 x 200 mm door stub must inherit the 200 mm type of the
  ;; selected collinear remainder, rather than treating 50 mm as its thickness.
  (foreach entry entries
    (setq best nil best-span nil)
    (if (not (alc--wall-tag-width (car entry)))
      (progn
        (setq points (alc--clean-polygon-points (alc--lwp-points (car entry))))
        (repeat (length points)
          (if (setq candidate (alc--wall-strip-candidate points))
            (progn
              (setq trial (list (car entry) candidate
                (alc--wall-stat-caps (car entry) (car candidate))))
              (foreach cap (nth 2 trial)
                (if (and (setq nearest (alc--nearest-legacy-wall-cap trial cap entries))
                         (or (not best-span) (< (nth 2 nearest) best-span)))
                  (setq best trial best-span (nth 2 nearest))))))
          (setq points (append (cdr points) (list (car points)))))))
    (setq result (cons (if best best entry) result)))
  (reverse result))

(defun alc--collect-wall-types (selection / i entity wall sources seen metrics totals key result entries)
  (setq *alc-stat-door-types* nil)
  (alc--end-hatch-index)
  (setq result (vl-catch-all-apply 'alc--build-hatch-index nil))
  (if (vl-catch-all-error-p result) (alc--end-hatch-index))
  (setq i 0)
  (if selection
    (repeat (sslength selection)
      (setq entity (ssname selection i) i (1+ i) wall nil)
      (cond
        ((= (cdr (assoc 0 (entget entity))) "LWPOLYLINE") (setq wall entity))
        ((= (cdr (assoc 0 (entget entity))) "HATCH")
          (setq sources (alc--hatch-source-boundaries entity))
          (if (= (length sources) 1) (setq wall (car sources)))))
      (if (and wall (not (member wall seen)))
        (progn
          (setq seen (cons wall seen)
                result (vl-catch-all-apply 'alc--wall-type-metrics (list wall)))
          (if (and (not (vl-catch-all-error-p result)) (setq metrics result))
            (progn
              ;; Numeric 0.001 mm keys keep tiny floating-point noise together.
              (setq key (/ (float (fix (+ (* (car metrics) 1000.0) 0.5))) 1000.0)
                    totals (alc--add-layer-length totals key (cadr metrics))
                    entries (cons (list wall (list key (cadr metrics))
                      (alc--wall-stat-caps wall (car metrics))) entries))))))))
  (alc--end-hatch-index)
  (setq entries (alc--legacy-fit-wall-neighbors entries) totals nil)
  (foreach entity entries
    (setq key (/ (float (fix (+ (* (caadr entity) 1000.0) 0.5))) 1000.0)
          totals (alc--add-layer-length totals key (cadadr entity))))
  (setq totals (alc--add-recorded-opening-lengths entries totals))
  (setq totals (alc--add-legacy-opening-lengths entries totals))
  (vl-sort totals '(lambda (a b) (< (car a) (car b)))))

(defun alc--wall-type-label (width / text)
  (setq text (rtos width 2 3))
  (if (vl-string-search "." text) (setq text (vl-string-right-trim "." (vl-string-right-trim "0" text))))
  (strcat "ALC " text))

(defun alc--add-wall-type-table-with-doors (totals doors title insertion text-height / table entity pairs item row name)
  ;; Reuse the existing table typography and transaction cleanup.
  (foreach item (vl-sort totals '(lambda (a b) (< (car a) (car b))))
    (setq name (alc--wall-type-label (car item)) pairs (append pairs (list (cons name (cdr item))))))
  (setq table (alc--add-length-table pairs insertion text-height)
        entity (alc--vla-object-ename table))
  (alc--track-temp entity)
  (vla-put-RegenerateTableSuppressed table :vlax-true)
  (alc--set-table-text table 0 0 title)
  (alc--set-table-text table 1 1 "LOẠI TƯỜNG ALC")
  (alc--set-table-text table 1 3 "CHIỀU DÀI (m)")
  ;; add-length-table sorts strings; write rows again in numeric width order.
  (setq row 2)
  (foreach item pairs
    (alc--set-table-text table row 1 (car item))
    (alc--set-table-text table row 3 (rtos (/ (cdr item) 1000.0) 2 3))
    (setq row (1+ row)))
  (alc--append-wall-door-rows table doors text-height)
  (vla-put-RegenerateTableSuppressed table :vlax-false)
  (vla-Update table)
  (alc--untrack-temp entity)
  table)

(defun alc--add-wall-type-table (totals title insertion text-height)
  (alc--add-wall-type-table-with-doors totals nil title insertion text-height))

(defun alc--append-wall-door-rows (table doors text-height / start row column index item count total-count total-span)
  (setq start (vla-get-Rows table)
        doors (vl-sort doors '(lambda (a b) (< (car a) (car b)))))
  (vla-InsertRows table start (* text-height 2.2) (if doors (+ (length doors) 3) 1))
  ;; InsertRows uses the table style's small default height, not the explicit
  ;; heights already set on the wall cells. Apply overrides to every new cell.
  (setq row start)
  (while (< row (vla-get-Rows table))
    (setq column 0)
    (repeat 4
      (vla-SetCellTextHeight table row column text-height)
      (vla-SetCellAlignment table row column 5)
      (setq column (1+ column)))
    (setq row (1+ row)))
  (vla-MergeCells table start start 0 3)
  (alc--set-table-text table start 0
    (if doors "CỬA ĐÃ TÍNH TRONG CHIỀU DÀI TƯỜNG" "KHÔNG CÓ CỬA ĐƯỢC CỘNG TRONG VÙNG CHỌN"))
  (if doors
    (progn
      (setq row (1+ start) index 1 total-count 0 total-span 0.0)
      (alc--set-table-text table row 0 "STT")
      (alc--set-table-text table row 1 "RỘNG CỬA (mm)")
      (alc--set-table-text table row 2 "SỐ LƯỢNG (cái)")
      (alc--set-table-text table row 3 "CHI TIẾT")
      (vla-SetRowHeight table row (* text-height 4.0))
      (setq row (1+ row))
      (foreach item doors
        (setq count (+ (cadr item) (caddr item)))
        (alc--set-table-text table row 0 (itoa index))
        (alc--set-table-text table row 1 (substr (alc--wall-type-label (car item)) 5))
        (alc--set-table-text table row 2 (itoa count))
        (alc--set-table-text table row 3
          (strcat "Đã lưu: " (itoa (cadr item)) "; Suy ra: " (itoa (caddr item))))
        (setq total-count (+ total-count count) total-span (+ total-span (* (car item) count))
              row (1+ row) index (1+ index)))
      (alc--set-table-text table row 1 "TỔNG SỐ CỬA")
      (alc--set-table-text table row 2 (itoa total-count))
      (alc--set-table-text table row 3 (strcat "Tổng rộng: " (rtos (/ total-span 1000.0) 2 3) " m"))))
  table)

(defun alc--wall-type-stat-loop (/ selection totals title insertion)
  (prompt "\nQuet chon tuong ALC can thong ke (bien hoac hatch): ")
  (if (setq selection (ssget '((0 . "LWPOLYLINE,HATCH"))))
    (if (setq totals (alc--collect-wall-types selection))
      (progn
        (setq title (vl-string-trim " \t" (getstring T "\nTen bang thong ke <BANG THONG KE TUONG ALC>: ")))
        (if (= title "") (setq title "BẢNG THỐNG KÊ TƯỜNG ALC"))
        (if (setq insertion (getpoint "\nChon diem chen bang: "))
          (progn
            (alc--add-wall-type-table-with-doors totals *alc-stat-door-types*
              title (trans insertion 1 0) *alc-stat-text-height*)
            (prompt (strcat "\nDa thong ke " (itoa (length totals)) " loai tuong ALC. Tong chieu dai tim = "
              (rtos (/ (alc--total-layer-length totals) 1000.0) 2 3) " m (bao gom lo cua)."))
            (if (> *alc-stat-inferred-openings* 0)
              (prompt (strcat "\nDa tu cong " (itoa *alc-stat-inferred-openings*)
                " khe ho tuong cu nhu cua; hay kiem tra cac khe ho co chu y."))))))
      (prompt "\nKhong tim thay tuong ALC hop le. Tuong cu can dung layer 0. Tuong ALC va hatch ALC; doi tuong khac duoc bo qua."))))
