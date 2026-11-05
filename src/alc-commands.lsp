(setq *alc-module-version* "3.4.6")
;;; ALCWALL v3.4.6 - commands module

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

;;; Recover two parallel offset sides between opposite end caps. Every side
;;; segment must be parallel to the recovered centerline and exactly width
;;; apart. This rejects tapered walls and arbitrary orthogonal polygons.
(defun alc--match-bent-path (points cap normal / n half k side-a side-b centers width valid a b c d u delta)
  (setq n (length points) half (/ n 2) k 0 valid T)
  (repeat half
    (setq a (nth (rem (+ cap 1 k) n) points)
          b (nth (rem (+ cap n (- k)) n) points)
          side-a (append side-a (list a)) side-b (append side-b (list b))
          centers (append centers (list (alc--vector-scale (alc--vector-add a b) 0.5)))
          k (1+ k)))
  (setq width (distance (car side-a) (car side-b)))
  (if (not (and (> width 1e-6)
                (equal width (distance (last side-a) (last side-b)) 1e-5)
                (alc--standard-wall-path centers normal))) (setq valid nil))
  (setq k 0)
  (repeat (1- half)
    (setq a (nth k side-a) b (nth (1+ k) side-a)
          c (nth k side-b) d (nth (1+ k) side-b)
          u (alc--unit-vector (alc--vector-subtract (nth (1+ k) centers) (nth k centers)))
          delta (alc--vector-subtract c a))
    (if (not (and u
           (equal u (alc--unit-vector (alc--vector-subtract b a)) 1e-7)
           (equal u (alc--unit-vector (alc--vector-subtract d c)) 1e-7)
           (equal (alc--vector-length
             (alc--vector-subtract delta (alc--vector-scale u (alc--vector-dot delta u)))) width 1e-5)))
      (setq valid nil))
    (setq k (1+ k)))
  (if (and valid
       (< (abs (alc--vector-dot (alc--vector-subtract (car side-a) (car side-b))
            (alc--unit-vector (alc--vector-subtract (cadr centers) (car centers))))) 1e-5)
       (< (abs (alc--vector-dot (alc--vector-subtract (last side-a) (last side-b))
            (alc--unit-vector (alc--vector-subtract (last centers) (nth (- half 2) centers))))) 1e-5))
    (cons width centers)))

