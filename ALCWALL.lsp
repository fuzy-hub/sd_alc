;;; ALCWALL.lsp
;;; ALC wall drafting toolkit loader for AutoCAD on Windows.
;;; Version: 3.3.0

(vl-load-com)

(setq *alc-version* "3.3.0")

(defun alc--loader-root (/ entry)
  (if (setq entry (findfile "ALCWALL.lsp"))
    (vl-filename-directory entry)
  )
)

(defun alc--load-module (root name / path result)
  (if root
    (setq path (strcat root "\\src\\" name))
  )
  (cond
    ((not path)
      (prompt
        (strcat
          "\nALCWALL loader error: add the ALCWALL folder to the CAD support path. Missing "
          name
          "."))
      nil
    )
    ((not (findfile path))
      (prompt (strcat "\nALCWALL loader error: module not found: " path))
      nil
    )
    (T
      (setq result (vl-catch-all-apply 'load (list path)))
      (if (vl-catch-all-error-p result)
        (progn
          (prompt
            (strcat
              "\nALCWALL loader error in "
              name
              ": "
              (vl-catch-all-error-message result)))
          nil
        )
        T
      )
    )
  )
)

(setq *alc-load-root* (alc--loader-root))

(if (and
      (alc--load-module *alc-load-root* "alc-settings.lsp")
      (alc--load-module *alc-load-root* "alc-styles.lsp")
      (alc--load-module *alc-load-root* "alc-patterns.lsp")
      (alc--load-module *alc-load-root* "alc-geometry.lsp")
      (alc--load-module *alc-load-root* "alc-wall.lsp")
      (alc--load-module *alc-load-root* "alc-trim.lsp")
      (alc--load-module *alc-load-root* "alc-schedule.lsp")
      (alc--load-module *alc-load-root* "alc-align.lsp")
      (alc--load-module *alc-load-root* "alc-commands.lsp"))
  (progn
    (setq *alc-resource-root* *alc-load-root*)
    (alc--load-settings)
    (alc--init-drawing-resources)
    (prompt (strcat "\nALCWALL v" *alc-version* " modules loaded.")))
  (prompt "\nALCWALL failed to load all modules.")
)

(setq *alc-load-root* nil)
(princ)
