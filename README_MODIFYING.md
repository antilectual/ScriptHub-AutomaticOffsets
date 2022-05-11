# Modifying Script Hub Importer

## Intro
Occasionally there will be times where new objects are needed, such as new champion event handlers. This readme explains how to update the script to include these new objects.

## Instructions

### Add .txt file(s)
* The first step is creating the .txt file that will include the offsets for that object. The .txt file name will need to be in the form of MemoryFunctions_``[ClassName]``.txt. (e.g. To add ``CrusadersGame.Defs.CrusadersGameDataSet`` the file MemoryLocations_``CrusadersGameDataSet``.txt will be needed.)

### Add Offsets to the .txt file
* Once the text file is created, offsets may be added by by adding a dot chain of the variable's location that an offset is needed for, starting from the class being imported. For example, to add the ID of chests from CrusadersGameData set, simply add ``ChestTypeDefines.ID`` to the ``MemoryLocations_CrusadersGameDataSet.txt`` file. ``ChestTypeDefines`` by itself is not needed as the script will automatically add the appropriate offsets for each item in the dot chain.

### Add class to the python script for reading.
* The second step is adding the class to the python script so it knows to read it. At the top of ScriptHubImporter.py are lines that append classes to a list of objects that are read throughout the script. Using the example aboove, to add ``CrusadersGame.Defs.CrusadersGameDataSet`` you would add the line 
``baseClassTypeList.append("CrusadersGame.Defs.CrusadersGameDataSet")`` to the top of the script. It will then automatically read the MemoryLocations_``CrusadersGameDataSet``.txt file to load offsets.

* ``ActiveEffectHandlers`` are special cases in ScriptHub and need to be imported slightly differently. Due to this, the added line in ScriptHubImporter.py will need to be added using ``effectClassTypeList`` instead. (e.g. importing ``CrusadersGame.Effects.HavilarImpHandler`` would require the line ``effectClassTypeList.append("CrusadersGame.Effects.HavilarImpHandler")`` instead of using baseClassTypeList).