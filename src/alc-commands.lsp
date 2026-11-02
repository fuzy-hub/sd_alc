(setq *alc-module-version* "3.4.5")
;;; ALCWALL v3.4.5 - commands module

;;; --------------------------------------------------------------------------
;;; Public commands

;; Reloading a renamed command does not remove its old definition in AutoLISP.
(setq c:ALCCUT20 nil)

(defun c:ALCSET ()
  (vl-load-com)
  (if (alc--ready-p) (progn (alc--ensure-settings) (alc--settings)))
  (princ)
)

(defun c:ALCS () (c:ALCSET))
(defun c:ALSC () (c:ALCSET))

(defun alc--wall-layer-name (name / prefix)
  (setq prefix "ALC_wall_" name (vl-string-trim " \t" name))
  (if (/= name "")
    (if (= (strcase (substr name 1 (strlen prefix))) (strcase prefix))
      (strcat prefix (substr name (1+ (strlen prefix))))
      (strcat prefix name))))

(defun alc--pick-wall-layer-color () (acad_colordlg 7 nil))

(defun alc--activate-new-wall-layer (name)
  (setvar "CLAYER" name)
  ;; Blank layer-name input targets only the new current layer, including
  ;; names containing characters that -LAYER would otherwise treat as patterns.
  (command-s "_.-LAYER" "_Transparency" "50" "" "")
  T)

