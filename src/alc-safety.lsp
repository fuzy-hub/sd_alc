(setq *alc-module-version* "3.3.6")
;;; Shared geometry validation, transactions and command-scoped hatch index.

(defun alc--cross2 (a b c)
  (- (* (- (car b) (car a)) (- (cadr c) (cadr a)))
     (* (- (cadr b) (cadr a)) (- (car c) (car a)))))

(defun alc--on-segment-p (a b p)
  (and (< (abs (alc--cross2 a b p)) 1e-7)
       (<= (- (min (car a) (car b)) 1e-7) (car p) (+ (max (car a) (car b)) 1e-7))
       (<= (- (min (cadr a) (cadr b)) 1e-7) (cadr p) (+ (max (cadr a) (cadr b)) 1e-7))))

(defun alc--segments-touch-p (a b c d / ab-c ab-d cd-a cd-b)
  (setq ab-c (alc--cross2 a b c) ab-d (alc--cross2 a b d)
        cd-a (alc--cross2 c d a) cd-b (alc--cross2 c d b))
  (or (and (< (* ab-c ab-d) 0.0) (< (* cd-a cd-b) 0.0))
      (alc--on-segment-p a b c) (alc--on-segment-p a b d)
      (alc--on-segment-p c d a) (alc--on-segment-p c d b)))

