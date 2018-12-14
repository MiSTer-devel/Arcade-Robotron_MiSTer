@echo off

set    zip=robotron.zip
set ifiles=robotron.sba+robotron.sbb+robotron.sbc+robotron.sb1+robotron.sb2+robotron.sb3+robotron.sb4+robotron.sb5+robotron.sb6+robotron.sb7+robotron.sb8+robotron.sb9+robotron.snd+decoder.4+decoder.6
set  ofile=a.robtrn.rom

rem =====================================
setlocal ENABLEDELAYEDEXPANSION

set pwd=%~dp0
echo.
echo.

if EXIST %zip% (

	!pwd!7za x -otmp %zip%
	if !ERRORLEVEL! EQU 0 ( 
		cd tmp

		copy /b/y %ifiles% !pwd!%ofile%
		if !ERRORLEVEL! EQU 0 ( 
			echo.
			echo ** done **
			echo.
			echo Copy "%ofile%" into root of SD card
		)
		cd !pwd!
		rmdir /s /q tmp
	)

) else (

	echo Error: Cannot find "%zip%" file
	echo.
	echo Put "%zip%", "7za.exe" and "%~nx0" into the same directory
)

echo.
echo.
pause
