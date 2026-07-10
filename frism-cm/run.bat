@echo off

rem Directory class path
set CLS_PS=.;./bin

rem Dependencies class path (run time)
set CLS_PS=%CLS_PS%;./lib/ojdbc8.jar
set CLS_PS=%CLS_PS%;./lib/orai18n.jar

rem Agent class path
set CLS_PS=%CLS_PS%;./lib/com.fowave.frism.api.all.3.0.1-7.jar
set CLS_PS=%CLS_PS%;./lib/com.kbcard.frism.api.jar

java -classpath %CLS_PS% com.kbcard.sample.SampleCm