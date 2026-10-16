(setq *alc-module-version* "3.4.0")
;;; ALCWALL v3.4.0 - settings module
;;; ALCWALL.lsp
;;; 2D ALC wall tool for AutoCAD on Windows.
;;; Commands: ALCWALL, ALCCENTRAL, ALCDOOR, ALCLT, ALCGT, ALCGTS, ALCTK, ALCTKC, TKDIM, TKCOUNT, TKMS, TKALIGN, ALCSET
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
        *alc-color* 251
        *alc-background-color* 256
        *alc-scale* 25.0
        *alc-angle* 0.0
        *alc-thickness* 100.0
        *alc-door-width* 900.0
        *alc-stat-text-height* 100.0
        *alc-count-prefix* "CK"
        *alc-last-side* 1
        *alc-settings-schema-version* 4)
)

;;; --------------------------------------------------------------------------
;;; Persistent settings

(defun alc--normalize-angle (value / result)
  (setq result (rem value (* 2.0 pi)))
  (if (< result 0.0) (+ result (* 2.0 pi)) result)
)

(defun alc--set-angle (/ value)
  ;; Explicit decimal degrees, independent of AUNITS, ANGBASE and ANGDIR.
  (if (setq value
        (getreal (strcat "\nHatch angle (degrees) <"
          (rtos (/ (* *alc-angle* 180.0) pi) 2 2) ">: ")))
    (progn
      (setq *alc-angle* (alc--normalize-angle (/ (* value pi) 180.0)))
      (alc--save-settings))
  )
)

(defun alc--ensure-wall-layer (/ layer)
  (or (tblobjname "LAYER" "0. Tuong ALC")
      (progn
        (entmakex '((0 . "LAYER") (100 . "AcDbSymbolTableRecord")
                        (100 . "AcDbLayerTableRecord") (2 . "0. Tuong ALC")
                        (70 . 0) (62 . 4) (6 . "Continuous") (370 . 9)))
        (tblobjname "LAYER" "0. Tuong ALC")))
)


(defun alc--settings-ename (/ record)
  (if (setq record (dictsearch (namedobjdict) "ALCWALL_SETTINGS_V1"))
    (cdr (assoc -1 record))
  )
)

(defun alc--valid-color-p (value)
  (and (numberp value)
       (= value (fix value))
       (>= value 1)
       (<= value 255))
)

(defun alc--valid-background-color-p (value)
  ;; 0 means no background. 256 is an internal sentinel for true white;
  ;; neither value is passed to the ACI ColorIndex property.
  (and (numberp value)
       (= value (fix value))
       (or (= value 0)
           (= value 256)
           (alc--valid-color-p value)))
)

