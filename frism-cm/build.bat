@echo off

rem Directory class path
set CLS_PS=.;./bin

rem Agent class path
set CLS_PS=%CLS_PS%;./lib/com.fowave.frism.api.all.3.0.1-7.jar
set CLS_PS=%CLS_PS%;./lib/com.kbcard.frism.api.jar

rem Cross-compile for JDK 1.8 runtime (--release 8) and force source encoding to EUC-KR
javac --release 8 -encoding EUC-KR -classpath %CLS_PS% -d ./bin ./src/com/kbcard/exception/BizException.java
javac --release 8 -encoding EUC-KR -classpath %CLS_PS% -d ./bin ./src/com/kbcard/cm/util/UtilCmData.java
javac --release 8 -encoding EUC-KR -classpath %CLS_PS% -d ./bin ./src/com/kbcard/cm/util/UtilCm.java
javac --release 8 -encoding EUC-KR -classpath %CLS_PS% -d ./bin ./src/com/kbcard/cm/cli/CmCli.java
javac --release 8 -encoding EUC-KR -classpath %CLS_PS% -d ./bin ./src/com/kbcard/sample/SampleCm.java