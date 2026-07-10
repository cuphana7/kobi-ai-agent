@echo off

rem Directory class path
set CLS_PS=.;./bin

rem Agent class path
set CLS_PS=%CLS_PS%;./lib/com.fowave.frism.api.all.3.0.1-7.jar
set CLS_PS=%CLS_PS%;./lib/com.kbcard.frism.api.jar

javac -classpath %CLS_PS% -d ./bin ./src/com/kbcard/exception/BizException.java
javac -classpath %CLS_PS% -d ./bin ./src/com/kbcard/cm/util/UtilCmData.java
javac -classpath %CLS_PS% -d ./bin ./src/com/kbcard/cm/util/UtilCm.java
javac -classpath %CLS_PS% -d ./bin ./src/com/kbcard/sample/SampleCm.java