(defun alc--valid-polygon-p (points normal / ps p z area i j n a b valid)
  (setq ps (mapcar '(lambda (p) (trans p 0 normal)) points)
        n (length ps) valid (>= n 3) area 0.0 i 0)
  (if ps (setq z (caddr (car ps))))
  (foreach p ps
    (if (not (equal z (caddr p) 1e-6)) (setq valid nil)))
  (while (and valid (< i n))
    (setq a (nth i ps) b (nth (rem (1+ i) n) ps)
          area (+ area (alc--cross2 (car ps) a b))
          j (+ i 2))
    (if (< (distance a b) 1e-7) (setq valid nil))
    (while (and valid (< j n))
      (if (and (not (and (= i 0) (= j (1- n))))
               (alc--segments-touch-p a b (nth j ps) (nth (rem (1+ j) n) ps)))
        (setq valid nil))
      (setq j (1+ j)))
    (setq i (1+ i)))
  (and valid (> (abs area) 1e-6)))

(defun alc--straight-wall-p (wall / data valid pair normal)
  (setq data (entget wall) valid (alc--closed-lwpolyline-p wall))
  (foreach pair data
    (if (and (= (car pair) 42) (not (equal (cdr pair) 0.0 1e-10))) (setq valid nil)))
  (and valid (not (alc--layer-locked-p (cdr (assoc 8 data))))
       (alc--valid-polygon-p (alc--clean-polygon-points (alc--lwp-points wall))
         (if (setq normal (cdr (assoc 210 data))) normal '(0.0 0.0 1.0)))))

(defun alc--door-supported-p (wall hatches / valid hatch data sources object)
  (setq valid (and (alc--straight-wall-p wall) (<= (length hatches) 1)))
  (foreach hatch hatches
    (setq data (entget hatch) sources (alc--hatch-source-boundaries hatch)
          object (vlax-ename->vla-object hatch))
    (if (or (alc--layer-locked-p (cdr (assoc 8 data)))
            (/= (cdr (assoc 71 data)) 1) (/= (cdr (assoc 91 data)) 1)
            (/= (vla-get-HatchObjectType object) 0)
            (not (equal sources (list wall))))
      (setq valid nil)))
  valid)

;; Property failures abort the replacement instead of silently discarding styling.
(defun alc--copy-properties (source target properties / property value)
  (foreach property properties
    (setq value (vlax-get-property source property))
    (vlax-put-property target property value)
    (if (= (type value) 'VLA-OBJECT) (vlax-release-object value)))
  T)

(defun alc--copy-boundary-properties (source target / data xdata)
  (alc--copy-properties (vlax-ename->vla-object source) (vlax-ename->vla-object target)
    '(Layer TrueColor EntityTransparency Linetype LinetypeScale Lineweight Visible Thickness ConstantWidth))
  (setq data (entget source '("*")) xdata (assoc -3 data))
  (if xdata (entmod (append (entget target) (list xdata))) T))

(defun alc--copy-hatch-properties (source target)
  (alc--copy-properties (vlax-ename->vla-object source) target
    '(Layer TrueColor BackgroundColor EntityTransparency Origin PatternDouble
      HatchStyle Linetype LinetypeScale Lineweight Visible))
  (vla-Evaluate target)
  T)

(defun alc--erase-for-door (entity)
  (if (entdel entity)
    (progn (setq *alc-door-erased* (cons entity *alc-door-erased*)) T)
    nil))

(defun alc--commit-wall (boundary / hatch entity)
  (setq hatch (alc--make-hatch boundary) entity (alc--vla-object-ename hatch))
  (if entity
    (progn (alc--track-temp entity) (alc--wall-tag boundary) (alc--save-settings)
      (alc--untrack-temp boundary) (alc--untrack-temp entity)
      (alc--cleanup-temp) T)
    (progn (alc--cleanup-temp) (prompt "\nHatch failed; new wall rolled back.") nil)))

;; Only actual VV/VVC walls get this marker. Lintels/ties use another hatch API.
;; Door replacement copies XData; trim/extend keep the same boundary entity.
(defun alc--wall-write-tag (boundary width version / data)
  (regapp "ALCWALL")
  (setq data (entget boundary '("ALCWALL")))
  (if (assoc -3 data) (setq data (vl-remove (assoc -3 data) data)))
  (if (entmod (append data
        (list (list -3 (list "ALCWALL" '(1000 . "WALL")
          (cons 1040 width) (cons 1070 version)))))) T))

(defun alc--wall-tag (boundary)
  (alc--wall-write-tag boundary *alc-thickness* 2))

(defun alc--wall-legacy-openings-p (wall / record)
  (setq record (cdr (assoc "ALCWALL" (cdr (assoc -3 (entget wall '("ALCWALL")))))))
  (not (equal (cdr (assoc 1070 record)) 2)))

(defun alc--wall-tag-width (boundary / record width)
  (setq record (cdr (assoc "ALCWALL" (cdr (assoc -3 (entget boundary '("ALCWALL"))))))
        width (cdr (assoc 1040 record)))
  (if (and (equal (cdr (assoc 1000 record)) "WALL")
           (numberp width) (> width 0.0)) width))

(defun alc--wall-openings (wall / record item start pairs)
  (setq record (cdr (assoc "ALCOPENINGS" (cdr (assoc -3 (entget wall '("ALCOPENINGS")))))))
  (foreach item record
    (if (= (car item) 1011)
      (if start
        (setq pairs (cons (list start (cdr item)) pairs) start nil)
        (setq start (cdr item)))))
  (reverse pairs))

(defun alc--wall-save-opening (wall start end / data record pair)
  (regapp "ALCOPENINGS")
  (setq record (list "ALCOPENINGS"))
  (foreach pair (append (alc--wall-openings wall) (list (list start end)))
    (setq record (append record (list (cons 1011 (car pair)) (cons 1011 (cadr pair))))))
  (setq data (entget wall '("ALCOPENINGS")))
  (if (assoc -3 data) (setq data (vl-remove (assoc -3 data) data)))
  (if (entmod (append data (list (list -3 record)))) T))

;; Scripting.Dictionary gives keyed lookup without an O(M*H) association list.
;; Only resize commands opt in; their geometry changes do not add/remove hatches.
(defun alc--end-hatch-index ()
  (if (and (boundp '*alc-hatch-index*) *alc-hatch-index*)
    (vl-catch-all-apply 'vlax-release-object (list *alc-hatch-index*)))
  (setq *alc-hatch-index* nil))

(defun alc--dictionary-value (dict key / value)
  (setq value (vlax-get-property dict 'Item key))
  (if (= (type value) 'VARIANT) (vlax-variant-value value) value))

(defun alc--build-hatch-index (/ dict selection i hatch key value source)
  (setq dict (vlax-create-object "Scripting.Dictionary") *alc-hatch-index* dict)
  (setq *alc-hatch-scan-count* (1+ *alc-hatch-scan-count*))
  (if (setq selection (ssget "_X" '((0 . "HATCH"))))
    (progn (setq i 0)
      (repeat (sslength selection)
        (setq hatch (ssname selection i) i (1+ i))
        (foreach source (alc--hatch-source-boundaries hatch)
          (setq key (cdr (assoc 5 (entget source)))
                value (if (= (vlax-invoke-method dict 'Exists key) :vlax-true)
                        (alc--dictionary-value dict key) ""))
          (vlax-put-property dict 'Item key
            (strcat value (if (= value "") "" ";") (cdr (assoc 5 (entget hatch)))))))))
  dict)

(defun alc--indexed-hatches (boundary / key result handle hatch)
  (setq key (cdr (assoc 5 (entget boundary))))
  (if (and key (= (vlax-invoke-method *alc-hatch-index* 'Exists key) :vlax-true))
    (foreach handle (alc--split-string (alc--dictionary-value *alc-hatch-index* key) ";")
      (if (and (setq hatch (handent handle)) (entget hatch)
               (alc--hatch-references-boundary-p hatch boundary))
        (setq result (cons hatch result)))))
  (reverse result))

(if (not (boundp '*alc-hatch-scan-count*)) (setq *alc-hatch-scan-count* 0))
(princ)
