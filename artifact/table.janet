#!/usr/bin/env janet

(import ./util)

(def usage
  ``
  Usage: janet table.janet [--pantomime <path>] [--leave <path>] [--output <path>] [--pdf] [--latex-cmd <cmd>] [--help]

    --pantomime:  Path to a pantomime .jdn result file, or a directory from which
                  the latest pantomime-*.jdn is used automatically.
                  If omitted, aimcore timing columns will show "no data".
    --leave:      Path to a leave .jdn result file, or a directory from which
                  the latest leave-*.jdn is used automatically.
                  If omitted, leave timing columns will show "no data".
    --output:     Directory to save output files (default: current directory)
    --pdf:        Compile the generated .tex file to PDF after writing it.
    --latex-cmd:  LaTeX command to use for compilation (default: latexmk -pdf -interaction=nonstopmode)
    --help:       Prints this usage information.
  ``)

# Loading
# ------------------------------------------------------------------------------
(defn latest-jdn [dir prefix]
  (def files
    (->> (os/dir dir)
         (filter (fn [f] (and (string/has-prefix? prefix f)
                              (string/has-suffix? ".jdn" f))))
         (sort)))
  (when (not (empty? files))
    (string dir "/" (last files))))

(defn load-results [path]
  (parse (slurp path)))

# Data
# ------------------------------------------------------------------------------
(defn fmt-secs [n]
  (if n (string/format "%.1f sec" n) "no data"))

(defn fmt-mins [n]
  (if n (string/format "%.1f min" (/ n 60)) "no data"))

(defn make-data [pantomime leave]
  (defn p-avg [core field]
    (get-in pantomime [core :averages field]))
  (defn l-avg [core field]
    (get-in leave [core :averages field]))

  {:isa
     {:aimcore-std "RV32I" :aimcore-sec "RV32I" :Sodor-2 "RV32I" :DarkRISCV-3 "RV32E" :Ibex-small "RV32IMC"}
   :pipeline-stages
     {:aimcore-std "5" :aimcore-sec "5" :Sodor-2 "2" :DarkRISCV-3 "3" :Ibex-small "2"}
   :code-size
     {:aimcore-std "800 Haskell / 2400 Verilog" :aimcore-sec "800 Haskell / 2400 Verilog" :Sodor-2 "400 Chisel / 2000 Verilog" :DarkRISCV-3 "620 Verilog" :Ibex-small "2500 Verilog"}
   :forwarding
     {:aimcore-std "yes" :aimcore-sec "yes" :Sodor-2 "no" :DarkRISCV-3 "no" :Ibex-small "yes"}
   :proof-effort
     {:aimcore-std "180 loc simulator; 30 loc projection" :aimcore-sec "1 loc simulator; 20 loc projection" :Sodor-2 "16 manual invariants" :DarkRISCV-3 "13 manual invariants" :Ibex-small "59 manual invariants"}
   :verif-time-with
     {:aimcore-std (fmt-secs (p-avg :aimcore-std :sim))
      :aimcore-sec (fmt-secs (p-avg :aimcore-sec :sim))}
   :verif-time-without
     {:aimcore-std (fmt-secs (p-avg :aimcore-std :no-sim))
      :aimcore-sec (fmt-secs (p-avg :aimcore-sec :no-sim))
      :Sodor-2     (fmt-mins (l-avg :Sodor-2     :total))
      :DarkRISCV-3 (fmt-mins (l-avg :DarkRISCV-3 :total))
      :Ibex-small  (fmt-mins (l-avg :Ibex-small  :total))}
   :unconditional
     {:aimcore-std "yes" :aimcore-sec "yes" :Sodor-2 "no" :DarkRISCV-3 "no" :Ibex-small "no"}})

# Markdown
# ------------------------------------------------------------------------------
(defn str-width [s] (count |(not= (band $ 0xC0) 0x80) s))

(defn pad-right [s w]
  (string s (string/repeat " " (- w (str-width s)))))

