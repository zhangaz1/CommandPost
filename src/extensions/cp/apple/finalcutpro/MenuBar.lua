--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                   F I N A L    C U T    P R O    A P I                     --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--- === cp.apple.finalcutpro.MenuBar ===
---
--- Represents the Final Cut Pro menu bar, providing functions that allow different tasks to be accomplished.

--------------------------------------------------------------------------------
--
-- EXTENSIONS:
--
--------------------------------------------------------------------------------
local log											= require("hs.logger").new("menubar")
local json											= require("hs.json")
local fnutils										= require("hs.fnutils")
local axutils										= require("cp.apple.finalcutpro.axutils")
local just											= require("cp.just")
local config										= require("cp.config")
local plist											= require("cp.plist")
local archiver										= require("cp.plist.archiver")

--------------------------------------------------------------------------------
--
-- THE MODULE:
--
--------------------------------------------------------------------------------
local MenuBar = {}

MenuBar.MENU_MAP_FILE								= config.scriptPath .. "/cp/apple/finalcutpro/menumap.json"
MenuBar.ROLE										= "AXMenuBar"

--- cp.apple.finalcutpro.MenuBar:new(App) -> MenuBar
--- Function
--- Constructs a new MenuBar for the specified App.
---
--- Parameters:
---  * app - The App instance the MenuBar belongs to.
---
--- Returns:
---  * a new MenuBar instance
---
function MenuBar:new(app)
	local o = {
	  _app 		= app
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

-- TODO: Add documentation
function MenuBar:app()
	return self._app
end

-- TODO: Add documentation
function MenuBar:UI()
	return axutils.cache(self, "_ui", function()
		local appUI = self:app():UI()
		return appUI and axutils.childWith(appUI, "AXRole", MenuBar.ROLE)
	end)
end

-- TODO: Add documentation
function MenuBar:getMainMenu()
	if not MenuBar._mainMenu then
		MenuBar._mainMenu = self:_loadMainMenu()
	end
	return MenuBar._mainMenu
end

--- cp.apple.finalcutpro.MenuBar:selectMenu(...) -> boolean
--- Function
--- Selects a Final Cut Pro Menu Item based on the list of menu titles in English.
---
--- Parameters:
---  * ... - The list of menu items you'd like to activate, for example:
---            select("View", "Browser", "as List")
---
--- Returns:
---  * `true` if the press was successful.
function MenuBar:selectMenu(...)
	local menuItemUI = self:findMenuUI(...)

	if menuItemUI then
		return menuItemUI:doPress()
	end
	return false
end

-- TODO: Add documentation
function MenuBar:isChecked(...)
	local menuItemUI = self:findMenuUI(...)
	return menuItemUI and self:_isMenuChecked(menuItemUI)
end

-- TODO: Add documentation
function MenuBar:isEnabled(...)
	local menuItemUI = self:findMenuUI(...)
	return menuItemUI and menuItemUI:attributeValue("AXEnabled")
end

-- TODO: Add documentation
function MenuBar:_isMenuChecked(menu)
	return menu:attributeValue("AXMenuItemMarkChar") ~= nil
end

-- TODO: Add documentation
function MenuBar:checkMenu(...)
	local menuItemUI = self:findMenuUI(...)
	if menuItemUI and not self:_isMenuChecked(menuItemUI) then
		if menuItemUI:doPress() then
			return just.doUntil(function() return self:_isMenuChecked(menuItemUI) end)
		end
	end
	return false
end

-- TODO: Add documentation
function MenuBar:uncheckMenu(...)
	local menuItemUI = self:findMenuUI(...)
	if menuItemUI and self:_isMenuChecked(menuItemUI) then
		if menuItemUI:doPress() then
			return just.doWhile(function() return self:_isMenuChecked(menuItemUI) end)
		end
	end
	return false
end

-- TODO: Add documentation
-- Finds a specific Menu UI element for the provided path.
-- Eg `findMenuUI("Edit", "Copy")` returns the 'Copy' menu item in the 'Edit' menu.
function MenuBar:findMenuUI(...)
	-- Start at the top of the menu bar list
	local menuMap = self:getMainMenu()
	local menuUI = self:UI()
	local language = self:app():getCurrentLanguage() or "en"

	if not menuUI then
		return nil
	end

	local menuItemUI = nil

	for i=1,select('#', ...) do
		menuItemUI = nil
		step = select(i, ...)
		if type(step) == "number" then
			menuItemUI = menuUI[step]
		elseif type(step) == "function" then
			for i,child in ipairs(menuUI) do
				if step(child) then
					menuItemUI = child
					break
				end
			end
		else
			if menuMap then
				-- See if the menu is in the map.
				for _,item in ipairs(menuMap) do
					if item.en == step then
						menuItemUI = axutils.childWith(menuUI, "AXTitle", item[language])
						menuMap = item.submenu
						break
					end
				end
			end
			
			if not menuItemUI then
				-- We don't have it in our list, so look it up manually. Hopefully they are in English!
				log.w("Searching manually for '"..step.."'.")
				menuItemUI = axutils.childWith(menuUI, "AXTitle", step)
			end
		end

		if menuItemUI then
			if #menuItemUI == 1 then
				-- Assign the contained AXMenu to the menuUI - it contains the next set of AXMenuItems
				menuUI = menuItemUI[1]
				assert(not menuUI or menuUI:role() == "AXMenu")
			end
		else
			log.w("Unable to find a menu called '"..step.."'.")
			return nil
		end
	end
	return menuItemUI
end

-- TODO: Add documentation
-- Returns the set of menu items in the provided path. If the path contains a menu, the
-- actual children of that menu are returned, otherwise the menu item itself is returned.
function MenuBar:findMenuItemsUI(...)
	local menu = self:findMenuUI(...)
	if menu and #menu == 1 then
		return menu[1]:children()
	end
	return menu
end

--- cp.apple.finalcutpro.MenuBar:visitMenuItems(visitFn[, startPath]) -> nil
--- Method
--- Walks the menu tree, calling the `visitFn` on all the 'item' values - that is,
--- `AXMenuItem`s that don't have any sub-menus.
---
--- The `visitFn` will be called on each menu item with the following parameters:
---
--- ```
--- function(path, menuItem)
--- ```
---
--- The `menuItem` is the AXMenuItem object, and the `path` is an array with the path to that
--- menu item. For example, if it is the "Copy" item in the "Edit" menu, the path will be
--- `{ "Edit" }`.
---
--- Parameters:
---  * `visitFn`	- The function called for each menu item.
---
--- Returns:
---  * True is successful otherwise Nil
function MenuBar:visitMenuItems(visitFn, ...)
	local menu = nil
	local path = table.pack(...) or {}
	path.n = nil
	if #path > 0 then
		menu = self:findMenuUI(...)
	else
		menu = self:UI()
	end
	if menu then
		self:_visitMenuItems(visitFn, path, menu)
	end
end

-- TODO: Add documentation
function MenuBar:_visitMenuItems(visitFn, path, menu)
	local title = menu:attributeValue("AXTitle")
	if #menu > 0 then
		local menuPath = fnutils.concat(fnutils.copy(path), { title })
		for _,item in ipairs(menu) do
			self:_visitMenuItems(visitFn, menuPath, item)
		end
	elseif title ~= nil and title ~= "" then
		visitFn(path, menu)
	end
end

--- cp.apple.finalcutpro.MenuBar:generateMenuMap() -> boolean
--- Function
--- Generates a map of the menu bar and saves it in the location specified
--- in MenuBar.MENU_MAP_FILE.
---
--- Parameters:
---  * None
---
--- Returns:
---  * True is successful otherwise Nil
function MenuBar:generateMenuMap()
	local menuMap = self:_processMenuItems(self:UI()) or {}

	-- Opens a file in append mode
	file = io.open(MenuBar.MENU_MAP_FILE, "w")

	if file then
		file:write(json.encode(menuMap))
		file:close()
		return true
	end

	return nil
end

-- TODO: Add documentation
function MenuBar:_processMenuItems(menu)
	local count = #menu
	if count then
		local items = {}
		for i,child in ipairs(menu) do
			local title = child:attributeValue("AXTitle")
			-- log.d("Title: "..inspect(title))
			if title and title ~= "" then
				local item = {id = i}
				local submenu = child[1]
				if submenu and submenu:role() == "AXMenu" then
					local children = self:_processMenuItems(submenu)
					if children then
						item.items = children
					end
				end
				items[title] = item
			end
		end
		return items
	else
		return nil
	end
end

function MenuBar:_loadMainMenu(languages)
	languages = languages or self:app():getSupportedLanguages()
	local menu = {}
	for _,language in ipairs(languages) do
		if language then
			self:_loadMainMenuLanguage(language, menu)
		else
			log.wf("Received a nil language request.")
		end
	end
	return menu
end

function MenuBar:_loadMainMenuLanguage(language, menu)
	local menuPlist = plist.fileToTable(string.format("%s/Contents/Resources/%s.lproj/MainMenu.nib", self:app():getPath(), language))
	if menuPlist then
		local menuArchive = archiver.unarchive(menuPlist)
		-- Find the 'MainMenu' item
		local mainMenu = nil
		for _,item in ipairs(menuArchive["IB.objectdata"].NSObjectsKeys) do
			if item.NSName == "_NSMainMenu" and item["$class"] and item["$class"]["$classname"] == "NSMenu" then
				mainMenu = item
				break
			end
		end
		if mainMenu then
			return self:_processMenu(mainMenu, language, menu)
		else
			log.ef("Unable to locate MainMenu in '%s.lproj/MainMenu.nib'.", language)
			return nil
		end
	else
		log.ef("Unable to load MainMenu.nib for specified language: %s", language)
		return nil
	end
end

function MenuBar:_processMenu(menuData, language, menu)
	if not menuData then
		return nil
	end
	-- process the menu items
	menu = menu or {}
	if menuData.NSMenuItems then
		for i,itemData in ipairs(menuData.NSMenuItems) do
			local item = menu[i] or {}
			item[language]	= itemData.NSTitle
			item.separator	= itemData.NSIsSeparator
			-- Check if there is a submenu
			if itemData.NSSubmenu then
				item.submenu = MenuBar:_processMenu(itemData.NSSubmenu, language, item.submenu)
			end
			menu[i] = item
		end
	end
	return menu
end

return MenuBar