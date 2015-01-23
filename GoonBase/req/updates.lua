----------
-- Payday 2 GoonMod, Public Release Beta 2, built on 1/9/2015 9:30:33 PM
-- Copyright 2014, James Wilkinson, Overkill Software
----------

_G.GoonBase.Updates = _G.GoonBase.Updates or {}
local Updates = _G.GoonBase.Updates

local UPrint = function(str)
	Print("[Update] " .. str)
end

-- Update
Updates.HasCheckedForUpdates = false
Updates.BasePath = "https://raw.githubusercontent.com/JamesWilko/GoonMod/master/"
Updates.BasePathToken = ""
Updates.Version = "update_version.txt"
Updates.FileList = "update_list.txt"
Updates.FileExts = {
	["lua"] = true,
	["txt"] = true,
	["ini"] = true,
	["yml"] = true,
	["dll"] = true
}
Updates.PatchNotesURL = "https://google.com/"
Updates.UpdateFileLocation = "GoonBase/req/updates.lua"
Updates.HookFileLocation = "PD2Hook.yml"
Updates.FilesToUpdate = {}
Updates.FilesCurrentlyUpdating = 0
Updates.FileCurrentlyProcessing = 0
Updates.CurrentFileRetries = 0
Updates.MaxFileRetries = 3
Updates.WaitingWindow = nil

-- Errors
Updates.ErrorList = {}

-- Options
GoonBase.Options.Updates = GoonBase.Options.Updates or {}
GoonBase.Options.Updates.FirstTimeStartup = true
GoonBase.Options.Updates.CheckForUpdates = true
GoonBase.Options.Updates.BypassUnsupported = false
GoonBase.Options.Updates.GameVersion = ""
GoonBase.Options.Updates.ShownUpdateWindow = false
GoonBase.Options:Load()

-- Localization
local Localization = GoonBase.Localization
Localization.Updates_FirstTitle = "GoonMod Automatic Updates"
Localization.Updates_FirstMessage = [[GoonMod has an automatic updates feature. This will allow you to update some aspects of GoonMod without installing the updates yourself.
You will be notified and asked before an update occurs, and you can change this setting at anytime via the options menu.

Would you like to enable automatic updates? (Highly Recommended)
]]
Localization.Updates_FirstAccept = "Enable Automatic Updates"
Localization.Updates_FirstDecline = "Disable Automatic Updates"

Localization.Updates_AvailableTitle = "GoonMod Update Available"
Localization.Updates_AvailableMessage = "A new update for GoonMod is available. Would you like to update now?"
Localization.Updates_AllowUpdate = "Update Now"
Localization.Updates_DontUpdate = "Later"
Localization.Updates_ViewPatchNotes = "View Update Notes"

Localization.Updates_UpdatingTitle = "Updating GoonMod"
Localization.Updates_UpdatingMessage = "Updating GoonMod. Please do not close your game during this time, doing so may corrupt your mod installation."

Localization.Updates_ManualTitle = "Manual Update Required"
Localization.Updates_ManualMessage = "A manual update to GoonMod is required. You can find the download link, payday 2 folder shortcut, and update notes available below."
Localization.Updates_ManualAccept = "View Update"
Localization.Updates_ManualPaydayFolder = "Open Payday 2 Folder"
Localization.Updates_ManualLater = "Update Later"

Localization.Updates_NoUpdateTitle = "No Update Required"
Localization.Updates_NoUpdateMessage = [[Your GoonMod installation is currently up-to-date.

If necessary, you can force a re-download of the latest files by clicking on the Force Redownload button.]]
Localization.Updates_NoUpdateAccept = "OK"
Localization.Updates_NoUpdateForce = "Force Redownload"

Localization.Updates_VersionMismatchTitle = "Unsupported Version"
Localization.Updates_VersionMismatchMessage = [[Your version of Payday 2 is currently unsupported, your game has probably updated.

Your Modifications menu may appear empty, and any enabled mods have been disabled to prevent any unwanted crashes.

An update may be available for download shortly, but if you wish to force GoonMod to work, and to load your mods, you can do so from the options menu.]]
Localization.Updates_VersionMismatchAccept = "OK"