(defun alc--create-current-wall-layer (name color / layer result old-layer)
  (setq old-layer (getvar "CLAYER"))
  (if (and name (snvalid name 0) (<= (strlen name) 255)
           (not (tblsearch "LAYER" name))
           (numberp color) (= color (fix color)) (<= 1 color 255)
           (entmake (list '(0 . "LAYER") '(100 . "AcDbSymbolTableRecord")
             '(100 . "AcDbLayerTableRecord") (cons 2 name) '(70 . 0)
             (cons 62 color) '(6 . "Continuous"))))
    (progn
      (setq layer (tblobjname "LAYER" name)
            result (vl-catch-all-apply 'alc--activate-new-wall-layer (list name)))
      (if (vl-catch-all-error-p result)
        (progn (setvar "CLAYER" old-layer)
          (vl-catch-all-apply 'vla-Delete (list (vlax-ename->vla-object layer))) nil)
        T))))

(defun alc--wall-layer-loop (/ input name color done)
  (while (not done)
    (setq input (getstring T "\nTen layer (sau ALC_wall_) <Enter huy>: ")
          name (alc--wall-layer-name input))
    (cond
      ((not name) (setq done T))
      ((or (= (strcase name) "ALC_WALL_") (not (snvalid name 0)) (> (strlen name) 255))
        (prompt "\nTen layer khong hop le. Hay nhap ten khac."))
      ((tblsearch "LAYER" name)
        (prompt "\nLayer da ton tai. Hay nhap ten moi."))
      (T
        (setq color (alc--pick-wall-layer-color) done T)
        (if color
          (if (alc--create-current-wall-layer name color)
            (prompt (strcat "\nDa tao va dat current: " name))
            (prompt "\nKhong the tao layer moi.")))))))

(defun c:ALCLAYER ()
  (alc--run-command 'alc--wall-layer-loop "ALCLAYER")
  (princ))

(defun alc--assign-width (name / record value i ch digits)
  (setq record (cdr (assoc "ALC_LAYER_WIDTH"
    (cdr (assoc -3 (entget (tblobjname "LAYER" name) '("ALC_LAYER_WIDTH"))))))
        value (cdr (assoc 1040 record)))
  (if (and (numberp value) (>= value 0.0)) value
    (progn
      (setq i (strlen name) digits "")
      (while (and (> i 0) (setq ch (substr name i 1))
                  (or (and (>= (ascii ch) 48) (<= (ascii ch) 57)) (= ch ".")))
        (setq digits (strcat ch digits) i (1- i)))
      (if (and (/= digits "")
               (or (= i 0) (member (substr name i 1) '("_" " " "-")))
               (setq value (distof digits 2)) (>= value 0.0)) value))))

(defun alc--assign-catalog (/ data names name)
  (setq data (tblnext "LAYER" T))
  (while data
    (setq name (cdr (assoc 2 data)))
    (if (and (= (substr (strcase name) 1 3) "ALC")
             (not (vl-string-search "|" name))
             (= 0 (logand 16 (cdr (assoc 70 data)))))
      (setq names (cons name names)))
    (setq data (tblnext "LAYER")))
  (acad_strlsort names))

(defun alc--assign-load-ui (/ old-filedia result)
  (setq old-filedia (getvar "FILEDIA"))
  (setvar "FILEDIA" 0)
  (setq result (vl-catch-all-apply 'command-s
    (list "_.NETLOAD" (strcat *alc-resource-root* "/src/alc-assign-ui.dll"))))
  (setvar "FILEDIA" old-filedia)
  (if (vl-catch-all-error-p result)
    (vl-exit-with-error (vl-catch-all-error-message result))))

(defun alc--choose-assign-layer (catalog / args name value result)
  ;; The native keyboard dialog receives digits immediately, unlike DCL edit boxes.
  (if (not (car (atoms-family 1 '("ALC-ASSIGN-UI"))))
    (alc--assign-load-ui))
  (setq args (list (getvar "CLAYER")))
  (foreach name catalog
    (setq value (alc--assign-width name)
          args (append args (list name (if value (float value) -1.0)))))
  (setq result (vl-catch-all-apply 'ALC-ASSIGN-UI args))
  (if (vl-catch-all-error-p result)
    (vl-exit-with-error (strcat "Khong mo duoc bang chon VVA: " (vl-catch-all-error-message result)))
    result))

(defun alc--assign-write (name width / data)
  (setvar "CLAYER" name)
  (setvar "PLINEWID" width)
  (regapp "ALC_LAYER_WIDTH")
  (setq data (entget (tblobjname "LAYER" name) '("ALC_LAYER_WIDTH")))
  (if (assoc -3 data) (setq data (vl-remove (assoc -3 data) data)))
  (if (entmod (append data
    (list (list -3 (list "ALC_LAYER_WIDTH" (cons 1040 (float width))))))) T))

(defun alc--apply-assign-layer (name width / data old-layer old-width result)
  (setq data (tblsearch "LAYER" name))
  (if (and data (= (substr (strcase name) 1 3) "ALC")
           (= 0 (logand 17 (cdr (assoc 70 data))))
           (not (vl-string-search "|" name)) (numberp width) (>= width 0.0))
    (progn
      (setq old-layer (getvar "CLAYER") old-width (getvar "PLINEWID")
            result (vl-catch-all-apply 'alc--assign-write (list name width)))
      (if (or (not result) (vl-catch-all-error-p result))
        (progn (setvar "CLAYER" old-layer) (setvar "PLINEWID" old-width) nil) T))))

(defun alc--assign-loop (/ catalog choice)
  (if (setq catalog (alc--assign-catalog))
    (if (setq choice (alc--choose-assign-layer catalog))
      (if (alc--apply-assign-layer (car choice) (cadr choice))
        (prompt (strcat "\nCurrent: " (car choice) "; PLINEWID = " (rtos (cadr choice) 2 3)))
        (prompt "\nKhong the chuyen layer/PLINEWID.")))
    (prompt "\nKhong co layer bat dau bang ALC trong ban ve.")))

(defun c:ALCASSIGN () (alc--run-command 'alc--assign-loop "ALCASSIGN") (princ))

(defun alc--match-corners (points / remaining previous point next ua ub result)
  (setq points (alc--clean-polygon-points points) remaining points previous (last points))
  (foreach point points
    (setq next (if (cdr remaining) (cadr remaining) (car points))
          ua (alc--unit-vector (alc--vector-subtract point previous))
          ub (alc--unit-vector (alc--vector-subtract next point)))
    (if (not (and ua ub (equal ua ub 1e-7))) (setq result (cons point result)))
    (setq previous point remaining (cdr remaining)))
  (reverse result))

(defun alc--match-entry (wall / data layer tagged preferred points a b length-a length-b width caps valid pair)
  ;; Read only the selected boundary. No selection sets, hatch scan, or neighbors.
  (setq data (entget wall) layer (cdr (assoc 8 data)) valid (alc--closed-lwpolyline-p wall)
        tagged (alc--wall-tag-width wall))
  (foreach pair data
    (if (and (= (car pair) 42) (not (equal (cdr pair) 0.0 1e-10))) (setq valid nil)))
  (if (and valid
           (or tagged (= (strcase layer) "0. TUONG ALC") (= (substr (strcase layer) 1 3) "ALC"))
           (= (length (setq points (alc--match-corners (alc--lwp-points wall)))) 4))
    (progn
      (setq a (alc--vector-subtract (cadr points) (car points))
            b (alc--vector-subtract (caddr points) (cadr points))
            length-a (alc--vector-length a) length-b (alc--vector-length b)
            preferred (if tagged tagged (alc--assign-width layer)))
      (if (and (> length-a 1e-6) (> length-b 1e-6)
               (equal a (alc--vector-subtract (caddr points) (last points)) 1e-5)
               (equal b (alc--vector-subtract (last points) (car points)) 1e-5)
               (< (abs (alc--vector-dot (alc--unit-vector a) (alc--unit-vector b))) 1e-7))
        (progn
          (setq width (cond
            ((and preferred (or (equal preferred length-a 1e-4) (equal preferred length-b 1e-4))) preferred)
            (tagged nil)
            (T (min length-a length-b))))
          (if width
            (progn
              (setq caps (if (equal width length-a 1e-4)
                (list (alc--vector-scale (alc--vector-add (car points) (cadr points)) 0.5)
                      (alc--vector-scale (alc--vector-add (caddr points) (last points)) 0.5))
                (list (alc--vector-scale (alc--vector-add (car points) (last points)) 0.5)
                      (alc--vector-scale (alc--vector-add (cadr points) (caddr points)) 0.5))))
              (list width (car caps) (cadr caps)))))))))

(defun alc--match-output-entry (entity / data valid pair points width)
  (setq data (entget entity) valid T)
  (if (and (= (cdr (assoc 0 data)) "LWPOLYLINE")
           (= (cdr (assoc 90 data)) 2)
           (= (logand (cdr (assoc 70 data)) 1) 0)
           (setq width (cdr (assoc 43 data))) (> width 0.0))
    (progn
      (foreach pair data
        (if (or (and (= (car pair) 42) (not (equal (cdr pair) 0.0 1e-10)))
                (and (member (car pair) '(40 41))
                     (not (equal (cdr pair) 0.0 1e-10))
                     (not (equal (cdr pair) width 1e-5)))) (setq valid nil)))
      (if (and valid (setq points (alc--lwp-points entity)))
        ;; Reactor references precede the actual owner in entget data.
        (list entity (cdr (assoc 330 (reverse data))) width (car points) (cadr points)
          (if (assoc 210 data) (cdr (assoc 210 data)) '(0.0 0.0 1.0)))))))

(defun alc--match-existing-outputs (/ selection index entry entries)
  ;; One candidate scan per command, including older untagged VVMATCH output.
  (if (setq selection (ssget "_X" (list '(0 . "LWPOLYLINE") '(90 . 2)
      (cons 410 (if (= (getvar "CVPORT") 1) (getvar "CTAB") "Model")))))
    (progn
      (setq index 0)
      (repeat (sslength selection)
        (setq entry (alc--match-output-entry (ssname selection index)) index (1+ index))
        (if entry (setq entries (cons entry entries))))))
  entries)

(defun alc--match-existing-p (wall entry / candidates owner normal found candidate)
  (setq candidates (if (and (boundp '*alc-match-index-ready*) *alc-match-index-ready*)
                     *alc-match-outputs* (alc--match-existing-outputs))
        owner (cdr (assoc 330 (reverse (entget wall))))
        normal (cdr (assoc 210 (entget wall))))
  (if (not normal) (setq normal '(0.0 0.0 1.0)))
  (while (and candidates (not found))
    (setq candidate (car candidates) candidates (cdr candidates))
    (if (and (equal owner (cadr candidate))
             (equal (car entry) (caddr candidate) 1e-5)
             (equal (abs (alc--vector-dot normal (nth 5 candidate))) 1.0 1e-7)
             (or (and (equal (cadr entry) (nth 3 candidate) 1e-5)
                      (equal (caddr entry) (nth 4 candidate) 1e-5))
                 (and (equal (cadr entry) (nth 4 candidate) 1e-5)
                      (equal (caddr entry) (nth 3 candidate) 1e-5))))
      (setq found T)))
  found)

(defun alc--match-wall (wall / layer entry normal output data)
  (setq layer (getvar "CLAYER"))
  (cond
    ((not (setq entry (alc--match-entry wall))) nil)
    ((alc--match-existing-p wall entry) 'existing)
    ((not (alc--layer-locked-p layer))
    (progn
      (setq normal (cdr (assoc 210 (entget wall)))
            output (alc--track-temp (alc--create-lwpolyline-wcs-on-layer
              (list (cadr entry) (caddr entry)) nil (if normal normal '(0.0 0.0 1.0)) layer)))
      (if output
        (progn
          (setq data (entget output))
          (if (entmod (if (assoc 43 data)
              (subst (cons 43 (car entry)) (assoc 43 data) data)
              (append data (list (cons 43 (car entry))))))
            (progn
              (vla-put-Color (vlax-ename->vla-object output) 256)
              (vla-put-EntityTransparency (vlax-ename->vla-object output) "ByLayer")
              (if (and (boundp '*alc-match-index-ready*) *alc-match-index-ready*)
                (setq *alc-match-outputs* (cons (alc--match-output-entry output) *alc-match-outputs*)))
              (alc--untrack-temp output)
              (prompt (strcat "\nDa tao pline tim doan tuong, width=" (rtos (car entry) 2 3)
                ", dai=" (rtos (distance (cadr entry) (caddr entry)) 2 3) " mm."))
              output)
            (progn (alc--cleanup-temp) nil))))))))

(defun alc--match-select ()
  (prompt "\nPick hoac quet chon cac tuong ALC thang <Enter xac nhan>: ")
  (ssget '((0 . "LWPOLYLINE,HATCH"))))
(defun alc--match-create-loop (/ wall result)
  (foreach wall (reverse *alc-match-pending*)
    (setq result (alc--match-wall wall))
    (cond
      ((eq result 'existing) (setq skipped (1+ skipped)))
      (result (setq count (1+ count)))
      (T (prompt "\nKhong the tao pline tim; layer current can mo khoa.")))))

(defun alc--match-loop (/ selection index wall entry seen count skipped
    *alc-match-index-ready* *alc-match-outputs* *alc-match-pending*)
  (setq count 0 skipped 0)
  (if (setq selection (alc--match-select))
    (progn
      (setq index 0 *alc-match-outputs* (alc--match-existing-outputs) *alc-match-index-ready* T)
      (repeat (sslength selection)
        (setq wall (alc--resolve-wall (ssname selection index))
              index (1+ index))
        (cond
          ((and wall (member wall seen)) nil)
          ((and wall (setq entry (alc--match-entry wall)) (alc--match-existing-p wall entry))
            (setq seen (cons wall seen) skipped (1+ skipped)))
          ((and wall entry)
            (setq seen (cons wall seen) *alc-match-pending* (cons wall *alc-match-pending*)))
          (T (prompt "\nBo qua doi tuong khong phai tuong ALC thang hop le."))))
      ;; Selection and duplicate checks are read-only: do not add empty Undo groups.
      (if *alc-match-pending*
        (if (alc--layer-locked-p (getvar "CLAYER"))
          (prompt "\nKhong the tao pline tim tren layer current bi khoa.")
          (alc--run-command 'alc--match-create-loop "VVMATCH")))))
  (prompt (strcat "\nDa tao " (itoa count) " pline tim tuong; bo qua "
    (itoa skipped) " tuong da co pline tim.")))
(defun c:VVMATCH (/ result message)
  (if (alc--ready-p)
    (progn
      (setq result (vl-catch-all-apply 'alc--match-loop nil))
      (if (vl-catch-all-error-p result)
        (progn
          (setq message (vl-catch-all-error-message result))
          (if (not (wcmatch (strcase message) "*BREAK*,*CANCEL*,*EXIT*"))
            (prompt (strcat "\nVVMATCH error: " message)))))))
  (princ))

(defun alc--filter-select-objects (/ previous result)
  ;; ssget otherwise consumes an existing Pickfirst set without prompting.
  (setq previous (cadr (ssgetfirst)))
  (sssetfirst nil nil)
  (prompt "\nChon cac doi tuong can loc theo layer: ")
  (setq result (vl-catch-all-apply 'ssget nil))
  (if (or (not result) (vl-catch-all-error-p result))
    (sssetfirst nil previous))
  (if (vl-catch-all-error-p result)
    (vl-exit-with-error (vl-catch-all-error-message result)) result))

(defun alc--filter-loop (/ layers source matched)
  (if (setq layers (alc--stat-choose-layers))
    (if (setq source (alc--filter-select-objects))
      (progn
        (setq matched (alc--stat-filter-selection source layers))
        (prompt (strcat "\nDa chon " (itoa (if matched (sslength matched) 0))
          " doi tuong thuoc bo loc layer."))
        ;; A wrapped nil means a completed selection with no matches: clear it.
        (list matched)))))

(defun c:VVFILTER (/ result message)
  ;; Read-only selection command: do not start an Undo group or modify entities.
  (if (alc--ready-p)
    (progn
      (setq result (vl-catch-all-apply 'alc--filter-loop nil))
      (if (vl-catch-all-error-p result)
        (progn
          (setq message (vl-catch-all-error-message result))
          (if (not (wcmatch (strcase message) "*BREAK*,*CANCEL*,*EXIT*"))
            (prompt (strcat "\nVVFILTER error: " message))))
        (if result (sssetfirst nil (car result))))))
  (princ))

(defun alc--run-command-unsafe
  (loop-function command-name
    / *error* document document-result old-cmdecho undo-open message)
  (vl-load-com)
  (alc--ensure-settings)
  (setq *alc-temp-entities* nil
        old-cmdecho (getvar "CMDECHO")
        undo-open nil)

  (defun *error* (message)
    (alc--end-hatch-index)
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

  (if (alc--ready-p) (apply loop-function '()))
  (alc--end-hatch-index)
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

(defun c:VV () (c:ALCWALL))

(defun c:ALCCENTRAL ()
  (alc--run-command 'alc--central-loop "ALCCENTRAL")
  (princ)
)

(defun c:VVC () (c:ALCCENTRAL))

(defun c:ALCDOOR ()
  (alc--run-command 'alc--door-loop "ALCDOOR")
  (princ)
)

(defun c:ALCTRIM ()
  (alc--run-command 'alc--trim-loop "ALCTRIM")
  (princ)
)

(defun c:ALCXTEND ()
  (alc--run-command 'alc--xtend-loop "ALCXTEND")
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

(defun c:ALCTK (/ result message)
  (if (alc--ready-p)
    (progn
      (setq result (vl-catch-all-apply 'alc--stat-command nil))
      (if (vl-catch-all-error-p result)
        (progn
          (setq message (vl-catch-all-error-message result))
          (if (not (wcmatch (strcase message) "*BREAK*,*CANCEL*,*EXIT*"))
            (prompt (strcat "\nALCTK error: " message)))))))
  (princ))

(defun c:VVSUMTABLE ()
  (alc--run-command 'alc--sumtable-loop "VVSUMTABLE")
  (princ))

(defun c:ALCTKT ()
  (alc--run-command 'alc--wall-type-stat-loop "ALCTKT")
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
  (if (and (alc--ready-p) (setq selection (entsel "\nSelect dimension to make its style current: ")))
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

;; Every public ALCxxx command has a matching VVxxx entry point.
(defun c:VVSET () (c:ALCSET))
(defun c:VVLAYER () (c:ALCLAYER))
(defun c:VVASSIGN () (c:ALCASSIGN))
(defun c:VVA () (c:ALCASSIGN))
(defun c:VVS () (c:ALCS))
(defun c:VVWALL () (c:ALCWALL))
(defun c:VVCENTRAL () (c:ALCCENTRAL))
(defun c:VVDOOR () (c:ALCDOOR))
(defun c:VVTRIM () (c:ALCTRIM))
(defun c:VVXTEND () (c:ALCXTEND))
(defun c:VVLT () (c:ALCLT))
(defun c:VVGT () (c:ALCGT))
(defun c:VVGTS () (c:ALCGTS))
(defun c:VVTK () (c:ALCTK))
(defun c:VVTKT () (c:ALCTKT))
(defun c:VVTKC () (c:ALCTKC))
(defun c:VVDIM () (c:ALCDIM))

(princ
  "\nALCWALL loaded. Commands: ALCWALL, VV, ALCCENTRAL, VVC, ALCDOOR, ALCTRIM, ALCXTEND, ALCLT, ALCGT, ALCGTS, ALCLAYER, ALCASSIGN, VVA, VVFILTER, VVMATCH, VVSUMTABLE, ALCTK, ALCTKT, ALCTKC, TKDIM, TKCOUNT, TKMS, TKALIGN, ALCDIM, ALCSET, ALCS, ALSC. ALCxxx aliases: VVxxx.")
(princ)

(defun alc--run-command (fn name) (if (alc--ready-p) (alc--run-command-unsafe fn name)))