(defun alc--match-split-path (path / width points count priority k a b u start end entries xaxis ax bx local-a local-b)
  (setq width (car path) points (cdr path) count (1- (length points)) priority 1)
  ;; U: the joining segment owns both corners. L: prefer the branch closest
  ;; to the current UCS X axis, regardless of polygon winding/start vertex.
  (if (= count 2)
    (progn
      (setq xaxis (trans '(1.0 0.0 0.0) 1 0 T)
            a (alc--unit-vector (alc--vector-subtract (cadr points) (car points)))
            b (alc--unit-vector (alc--vector-subtract (caddr points) (cadr points))))
      (setq ax (abs (alc--vector-dot a xaxis)) bx (abs (alc--vector-dot b xaxis))
            local-a (trans a 0 1 T) local-b (trans b 0 1 T))
      ;; At an exact 45-degree tie prefer the positive-slope undirected axis.
      (setq priority
        (if (if (equal ax bx 1e-7)
              (>= (* (car local-a) (cadr local-a)) (* (car local-b) (cadr local-b)))
              (> ax bx)) 0 1))))
  (setq k 0)
  (repeat count
    (setq a (nth k points) b (nth (1+ k) points)
          u (alc--unit-vector (alc--vector-subtract b a)) start a end b)
    (if (> k 0)
      (setq start (alc--vector-add a (alc--vector-scale u (* (if (= k priority) -0.5 0.5) width)))))
    (if (< k (1- count))
      (setq end (alc--vector-add b (alc--vector-scale u (* (if (= k priority) 0.5 -0.5) width)))))
    (if (> (alc--vector-dot (alc--vector-subtract end start) u) 1e-6)
      (setq entries (append entries (list (list width start end))))
      (setq entries (append entries (list nil))))
    (setq k (1+ k)))
  (if (not (member nil entries)) entries))

(defun alc--match-entries (wall / straight data points normal valid pair cap path found)
  (if (setq straight (alc--match-entry wall)) (list straight)
    (progn
      (setq data (entget wall) valid (alc--closed-lwpolyline-p wall)
            normal (if (assoc 210 data) (cdr (assoc 210 data)) '(0.0 0.0 1.0)))
      (foreach pair data
        (if (and (= (car pair) 42) (not (equal (cdr pair) 0.0 1e-10))) (setq valid nil)))
      (if (and valid
           (or (alc--wall-tag-width wall) (= (strcase (cdr (assoc 8 data))) "0. TUONG ALC")
               (= (substr (strcase (cdr (assoc 8 data))) 1 3) "ALC"))
           (member (length (setq points (alc--match-corners (alc--lwp-points wall)))) '(6 8))
           (alc--valid-polygon-p points normal))
        (progn
          (setq cap 0)
          (repeat (/ (length points) 2)
            (if (setq path (alc--match-bent-path points cap normal))
              (setq found (cons path found)))
            (setq cap (1+ cap)))
          ;; Ambiguous geometry is skipped rather than choosing an arbitrary axis.
          (if (= (length found) 1) (alc--match-split-path (car found))))))))

(defun alc--match-all-existing-p (wall entries / valid entry)
  (setq valid (and entries T))
  (foreach entry entries (if (not (alc--match-existing-p wall entry)) (setq valid nil)))
  valid)

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

(defun alc--match-segment (wall entry / layer normal output data)
  (setq layer (getvar "CLAYER"))
  (cond
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
              (prompt (strcat "\nDa tao pline tim doan tuong, width=" (rtos (car entry) 2 3)
                ", dai=" (rtos (distance (cadr entry) (caddr entry)) 2 3) " mm."))
              output)
            (progn (entdel output) (alc--untrack-temp output) nil))))))))

