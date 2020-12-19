# MDT_AUTOLOGON  

## Introduction  
MDT_AUTOLOGON et un programme réalisé en code AutoIT 3. Il a pour objectif de configurer un poste en ouverture de session automatique pour par exemple, le mettre en mode kiosque.  

MDT_AUTOLOGON ne stocke pas le mot de passe de session utilisateur en clair dans la valeur de registre "DefaultPassword" située dans "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon". En lieu et place, il utilise la fonction "LsaStorePrivateData" du module WIN32 "Advapi32.lib" qui va permettre de stocker le mot de passe chiffré dans une valeur présente dans une sous-clé de "HKEY_LOCAL_MACHINE\SECURITY\Policy\Secrets".  

Bien qu'il existe un programme similaire de Microsoft Sysinternals nommé "autologon", MDT_AUTOLOGON a pour objectif d'être intégré en fin de séquence de tâche MDT pour réaliser une configuration "d'autologon" de manière automatisée. En effet, lorsque qu'un déploiement MDT se termine, un script de nettoyage nommé "LTICleanup.wsf" se lance et effectue entre autres, un nettoyage des valeurs de registre d'autologon présentes dans "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon". Ce qui empêche l'automatisation de cette tâche. Il existe une astuce consistant à modifier les fichiers de scripts MDT, mais ne voulant pas altérer le code source de MDT, j'ai décidé d'utiliser un script AutoIT pour réaliser cette opération. Lorsque lancé, MDT_AUTOLOGON va attendre la fin des processus de déploiement MDT sur le poste client pour commencer l'application des paramètres d'ouverture de session automatique.  

AutoIT étant un langage de programmation assez simple, le code source présent dans ce dépot permet aux administrateurs systèmes de personnaliser le code selon leurs souhaits et de générer leur propre exécutable à l'aide de `SciTE Script Editor` disponible à l'adresse suivante :  
https://www.autoitscript.com/site/autoit-script-editor/downloads/


## Utilisation
### Pré-requis
Nécessite `powershell v2` d'installé sur le poste exécutant le programme.  
Nécessite d'être `Exécuter en tant qu'administrateur`  

### Commande
MDT_AUTOLOGON s'utilise comme suit depuis une ligne de commande `cmd` :  
`MDT_AUTOLOGON.exe <user> <password> <domain>`  
Exemple :  
`MDT_AUTOLOGON.exe toto totopass totodomain`

Le paramètre `<domain>` est facultatif si l'utilisateur est un compte local du poste.  

### Cas particulier
Si un ou plusieurs des paramètres utilisés en ligne commande comportent un ou plusieurs guillemets, ceux-ci doivent être échappés.  
Exemple pour un mot de passe `"totopass"` :  
`MDT_AUTOLOGON.exe toto """totopass""" totodomain`  

### Integration à une séquence de tâches MDT
En fin de séquence, créez une nouvelle étape du type `Run Command Line`  

Dans le champ "Command Line", tapez une commande du même genre :  
`cmd.exe /C start %SCRIPTROOT%\MDT_AUTOLOGON.exe toto totopass totodomain`  

Ou %SCRIPTROOT% correspond au dossier "Scripts" de votre "DeploymentShare" ou est stocké votre exécutable.  

#### Dans une séquence de tâches MDT, il ne faut pas lancer l'exécutable directement dans une etape `Run Command Line` sinon l'étape ne se terminera jamais. Utilisez `cmd.exe /C start`

