## Setting up FileGameVersion:
```
To include the correct game version follow the following steps:

Recommended, but optional:
1) Install a virtual environment for python 
    python -m venv .\EnvironmentName
2) Activate the environment
    .\EnvironmentName\Scripts\Activate.ps1

Installing required packages and updating GameSettings.json:
1) Install prerequisite packages
    pip install wheel 
2) Install pythonnet
    pip install pythonnet
3) Create a GameLocation.json using your own game file locations following the format:
{
    "32bit" : "C:\\GameLocation\\IdleDragons_Data\\Managed\\Assembly-CSharp.dll",
    "64bit" : "C:\\OtherGameLocation\\IdleDragons_Data\\Managed\\Assembly-CSharp.dll",
}
See GameLocations_Sample.json for an example. 
4) Run ScriptHubImporter.py again
```