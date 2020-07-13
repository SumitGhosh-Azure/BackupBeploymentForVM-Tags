This helps in automating backup deployments of Azure virtual machines based on the TAGS assigned to them.

Please find the following Script files in repository to automate the process:
1.	BackupParentScript
2.	BackupChildScript
3.	Export RunAsAccount Cert to Hybrid worker
4.	Sample JSON File

Please make sure the following requirements are met for these scripts to run:

•	When you deploy a Automation account, make sure you create a RunAsAccount along with it, so that scripts don’t need authentication while running.
•	The Parent Script can only work on a Hybrid Worker machine and not on Azure Sandbox.

        $vmlist= Get-AzureStorageBlobContent    -Context $Context `
        -Container 'backupdata'  -Blob 'BackupDataVM.json' -Destination "C:\Program Files\" -Force
        $vmlistJson = Get-Content -Path "C:\Program Files\BackupDataVM.json" | ConvertFrom-Json

•	This part of the script is fetching the Input JSON file from a Azure storage account and saving it on Worker Machine, before converting the JSON to PS Object. Since Azure Sandbox does not give us this liberty, we need to use         Hybrid Workers. 

•	If customers do not want to use Hybrid worker, they can host the .Json file on GitHub(Private Repo). Though it is a best practice to host your data in your storage account and not GitHub.
•	$StorageAccountKey = Get-AutomationVariable -Name 'storageKey'   ## Make sure the Key Is stored as a Variable in Automation account and not directly in the script as it is a security compliance.
•	Make changes to the parent script depending upon the Automation account name, storage account name and the name of Runbooks.
•	Parent Script has a command: Start-Sleep -s 15   # This basically is the time for the script to sleep, so that the JSON file from Storage account is downloaded in a Hybrid worker Machine. If the Json file is large or network         connectivity is a constraint, increase the sleep time from 15 second.
•	Make sure Hybrid worker has “AzureRM” Modules.
•	Run as Account, Certificates should be exported to the Hybrid worked roles using the Export Cert script attached to the mail. Please run this script from Automation account, selecting Hybrid worker groups you plan to run the         backup scripts from.
•	Automation account should have Recovery services modules, specially Backup modules.
•	You need to upload the JSON file to one of the storage accounts with Public access, prior to running the script from Automation account, and modify the storage account details accordingly in the Parent script.
•	Child Script has $Tag variable which as of now is looking for a TAG named “Sumit” in Azure VM’s. Make sure you change the TAG name accordingly in the script as per customer requirements.

Here are some links which may help you in configuring the environment to run these scripts:

	Register a machine to Log Analytics Workspace: https://docs.microsoft.com/en-us/azure/azure-monitor/platform/agent-windows
	Enable your Log Analytics account to support Hybrid workers: https://docs.microsoft.com/en-us/azure/automation/automation-windows-hrw-install#manual-deployment
	Register your MMA agent in VM to register to a Automation account as Hybrid Worker: https://docs.microsoft.com/en-us/azure/automation/automation-windows-hrw-install#manual-deployment 
	Upgrade your WMF on VM according to the guest OS: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-windows-powershell?view=powershell-6#upgrading-existing-windows-powershell
	To install the “AzureRM” modules in your Hybrid Worker use:  Install-Module -Name AzureRM -AllowClobber -Scope AllUsers


