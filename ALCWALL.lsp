;;; ALCWALL 3.3.6 — pinned root, manifest validation, fail-closed command gate.
(vl-load-com)
(setq *alc-ready* nil)
(defun alc--require (condition message)
  (if condition T (progn (prompt (strcat "\n" message)) nil)))

(defun alc--ready-p ()
  (if (and (boundp '*alc-ready*) *alc-ready*) T
    (progn (prompt "\nALCWALL is not ready. Load the complete installation.") nil)))

;; Disable even entry points left by an older version before any file is loaded.
(foreach alc-command-symbol '(c:ALCSET c:ALCS c:ALSC c:ALCWALL c:VV c:ALCCENTRAL c:VVC c:ALCDOOR c:ALCTRIM c:ALCXTEND c:ALCLT c:ALCGT c:ALCGTS c:ALCTK c:ALCTKT c:ALCTKC c:TKDIM c:TKCOUNT c:TKMS c:TKALIGN c:ALCDIM c:VVSET c:VVS c:VVWALL c:VVCENTRAL c:VVDOOR c:VVTRIM c:VVXTEND c:VVLT c:VVGT c:VVGTS c:VVTK c:VVTKT c:VVTKC c:VVDIM)
  (eval (list 'defun alc-command-symbol nil '(alc--ready-p) '(princ))))
(setq alc-command-symbol nil)

(defun alc--loader-root (/ paths part candidate roots selected)
  (if (and (boundp '*alc-install-root*) *alc-install-root*)
    (if (findfile (strcat *alc-install-root* "/ALCWALL.lsp")) *alc-install-root*)
    (progn
      (setq paths (getenv "ACAD"))
      (while paths
        (if (setq part (vl-string-search ";" paths))
          (setq candidate (substr paths 1 part) paths (substr paths (+ part 2)))
          (setq candidate paths paths nil))
        (if (and (/= candidate "") (findfile (strcat candidate "/ALCWALL.lsp")))
          (if (not (member (strcase (vl-string-translate "\\" "/" candidate)) roots))
            (setq roots (cons (strcase (vl-string-translate "\\" "/" candidate)) roots)))))
      (setq selected (findfile "ALCWALL.lsp"))
      (if selected
        (progn (setq selected (vl-string-translate "\\" "/" (vl-filename-directory selected)))
          (if (not (member (strcase selected) roots)) (setq roots (cons (strcase selected) roots)))))
      (if (= (length roots) 1) selected
        (progn (prompt "\nAmbiguous/missing ALCWALL installation. Use tools/install.ps1 and APPLOAD ALCWALL-LOAD.lsp.") nil)))))

(defun alc--load-module (root name / result)
  (setq *alc-module-version* nil
        result (vl-catch-all-apply 'load (list (strcat root "/src/" name))))
  (alc--require (and (not (vl-catch-all-error-p result)) (equal *alc-module-version* "3.3.6"))
    (strcat "Module load/version error: " name)))


(defun alc--boot (root / stream line manifest item pass)
  (and
    (alc--require root "Cannot resolve installation folder.")
    (alc--require (setq stream (open (strcat root "/manifest.lspdata") "r")) "Missing manifest.lspdata.")
    (progn (setq line (read-line stream)) (close stream) (setq manifest (read line))
      (alc--require (equal (car manifest) "3.3.6") "Manifest version mismatch."))
    (progn
      (setq pass T)
      (foreach item (cdr manifest)
        (if (not (equal (vl-file-size (strcat root "/" (car item))) (cadr item)))
          (progn (setq pass nil) (prompt (strcat "\nMissing/changed file: " (car item))))))
      pass)
    (progn
      (foreach item '("alc-settings.lsp" "alc-styles.lsp" "alc-patterns.lsp" "alc-geometry.lsp" "alc-safety.lsp" "alc-wall.lsp" "alc-trim.lsp" "alc-schedule.lsp" "alc-door-schedule.lsp" "alc-dim-schedule.lsp" "alc-count.lsp" "alc-text-copy.lsp" "alc-align.lsp" "alc-commands.lsp")
        (if (and pass (not (alc--load-module root item))) (setq pass nil)))
      pass)
    (progn
      ;; Apply metric hatch/linetype libraries on every startup or manual reload.
      (setvar "MEASUREMENT" 1)
      (setq *alc-resource-root* root) (alc--load-settings)
      (alc--init-drawing-resources))
    (progn (setq *alc-version* "3.3.6" *alc-ready* T) T)))

(setq *alc-boot-result* (vl-catch-all-apply 'alc--boot (list (alc--loader-root))))
(if (or (not *alc-boot-result*) (vl-catch-all-error-p *alc-boot-result*))
  (prompt (strcat "\nALCWALL load failed: " (if (vl-catch-all-error-p *alc-boot-result*) (vl-catch-all-error-message *alc-boot-result*) "installation validation failed")))
  (prompt (strcat "\nALCWALL v" *alc-version* " modules loaded.")))
(setq *alc-boot-result* nil)
(princ)
