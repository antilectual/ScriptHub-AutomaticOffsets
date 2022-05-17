# Script Hub Importer

## Exporting via cheat engine:
* Place ScriptHubExport.lua in Cheat Engine's .\autorun folder while Cheat Engine is closed.
* Run Cheat Engine
* Open the game's process in cheat engine.
* Go to the Script Hub menu item in Cheat Engine and choose Export.
* Select a location to save the exported json file.
* Wait patiently as the script can take several minutes to complete the export and CE will be frozen during this time.

## Importing using ScriptHubImporter.py:
> Note: Before continuing, ensure Script Hub has been updated to have the automatic offsets update.  

> Note: Requires [Python](https://www.python.org/) v3.9.2 or later to run. 
* Copy the exported json to the same folder as ``ScriptHubImporter.py`` replacing ScriptHubExport``32``.json or ScriptHubExport``64``.json depending on if you are exporting from steam (``32``) or EGS (``64``)
* Run ``ScriptHubImporter.py``
* Copy the resulting ``Imports`` folder and files to Script Hub's ``.\SharedFunctions\MemoryRead\`` directory. *
* Start Script Hub.

> * Note: Alternatively ``ScriptHubImporter.py`` along with the ``MemoryLocations`` txt files and the ``ScriptHubExport`` json files may be placed in the ``.\SharedFunctions\MemoryRead\`` directory of Script Hub and run from there.

## Troubleshooting:
 ``game.gameInstances.Controller.userData.HeroHandler.heroes.[_level]`` or ``game.gameInstances.Controller.userData.HeroHandler.heroes.[<Level>k__BackingField]`` are not being found.  

* These are the same variable which was renamed. Both are being kept for backwards compatability to older DLL versions. If you wish to not see the error anymore, you can remove the associated line from the ``MemoryLocations_IdleGameManager.txt`` file.  

When running the script, the window immediately closes.  

* If the script runs successfully it will wait for a keypress before closing. If it is not then the script likely had an error and exited. Run the script from a command prompt/powershell window to see the error.

The script worked before a game update but after there are multiple ``--ERROR--`` in the FullMemoryRead addon, even after importing pointers.

* This typically means the pointers changed and not just the offsets.\
\
To update pointers in ``IdleGameManager`` and other dynamic pointers follow the instructions here:\
https://github.com/mikebaldi/Idle-Champions/blob/main/Pointers.pdf  
\
If you are familiar with that, then to update pointers in ``CrusadersGameDataSet``, ``DialogManager``, ``EngineSettings``, ``GameSettings`` and other static pointers follow the instructions here**:\
https://github.com/mikebaldi/Idle-Champions/blob/main/GameSettingsStaticInstructions.pdf  

  
> ** Note: The instructions say you typically only need a depth of 2 for static, but be aware sometimes it may require more. As of v435 Steam is using a pointer with a depth of 5.  
  
  \
Which pointer is causing the problem?

* If errors show up in functions referencing **Favor** or **Blessings** then the problem is likely in ``DialogManager``\
\
If errors show up in multiple functions referencing **Chests** then the problem is likely in ``CrusadersGameDialogSet``\
\
If **webroot** cannot be found, there is an issue with ``EngineSettings``\
\
If **UserID**, **Hash**, or **Game version** are not working there is an issue with ``GameSettings``\
\
Most other problems will be in ``IdleGameManager``\
\
The relevent files will be found in ``.\SharedFunctions\MemoryRead\`` using a format of ``IC_[NAME]_Class.ahk`` where ``[NAME]`` is one of the above. E.G. ``IC_DialogManager_Class.ahk``