Localization.Updates_UpdateCompleteTitle = "Update Complete!"
Localization.Updates_UpdateCompleteMessage = "Update completed successfully! Please restart Payday 2 to complete the update."
Localization.Updates_UpdateCompleteAccept = "Restart Now"
Localization.Updates_UpdateCompleteLater = "Restart Later" 

Localization.Updates_UpdateErrorTitle = "Warning!"
Localization.Updates_UpdateErrorMessage = [[An error occurred during the update. You may be required to reinstall GoonMod if problems occur.
Please contact, and send your GoonBase.log file from your Payday 2 folder to the mod author if you experience further problems.]]
Localization.Updates_UpdateErrorAccept = "OK"

Localization.Updates_Options_CheckForUpdates = "Automically Check For Updates"
Localization.Updates_Options_CheckForUpdatesDesc = "Automatically check for and download GoonMod updates"
Localization.Updates_Options_CheckNow = "Check For Updates Now"
Localization.Updates_Options_CheckNowDesc = "Immediately check for any updates to GoonMod"
Localization.Updates_Options_IgnoreUnsupported = "Ignore Unsupported Version"
Localization.Updates_Options_IgnoreUnsupportedDesc = "Ignore the unsupported version check and run all GoonMod modules anyway (Requires Restart)"

-- Hooks
Hooks:Add("MenuManagerOnOpenMenu", "MenuManagerOnOpenMenu_Updates", function( menu_manager, menu, position )

	-- Check for updates after going to the main menu
	if menu == "menu_main" then

		if GoonBase.Options.Updates.ShownUpdateWindow then
			return
		end

		-- Check for first time setup
		if GoonBase.Options.Updates.FirstTimeStartup then
			if not Updates:IsSupportedVersion() then
				Updates:GameVersionMismatchWindow()
			end
			Queue:Add("MenuManagerInitialize_Updates_FirstTime", Updates.FirstTimeSetup, 0.25)
			return
		end

		-- Check for updates
		Updates:InitialCheckForUpdates()

	end

end)

Hooks:Add("MenuManagerSetupGoonBaseMenu", "MenuManagerSetupGoonBaseMenu_Updates", function( menu_manager )

	local success, err = pcall(function()

		MenuCallbackHandler.toggle_updates_checkforupdates = function(this, item)
			GoonBase.Options.Updates.CheckForUpdates = item:value() == "on" and true or false
			GoonBase.Options:Save()
		end

		MenuCallbackHandler.button_check_for_updates = function(this, item)
			Updates._force_check = true
			Updates:CheckForUpdates(true)
		end

		MenuCallbackHandler.toggle_unsupported_bypass = function(this, item)
			GoonBase.Options.Updates.BypassUnsupported = item:value() == "on" and true or false
			GoonBase.Options:Save()
		end

		GoonBase.MenuHelper:AddToggle({
			id = "toggle_updates",
			title = "Updates_Options_CheckForUpdates",
			desc = "Updates_Options_CheckForUpdatesDesc",
			callback = "toggle_updates_checkforupdates",
			value = GoonBase.Options.Updates.CheckForUpdates,
			menu_id = "goonbase_options_menu",
			priority = 999
		})

		GoonBase.MenuHelper:AddButton({
			id = "button_updates_check_now",
			title = "Updates_Options_CheckNow",
			desc = "Updates_Options_CheckNowDesc",
			callback = "button_check_for_updates",
			menu_id = "goonbase_options_menu",
			priority = 998,
		})


		if GoonBase.Options.Updates.BypassUnsupported or not Updates:IsSupportedVersion() then
			GoonBase.MenuHelper:AddToggle({
				id = "toggle_unsupported_bypass",
				title = "Updates_Options_IgnoreUnsupported",
				desc = "Updates_Options_IgnoreUnsupportedDesc",
				callback = "toggle_unsupported_bypass",
				value = GoonBase.Options.Updates.BypassUnsupported,
				menu_id = "goonbase_options_menu",
				priority = 1000
			})
		end

	end)
	if not success then PrintTable(err) end

end)

