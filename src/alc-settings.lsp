;;; ALCWALL v2.0.1 - settings module
;;; ALCWALL.lsp
;;; 2D ALC wall tool for AutoCAD on Windows.
;;; Commands: ALCWALL, ALCCENTRAL, ALCDOOR, ALCLT, ALCGT, ALCGTS, ALCTK, ALCTKC, TKDIM, TKCOUNT, ALCSET
;;;
;;; Creates a closed LWPOLYLINE wall boundary and an associative hatch.
;;; Straight segments only; all picked points are projected to the plane of
;;; the first point in the current UCS.

(vl-load-com)

;;; Session defaults for ALCGT. These values are intentionally not reset by
;;; ALCSET, so the most recent width and color remain active in this session.
(if (not (and (boundp '*alc-wall-tie-width*)
              (numberp *alc-wall-tie-width*)
              (> *alc-wall-tie-width* 0.0)))
  (setq *alc-wall-tie-width* 150.0)
)
(if (not (and (boundp '*alc-wall-tie-color*)
              (numberp *alc-wall-tie-color*)
              (>= *alc-wall-tie-color* 1)
              (<= *alc-wall-tie-color* 255)))
  (setq *alc-wall-tie-color* 4)
)

(defun alc--defaults ()
  (setq *alc-pattern* "ANSI37"
        *alc-color* 5
        *alc-scale* 500.0
        *alc-thickness* 100.0
        *alc-door-width* 900.0
        *alc-stat-text-height* 100.0
        *alc-count-prefix* "CK"
        *alc-last-side* 1)
)

;;; --------------------------------------------------------------------------
;;; Persistent settings

(defun alc--settings-ename (/ record)
  (if (setq record (dictsearch (namedobjdict) "ALCWALL_SETTINGS_V1"))
    (cdr (assoc -1 record))
  )
)

(defun alc--dxf-put (code value data / item)
  (if (setq item (assoc code data))
    (subst (cons code value) item data)
    (append data (list (cons code value)))
  )
)

(defun alc--valid-color-p (value)
  (and (numberp value)
       (= value (fix value))
       (>= value 1)
       (<= value 255))
)

(defun alc--load-settings (/ ename data value)
  (alc--defaults)
  (if (setq ename (alc--settings-ename))
    (progn
      (setq data (entget ename))
      (if (and (setq value (cdr (assoc 1 data)))
               (eq (type value) 'STR)
               (/= value ""))
        (setq *alc-pattern* value)
      )
      (if (and (setq value (cdr (assoc 90 data)))
               (alc--valid-color-p value))
        (setq *alc-color* (fix value))
      )
      (if (and (setq value (cdr (assoc 40 data)))
               (numberp value)
               (> value 0.0))
        (setq *alc-scale* value)
      )
      (if (and (setq value (cdr (assoc 41 data)))
               (numberp value)
               (> value 0.0))
        (setq *alc-thickness* value)
      )
      (if (and (setq value (cdr (assoc 42 data)))
               (numberp value)
               (> value 0.0))
        (setq *alc-door-width* value)
      )
      (if (and (setq value (cdr (assoc 43 data)))
               (numberp value)
               (> value 0.0))
        (setq *alc-stat-text-height* value)
      )
      (if (and (setq value (cdr (assoc 2 data)))
               (eq (type value) 'STR)
               (/= value ""))
        (setq *alc-count-prefix* value)
      )
      (if (setq value (cdr (assoc 70 data)))
        (setq *alc-last-side* (if (= value -1) -1 1))
      )
    )
  )
)

(defun alc--save-settings (/ ename data)
  (if (setq ename (alc--settings-ename))
    (progn
      (setq data (entget ename)
            data (alc--dxf-put 1 *alc-pattern* data)
            data (alc--dxf-put 90 *alc-color* data)
            data (alc--dxf-put 40 *alc-scale* data)
            data (alc--dxf-put 41 *alc-thickness* data)
            data (alc--dxf-put 42 *alc-door-width* data)
            data (alc--dxf-put 43 *alc-stat-text-height* data)
            data (alc--dxf-put 2 *alc-count-prefix* data)
            data (alc--dxf-put 70 *alc-last-side* data))
      (entmod data)
    )
    (progn
      (setq ename
        (entmakex
          (list
            '(0 . "XRECORD")
            '(100 . "AcDbXrecord")
            (cons 1 *alc-pattern*)
            (cons 90 *alc-color*)
            (cons 40 *alc-scale*)
            (cons 41 *alc-thickness*)
            (cons 42 *alc-door-width*)
            (cons 43 *alc-stat-text-height*)
            (cons 2 *alc-count-prefix*)
            (cons 70 *alc-last-side*)
          )
        )
      )
      (if ename
        (dictadd (namedobjdict) "ALCWALL_SETTINGS_V1" ename)
      )
    )
  )
  (princ)
)

;;; --------------------------------------------------------------------------
;;; Settings UI

(defun alc--color-name (color)
  (strcat "ACI " (itoa color))
)

(defun alc--status ()
  (strcat
    "\nCurrent: Thickness=" (rtos *alc-thickness* 2 0)
    " | Pattern=" *alc-pattern*
    " | Color=" (alc--color-name *alc-color*)
    " | Scale=" (rtos *alc-scale* 2 0)
  )
)

(defun alc--set-pattern (/ value)
  (setq value (getstring T (strcat "\nPattern <" *alc-pattern* ">: "))
        value (vl-string-trim " " value))
  (if (/= value "")
    (progn
      (setq *alc-pattern* (strcase value))
      (alc--save-settings)
    )
  )
)

(defun alc--set-color (/ color)
  (if (setq color (acad_colordlg *alc-color* nil))
    (progn
      (setq *alc-color* color)
      (alc--save-settings)
      (prompt (strcat "\nSelected color: " (alc--color-name color)))
    )
  )
)

(defun alc--set-scale (/ value)
  (initget 6)
  (if (setq value
        (getreal (strcat "\nHatch scale <" (rtos *alc-scale* 2 0) ">: ")))
    (progn
      (setq *alc-scale* value)
      (alc--save-settings)
    )
  )
)

(defun alc--set-thickness (/ value)
  (initget 6)
  (if (setq value
        (getdist (strcat "\nWall thickness <" (rtos *alc-thickness* 2 0) ">: ")))
    (progn
      (setq *alc-thickness* value)
      (alc--save-settings)
    )
  )
)

(defun alc--ask-door-width (/ value)
  (initget 6)
  (if (setq value
        (getdist
          (strcat
            "\nDoor opening width <"
            (rtos *alc-door-width* 2 0)
            ">: ")))
    (progn
      (setq *alc-door-width* value)
      (alc--save-settings)
    )
  )
  *alc-door-width*
)

(defun alc--settings (/ choice)
  (setq choice "Continue")
  (while (not (equal choice "Exit"))
    (prompt (alc--status))
    (initget "Thickness Pattern Color Scale Exit")
    (setq choice
      (getkword "\nSettings [Thickness/Pattern/Color/Scale/Exit] <Exit>: "))
    (cond
      ((equal choice "Thickness") (alc--set-thickness))
      ((equal choice "Pattern") (alc--set-pattern))
      ((equal choice "Color") (alc--set-color))
      ((equal choice "Scale") (alc--set-scale))
      (T (setq choice "Exit"))
    )
  )
  (princ)
)