(defn mk-table [headers rows]
  (def col-widths
    (map (fn [i] (max (length (headers i))
                      (max ;(map (fn [r] (str-width (string (r i)))) rows))))
         (range (length headers))))
  (defn fmt-row [cells]
    (string "| "
      (string/join
        (map (fn [i] (pad-right (string (cells i)) (col-widths i)))
             (range (length cells)))
        " | ")
      " |"))
  (string/join
    [(fmt-row headers)
     (string "|" (string/join (map (fn [w] (string/repeat "-" (+ w 2))) col-widths) "|") "|")
     ;(map fmt-row rows)]
    "\n"))

(defn render-markdown [pantomime leave]
  (def d (make-data pantomime leave))
  (defn col [k col-key] (get-in d [k col-key]))
  (defn fmt-bool [v] (if (= v "yes") "✓" "✗"))
  (defn row [label k]
    [label (col k :aimcore-std) (col k :aimcore-sec) (col k :Sodor-2) (col k :DarkRISCV-3) (col k :Ibex-small)])
  (defn bool-row [label k]
    [label ;(map fmt-bool [(col k :aimcore-std) (col k :aimcore-sec) (col k :Sodor-2) (col k :DarkRISCV-3) (col k :Ibex-small)])])
  (defn verif-time-cell [c]
    (string (col :verif-time-with c) " (w/ sim) / " (col :verif-time-without c) " (w/o sim)"))

  (mk-table
    ["" "AIMCore Standard" "AIMCore Secure" "Sodor-2" "DarkRISCV-3" "Ibex-small"]
    [["*Architecture*" "" "" "" "" ""]
     (row "ISA"              :isa)
     (row "Pipeline stages"  :pipeline-stages)
     (row "Code size (loc)"  :code-size)
     (bool-row "Forwarding"       :forwarding)
     ["*Security & Proof*" "" "" "" "" ""]
     (row "Proof effort"     :proof-effort)
     ["Verification Time"
      (verif-time-cell :aimcore-std)
      (verif-time-cell :aimcore-sec)
      (col :verif-time-without :Sodor-2)
      (col :verif-time-without :DarkRISCV-3)
      (col :verif-time-without :Ibex-small)]
     (bool-row "Unconditional proof" :unconditional)]))

# LaTeX
# ------------------------------------------------------------------------------
(defn render-latex [pantomime leave]
  (def d (make-data pantomime leave))
  (defn col [k col-key] (get-in d [k col-key]))
  (defn mark [v] (if (= v "yes") `\cmark` `\xmark`))
  # Architecture rows: aimcore-std = aimcore-sec, so merge with \multicolumn{2}{c|}
  (defn arch-row [label k]
    (string/format `  %s & \multicolumn{2}{c|}{%s} & %s & %s & %s \\`
      label
      (col k :aimcore-std)
      (col k :Sodor-2) (col k :DarkRISCV-3) (col k :Ibex-small)))

  (string/join
    [`\begin{table*}[htbp]`
     `  \small`
     `  \centering`
     `  \caption{\core~compared with the processors verified in LeaVe~\cite{leave}.}`
     `  \resizebox{\linewidth}{!}{`
     `  \begin{tabular}{l|cc|ccc}`
     `  \toprule`
     `  & \multicolumn{2}{c|}{\textbf{AIMCore (Our work)}} & \multicolumn{3}{c}{\textbf{Processors verified by LeaVe~\cite{leave}}} \\`
     `  & \textbf{Standard} & \textbf{Secure} & \textbf{Sodor} & \textbf{DarkRISCV-3} & \textbf{Ibex-small} \\`
     `  \midrule`
     `  \multicolumn{6}{l}{\textit{Architecture}} \\`
     (arch-row "ISA"             :isa)
     (arch-row "Pipeline stages" :pipeline-stages)
     (arch-row "Code size (loc)" :code-size)
     (string/format `  Forwarding & \multicolumn{2}{c|}{%s} & %s & %s & %s \\`
       (mark (col :forwarding :aimcore-std))
       (mark (col :forwarding :Sodor-2)) (mark (col :forwarding :DarkRISCV-3)) (mark (col :forwarding :Ibex-small)))
     `  \midrule`
     `  \multicolumn{6}{l}{\textit{Security Properties \& Proof}} \\`
     (string/format `  Proof effort & \makecell{%s} & \makecell{%s} & %s & %s & %s \\`
       (col :proof-effort :aimcore-std) (col :proof-effort :aimcore-sec)
       (col :proof-effort :Sodor-2) (col :proof-effort :DarkRISCV-3) (col :proof-effort :Ibex-small))
     (string/format `  Verification Time & \makecell{%s (w/ simulator) \\ %s (w/o simulator)} & \makecell{%s (w/ simulator) \\ %s (w/o simulator)} & %s & %s & %s \\`
       (col :verif-time-with :aimcore-std) (col :verif-time-without :aimcore-std)
       (col :verif-time-with :aimcore-sec) (col :verif-time-without :aimcore-sec)
       (col :verif-time-without :Sodor-2) (col :verif-time-without :DarkRISCV-3) (col :verif-time-without :Ibex-small))
     (string/format `  Unconditional proof & %s & %s & %s & %s & %s \\`
       (mark (col :unconditional :aimcore-std)) (mark (col :unconditional :aimcore-sec))
       (mark (col :unconditional :Sodor-2)) (mark (col :unconditional :DarkRISCV-3)) (mark (col :unconditional :Ibex-small)))
     `  \bottomrule`
     `  \end{tabular}`
     `  }`
     `  \label{tab:processor_comparison}`
     `\end{table*}`]
    "\n"))

