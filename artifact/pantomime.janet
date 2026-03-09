#!/usr/bin/env janet

(import ./util)

(def usage
  ``
  Usage: janet pantomime.janet [--aimcore <path>] [--output <output-path>] [--runs <n>] [--help]
   --aimcore: Path to aimcore directory (default: current directory)
   --output:  Directory to save results (default: current directory)
   --runs:    Number of runs (default: 1)
   --help:    Prints this usage information.
  ``)

(def cores @{
   :aimcore-std @{:runs @[] :averages @{}}
   :aimcore-sec @{:runs @[] :averages @{}}
})

(def func-map
  {"Leak.PC.PC.theory"                          [:aimcore-std :sim]
   "Leak.PC.PC.tickStateCorrespondence"         [:aimcore-std :tick]
   "Leak.PC.PC.projectionCoherence"             [:aimcore-std :proj]
   "Leak.SecretPC.PC.theory"                    [:aimcore-sec :sim]
   "Leak.SecretPC.PC.tickStateCorrespondence"   [:aimcore-sec :tick]
   "Leak.SecretPC.PC.projectionCoherence"       [:aimcore-sec :proj]})

(defn parse-log [path]
  (each line (string/split "\n" (string/trimr (slurp path)))
    (unless (empty? line)
      (def [func time verified?] (string/split ", " line))
      (unless (= "True" verified?)
        (eprintf "ERROR: Verification failed for: %s" func)
        (os/exit 1))
      (when-let [[core type] (func-map func)]
        (put (cores core) type (scan-number time)))))
  (eachk core cores
    (def entry (cores core))
    (def sim  (entry :sim))
    (def tick (entry :tick))
    (def proj (entry :proj))
    (array/push (entry :runs) {:sim sim :tick tick :proj proj :no-sim (+ tick proj)})
    (def n (length (entry :runs)))
    (put (entry :averages) :n n)
    (each field [:sim :tick :proj :no-sim]
      (put (entry :averages) field
        (/ (sum (map |($ field) (entry :runs))) n)))))

(defn run-bench [dir n]
  (def dir (os/realpath dir))
  (def log-path (string dir "/log.txt"))
  (when (os/stat log-path)
        (os/rm log-path))
  (repeat n
    (util/run ["stack" "clean"] dir)
    (util/run ["stack" "build" "--system-ghc" "--no-install-ghc"] dir)
    (parse-log log-path)))

(defn save-results [output-path n]
  (util/mkdirp output-path)
  (def filename (string output-path "/pantomime-" (util/mk-timestamp) "-n" n ".jdn"))
  (spit filename (string/format "%j" cores))
  (printf "Results saved to %s\n" filename))

(defn main [& args]
  (def rest (slice args 1))
  (when (find-index |(= $ "--help") rest)
    (print usage)
    (os/exit 0))

  (util/check-flags ["--aimcore" "--output" "--runs" "--help"] rest)

  (def dir (or (util/get-arg "--aimcore" rest false) "."))
  (def output-path (or (util/get-arg "--output" rest false) "."))
  (def n (scan-number (or (util/get-arg "--runs" rest false) "1")))

  (run-bench dir n)
  (save-results output-path n))
