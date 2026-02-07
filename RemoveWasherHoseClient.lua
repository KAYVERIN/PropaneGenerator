local function createAdvancedTooltip(titleKey, descKey, reqsKey)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip:setName(getText(titleKey))
    
    local desc = getText(descKey)
    if desc and desc ~= "" then
        tooltip.description = desc
    end
    
    local reqs = getText(reqsKey)
    if reqs and reqs ~= "" then
        tooltip.description = (tooltip.description or "") .. "\n\n" .. "<RGB:1,0.8,0> " .. reqs
    end
    
    return tooltip
end

local function isWashingMachine(object)
    if not instanceof(object, "IsoObject") then
        return false
    end
    
    if instanceof(object, "IsoClothingWasher") or instanceof(object, "IsoClothingDryer") then
        return true
    end
    
    local sprite = object:getSprite()
    if not sprite or not sprite:getName() then
        return false
    end
    
    local spriteName = sprite:getName():lower()
    
    if string.contains(spriteName, "laundry") and not string.contains(spriteName, "broken") then
        return true
    end
    
    if string.contains(spriteName, "washer") or 
       string.contains(spriteName, "dryer") or 
       string.contains(spriteName, "appliances_01") then
        return true
    end
    
    return false
end

local function hasRequiredTools(player)
    if not player then return false end
    
    local playerInv = player:getInventory()
    local hasTool = playerInv:contains("Base.Wrench") or 
                   playerInv:contains("Base.PipeWrench")
    
    return hasTool
end

local function isHoseRemoved(object)
    local modData = object:getModData()
    return modData.hoseRemoved == true
end

local function hasRubberHose(player)
    if not player then return false end
    
    local playerInv = player:getInventory()
    return playerInv:contains("Base.RubberHose")
end

local function addWashingMachineHoseOption(playerNum, context, worldobjects)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end
    
    for _, object in ipairs(worldobjects) do
        if isWashingMachine(object) then
            local playerSquare = playerObj:getSquare()
            local objectSquare = object:getSquare()
            if not playerSquare or not objectSquare then return end
            
            local distX = math.abs(playerSquare:getX() - objectSquare:getX())
            local distY = math.abs(playerSquare:getY() - objectSquare:getY())
            if distX > 1 or distY > 1 then
                return
            end
            
            if isHoseRemoved(object) then
                if hasRubberHose(playerObj) and hasRequiredTools(playerObj) then
                    local installHoseOption = context:addOption(
                        getText("ContextMenu_RemoveWasherHoseInstallHose"), 
                        worldobjects, 
                        function()
                            onInstallHose(worldobjects, playerObj, object)
                        end
                    )
                    
                    local tooltip = createAdvancedTooltip(
                        "Tooltip_RemoveWasherHoseInstallTitle",
                        "Tooltip_RemoveWasherHoseInstallDesc",
                        "Tooltip_RemoveWasherHoseInstallReqs"
                    )
                    installHoseOption.toolTip = tooltip
                else
                    local infoOption = context:addOption(
                        getText("ContextMenu_RemoveWasherHoseHoseRemoved"), 
                        worldobjects, 
                        function() end
                    )
                    infoOption.notAvailable = true
                    
                    local tooltip = createAdvancedTooltip(
                        "Tooltip_RemoveWasherHoseTooltipRemovedTitle",
                        "Tooltip_RemoveWasherHoseTooltipRemovedDesc",
                        "Tooltip_RemoveWasherHoseTooltipRemovedReqs"
                    )
                    infoOption.toolTip = tooltip
                end
                break
            else
                local hasTool = hasRequiredTools(playerObj)
                local removeHoseOption = context:addOption(
                    getText("ContextMenu_RemoveWasherHoseRemoveHose"), 
                    worldobjects, 
                    function()
                        onRemoveHose(worldobjects, playerObj, object)
                    end
                )
                
                if not hasTool then
                    removeHoseOption.notAvailable = true
                    local tooltip = createAdvancedTooltip(
                        "Tooltip_RemoveWasherHoseTooltipActionTitle",
                        "Tooltip_RemoveWasherHoseTooltipActionDesc",
                        "Tooltip_RemoveWasherHoseTooltipActionNoTools"
                    )
                    removeHoseOption.toolTip = tooltip
                else
                    local tooltip = createAdvancedTooltip(
                        "Tooltip_RemoveWasherHoseTooltipActionTitle",
                        "Tooltip_RemoveWasherHoseTooltipActionDesc",
                        "Tooltip_RemoveWasherHoseTooltipActionHasTools"
                    )
                    removeHoseOption.toolTip = tooltip
                end
            end
            
            break
        end
    end
end

function onRemoveHose(worldobjects, playerObj, object)
    if not object or not playerObj then return end
    
    if not hasRequiredTools(playerObj) then
        HaloTextHelper.addTextWithArrow(playerObj, getText("IGUI_RemoveWasherHoseNeedWrench"), false, HaloTextHelper.getColorGreen())
        return
    end
    
    local action = ISRemoveWashingMachineHose:new(playerObj, object)
    ISTimedActionQueue.add(action)
end

function onInstallHose(worldobjects, playerObj, object)
    if not object or not playerObj then return end
    
    if not hasRequiredTools(playerObj) then
        HaloTextHelper.addTextWithArrow(playerObj, getText("IGUI_RemoveWasherHoseNeedWrench"), false, HaloTextHelper.getColorGreen())
        return
    end
    
    if not hasRubberHose(playerObj) then
        HaloTextHelper.addTextWithArrow(playerObj, getText("IGUI_RemoveWasherHoseNeedHose"), false, HaloTextHelper.getColorRed())
        return
    end
    
    local action = ISInstallWashingMachineHose:new(playerObj, object)
    ISTimedActionQueue.add(action)