Hooks:Add("SetupOnQuit", "SetupOnQuit_Updates", function(setup)
	GoonBase.Options.Updates.ShownUpdateWindow = false
	GoonBase.Options:Save()
end)

function Updates:InitialCheckForUpdates()

	-- Check game version
	if not Updates:IsSupportedVersion() then
		Updates:GameVersionMismatchWindow()
	end

	-- Only check for updates immediately if allowed
	if GoonBase.Options.Updates.CheckForUpdates then
		Queue:Add("MenuManagerInitialize_Updates", Updates.CheckForUpdates, 1)
	end

end

-- First Time Setup
function Updates:FirstTimeSetup()

	local title = managers.localization:text("Updates_FirstTitle")
	local message = managers.localization:text("Updates_FirstMessage")
	local menuOptions = {}
	menuOptions[1] = {
		text = managers.localization:text("Updates_FirstAccept"),
		callback = Updates.FirstTimeSetup_UpdatesOn,
	}
	menuOptions[2] = {
		text = managers.localization:text("Updates_FirstDecline"),
		callback = Updates.FirstTimeSetup_UpdatesOff,
	}
	local updateWindow = SimpleMenu:New(title, message, menuOptions)
	updateWindow:Show()

end

function Updates.FirstTimeSetup_UpdatesOn()
	-- Setup options
	GoonBase.Options.Updates.CheckForUpdates = true
	GoonBase.Options.Updates.FirstTimeStartup = false
	GoonBase.Options:Save()

	-- Check for updates
	Updates:InitialCheckForUpdates()
end

function Updates.FirstTimeSetup_UpdatesOff()
	-- Setup options
	GoonBase.Options.Updates.CheckForUpdates = false
	GoonBase.Options.Updates.FirstTimeStartup = false
	GoonBase.Options:Save()
end

-- Update Check
function Updates:CheckForUpdates( force )

	if not force and not GoonBase.Options.Updates.CheckForUpdates then return end

	if force or not Updates.HasCheckedForUpdates then
		UPrint("Requesting update version...")
		Print( Updates.BasePath .. Updates.Version .. Updates.BasePathToken )
		Steam:http_request(Updates.BasePath .. Updates.Version .. Updates.BasePathToken, callback(Updates, Updates, "UpdateVersionCallback"))
	end

end

function Updates:GetUpdateFileList()

	UPrint("Requesting file list from server...")
	Steam:http_request(Updates.BasePath .. Updates.FileList .. Updates.BasePathToken, callback(Updates, Updates, "UpdateListCallback"))

end

-- Update menu
function Updates:RequestUpdatePermission()

	if not GoonBase.Options.Updates.CheckForUpdates then return end

	local title = managers.localization:text("Updates_AvailableTitle")
	local message = managers.localization:text("Updates_AvailableMessage")
	local menuOptions = {}
	menuOptions[1] = {
		text = managers.localization:text("Updates_AllowUpdate"),
		callback = Updates.BeginUpdateFiles,
		is_cancel_button = true
	}
	menuOptions[2] = {
		text = managers.localization:text("Updates_ViewPatchNotes"),
		callback = Updates.OpenPatchNotes,
	}
	menuOptions[3] = {
		text = managers.localization:text("Updates_DontUpdate"),
		is_cancel_button = true
	}

	local updateWindow = SimpleMenu:New(title, message, menuOptions)
	updateWindow:Show()

end

function Updates:GameVersionMismatchWindow()

	if GoonBase.Options.Updates.GameVersion == Application:version() then
		return
	end

	-- Show message
	local title = managers.localization:text("Updates_VersionMismatchTitle")
	local message = managers.localization:text("Updates_VersionMismatchMessage")
	local menuOptions = {}
	menuOptions[1] = {
		text = managers.localization:text("Updates_VersionMismatchAccept"),
		is_cancel_button = true
	}
	local updateWindow = SimpleMenu:New(title, message, menuOptions)
	updateWindow:Show()

	-- Don't show message again
	GoonBase.Options.Updates.GameVersion = Application:version()
	GoonBase.Options:Save()

end

