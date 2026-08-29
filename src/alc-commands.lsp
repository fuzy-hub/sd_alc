;;; ALCWALL v2.5.0 - commands module

;;; --------------------------------------------------------------------------
;;; Public commands

(defun c:ALCSET ()
  (vl-load-com)
  (alc--ensure-settings)
  (alc--settings)
  (princ)
)

(defun alc--run-command
  (loop-function command-name
    / *error* document document-result old-cmdecho undo-open message)
  (vl-load-com)
  (alc--ensure-settings)
  (setq *alc-temp-entities* nil
        old-cmdecho (getvar "CMDECHO")
        undo-open nil)

  (defun *error* (message)
    (alc--cleanup-temp)
    (if old-cmdecho
      (setvar "CMDECHO" old-cmdecho)
    )
    (if undo-open
      (progn
        (vl-catch-all-apply 'vla-EndUndoMark (list document))
        (setq undo-open nil)
      )
    )
    (if (and message
             (not (wcmatch (strcase message) "*BREAK*,*CANCEL*,*EXIT*")))
      (prompt (strcat "\n" command-name " error: " message))
    )
    (princ)
  )

  (setvar "CMDECHO" 0)
  (setq document-result
    (vl-catch-all-apply 'alc--get-active-document nil))
  (if (not (vl-catch-all-error-p document-result))
    (setq document document-result)
  )
  (if (and document
           (not
        (vl-catch-all-error-p
          (vl-catch-all-apply 'vla-StartUndoMark (list document)))))
    (setq undo-open T)
  )

  (apply loop-function '())
  (alc--cleanup-temp)
  (setvar "CMDECHO" old-cmdecho)
  (if undo-open
    (progn
      (vl-catch-all-apply 'vla-EndUndoMark (list document))
      (setq undo-open nil)
    )
  )
  (princ)
)

(defun c:ALCWALL ()
  (alc--run-command 'alc--wall-loop "ALCWALL")
  (princ)
)

(defun c:ALCCENTRAL ()
  (alc--run-command 'alc--central-loop "ALCCENTRAL")
  (princ)
)

(defun c:ALCDOOR ()
  (alc--run-command 'alc--door-loop "ALCDOOR")
  (princ)
)

(defun c:ALCLT ()
  (alc--run-command 'alc--lintel-loop "ALCLT")
  (princ)
)

(defun c:ALCGT ()
  (alc--run-command 'alc--wall-tie-loop "ALCGT")
  (princ)
)

(defun c:ALCGTS ()
  (alc--run-command 'alc--wall-tie-settings-loop "ALCGTS")
  (princ)
)

(defun c:ALCTK ()
  (alc--run-command 'alc--stat-loop "ALCTK")
  (princ)
)

(defun c:ALCTKC ()
  (alc--run-command 'alc--door-stat-loop "ALCTKC")
  (princ)
)

(defun c:TKDIM ()
  (alc--run-command 'alc--dimension-stat-loop "TKDIM")
  (princ)
)

(defun c:TKCOUNT ()
  (alc--run-command 'alc--count-loop "TKCOUNT")
  (princ)
)

(defun c:TKMS ()
  (alc--run-command 'alc--tkms-loop "TKMS")
  (princ)
)

(defun c:TKALIGN ()
  (alc--run-command 'alc--text-align-loop "TKALIGN")
  (princ)
)

(defun c:ALCDIM (/ selection entity-data style-name document dim-style result)
  (vl-load-com)
  (if (setq selection (entsel "\nSelect dimension to make its style current: "))
    (progn
      (setq entity-data (entget (car selection)))
      (cond
        ((/= (cdr (assoc 0 entity-data)) "DIMENSION")
          (prompt "\nSelected object is not a dimension."))
        ((not (setq style-name (cdr (assoc 3 entity-data))))
          (prompt "\nCannot determine the selected dimension style."))
        (T
          (setq document
                  (vla-get-ActiveDocument (vlax-get-acad-object))
                dim-style
                  (vl-catch-all-apply
                    'vla-Item
                    (list (vla-get-DimStyles document) style-name)))
          (if (vl-catch-all-error-p dim-style)
            (prompt
              (strcat "\nCannot find dimension style: " style-name "."))
            (progn
              (setq result
                (vl-catch-all-apply
                  'vla-put-ActiveDimStyle (list document dim-style)))
              (if (vl-catch-all-error-p result)
                (prompt
                  (strcat
                    "\nCannot set current dimension style: "
                    (vl-catch-all-error-message result)))
                (prompt
                  (strcat "\nCurrent dimension style: " style-name "."))
              )
            )
          )
        )
      )
    )
  )
  (princ)
)

(princ
  "\nALCWALL loaded. Commands: ALCWALL, ALCCENTRAL, ALCDOOR, ALCLT, ALCGT, ALCGTS, ALCTK, ALCTKC, TKDIM, TKCOUNT, TKMS, TKALIGN, ALCDIM, ALCSET.")
(princ)
