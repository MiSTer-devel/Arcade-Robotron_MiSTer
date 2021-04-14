# [Arcade: Robotron](https://en.wikipedia.org/wiki/Robotron:_2084) port to [MiSTer](https://github.com/MiSTer-devel/Main_MiSTer/wiki) 

MiSTer port by oldgit(davewoo999) and Sorgelig  
12 December 2018

This port is only possible because of previous work by many many others - Thank You

## Description

A simulation model of the Williams Electronics Robotron: 2084 arcade hardware. Click the wikipedia link in the title for more information or search "williams robotron" in your favorite search engine to learn more.

## Games

* Stargate
* Robotron
* Joust
* Bubbles
* Splat!
* Sinistar
* PlayBall!

## ROM Files Instructions

**ROMs are not included!** In order to use this arcade core, you will need to provide the correct ROM file yourself.

To simplify the process .mra files are provided in the releases folder, that specify the required ROMs with their checksums. The ROMs .zip filename refers to the
corresponding file from the MAME project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for information on how to setup and use the environment.

Quick reference for folders and file placement:

```
/_Arcade/<game name>.mra  
/_Arcade/cores/<game rbf>.rbf  
/_Arcade/mame/<mame rom>.zip  
/_Arcade/hbmame/<hbmame rom>.zip  
```

## Copyright and Licenses

```
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
```