function Updates:ManualUpdateWindow()

	local title = managers.localization:text("Updates_ManualTitle")
	local message = managers.localization:text("Updates_ManualMessage")
	local menuOptions = {}
	menuOptions[1] = {
		text = managers.localization:text("Updates_ManualAccept"),
		callback = Updates.ManualUpdateCallback,
		is_cancel_button = true
	}
	menuOptions[1] = {
		text = managers.localization:text("Updates_ManualPaydayFolder"),
		callback = Updates.ManualOpenPaydayFolder,
		is_cancel_button = true
	}
	menuOptions[3] = {
		text = managers.localization:text("Updates_ManualLater"),
		is_cancel_button = true
	}
	local updateWindow = SimpleMenu:New(title, message, menuOptions)
	updateWindow:Show()

end

-- File update
function Updates.BeginUpdateFiles()

	UPrint("Beginning Updates...")
	Updates:ShowUpdatingWindow()

	for k, v in pairs( Updates.FilesToUpdate ) do
		Updates.FilesCurrentlyUpdating = Updates.FilesCurrentlyUpdating + 1
	end

	Updates.FileCurrentlyProcessing = 0
	Updates:UpdateNextFileInList()

end

function Updates:UpdateNextFileInList()

	Updates.FileCurrentlyProcessing = Updates.FileCurrentlyProcessing + 1
	local file = Updates.FilesToUpdate[ Updates.FileCurrentlyProcessing ]

	if file ~= nil then
		file = file:gsub("\\", "/")
		UPrint("Updating " .. file .. " (" .. Updates.BasePath .. file .. ")")
		Steam:http_request(Updates.BasePath .. file .. Updates.BasePathToken, callback(Updates, Updates, "UpdateFileCallback", file))
	end

end

function Updates:RetryCurrentFile()

	Updates.CurrentFileRetries = Updates.CurrentFileRetries + 1

	local psuccess, perror = pcall(function()
	
	if Updates.CurrentFileRetries > Updates.MaxFileRetries then
		local errorString = "File '" .. fileName .. "' exceeded the maximum download retries, skipping..."
		UPrint(errorString)
		table.insert( Updates.ErrorList, errorString )
		Updates:UpdateNextFileInList()
		return
	end

	local file = Updates.FilesToUpdate[ Updates.FileCurrentlyProcessing ]
	if file ~= nil then
		UPrint("Retrying " .. file)
		Steam:http_request(Updates.BasePath .. file .. Updates.BasePathToken, callback(Updates, Updates, "UpdateFileCallback", file))
	end

	end)
	if not psuccess then
		Print("[Error] " .. perror)
	end

end

function Updates.OpenPatchNotes()
	UPrint("Displaying patch notes...")
	Updates:ShowPatchNotes()
	Updates:RequestUpdatePermission()
end

function Updates:ShowPatchNotes()
	Steam:overlay_activate("url", Updates.PatchNotesURL)
end

function Updates.ManualUpdateCallback()
	Updates:ShowPatchNotes()
end

function Updates.ManualOpenPaydayFolder()
	if SystemInfo:platform() == Idstring("WIN32") then
		os.execute( "explorer " .. Application:base_path() )
	end
end

function Updates:ShowNoUpdates()

	local title = managers.localization:text("Updates_NoUpdateTitle")
	local message = managers.localization:text("Updates_NoUpdateMessage")
	local menuOptions = {}
	menuOptions[1] = {
		text = managers.localization:text("Updates_NoUpdateForce"),
		callback = Updates.ForceRedownloadMod,
		is_cancel_button = true
	}
	menuOptions[2] = {
		text = managers.localization:text("Updates_NoUpdateAccept"),
		is_cancel_button = true
	}
	local updateWindow = SimpleMenu:New(title, message, menuOptions)
	updateWindow:Show()

end

function Updates.ForceRedownloadMod()
	Updates._force_redownload = true
	Updates:CheckForUpdates( true )
end