(defun alc--match-wall (wall / entries entry result output created old-index old-temps)
  (setq entries (alc--match-entries wall) old-index *alc-match-outputs* old-temps *alc-temp-entities*)
  (if entries
    (progn
      (setq result (vl-catch-all-apply
        '(lambda ()
          (foreach entry entries
            (setq output (alc--match-segment wall entry))
            (cond ((eq output 'existing) nil)
                  (output (setq created (cons output created)))
                  (T (vl-exit-with-error "Khong tao duoc day du pline tim tuong."))))
          (if created (car created) 'existing)) nil))
      (if (vl-catch-all-error-p result)
        (progn
          (foreach output *alc-temp-entities*
            (if (not (member output old-temps))
              (progn (if (entget output) (entdel output)) (alc--untrack-temp output))))
          (setq *alc-match-outputs* old-index)
          (prompt (strcat "\n" (vl-catch-all-error-message result))) nil)
        (progn
          (foreach output created (alc--untrack-temp output))
          (setq *alc-match-created-count* (+ (if (numberp *alc-match-created-count*) *alc-match-created-count* 0) (length created)))
          result)))))

(defun alc--match-select ()
  (prompt "\nPick hoac quet chon cac tuong ALC thang/L/U <Enter xac nhan>: ")
  (ssget '((0 . "LWPOLYLINE,HATCH"))))
;;; Door matching is selection-scoped. Records are (source-wall entry);
;;; jobs are (representative-wall joined-entry member-records door-endpoints).
(defun alc--match-collinear-p (left right / a b u delta na nb da db)
  (setq a (cadr left) b (cadr right)
        da (entget (car left)) db (entget (car right))
        na (cdr (assoc 210 da)) nb (cdr (assoc 210 db))
        u (alc--unit-vector (alc--vector-subtract (caddr a) (cadr a)))
        delta (alc--vector-subtract (cadr b) (cadr a)))
  (if (not na) (setq na '(0.0 0.0 1.0)))
  (if (not nb) (setq nb '(0.0 0.0 1.0)))
  (and (equal (car a) (car b) 1e-5)
       (equal (cdr (assoc 330 (reverse da))) (cdr (assoc 330 (reverse db))))
       (equal (abs (alc--vector-dot na nb)) 1.0 1e-7)
       (equal (abs (alc--vector-dot u
         (alc--unit-vector (alc--vector-subtract (caddr b) (cadr b))))) 1.0 1e-7)
       (< (alc--vector-length (alc--vector-subtract delta
            (alc--vector-scale u (alc--vector-dot delta u)))) 1e-5)))

(defun alc--match-jobs (records / seed remaining group record u origin intervals a b lo hi
    interval sorted job jobs gap start end blocked cursor)
  (while records
    (setq seed (car records) remaining nil group (list seed))
    (foreach record (cdr records)
      (if (alc--match-collinear-p seed record)
        (setq group (cons record group)) (setq remaining (cons record remaining))))
    (setq records (reverse remaining) origin (cadr (cadr seed))
          u (alc--unit-vector (alc--vector-subtract (caddr (cadr seed)) origin)))
    ;; Canonical direction makes ordering and dimension side independent of picks.
    (if (or (< (car u) -1e-7)
            (and (< (abs (car u)) 1e-7) (< (cadr u) -1e-7))
            (and (< (abs (car u)) 1e-7) (< (abs (cadr u)) 1e-7) (< (caddr u) 0.0)))
      (setq u (alc--vector-scale u -1.0)))
    (setq intervals nil)
    (foreach record group
      (setq a (cadr (cadr record)) b (caddr (cadr record))
            lo (alc--vector-dot (alc--vector-subtract a origin) u)
            hi (alc--vector-dot (alc--vector-subtract b origin) u))
      (if (> lo hi) (setq intervals (cons (list hi lo record b a) intervals))
        (setq intervals (cons (list lo hi record a b) intervals))))
    (setq sorted (mapcar '(lambda (i) (nth i intervals))
      (vl-sort-i intervals '(lambda (a b) (if (equal (car a) (car b) 1e-7)
        (< (cadr a) (cadr b)) (< (car a) (car b)))))))
    (setq job nil end nil blocked nil cursor nil)
    (foreach interval sorted
      (if (and cursor (< (car interval) (- cursor 1e-5))) (setq blocked T))
      (setq cursor (if cursor (max cursor (cadr interval)) (cadr interval))))
    (foreach interval sorted
      (setq record (nth 2 interval) gap (if end (- (car interval) end)))
      (if (and job (not blocked) (>= gap (- 900.0 1e-5)) (<= gap (+ 2000.0 1e-5)))
        (setq job (list (car job)
          (list (car (cadr job)) (cadr (cadr job)) (nth 4 interval))
          (append (caddr job) (list record))
          (append (cadddr job) (list (list (caddr (cadr job)) (nth 3 interval))))))
        (progn
          (if job (setq jobs (cons job jobs)))
          (setq job (list (car record)
            (list (car (cadr record)) (nth 3 interval) (nth 4 interval)) (list record) nil))))
      (setq end (cadr interval)))
    (if job (setq jobs (cons job jobs))))
  (reverse jobs))

(defun alc--match-door-dimensions (/ selection i entity data result)
  (if (setq selection (ssget "_X" (list '(0 . "DIMENSION")
        (cons 410 (if (= (getvar "CVPORT") 1) (getvar "CTAB") "Model"))
        '(-3 ("ALC_VVM_DOOR")))))
    (progn
      (setq i 0)
      (repeat (sslength selection)
        (setq entity (ssname selection i) data (entget entity) i (1+ i))
        (if (and (= (logand (cdr (assoc 70 data)) 7) 1) (assoc 13 data) (assoc 14 data))
          (setq result (cons (list entity (cdr (assoc 13 data)) (cdr (assoc 14 data))) result))))))
  result)

(defun alc--match-door-dim-p (gap dimensions wall / found dim data source normal other)
  (setq source (entget wall) normal (cdr (assoc 210 source)))
  (if (not normal) (setq normal '(0.0 0.0 1.0)))
  (foreach dim dimensions
    (setq data (entget (car dim)) other (cdr (assoc 210 data)))
    (if (not other) (setq other '(0.0 0.0 1.0)))
    (if (and data
      (equal (cdr (assoc 330 (reverse data))) (cdr (assoc 330 (reverse source))))
      (equal (abs (alc--vector-dot normal other)) 1.0 1e-7)
      (or (and (equal (car gap) (cadr dim) 1e-5) (equal (cadr gap) (caddr dim) 1e-5))
          (and (equal (car gap) (caddr dim) 1e-5) (equal (cadr gap) (cadr dim) 1e-5))))
      (setq found T)))
  found)

(defun alc--match-add-door-dim (wall width gap / normal u side offset point dim entity data)
  (setq normal (cdr (assoc 210 (entget wall))))
  (if (not normal) (setq normal '(0.0 0.0 1.0)))
  (setq u (alc--unit-vector (alc--vector-subtract (cadr gap) (car gap)))
        side (list (- (* (cadr normal) (caddr u)) (* (caddr normal) (cadr u)))
                   (- (* (caddr normal) (car u)) (* (car normal) (caddr u)))
                   (- (* (car normal) (cadr u)) (* (cadr normal) (car u))))
        offset (max (* 2.0 width) (* 3.0 (getvar "DIMTXT") (max 1.0 (getvar "DIMSCALE"))))
        point (alc--vector-add (alc--vector-scale (alc--vector-add (car gap) (cadr gap)) 0.5)
                  (alc--vector-scale side offset))
        dim (vla-AddDimAligned (alc--current-space) (vlax-3d-point (car gap))
              (vlax-3d-point (cadr gap)) (vlax-3d-point point))
        entity (alc--track-temp (vlax-vla-object->ename dim)))
  (vla-put-Normal dim (vlax-3d-point normal))
  (vla-put-ExtLine1Point dim (vlax-3d-point (car gap)))
  (vla-put-ExtLine2Point dim (vlax-3d-point (cadr gap)))
  (vla-put-TextPosition dim (vlax-3d-point point))
  (vla-put-Layer dim (getvar "CLAYER"))
  (vla-put-LinearScaleFactor dim 1.0)
  (regapp "ALC_VVM_DOOR")
  (entmod (append (entget entity) '((-3 ("ALC_VVM_DOOR" (1000 . "1"))))))
  (vla-Update dim)
  entity)

(defun alc--match-old-axes (job / record candidate nodes old entry)
  ;; Retire exact local axes or earlier joined subsets. Endpoints must coincide
  ;; with selected source endpoints, so arbitrary shorter plines are preserved.
  (if (cadddr job)
    (progn
      (foreach record (caddr job)
        (setq nodes (append nodes (cdr (cadr record)))))
      (foreach candidate *alc-match-outputs*
        (setq entry (list (caddr candidate) (nth 3 candidate) (nth 4 candidate)))
        (if (and (not (alc--match-same-entry-p entry (cadr job)))
                 (alc--match-collinear-p (list (car job) entry) (list (car job) (cadr job)))
                 (vl-some '(lambda (p) (equal p (cadr entry) 1e-5)) nodes)
                 (vl-some '(lambda (p) (equal p (caddr entry) 1e-5)) nodes)
                 (equal (cadr candidate) (cdr (assoc 330 (reverse (entget (car job))))))
                 (equal (abs (alc--vector-dot (nth 5 candidate)
                   (if (assoc 210 (entget (car job))) (cdr (assoc 210 (entget (car job)))) '(0.0 0.0 1.0)))) 1.0 1e-7))
          (setq old (cons (car candidate) old))))))
  old)

(defun alc--match-same-entry-p (a b)
  (and (equal (car a) (car b) 1e-5)
    (or (and (equal (cadr a) (cadr b) 1e-5) (equal (caddr a) (caddr b) 1e-5))
        (and (equal (cadr a) (caddr b) 1e-5) (equal (caddr a) (cadr b) 1e-5)))))

(defun alc--match-job-needed-p (job / needed gap)
  (setq needed (or (not (alc--match-existing-p (car job) (cadr job))) (alc--match-old-axes job)))
  (foreach gap (cadddr job)
    (if (not (alc--match-door-dim-p gap *alc-match-door-dims* (car job))) (setq needed T)))
  needed)

(defun alc--match-create-loop (/ job output gap result old old-axes erased saved-index saved-dims saved-temps)
  (setq saved-index *alc-match-outputs* saved-dims *alc-match-door-dims* saved-temps *alc-temp-entities*)
  (setq result (vl-catch-all-apply
    '(lambda ()
      (foreach job *alc-match-pending*
        (setq old-axes (append old-axes (alc--match-old-axes job))
              output (alc--match-segment (car job) (cadr job)))
        (cond ((eq output 'existing) nil)
              (output (setq count (1+ count)))
              (T (vl-exit-with-error "Khong tao duoc pline qua cua.")))
        (foreach gap (cadddr job)
          (if (not (alc--match-door-dim-p gap *alc-match-door-dims* (car job)))
            (progn
              (setq output (alc--match-add-door-dim (car job) (car (cadr job)) gap)
                    *alc-match-door-dims* (cons (cons output gap) *alc-match-door-dims*)
                    dim-count (1+ dim-count))))))
      ;; All replacement geometry exists before any older local output is erased.
      (foreach old old-axes
        (if (entget old)
          (if (and (not (alc--layer-locked-p (cdr (assoc 8 (entget old))))) (entdel old))
            (setq erased (cons old erased))
            (vl-exit-with-error "Khong thay duoc pline tim cu; hay mo khoa layer cua pline."))))
      T) nil))
  (if (vl-catch-all-error-p result)
    (progn
      (foreach old erased (if (not (entget old)) (entdel old)))
      (foreach output *alc-temp-entities*
        (if (not (member output saved-temps))
          (progn (if (entget output) (entdel output)) (alc--untrack-temp output))))
      (setq *alc-match-outputs* saved-index *alc-match-door-dims* saved-dims count 0 dim-count 0)
      (prompt (strcat "\nDa huy luot tao pline/cua: " (vl-catch-all-error-message result))))
    (progn
      (foreach output *alc-temp-entities*
        (if (not (member output saved-temps)) (alc--untrack-temp output)))
      (setq replaced-count (length erased)))))

(defun alc--match-loop (/ selection index wall entries entry seen records job count skipped dim-count replaced-count
    *alc-match-index-ready* *alc-match-outputs* *alc-match-pending* *alc-match-door-dims*)
  (setq count 0 skipped 0 dim-count 0 replaced-count 0)
  (if (setq selection (alc--match-select))
    (progn
      (setq index 0 *alc-match-outputs* (alc--match-existing-outputs)
            *alc-match-door-dims* (alc--match-door-dimensions) *alc-match-index-ready* T)
      (repeat (sslength selection)
        (setq wall (alc--resolve-wall (ssname selection index)) index (1+ index))
        (if (and wall (not (member wall seen)))
          (progn
            (setq seen (cons wall seen) entries (alc--match-entries wall))
            (if entries
              (foreach entry entries (setq records (cons (list wall entry) records)))
              (prompt "\nBo qua tuong ngoai tieu chuan thang/L/U deu be day.")))))
      (foreach job (alc--match-jobs (reverse records))
        (if (alc--match-job-needed-p job) (setq *alc-match-pending* (cons job *alc-match-pending*))
          (setq skipped (1+ skipped))))
      (if *alc-match-pending*
        (if (alc--layer-locked-p (getvar "CLAYER"))
          (prompt "\nHay mo khoa layer current truoc khi tao pline/dim cua.")
          (alc--run-command 'alc--match-create-loop "VVMATCH")))))
  (prompt (strcat "\nDa tao " (itoa count) " pline tim (tinh ca cua), " (itoa dim-count)
    " dim cua; thay " (itoa replaced-count) " pline tim roi; bo qua " (itoa skipped) " doan da co.")))

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

(defun c:VVM () (c:VVMATCH))

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
