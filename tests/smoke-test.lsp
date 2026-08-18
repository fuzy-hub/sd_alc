;;; Verifies that the public ALCWALL command surface loads in CAD.

(vl-load-com)

(defun alc-test--root ()
  (vl-string-translate "\\" "/" (getenv "ALCWALL_TEST_ROOT"))
)

(defun alc-test--write-lines (path lines / stream line)
  (if (setq stream (open path "w"))
    (progn
      (foreach line lines (write-line line stream))
      (close stream)
      T
    )
  )
)

(defun alc-test-run-smoke (/ root load-result commands atoms missing name lines)
  (setq root (alc-test--root)
        load-result
          (vl-catch-all-apply
            'load (list (strcat root "/ALCWALL.lsp")))
        commands
          '("C:ALCSET" "C:ALCWALL" "C:ALCCENTRAL" "C:ALCDOOR"
            "C:ALCLT" "C:ALCGT" "C:ALCGTS" "C:ALCTK"
            "C:ALCTKC" "C:TKDIM" "C:TKCOUNT")
        atoms (atoms-family 1)
        missing nil)
  (if (vl-catch-all-error-p load-result)
    (setq lines
      (list
        "FAIL"
        (strcat "LOAD_ERROR=" (vl-catch-all-error-message load-result))))
    (progn
      (foreach name commands
        (if (not (member name atoms))
          (setq missing (cons name missing))
        )
      )
      (if missing
        (setq lines
          (list
            "FAIL"
            (strcat "MISSING_COMMANDS="
              (apply 'strcat
                (mapcar '(lambda (item) (strcat item " "))
                  (reverse missing))))))
        (setq lines
          (list
            "PASS"
            "COMMAND_COUNT=11"
            (strcat "VERSION=" *alc-version*)))
      )
    )
  )
  (alc-test--write-lines
    (strcat root "/tests/results/smoke-test.log") lines)
  (prompt (strcat "\nALCWALL_SMOKE_TEST_" (car lines)))
  (equal (car lines) "PASS")
)

(princ)
