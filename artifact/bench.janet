#!/usr/bin/env janet

(import ./util)

(def usage
  ``

  Usage: janet bench.janet [--aimcore <path>] [--leave <path>] [--data <path>] [--results <path>]
                           [--runs-pantomime <n>] [--runs-leave <n>] [--threads-leave <n>]
                           [--cores-leave <cores...>] [--skip-pantomime] [--skip-leave] [--help]

    --aimcore:        Path to the aimcore directory (default: aimcore)
    --leave:          Path to the leave repo (default: leave)
    --data:           Directory to save raw benchmark data (default: data)
    --results:        Directory to save generated tables (default: results)
    --runs-pantomime: Number of runs for each leave benchmark (default: 1)
    --runs-leave:     Number of runs for each pantomime benchmark (default: 1)
    --threads-leave:  Number of threads for the leave benchmark. (default: 1)
                      Note: only one instance of each benchmark can run simultaneously.
    --cores-leave:    The cores to benchmark for the leave benchmark. (default: all)
                      Choices: DarkRISCV-3, Sodor-2, Ibex-small
    --skip-pantomime: Skip running the pantomime benchmarks
    --skip-leave:     Skip running the leave benchmarks
    --help:           Prints this usage information.
  ``)

(defn main [& args]
  (def rest (slice args 1))
  (when (find-index |(= $ "--help") rest)
    (print usage)
    (os/exit 0))

  (util/check-flags ["--aimcore" "--leave" "--data" "--results"
                     "--runs-pantomime" "--runs-leave" "--threads-leave"
                     "--cores-leave" "--skip-pantomime" "--skip-leave" "--help"]
                    rest)

  (def aimcore-path    (or (util/get-arg "--aimcore"        rest false) "aimcore"))
  (def leave-path      (or (util/get-arg "--leave"          rest false) "leave"))
  (def data-path       (or (util/get-arg "--data"           rest false) "data"))
  (def results-path    (or (util/get-arg "--results"        rest false) "results"))
  (def runs-pantomime  (or (util/get-arg "--runs-pantomime" rest false) "1"))
  (def runs-leave      (or (util/get-arg "--runs-leave"     rest false) "1"))
  (def threads-leave   (or (util/get-arg "--threads-leave"  rest false) "1"))
  (def raw-cores-leave (util/get-args "--cores-leave" rest))
  (def skip-pantomime? (find-index |(= $ "--skip-pantomime") rest))
  (def skip-leave?     (find-index |(= $ "--skip-leave")   rest))

  (util/mkdirp data-path)
  (util/mkdirp results-path)

  (unless skip-pantomime?
    (util/run ["janet" "pantomime.janet"
               "--aimcore" aimcore-path
               "--output"  data-path
               "--runs"    runs-pantomime]))


  (def cores-leave (if (empty? raw-cores-leave)
                        ["Sodor-2" "DarkRISCV-3" "Ibex-small"]
                        raw-cores-leave))

  (unless skip-leave?
    (util/run ["janet" "leave.janet"
               "--leave"   leave-path
               "--output"  data-path
               "--runs"    runs-leave
               "--threads" threads-leave
               "--cores"   ;cores-leave]))

  (def table-cmd
    @["janet" "table.janet"
      "--output" results-path
      "--pantomime" data-path
      "--leave"     data-path
      "--pdf"])
  (util/run table-cmd))
