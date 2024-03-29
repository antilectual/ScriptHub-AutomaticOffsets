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

`UPDATE 2023-04-25` ScriptHubExport.lua has been updated to be much faster. Depending on the speed of your system it may take as few as 10s!

`UPDATE 2022-07-27` ScriptHubExport.lua has been updated so update the script in your Cheat Engine autorun folder! With this change, the ScriptHubImporter.py script no longer requires wheel or pythonnet. (Special thanks to Ismo for helping with this!)

> Note: Requires [Python](https://www.python.org/) v3.9.2 or later to run.  
  

* Copy the exported json to the same folder as ``ScriptHubImporter.py`` replacing ScriptHubExport``32``.json or ScriptHubExport``64``.json depending on if you are exporting from steam (~~``32``~~) (``64``) or EGS (``64``)
  > Note: In late 2022 all PC platforms have switched to using the ``64`` bit versions of the game.   
* Run ``ScriptHubImporter.py``
* Copy the resulting ``Imports`` folder and files to Script Hub's ``[Script Hub Folder]\AddOns\IC_Core\MemoryRead\`` directory. *
* Start Script Hub.

> * Note: Alternatively ``ScriptHubImporter.py`` along with the ``MemoryLocations`` txt files and the ``ScriptHubExport`` json files may be placed in the ``[Script Hub Folder]\AddOns\IC_Core\MemoryRead\`` directory of Script Hub and run from there.

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
The relevent files will be found in ``[Script Hub Folder]\AddOns\IC_Core\MemoryRead\`` using a format of ``IC_[NAME]_Class.ahk`` where ``[NAME]`` is one of the above. E.G. ``IC_DialogManager_Class.ahk``

Script Hub is almost all ``-- ERROR --`` in FullMemoryFunctions after importing.

* First, make sure the ``Import`` files are in the correct locations.\
\
Using an old version of Python could cause the AHK files to build offsets out of order and they won't load correctly in ScriptHhub. Versions 3.10.4 and 3.9.2 have been verified to work correctly. Type ``python -V`` in a cmd or powershell window to see the version.