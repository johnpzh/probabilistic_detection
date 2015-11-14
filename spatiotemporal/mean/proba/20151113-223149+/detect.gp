#set terminal pdfcairo enhanced font "Times New Roman, 20"
#set output "20_m_num_vs_vt.pdf"
#set terminal postscript eps color solid font "Times New Roman, 20"
set terminal postscript eps color solid
#set terminal emf color solid enhanced font "Times New Roman, 20"
set output "100_f_num_vs_pdetect.eps"
#set terminal qt font "Times New Roman, 20"
#set xlabel "{/SimSun=20 空洞数量}"
set xlabel "Mean of Noise"
set xrange [0.1:0.3]
set xtics 0.05
set mxtics 1
#set ylabel "{/SimSun=20 有效监测时间率 (%)}"
set ylabel "Detection Probability (%)"
set yrange [0:100]
set ytics 20
set mytics 1
set format y "%.2f"
set grid
set key box
set key Left
#set key width 10
#set key spacing 10
#set key left top at 41, 89
plot "mean-pro_vs_pd" u 1:($2*100) w lp lt 1 lw 2 pt 5 ps 2 title "PD", \
     "mean-maj_vs_pd" u 1:($2*100) w lp lt 2 lw 2 pt 2 ps 2 title "MD", \
     "mean-cls_vs_pd" u 1:($2*100) w lp lt 3 lw 2 pt 3 ps 2 title "CD"
set output
#!pdftops -eps 20_m_num_vs_vt.pdf