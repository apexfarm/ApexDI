# force:package:create only execute for the first time
# sfdx force:package:create -n ApexDI -t Unlocked -r apex-di
sfdx force:package:version:create -p ApexDI -x -c --wait 10 --code-coverage
sfdx force:package:version:list
sfdx force:package:version:promote -p 04tGC000007TOgUYAW
sfdx force:package:version:report -p 04tGC000007TOgUYAW