(defun alc--load-settings (/ ename data value schema-version needs-upgrade)
  (alc--defaults)
  (if (setq ename (alc--settings-ename))
    (progn
      (setq data (entget ename)
            schema-version (cdr (assoc 92 data))
            needs-upgrade
              (not (and (numberp schema-version)
                        (member schema-version '(2 3 4)))))
      (if (and (setq value (cdr (assoc 1 data)))
               (eq (type value) 'STR)
               (/= value ""))
        (setq *alc-pattern* value)
      )
      ;; Schema V1 used color 5 and scale 500 as defaults. Do not let those
      ;; persisted legacy values override the V2 defaults.
      (if (not needs-upgrade)
        (progn
          (if (and (setq value (cdr (assoc 90 data)))
                   (alc--valid-color-p value))
            (setq *alc-color* (fix value))
          )
          (if (and (setq value (cdr (assoc 91 data)))
                   (alc--valid-background-color-p value))
            (setq *alc-background-color* (fix value))
          )
          (if (and (setq value (cdr (assoc 40 data)))
                   (numberp value)
                   (> value 0.0))
            ;; Upgrade the old default once; preserve custom scales in V4.
            (setq *alc-scale*
              (if (and (/= schema-version 4) (equal value 250.0 1e-9))
                25.0 value))
          )
        )
      )
      (if (and (setq value (cdr (assoc 44 data)))
               (numberp value))
        (setq *alc-angle* (alc--normalize-angle value))
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
      (if (or needs-upgrade (/= schema-version 4))
        (alc--save-settings)
      )
    )
  )
  ;; Every APPLOAD starts with a true-white hatch background. ALCSET may
  ;; change it for the current session, but persisted background choices do
  ;; not override this startup default on the next load.
  (setq *alc-background-color* 256)
)

(defun alc--settings-ready-p ()
  (and (boundp '*alc-settings-schema-version*)
       (numberp *alc-settings-schema-version*)
       (= *alc-settings-schema-version* 4)
       (boundp '*alc-pattern*)
       (eq (type *alc-pattern*) 'STR)
       (/= *alc-pattern* "")
       (boundp '*alc-color*)
       (alc--valid-color-p *alc-color*)
       (boundp '*alc-background-color*)
       (alc--valid-background-color-p *alc-background-color*)
       (boundp '*alc-scale*)
       (numberp *alc-scale*)
       (> *alc-scale* 0.0)
       (boundp '*alc-angle*)
       (numberp *alc-angle*)
       (>= *alc-angle* 0.0)
       (< *alc-angle* (* 2.0 pi))
       (boundp '*alc-thickness*)
       (numberp *alc-thickness*)
       (> *alc-thickness* 0.0)
       (boundp '*alc-door-width*)
       (numberp *alc-door-width*)
       (> *alc-door-width* 0.0)
       (boundp '*alc-stat-text-height*)
       (numberp *alc-stat-text-height*)
       (> *alc-stat-text-height* 0.0)
       (boundp '*alc-count-prefix*)
       (eq (type *alc-count-prefix*) 'STR)
       (/= *alc-count-prefix* "")
       (boundp '*alc-last-side*)
       (member *alc-last-side* '(-1 1)))
)

(defun alc--ensure-settings ()
  ;; Do not reload the drawing XRecord before every command.  ALCSET changes
  ;; these session variables immediately; reloading here could overwrite those
  ;; changes when a CAD host has not committed the XRecord yet.
  (if (not (alc--settings-ready-p))
    (alc--load-settings)
  )
)

(defun alc--make-settings-record ()
  (entmakex
    (list
      '(0 . "XRECORD")
      '(100 . "AcDbXrecord")
      (cons 1 *alc-pattern*)
      (cons 90 *alc-color*)
      (cons 91 *alc-background-color*)
      (cons 92 4)
      (cons 40 *alc-scale*)
      (cons 44 *alc-angle*)
      (cons 41 *alc-thickness*)
      (cons 42 *alc-door-width*)
      (cons 43 *alc-stat-text-height*)
      (cons 2 *alc-count-prefix*)
      (cons 70 *alc-last-side*)
    )
  )
)

(defun alc--save-settings
  (/ dictionary old-record new-record added-record restored-record)
  ;; AutoCAD does not support changing XRECORD contents with entmod.  Some
  ;; hosts append the submitted entity list instead, making the record grow
  ;; exponentially on repeated saves.  Replace the dictionary entry with a
  ;; freshly created, canonical XRECORD and erase the old object only after
  ;; the replacement has succeeded.
  (setq dictionary (namedobjdict)
        old-record (alc--settings-ename)
        new-record (alc--make-settings-record))
  (if new-record
    (progn
      (if old-record
        (dictremove dictionary "ALCWALL_SETTINGS_V1")
      )
      (setq added-record
        (dictadd dictionary "ALCWALL_SETTINGS_V1" new-record))
      (if added-record
        (if old-record
          (entdel old-record)
        )
        (progn
          ;; Keep the previous settings reachable if replacing the dictionary
          ;; entry fails for any reason.
          (if old-record
            (setq restored-record
              (dictadd dictionary "ALCWALL_SETTINGS_V1" old-record))
          )
          (entdel new-record)
          (if (not restored-record)
            (prompt "\nCould not save ALC settings to this drawing.")
          )
        )
      )
    )
    (prompt "\nCould not create the ALC settings record.")
  )
  (princ)
)

;;; --------------------------------------------------------------------------
;;; Settings UI

(defun alc--color-name (color)
  (strcat "ACI " (itoa color))
)

(defun alc--background-color-name (color)
  (cond
    ((= color 0) "None")
    ((= color 256) "TrueColor RGB 255,255,255")
    (T (alc--color-name color))
  )
)

(defun alc--status ()
  (strcat
    "\nCurrent: Thickness=" (rtos *alc-thickness* 2 0)
    " | Pattern=" *alc-pattern*
    " | Color=" (alc--color-name *alc-color*)
    " | Background=" (alc--background-color-name *alc-background-color*)
    " | Scale=" (rtos *alc-scale* 2 0)
    " | Angle=" (rtos (/ (* *alc-angle* 180.0) pi) 2 2) " deg"
  )
)

(defun alc--set-pattern (/ value)
  (setq value (alc--choose-pattern *alc-pattern*))
  (if value
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

(defun alc--set-background-color (/ choice color dialog-color)
  (initget "Color None TrueColor")
  (setq choice
    (getkword
      (strcat
        "\nBackground [Color/None/TrueColor] <Color> (current: "
        (alc--background-color-name *alc-background-color*)
        "): ")))
  (cond
    ((equal choice "None")
      (setq color 0))
    ((equal choice "TrueColor")
      (setq color 256))
    (T
      (setq dialog-color
        (if (alc--valid-color-p *alc-background-color*)
          *alc-background-color*
          9))
      (setq color (acad_colordlg dialog-color nil)))
  )
  (if color
    (progn
      (setq *alc-background-color* color)
      (alc--save-settings)
      (prompt
        (strcat
          "\nSelected background: "
          (alc--background-color-name color)))
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
    (initget "Thickness Pattern Color Background Scale Angle Exit")
    (setq choice
      (getkword
        "\nSettings [Thickness/Pattern/Color/Background/Scale/Angle/Exit] <Exit>: "))
    (cond
      ((equal choice "Thickness") (alc--set-thickness))
      ((equal choice "Pattern") (alc--set-pattern))
      ((equal choice "Color") (alc--set-color))
      ((equal choice "Background") (alc--set-background-color))
      ((equal choice "Scale") (alc--set-scale))
      ((equal choice "Angle") (alc--set-angle))
      (T (setq choice "Exit"))
    )
  )
  (princ)
)
