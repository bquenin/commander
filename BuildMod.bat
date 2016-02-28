@echo off

set CNC3_HOME="%USERPROFILE%\Documents\Command & Conquer 3 Tiberium Wars"

@echo Mod Name: %1
@echo Building Mod Data...
tools\binaryAssetBuilder.exe "%cd%\Mods\%1\data\mod.xml" /od:"%cd%\BuiltMods" /iod:"%cd%\BuiltMods" /ls:true /gui:false /UsePrecompiled:true /vf:true

@echo Building Low LOD...
tools\binaryAssetBuilder.exe "%cd%\Mods\%1\data\mod.xml" /od:"%cd%\BuiltMods" /iod:"%cd%\BuiltMods" /ls:true /gui:false /UsePrecompiled:true /vf:true /bcn:LowLOD /bps:"%cd%\BuiltMods\mods\%1\data\mod.manifest"

@echo Copying str file if it exists...
IF EXIST "%cd%\Mods\%1\data\mod.str" copy "%cd%\Mods\%1\data\mod.str" "%cd%\BuiltMods\mods\%1\data"
del "%cd%\Builtmods\mods\%1\data\mod_l.version"

@echo Creating Mod Big File...
tools\MakeBig.exe -f "%cd%\BuiltMods\mods\%1" -x:*.asset -o:"%cd%\BuiltMods\mods\%1.big"

@echo Copying built mod...
IF NOT EXIST %CNC3_HOME%\mods md %CNC3_HOME%\mods
IF NOT EXIST %CNC3_HOME%\mods\%1 md %CNC3_HOME%\mods\%1
copy "builtmods\mods\%1.big" %CNC3_HOME%\mods\%1
copy "mods\%1_*.skudef" %CNC3_HOME%\mods\%1
