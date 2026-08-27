/*
[INFO]
NAME=Archviz Project Builder
VERSION=x.x.x
AUTHOR=Vasyl Lukianenko
DEV=https://3dground.net
SITE=https://maxpkg.dev
HELP=
UPDATE=

[ABOUT]
Create and reuse custom folder structures for architectural visualization projects directly in 3ds Max.=

[1.0.0]
* Initial release =

[SCRIPT]
*/

(
    try (closeRolloutFloater AVP_Floater) catch()

    global AVP_Floater
    global AVP_MainRollout
    global AVP_IORollout
    global AVP_AboutRollout
    global AVP_NamePromptRollout
    global AVP_ConfirmRollout
    global AVP_ConfirmResult
    global AVP_ConfirmText
    global AVP_ConfirmTitle
    global AVP_PromptResult
    global AVP_PromptText
    global AVP_PromptDefault
    global AVP_Node
    global AVP_Nodes = #()
    global AVP_VisibleIds = #()
    global AVP_NextId = 1
    global AVP_ScriptFile
    global AVP_IniFile

    global AVP_ScriptName = "Archviz Project Builder"
    global AVP_ScriptVersion = "1.0.1"
    global AVP_ScriptDeveloper = "Lukianenko Vasyl"

    global AVP_UChar
    global AVP_Tee
    global AVP_Last
    global AVP_Line
    global AVP_FindNode
    global AVP_Children
    global AVP_NameExists
    global AVP_ValidFolderName
    global AVP_AddNode
    global AVP_LoadDefaults
    global AVP_BuildTreeLines
    global AVP_RefreshTree
    global AVP_SelectedNode
    global AVP_CollectBranch
    global AVP_RemoveNode
    global AVP_SaveStructure
    global AVP_NodeArrayIsValid
    global AVP_LoadStructure
    global AVP_SaveSettings
    global AVP_SaveWindowPosition
    global AVP_LoadWindowPosition
    global AVP_AskFolderName
    global AVP_NodeRelativePath
    global AVP_CreateDirectories
    global AVP_AskConfirmation
    global AVP_SetStatus
    struct AVP_Node (id, parentId, name)

    AVP_ScriptFile = getSourceFileName()
    if AVP_ScriptFile == undefined or AVP_ScriptFile == "" then
        AVP_ScriptFile = (getDir #userScripts) + "\\ArchvizProjectBuilder.ms"
    AVP_IniFile = (getFilenamePath AVP_ScriptFile) + "ArchvizProjectBuilder.ini"

    fn AVP_UChar code =
    (
        ((dotNetClass "System.Char").ConvertFromUtf32 code)
    )

    fn AVP_Tee = ((AVP_UChar 9500) + (AVP_UChar 9472) + " ")
    fn AVP_Last = ((AVP_UChar 9492) + (AVP_UChar 9472) + " ")
    fn AVP_Line = ((AVP_UChar 9474) + "  ")

    fn AVP_FindNode nodeId nodes:AVP_Nodes =
    (
        for n in nodes where n.id == nodeId do return n
        undefined
    )

    fn AVP_Children parentId nodes:AVP_Nodes =
    (
        for n in nodes where n.parentId == parentId collect n
    )

    fn AVP_NameExists folderName parentId nodes:AVP_Nodes =
    (
        local wanted = toLower folderName
        for n in nodes where n.parentId == parentId do
            if (toLower n.name) == wanted do return true
        false
    )

    fn AVP_ValidFolderName folderName =
    (
        if folderName == undefined then return false
        if folderName == "" or folderName == "." or folderName == ".." then return false
        local invalidChars = #("\\", "/", ":", "*", "?", "\"", "<", ">", "|")
        for ch in invalidChars where (findString folderName ch) != undefined do return false
        true
    )

    fn AVP_SetStatus messageText =
    (
        try (AVP_MainRollout.lblStatus.text = messageText) catch()
        messageText
    )
    fn AVP_AddNode folderName parentId:0 saveAfter:true refreshAfter:true =
    (
        if not (AVP_ValidFolderName folderName) then
        (
            AVP_SetStatus "Invalid folder name."
            return undefined
        )
        if AVP_NameExists folderName parentId then
        (
            AVP_SetStatus "A folder with this name already exists at this level."
            return undefined
        )

        local newNode = AVP_Node id:AVP_NextId parentId:parentId name:folderName
        AVP_NextId += 1
        append AVP_Nodes newNode
        if saveAfter do AVP_SaveSettings()
        if refreshAfter do AVP_RefreshTree selectId:newNode.id
                AVP_SetStatus ("Added: " + folderName)
        newNode
    )

    fn AVP_LoadDefaults =
    (
        AVP_Nodes = #()
        AVP_NextId = 1

        AVP_AddNode "scenes" saveAfter:false refreshAfter:false
        AVP_AddNode "models" saveAfter:false refreshAfter:false
        AVP_AddNode "proxy" saveAfter:false refreshAfter:false
        AVP_AddNode "maps" saveAfter:false refreshAfter:false
        AVP_AddNode "reference" saveAfter:false refreshAfter:false
        local rendersNode = AVP_AddNode "renders" saveAfter:false refreshAfter:false
        AVP_AddNode "previews" parentId:rendersNode.id saveAfter:false refreshAfter:false
        AVP_AddNode "final" parentId:rendersNode.id saveAfter:false refreshAfter:false
        AVP_AddNode "post" saveAfter:false refreshAfter:false
        AVP_AddNode "temp" saveAfter:false refreshAfter:false
        AVP_AddNode "delivery" saveAfter:false refreshAfter:false
    )

    fn AVP_BuildTreeLines parentId prefix &lines &ids =
    (
        local children = AVP_Children parentId
        for i = 1 to children.count do
        (
            local child = children[i]
            local isLast = (i == children.count)
            append lines (prefix + (if isLast then AVP_Last() else AVP_Tee()) + child.name)
            append ids child.id
            local childPrefix = prefix + (if isLast then "   " else AVP_Line())
            AVP_BuildTreeLines child.id childPrefix &lines &ids
        )
    )

    fn AVP_RefreshTree selectId:0 =
    (
        local lines = #()
        local ids = #()
        AVP_BuildTreeLines 0 "" &lines &ids
        AVP_VisibleIds = ids

        try
        (
            AVP_MainRollout.lstStructure.items = lines
            if selectId != 0 then
            (
                local idx = findItem ids selectId
                if idx > 0 do AVP_MainRollout.lstStructure.selection = idx
            )
            else if lines.count > 0 do AVP_MainRollout.lstStructure.selection = 1
        )
        catch()
    )

    fn AVP_SelectedNode =
    (
        try
        (
            local idx = AVP_MainRollout.lstStructure.selection
            if idx > 0 and idx <= AVP_VisibleIds.count then
                return AVP_FindNode AVP_VisibleIds[idx]
        )
        catch()
        undefined
    )

    fn AVP_CollectBranch nodeId &ids =
    (
        appendIfUnique ids nodeId
        for child in (AVP_Children nodeId) do AVP_CollectBranch child.id &ids
    )

    fn AVP_RemoveNode nodeId =
    (
        local node = AVP_FindNode nodeId
        if node == undefined then return false
        local removeIds = #()
        AVP_CollectBranch nodeId &removeIds
        AVP_Nodes = for n in AVP_Nodes where (findItem removeIds n.id) == 0 collect n
        AVP_SaveSettings()
        AVP_RefreshTree()
                AVP_SetStatus ("Removed: " + node.name)
        true
    )

    fn AVP_SaveStructure fileName =
    (
        if fileName == undefined or fileName == "" then return false
        setIniSetting fileName "Structure" "FormatVersion" "1"
        setIniSetting fileName "Structure" "Count" (AVP_Nodes.count as string)
        for i = 1 to AVP_Nodes.count do
        (
            local n = AVP_Nodes[i]
            local value = (n.id as string) + "|" + (n.parentId as string) + "|" + n.name
            setIniSetting fileName "Structure" ("Node" + i as string) value
        )
        true
    )

    fn AVP_NodeArrayIsValid nodes =
    (
        if nodes.count == 0 then return false

        for n in nodes do
        (
            if n.id <= 0 or n.parentId == n.id or not (AVP_ValidFolderName n.name) then return false
            local idMatches = 0
            for checkNode in nodes where checkNode.id == n.id do idMatches += 1
            if idMatches != 1 then return false
            if n.parentId != 0 and (AVP_FindNode n.parentId nodes:nodes) == undefined then return false

            local sameNameCount = 0
            for checkNode in nodes where checkNode.parentId == n.parentId and (toLower checkNode.name) == (toLower n.name) do sameNameCount += 1
            if sameNameCount != 1 then return false

            local seen = #()
            local cursor = n
            while cursor.parentId != 0 do
            (
                if (findItem seen cursor.id) > 0 then return false
                append seen cursor.id
                cursor = AVP_FindNode cursor.parentId nodes:nodes
                if cursor == undefined then return false
            )
        )
        true
    )

    fn AVP_LoadStructure fileName showError:true =
    (
        if fileName == undefined or fileName == "" or not (doesFileExist fileName) then return false
        local countText = getIniSetting fileName "Structure" "Count"
        if countText == "" then return false
        local nodeCount = countText as integer
        if nodeCount < 1 then return false

        local loadedNodes = #()
        local highestId = 0
        for i = 1 to nodeCount do
        (
            local row = getIniSetting fileName "Structure" ("Node" + i as string)
            local parts = filterString row "|"
            if parts.count != 3 then
            (
                if showError do messageBox "The selected structure file is damaged or has an unsupported format." title:"Import failed"
                return false
            )
            local nodeId = parts[1] as integer
            local parentId = parts[2] as integer
            local folderName = parts[3]
            append loadedNodes (AVP_Node id:nodeId parentId:parentId name:folderName)
            if nodeId > highestId do highestId = nodeId
        )

        if not (AVP_NodeArrayIsValid loadedNodes) then
        (
            if showError do messageBox "The structure contains invalid names, duplicate IDs, missing parents, or a hierarchy cycle." title:"Import failed"
            return false
        )

        AVP_Nodes = loadedNodes
        AVP_NextId = highestId + 1
        true
    )

    fn AVP_SaveSettings =
    (
        try
        (
            AVP_SaveStructure AVP_IniFile
            if AVP_MainRollout.edtRoot.text != undefined do
                setIniSetting AVP_IniFile "Project" "LastRoot" AVP_MainRollout.edtRoot.text
        )
        catch()
    )

    fn AVP_SaveWindowPosition =
    (
        try
        (
            local p = AVP_Floater.pos
            setIniSetting AVP_IniFile "Window" "X" (p.x as string)
            setIniSetting AVP_IniFile "Window" "Y" (p.y as string)
            AVP_SaveSettings()
        )
        catch()
    )

    fn AVP_LoadWindowPosition =
    (
        local xText = getIniSetting AVP_IniFile "Window" "X"
        local yText = getIniSetting AVP_IniFile "Window" "Y"
        local x = if xText == "" then 120 else xText as integer
        local y = if yText == "" then 120 else yText as integer
        if x < -100 then x = 50
        if y < -100 then y = 50
        [x, y]
    )

    fn AVP_AskFolderName prompt defaultValue:"" =
    (
        AVP_PromptText = prompt
        AVP_PromptDefault = defaultValue
        AVP_PromptResult = undefined
        createDialog AVP_NamePromptRollout 360 112 modal:true style:#(#style_titlebar, #style_sysmenu)
        if AVP_PromptResult == undefined then "" else AVP_PromptResult
    )

    fn AVP_AskConfirmation prompt titleText:"Confirm" =
    (
        AVP_ConfirmText = prompt
        AVP_ConfirmTitle = titleText
        AVP_ConfirmResult = false
        createDialog AVP_ConfirmRollout 390 112 modal:true style:#(#style_titlebar, #style_sysmenu)
        AVP_ConfirmResult
    )
    fn AVP_NodeRelativePath nodeId =
    (
        local n = AVP_FindNode nodeId
        if n == undefined then return ""
        if n.parentId == 0 then n.name
        else ((AVP_NodeRelativePath n.parentId) + "\\" + n.name)
    )

    fn AVP_CreateDirectories rootPath =
    (
        if rootPath == undefined or rootPath == "" then
        (
            AVP_SetStatus "Select a project folder first."
            return false
        )

        local directoryClass = dotNetClass "System.IO.Directory"
        if not (directoryClass.Exists rootPath) then
        (
            AVP_SetStatus "The selected project folder does not exist."
            return false
        )

        local pathClass = dotNetClass "System.IO.Path"
        local createdCount = 0
        local existingCount = 0
        local failedNames = #()

        for n in AVP_Nodes do
        (
            local fullPath = pathClass.Combine rootPath (AVP_NodeRelativePath n.id)
            try
            (
                if directoryClass.Exists fullPath then existingCount += 1
                else
                (
                    directoryClass.CreateDirectory fullPath
                    createdCount += 1
                )
            )
            catch (append failedNames fullPath)
        )

        AVP_SaveSettings()
        local report = "Created: " + createdCount as string + " | Existing: " + existingCount as string
        if failedNames.count > 0 then report += (" | Failed: " + failedNames.count as string)
        AVP_SetStatus report
        failedNames.count == 0
    )

    rollout AVP_NamePromptRollout "Folder name"
    (
        label lblPrompt "Folder name:" width:330 align:#left
        editText edtName "" width:330
        button btnPromptOK "OK" width:158 height:26 across:2
        button btnPromptCancel "Cancel" width:158 height:26

        on AVP_NamePromptRollout open do
        (
            lblPrompt.text = AVP_PromptText
            edtName.text = AVP_PromptDefault
            setFocus edtName
        )

        on btnPromptOK pressed do
        (
            AVP_PromptResult = edtName.text
            destroyDialog AVP_NamePromptRollout
        )

        on btnPromptCancel pressed do
        (
            AVP_PromptResult = undefined
            destroyDialog AVP_NamePromptRollout
        )
    )
    rollout AVP_ConfirmRollout "Confirm"
    (
        label lblConfirm "Are you sure?" width:360 align:#center
        button btnConfirmYes "Yes" width:172 height:26 across:2
        button btnConfirmNo "Cancel" width:172 height:26

        on AVP_ConfirmRollout open do
        (
            AVP_ConfirmRollout.title = AVP_ConfirmTitle
            lblConfirm.text = AVP_ConfirmText
        )

        on btnConfirmYes pressed do
        (
            AVP_ConfirmResult = true
            destroyDialog AVP_ConfirmRollout
        )

        on btnConfirmNo pressed do
        (
            AVP_ConfirmResult = false
            destroyDialog AVP_ConfirmRollout
        )
    )
    rollout AVP_MainRollout "Project Structure"
    (
        group "Project folder"
        (
            editText edtRoot "" width:193 readOnly:true height: 21 offset: [0, 2] across:2 
            button btnBrowse "..." width: 40 height:24 align: #right
        )

        group "Folder structure"
        (
            listBox lstStructure "" width:240 height:17
            editText edtNewName "Name:" width:240
            button btnAddRoot "Add" width:72  across:3
            button btnAddChild "Subfolder" width:86
            button btnRemove "Remove" width:72 
        )

        button btnCreate "CREATE PROJECT STRUCTURE" width:240 height:38
        label lblStatus "Ready." width:240 align:#center

        on btnBrowse pressed do
        (
            local picked = undefined
            if edtRoot.text != "" and doesDirectoryExist edtRoot.text then
                picked = getSavePath caption:"Select the project folder" initialDir:(edtRoot.text as string)
            else
                picked = getSavePath caption:"Select the project folder"
            if picked != undefined do
            (
                edtRoot.text = picked
                AVP_SaveSettings()
            )
        )

        on btnAddRoot pressed do
        (
            local folderName = edtNewName.text
            local newNode = AVP_AddNode folderName
            if newNode != undefined do edtNewName.text = ""
        )

        on btnAddChild pressed do
        (
            local parentNode = AVP_SelectedNode()
            if parentNode == undefined then
                AVP_SetStatus "Select a parent folder first."
            else
            (
                local folderName = edtNewName.text
                local newNode = AVP_AddNode folderName parentId:parentNode.id
                if newNode != undefined do edtNewName.text = ""
            )
        )

        on btnRemove pressed do
        (
            local selectedNode = AVP_SelectedNode()
            if selectedNode == undefined then
                AVP_SetStatus "Select a folder first."
            else AVP_RemoveNode selectedNode.id
        )
        on btnCreate pressed do AVP_CreateDirectories edtRoot.text

        on AVP_MainRollout open do
        (
            edtRoot.text = getIniSetting AVP_IniFile "Project" "LastRoot"
            AVP_RefreshTree()
        )

        on AVP_MainRollout close do AVP_SaveWindowPosition()
    )

    rollout AVP_IORollout "Templates - Import / Export"
    (
        label lblInfo "Save or load a folder template." width:240 align:#center
        button btnExport "Export" width:72 across:3
        button btnImport "Import" width:82
        button btnDefaults "Defaults" width:76

        on btnExport pressed do
        (
            local outFile = getSaveFileName caption:"Export folder structure" filename:"ArchvizSmallProject.avpstructure" types:"Archviz structure (*.avpstructure)|*.avpstructure|INI file (*.ini)|*.ini|All files (*.*)|*.*|"
            if outFile != undefined do
            (
                if AVP_SaveStructure outFile then AVP_SetStatus ("Template exported: " + outFile)
            )
        )

        on btnImport pressed do
        (
            local inFile = getOpenFileName caption:"Import folder structure" types:"Archviz structure (*.avpstructure)|*.avpstructure|INI file (*.ini)|*.ini|All files (*.*)|*.*|"
            if inFile != undefined do
            (
                if AVP_LoadStructure inFile showError:false then
                (
                    AVP_SaveSettings()
                    AVP_RefreshTree()
                    AVP_SetStatus ("Template imported: " + inFile)
                )
            )
        )

        on btnDefaults pressed do
        (
            (
                AVP_LoadDefaults()
                AVP_SaveSettings()
                AVP_RefreshTree()
                AVP_SetStatus "Default structure restored."
            )
        )
    )


    rollout AVP_AboutRollout "About"
    (
        label lblAboutName "" align:#center
        label lblAboutVersion "" align:#center 
        label lblAboutDeveloper "" align:#center
        hyperLink hplSite "3dground.net" address: "https://3dground.net" align:#center color: orange hoverColor: orange visitedColor: orange

        on AVP_AboutRollout open do
        (
            lblAboutName.text = AVP_ScriptName
            lblAboutVersion.text = AVP_ScriptVersion
            lblAboutDeveloper.text = AVP_ScriptDeveloper
        )
    )
    if not (AVP_LoadStructure AVP_IniFile showError:false) do
    (
        AVP_LoadDefaults()
        AVP_SaveStructure AVP_IniFile
    )

    local windowPos = AVP_LoadWindowPosition()
    AVP_Floater = newRolloutFloater "Archviz Project Builder" 280 510 pos:windowPos
    AVP_Floater.pos = windowPos
    addRollout AVP_MainRollout AVP_Floater rolledUp:false
    addRollout AVP_IORollout AVP_Floater rolledUp:true
    addRollout AVP_AboutRollout AVP_Floater rolledUp:true
)