end

ISRemoveWashingMachineHose = ISBaseTimedAction:derive("ISRemoveWashingMachineHose")

function ISRemoveWashingMachineHose:new(player, object)
    local o = ISBaseTimedAction.new(self, player)
    o.object = object
    o.maxTime = 150
    o.stopOnWalk = true
    o.stopOnRun = true
    o.soundStarted = false
    o.soundEffect = nil
    
    return o
end

function ISRemoveWashingMachineHose:isValid()
    if not self.object or not self.character then
        return false
    end
    
    if self.character:isDead() then
        return false
    end
    
    if not hasRequiredTools(self.character) then
        return false
    end
    
    if isHoseRemoved(self.object) then
        return false
    end
    
    local playerSquare = self.character:getSquare()
    local objectSquare = self.object:getSquare()
    if playerSquare and objectSquare then
        local distX = math.abs(playerSquare:getX() - objectSquare:getX())
        local distY = math.abs(playerSquare:getY() - objectSquare:getY())
        if distX > 1 or distY > 1 then
            return false
        end
    end
    
    return true
end

function ISRemoveWashingMachineHose:waitToStart()
    if self.character and self.object then
        self.character:faceThisObject(self.object)
        return self.character:shouldBeTurning()
    end
    return false
end

function ISRemoveWashingMachineHose:update()
    if self.character and self.object then
        self.character:faceThisObject(self.object)
        self.character:setMetabolicTarget(Metabolics.LightWork)
    end
end

function ISRemoveWashingMachineHose:start()
    self:setActionAnim("VehicleWorkOnMid")
    self.character:SetVariable("VehicleWorkOnMid", "true")
    
    self.soundEffect = self.character:playSound("GeneratorRepair")
    self.soundStarted = true
end

function ISRemoveWashingMachineHose:stop()
    if self.soundEffect ~= nil then
        self.character:getEmitter():stopSound(self.soundEffect)
        self.soundEffect = nil
    end
    
    ISBaseTimedAction.stop(self)
end

function ISRemoveWashingMachineHose:perform()
    if self.soundEffect ~= nil then
        self.character:getEmitter():stopSound(self.soundEffect)
        self.soundEffect = nil
    end
    
    ISBaseTimedAction.perform(self)
    
    self.character:getInventory():AddItem("Base.RubberHose")
    
    self.character:getXp():AddXP(Perks.Mechanics, 15)
    
    HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_RemoveWasherHoseSuccess"), true, HaloTextHelper.getColorGreen())
    
    local modData = self.object:getModData()
    modData.hoseRemoved = true
    
    if instanceof(self.object, "IsoClothingWasher") then
        modData.canBeWaterPiped = false
        
        if self.object.setUsesExternalWaterSource then
            self.object:setUsesExternalWaterSource(false)
        end
    end
    
    self.object:transmitModData()
end

ISInstallWashingMachineHose = ISBaseTimedAction:derive("ISInstallWashingMachineHose")

function ISInstallWashingMachineHose:new(player, object)
    local o = ISBaseTimedAction.new(self, player)
    o.object = object
    o.maxTime = 150
    o.stopOnWalk = true
    o.stopOnRun = true
    o.soundStarted = false
    o.soundEffect = nil
    
    return o
end

function ISInstallWashingMachineHose:isValid()
    if not self.object or not self.character then
        return false
    end
    
    if self.character:isDead() then
        return false
    end
    
    if not hasRequiredTools(self.character) then
        return false
    end
    
    if not hasRubberHose(self.character) then
        return false
    end
    
    if not isHoseRemoved(self.object) then
        return false
    end
    
    local playerSquare = self.character:getSquare()
    local objectSquare = self.object:getSquare()
    if playerSquare and objectSquare then
        local distX = math.abs(playerSquare:getX() - objectSquare:getX())
        local distY = math.abs(playerSquare:getY() - objectSquare:getY())
        if distX > 1 or distY > 1 then
            return false
        end
    end
    
    return true
end

function ISInstallWashingMachineHose:waitToStart()
    if self.character and self.object then
        self.character:faceThisObject(self.object)
        return self.character:shouldBeTurning()
    end
    return false
end

function ISInstallWashingMachineHose:update()
    if self.character and self.object then
        self.character:faceThisObject(self.object)
        self.character:setMetabolicTarget(Metabolics.LightWork)
    end
end

function ISInstallWashingMachineHose:start()
    self:setActionAnim("VehicleWorkOnMid")
    self.character:SetVariable("VehicleWorkOnMid", "true")
    self.soundEffect = self.character:playSound("GeneratorRepair")
    self.soundStarted = true
end

function ISInstallWashingMachineHose:stop()
    if self.soundEffect ~= nil then
        self.character:getEmitter():stopSound(self.soundEffect)
        self.soundEffect = nil
    end
    
    ISBaseTimedAction.stop(self)
end

function ISInstallWashingMachineHose:perform()
    if self.soundEffect ~= nil then
        self.character:getEmitter():stopSound(self.soundEffect)
        self.soundEffect = nil
    end
    
    ISBaseTimedAction.perform(self)
    
    self.character:getInventory():RemoveOneOf("Base.RubberHose")
    
    self.character:getXp():AddXP(Perks.Mechanics, 10)
    
    HaloTextHelper.addTextWithArrow(self.character, getText("IGUI_RemoveWasherHoseInstallSuccess"), true, HaloTextHelper.getColorGreen())
    
    local modData = self.object:getModData()
    modData.hoseRemoved = nil
    
    self.object:transmitModData()
end

local function initMod()
end

Events.OnGameStart.Add(initMod)
Events.OnFillWorldObjectContextMenu.Add(addWashingMachineHoseOption)