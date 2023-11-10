# Modifying Script Hub Importer

## Intro
Occasionally there will be times where new objects are needed, such as new champion event handlers. This readme explains how to update the script to include these new objects.

## Instructions
## Determine type of class being added
Classes that are added ``ActiveEffectHandler`` require special attention. These are typically used for champion specific abilities such as their ultimates. If the class is an ``ActiveEffectHandler`` the settings file will need to be added to the ``Settings_EffectClassTypeList`` folder. Otherwise it will belong in the ``Settings_BaseClassTypeList`` folder.

### Add .txt file(s)
* The first step is creating the settings .txt file that will include the offsets for that object. The .txt file name will need to be in the form of MemoryFunctions_``[ClassName]``.txt. (e.g. To add ``CrusadersGame.Defs.CrusadersGameDataSet`` the file MemoryLocations_``CrusadersGameDataSet``.txt will be needed.)

> Note: Since update, the name restrictions on the file are no longer required as long as it ends in .txt. However, the class is now required to be added to a comment in the file as described in the next step.

### Add class to the text file.
Once the text file is created, to know where to look, the script must know the class in which the the variables are stored. Add this to the top of the section using ``#!``. (e.g. ``#! CrusadersGame.Defs.CrusadersGameDataSet``).

### Add Offsets to the .txt file
* After adding the class the offsets may be added by by adding a dot chain of the variable's location that an offset is needed for, starting from the class being imported. For example, to add the ID of chests from CrusadersGameData set, simply add ``ChestTypeDefines.ID`` to the ``MemoryLocations_CrusadersGameDataSet.txt`` file. ``ChestTypeDefines`` by itself is not needed as the script will automatically add the appropriate offsets for each item in the dot chain.

* ``ActiveEffectHandlers`` are special cases in ScriptHub and need to be imported slightly differently. Due to this, the added line in ScriptHubImporter.py will need to be added using ``effectClassTypeList`` instead. (e.g. importing ``CrusadersGame.Effects.HavilarImpHandler`` would require the line ``effectClassTypeList.append("CrusadersGame.Effects.HavilarImpHandler")`` instead of using baseClassTypeList).