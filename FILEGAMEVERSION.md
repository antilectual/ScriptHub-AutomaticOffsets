## Setting up FileGameVersion:
```
To include the correct game version follow the following steps:
1) Install a virtual environment for python 
    python -m venv .\EnvironmentName
2) Activate the environment
    .\EnvironmentName\Scripts\Activate.ps1
3) Install prerequisite packages
    pip install wheel 
4) Install pythonnet
    pip install pythonnet
5) Create a GameLocation.json using your own game file locations following the format:
{
    "32bit" : "C:\\GameLocation\\IdleDragons_Data\\Managed\\Assembly-CSharp.dll",
    "64bit" : "C:\\OtherGameLocation\\IdleDragons_Data\\Managed\\Assembly-CSharp.dll",
}
6) Run ScriptHubImporter.py again
```