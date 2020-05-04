---------------------------------------------------------------------------------
-- Arcade: Robotron port to MiSTer by oldgit, Sorgelig
-- 12 December 2018
-- 
---------------------------------------------------------------------------------
-- gen_ram.vhd
-------------------------------- 
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
---------------------------------------------------------------------------------
-- cpu09l - Version : 0128
-- Synthesizable 6809 instruction compatible VHDL CPU core
-- Copyright (C) 2003 - 2010 John Kent
---------------------------------------------------------------------------------
-- cpu68 - Version 9th Jan 2004 0.8
-- 6800/01 compatible CPU core 
-- GNU public license - December 2002 : John E. Kent
---------------------------------------------------------------------------------
--
-- This port is only possible because of previous work by many many others - Thank You
-- to find out more search "Williams robotron" on a search engine.  
-- 
-- 
-- Keyboard players inputs :
--
--   F10 : Advance
--   F9  : Auto up
--   F7  : High score reset
--   F5  : Add coin right
--   F4  : Add coin centre
--   F3  : Add coin left
--   F2  : Start 2 players
--   F1  : Start 1 player
--   ESC : Slam  
--   W move up
--   S move down
--   A move left
--   D move right
--   UP arrow Fire up
--   Down arrow Fire Down
--	 Left arrow Fir Left
-- 	 Right arrow Fire right
--
--
-- Joystick support.
-- 
-- 
---------------------------------------------------------------------------------

                                *** Attention ***

ROMs are not included. In order to use this arcade, you need to provide the
correct ROMs.

To simplify the process .mra files are provided in the releases folder, that
specifies the required ROMs with checksums. The ROMs .zip filename refers to the
corresponding file of the M.A.M.E. project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for
information on how to setup and use the environment.

Quickreference for folders and file placement:

/_Arcade/<game name>.mra
/_Arcade/cores/<game rbf>.rbf
/_Arcade/mame/<mame rom>.zip
/_Arcade/hbmame/<hbmame rom>.zip