(defn render-latex-document [pantomime leave]
  (string/join
    [`\documentclass{article}`
     `\usepackage{booktabs}`
     `\usepackage{makecell}`
     `\usepackage{graphicx}`
     `\usepackage{pifont}`
     `\usepackage{xcolor}`
     `\usepackage{xspace}`
     `\newcommand{\cmark}{\textcolor{green!70!black}{\ding{51}}}`
     `\newcommand{\xmark}{\textcolor{red}{\ding{55}}}`
     `\newcommand{\core}{\textsc{AIMCore}\xspace}`
     `\begin{document}`
     (render-latex pantomime leave)
     `\end{document}`]
    "\n"))

# Main
# ------------------------------------------------------------------------------
(defn resolve-path [path prefix]
  (if (= :directory ((os/stat path) :mode))
    (latest-jdn path prefix)
    path))

(defn main [& args]
  (def rest (slice args 1))
  (when (or (find-index |(= $ "--help") rest) (empty? rest))
    (print usage)
    (os/exit 0))

  (util/check-flags ["--pantomime" "--leave" "--output" "--pdf" "--latex-cmd" "--help"] rest)

  (def pantomime-arg (util/get-arg "--pantomime" rest false))
  (def leave-arg     (util/get-arg "--leave"     rest false))

  (unless (or pantomime-arg leave-arg)
    (eprintf "ERROR: at least one of --pantomime or --leave is required")
    (print usage)
    (os/exit 1))

  (def pantomime-path (when pantomime-arg (resolve-path pantomime-arg "pantomime-")))
  (def leave-path     (when leave-arg     (resolve-path leave-arg     "leave-")))

  (def output-path (or (util/get-arg "--output" rest false) "."))
  (def render-pdf? (find-index |(= $ "--pdf") rest))
  (def latex-cmd   (or (util/get-arg "--latex-cmd" rest false)
                       "latexmk -pdf -interaction=nonstopmode"))

  (def pantomime (if pantomime-path (load-results pantomime-path) @{}))
  (def leave     (if leave-path     (load-results leave-path)     @{}))
  (def ts        (util/mk-timestamp))
  (def md-file   (string output-path "/table1-" ts ".md"))
  (def tex-file  (string output-path "/table1-" ts ".tex"))
  (util/mkdirp output-path)
  (spit md-file  (render-markdown pantomime leave))
  (spit tex-file (render-latex-document pantomime leave))
  (printf "Results saved to %s and %s\n" md-file tex-file)

  (when render-pdf?
    (def cmd [;(string/split " " latex-cmd)
               (string "-outdir=" output-path) tex-file])
    (util/run cmd)
    (util/run ["latexmk" "-c" (string "-outdir=" output-path) tex-file])))
