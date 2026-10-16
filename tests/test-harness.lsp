;;; Every suite has an isolated log and a completion marker written after return.
(defun alc-test--result-path (filename)
  (strcat (getenv "ALCWALL_TEST_RUN") "/" filename))

(defun alc-test--read-lines (path / f line lines)
  (if (setq f (open path "r"))
    (progn (while (setq line (read-line f)) (setq lines (cons line lines))) (close f)))
  (reverse lines))

(defun alc-test--write-lines (path lines / f line)
  (setq path (alc-test--result-path (strcat (vl-filename-base path) (vl-filename-extension path))))
  (if (setq f (open path "w"))
    (progn (foreach line lines (write-line line f)) (close f) T)))

(defun alc-test--exception (suite message / path lines f)
  (prompt (strcat "\nSUITE EXCEPTION " suite ": " message))
  (setq *alc-test-failed-suites* (cons suite *alc-test-failed-suites*))
  (setq path (alc-test--result-path (strcat suite ".log"))
        lines (alc-test--read-lines path))
  (if (setq f (open path "a"))
    (progn (write-line (strcat "FAIL EXCEPTION: " message) f) (close f))))

(defun alc-test--finish (suite / lines count failures line f)
  (setq lines (alc-test--read-lines (alc-test--result-path (strcat suite ".log"))) count 0 failures 0)
  (foreach line lines
    (if (or (= line "FAIL") (= (substr line 1 5) "FAIL ") (wcmatch line "*=FAIL"))
      (setq failures (1+ failures)))
    (if (or (= line "PASS") (= (substr line 1 5) "PASS ") (wcmatch line "*=PASS"))
      (setq count (1+ count))))
  (if (= count 0) (setq failures (1+ failures)))
  (if (member suite *alc-test-failed-suites*) (setq failures (1+ failures)))
  (setq f (open (alc-test--result-path (strcat suite ".done.json")) "w"))
  (if f (progn
    (write-line (strcat "{\"session\":\"" (getenv "ALCWALL_TEST_LABEL")
      "\",\"status\":\"complete\",\"checks\":" (itoa count) ",\"failed\":" (itoa failures) "}") f)
    (close f)))
  (= failures 0))

(defun alc-test--invoke-suite (file fn)
  (load (strcat (getenv "ALCWALL_TEST_ROOT") "/tests/" file))
  (apply fn nil))

(defun alc-test--suite (suite file fn deferred / result)
  (setq result (vl-catch-all-apply 'alc-test--invoke-suite (list file fn)))
  (if (vl-catch-all-error-p result) (alc-test--exception suite (vl-catch-all-error-message result)))
  (if (not deferred) (alc-test--finish suite))
  (princ))

(defun alc-test--step (fn suite / result)
  (setq result (vl-catch-all-apply fn nil))
  (if (vl-catch-all-error-p result) (alc-test--exception suite (vl-catch-all-error-message result)))
  (princ))
(setq *alc-test-failed-suites* nil)
(princ)