-- Updating Window
function Updates:ShowUpdatingWindow()

	-- Display Update Window
	local title = managers.localization:text("Updates_UpdatingTitle")
	local message = managers.localization:text("Updates_UpdatingMessage")
	Updates.WaitingWindow = SimpleMenu:New(title, message, {})
	Updates.WaitingWindow.dialog_data.no_buttons = true
	Updates.WaitingWindow.dialog_data.indicator = true
	Updates.WaitingWindow:Show()

	-- Check if updates have completed
	Queue:Add("Updates_CheckUpdateStatus", Updates.CheckUpdatingStatus, 3)

end

function Updates:CheckUpdatingStatus()

	if Updates.FilesCurrentlyUpdating > 0 then
		-- Check again if updates have completed
		Queue:Add("Updates_CheckUpdateStatus", Updates.CheckUpdatingStatus, 1)
	else
		-- Updates finished
		Updates:CloseUpdatingWindow()
	end

end

function Updates:CloseUpdatingWindow()

	-- Close window if updates have completed
	managers.system_menu:close(Updates.WaitingWindow.dialog_data.id)
	Updates.WaitingWindow.visible = false

	-- Show completion window
	local title = managers.localization:text("Updates_UpdateCompleteTitle")
	local message = managers.localization:text("Updates_UpdateCompleteMessage")
	local menuOptions = {}
	menuOptions[1] = {
		text = managers.localization:text("Updates_UpdateCompleteAccept"),
		callback = Updates.ForceCloseGame,
		is_cancel_button = true
	}
	menuOptions[2] = {
		text = managers.localization:text("Updates_UpdateCompleteLater"),
		is_cancel_button = true
	}
	local updateWindow = SimpleMenu:New(title, message, menuOptions)
	updateWindow:Show()

	-- Show unsupported message again in the future
	GoonBase.Options.Updates.ShownUnsupportedMessage = false
	GoonBase.Options:Save()

end

function Updates.ForceCloseGame()
	managers.savefile:save_progress("local_hdd")
	setup:quit()
end

-- Callback
function Updates:UpdateVersionCallback( success, file )

	local psuccess, perror = pcall(function()

		UPrint("Received callback: " .. tostring(success))

		-- Don't process failed request
		if not success then
			UPrint("Couldn't retreive latest version")
			Print(file)
			return
		end

		-- Parse info
		local shouldUpdate = false
		local lines = string.split( file, "\n" )
		local serverVersion = tonumber(lines[1])
		local serverGameVersion = lines[2]
		local patchNotes = lines[3]
		local manualUpdate = lines[4]

		if serverVersion == nil then
			UPrint("Could not process server version")
			return
		end

		-- Check version number
		UPrint("Versions - Local: " .. GoonBase.Version .. " / Remote: " .. serverVersion)
		if type(serverVersion) == "number" and type(GoonBase.Version) == "number" then
			if serverVersion > GoonBase.Version then
				UPrint("New version available, version " .. serverVersion)
				shouldUpdate = true
			end
		end

		-- Forced redownload
		if Updates._force_redownload then
			shouldUpdate = true
		end
		
		-- Forced check if update required
		if not shouldUpdate then

			-- Show forced check for updates screen
			if Updates._force_check then
				Updates:ShowNoUpdates()
				Updates._force_check = nil
			end

			return
		end

		-- Get patch notes URL
		Updates.PatchNotesURL = patchNotes

		-- Check if manual update is required
		local manualUpdateString = "manual=true"
		local req = string.match( manualUpdate, "(" .. manualUpdateString .. ")" )
		if req ~= nil and req == manualUpdateString then
			-- Manual Update
			Updates:ManualUpdateWindow()
		else
			-- Automatic Update
			Updates:GetUpdateFileList()
		end

		GoonBase.Options.Updates.ShownUpdateWindow = true
		GoonBase.Options:Save()

	end)
	if not psuccess then
		Print("[Error] " .. perror)
	end
end

