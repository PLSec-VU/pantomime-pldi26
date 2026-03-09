(defn mkdirp [path]
  (var cur "")
  (each part (string/split "/" path)
    (set cur (if (= cur "") part (string cur "/" part)))
    (when (and (not= cur "") (not (os/stat cur)))
      (os/mkdir cur))))

(defn get-args [flag rest]
  (def idx (find-index |(= $ flag) rest))
  (if (not idx)
    @[]
    (let [after (slice rest (+ idx 1))
          end (or (find-index |(string/has-prefix? "--" $) after) (length after))]
      (slice after 0 end))))

(defn get-arg [flag rest &opt required usage]
  (default required true)
  (def value (first (get-args flag rest)))
  (when (and required (nil? value))
    (eprintf "Error: %s is required\n" flag)
    (when usage (eprintf "%s\n" usage))
    (os/exit 1))
  value)

(defn run [cmd &opt cwd]
  (def original (os/cwd))
  (when cwd (os/cd cwd))
  (def exit-code (os/execute cmd :p))
  (when cwd (os/cd original))
  (unless (= exit-code 0)
    (eprintf "ERROR: command failed with exit code %d" exit-code)
    (os/exit exit-code)))

(defn check-flags [known args]
  (each arg args
    (when (string/has-prefix? "--" arg)
      (unless (find |(= $ arg) known)
        (eprintf "Error: unknown flag '%s'" arg)
        (os/exit 1)))))

(defn mk-timestamp []
  (def t (os/date))
  (string/format "%04d%02d%02d-%02d%02d%02d"
    (t :year) (t :month) (t :month-day)
    (t :hours) (t :minutes) (t :seconds)))
