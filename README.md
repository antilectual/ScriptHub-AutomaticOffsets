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

> Note: Requires [Python](https://www.python.org/) to run. 
* Copy the exported json to the same folder as ``ScriptHubImporter.py``
* Rename the json to ScriptHubExport32.json or ScriptHubExport64.json depending on if you are exporting from steam (32) or EGS (64)
* Run ``ScriptHubImporter.py``
* Copy the resulting ``Imports`` folder and files to Script Hub's ``.\SharedFunctions\MemoryRead\`` directory.
* Start Script Hub.