function Updates:UpdateListCallback(success, file)

	UPrint("Received callback: " .. tostring(success))

	-- Don't process failed request
	if not success then
		UPrint("Couldn't retreive update list")
		return
	end

	UPrint("Processing update list...")

	-- Clear files list
	Updates.FilesToUpdate = {}

	-- Check files to update
	local files = string.split(file, "[\n]")
	for k, v in pairs(files) do
		local f = string.split(v, "[.]")
		if Updates.FileExts[ f[2] ] == true then
			table.insert( Updates.FilesToUpdate, v )
		end
	end

	Updates.HasCheckedForUpdates = true

	if not Updates._force_redownload then
		self:RequestUpdatePermission()
	else
		Updates.BeginUpdateFiles()
	end

end

function Updates:UpdateFileCallback(fileName, success, data)

	-- Decrement files updating
	Updates.FilesCurrentlyUpdating = Updates.FilesCurrentlyUpdating - 1

	-- Check if successful
	if not success then
		UPrint("Could not update file '" .. fileName .. "'")
		Updates:RetryCurrentFile()
		return
	end

	-- Write file to disk
	local redownloadFile = false
	local writeSuccess, writeError = pcall(function()

		-- Remove garbage data from end of files
		local file_ending = "-- END OF FILE"
		if fileName == self.UpdateFileLocation then
			file_ending = "--" .. "#" .. " END OF FILE"
		end
		data = string.gsub( data, "(" .. file_ending .. ".*)", "" )

		-- Process hook file separately
		if fileName == self.HookFileLocation then
			data = self:ProcessHookFile( data )
		end

		-- Save file
		local file = io.open(fileName, "w+")
		io.output(file)
		io.write(data)
		io.close(file)

	end)

	-- Check for write success
	if not redownloadFile then
		if writeSuccess then
			UPrint("Successfully updated file '" .. fileName .. "'")
		else
			local errorString = "Error while updating file '" .. fileName .. "'\n" .. writeError
			UPrint(errorString)
			table.insert( Updates.ErrorList, errorString )
		end
	else
		Updates:RetryCurrentFile()
		return
	end

	-- Continue
	Updates:UpdateNextFileInList()

end

function Updates:ProcessHookFile( data )

	local localfile_data = {}
	local update_data = {}
	local write_data = true

	-- Get local data
	write_data = true
	for line in io.lines( self.HookFileLocation ) do

		if line ~= nil then

			local linetrim = line:gsub("^%s*(.-)%s*$", "%1")
			if linetrim == "# GOONBASE" then
				write_data = false
				table.insert( localfile_data, line )
			elseif linetrim == "# END" then
				write_data = true
				table.insert( localfile_data, line )
			elseif write_data then
				table.insert( localfile_data, line )
			end

		end

	end

	-- Get data from update
	local data_lines = string.split( data, "[\n]" )
	write_data = false
	for l, line in pairs( data_lines ) do

		if line ~= nil then

			local linetrim = line:gsub("^%s*(.-)%s*$", "%1")
			if linetrim == "# GOONBASE" then
				write_data = true
			elseif linetrim == "# END" then
				write_data = false
			elseif write_data then
				table.insert( update_data, line )
			end

		end

	end

	-- Merge data
	local merged = false
	for l, line in pairs( localfile_data ) do

		local linetrim = line:gsub("^%s*(.-)%s*$", "%1")
		if linetrim == "# GOONBASE" and not merged then
			for i = 1, #update_data, 1 do
				table.insert( localfile_data, l + i, update_data[i] )
			end
			merged = true
		end

	end

	-- Build string
	local new_data = ""
	for l, line in pairs( localfile_data ) do
		if line ~= nil then
			new_data = new_data .. line .. "\n"
		end
	end

	return new_data

end

-- Parse string into version
function Updates:ParseUpdateString(str)
	return str:split("[.]")
end

function Updates:CompareVersionStrings(local_version_str, other_version_str)

	local local_version = self:ParseUpdateString(local_version_str)
	local other_version = self:ParseUpdateString(other_version_str)

	-- Return false if version is out of date
	for i = 1, 3, 1 do
		if local_version[i] < other_version[i] then
			return false
		end
	end

	return true

end

function Updates:IsSupportedVersion()
	if GoonBase.Options.Updates.BypassUnsupported then
		return true
	end
	return Updates:CompareVersionStrings(GoonBase.GameVersion, Application:version())
end

--# END OF FILE
-- END OF FILE
