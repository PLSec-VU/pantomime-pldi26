#!/usr/bin/env janet

(import ./util)

# Table for data
(def cores @{
  :RE @{:runs @[] :averages @{}}
  :DarkRISCV-2 @{:runs @[] :averages @{}}
  :DarkRISCV-3 @{:runs @[] :averages @{}}
  :Sodor-2 @{:runs @[] :averages @{}}
  :Ibex-small @{:runs @[] :averages @{}}
  :Ibex-cache @{:runs @[] :averages @{}}
  :Ibex-mult-div @{:runs @[] :averages @{}}
})

(def available-cores (string/join (map string (keys cores)) ", "))

(def usage
  (string
    ``
    Usage: janet leave.janet [--leave <leave-path>] [--output <output-path>] [--threads <n>] [--runs <n>] [--cores <cores...>] [--help]
     --leave:    Path to leave repo (default: current directory)
     --output:   Directory to save results (default: current directory)
     --threads:  Number of threads to use. Runs benchmarks in parallel if > 1. (default: 1)
     --runs:     Number of runs (default: 1)
     --cores:    Cores to benchmark (default: all)
     --help:     Prints this usage information.

     Available cores: ``
    available-cores))

(defn config-path [leave-path c]
  (string leave-path "/config/" (string c) ".yaml"))

(defn logfile-path [leave-path c]
  (string leave-path "/testOut/" (string c) "/logfile"))

(defn get-result [leave-path c]
  (def logfile (slurp (logfile-path leave-path c)))
  (defn get-time [type]
    ((peg/match ~(* (thru ,(string "Time for " type " step:")) :s* (number :d+)) logfile) 0))
  (unless (peg/match '(thru "Verification passed!!") logfile)
    (eprintf "ERROR: Verification failed for: %s" (string c))
    (os/exit 1))
  (def base-time (get-time "base"))
  (def inductive-time (get-time "inductive"))
  (def entry (cores c))
  (array/push (entry :runs) {:base base-time :inductive inductive-time :total (+ base-time inductive-time)})
  (def n (length (entry :runs)))
  (put (entry :averages) :n n)
  (each field [:base :inductive :total]
    (put (entry :averages) field
      (/ (sum (map |($ field) (entry :runs))) n))))

(defn setup [leave-path]
  (def leave-path (os/realpath leave-path))
  (def proc (os/spawn ["which" "yosys"] :p {:out :pipe}))
  (def yosys-path (string/trimr (:read (proc :out) :all)))
  (os/proc-wait proc)
  (util/run ["make" "-C" (string leave-path "/yosys-passes")])
  (eachk c cores
    (util/run
      ["sed" "--in-place"
       (string "s|^yosysPath:.*$|yosysPath: \"" yosys-path "\"|")
       (config-path leave-path (string c))])))

(defn bench [leave-path c]
  (os/spawn ["python3"
             "source/cli.py"
             (string "config/" c ".yaml")] :p {:cd leave-path}))

(defn run-queue [leave-path cs threads n]
  (def pending @[])
  (repeat n (each c cs (array/push pending c)))
  (def ch (ev/chan))
  (def active @{})
  (var n-running 0)

  (defn launch-eligible []
    (var i 0)
    (while (and (< i (length pending)) (< n-running threads))
      (def cand (pending i))
      (if (active cand)
        (++ i)
        (do (array/remove pending i)
            (put active cand true)
            (++ n-running)
            (ev/spawn (os/proc-wait (bench leave-path cand)) (ev/give ch cand))))))

  (launch-eligible)
  (while (> n-running 0)
    (def c (ev/take ch))
    (-- n-running)
    (put active c nil)
    (get-result leave-path c)
    (launch-eligible)))

(defn save-results [output-path threads n cs]
  (util/mkdirp output-path)
  (def label
    (if (= (length cs) (length (keys cores)))
      "all"
      (string/join (map string cs) "-")))
  (def filename
    (string/join [(string output-path "/leave") (util/mk-timestamp) (string "n" n) (string "t" threads) (string label ".jdn")] "-"))
  (spit filename (string/format "%j" (tabseq [c :in cs] c (cores c))))
  (printf "Results saved to %s\n" filename))

(defn run [leave-path output-path threads n raw-cs]
  (defn find-processor [s]
    (or (find |(= (string/ascii-lower $) (string/ascii-lower s)) (keys cores))
        (do (eprintf "Error: invalid processor '%s'" s)
            (eprintf "Available: %s" available-cores)
            (os/exit 1))))
  (def cs (if (empty? raw-cs) (keys cores) (map find-processor raw-cs)))
  (setup leave-path)
  (run-queue leave-path cs threads n)
  (save-results output-path threads n cs))

(defn main [& args]
  (def rest (slice args 1))
  (when (find-index |(= $ "--help") rest)
    (print usage)
    (os/exit 0))

  (util/check-flags ["--leave" "--output" "--threads" "--runs" "--cores" "--help"] rest)

  (def leave-path (or (util/get-arg "--leave" rest false) "."))
  (def output-path (or (util/get-arg "--output" rest false) "."))
  (def threads (scan-number (or (util/get-arg "--threads" rest false) "1")))
  (def n (scan-number (or (util/get-arg "--runs" rest false) "1")))
  (def raw-cs (util/get-args "--cores" rest))

  (run leave-path output-path threads n raw-cs))
