-- PropaneGeneratorOld.lua
-- Mod dlya odinochnoy igry Project Zomboid 42.13.2
-- Zapravka starogo generatora (Base.Generator_Old) propanovymi balonami (Base.PropaneTank)

-- ============================================================================
-- БЛОК 1: НАСТРОЙКИ МОДА
-- ============================================================================

local MOD_SETTINGS = {
    -- Настройка заправки
    PROPANE_PER_TANK = 100,          -- Один баллон = 100% заправки
    REFUEL_TIME = 150,               -- 150 тиков как в ISAddFuelAction
    
    -- Настройки звуков
    SOUND_START = "TakeGasFromContainer",   
    SOUND_FINISH = "PutGasIntoContainer",
    
    -- Тексты
    TEXT_REFUEL_OPTION = "Zapravit' Propanom",
    TEXT_FUEL_DISPLAY = "Propana: ",
    TEXT_ACTION = "Zapravka propanom...",
    TEXT_GENERATOR_MENU = "Generator",
    
    -- Отладка
    DEBUG_MODE = true,
    PRINT_PREFIX = "[PropaneGenerator]"
}

print(MOD_SETTINGS.PRINT_PREFIX .. " Mod nachinaet zagruzku...")

-- ============================================================================
-- БЛОК 2: ГЛОБАЛЬНЫЙ ОБЪЕКТ МОДА
-- ============================================================================

local PropaneGeneratorMod = {}

--[[
    Инициализация мода
]]
function PropaneGeneratorMod.init()
    print(MOD_SETTINGS.PRINT_PREFIX .. " Inicializaciya moda...")
    
    -- Регистрация обработчиков
    Events.OnFillWorldObjectContextMenu.Add(PropaneGeneratorMod.onFillContextMenu)
    
    -- Простое уведомление о старте
    Events.OnGameStart.Add(function()
        print(MOD_SETTINGS.PRINT_PREFIX .. " Mod gotov k rabote")
    end)
    
    print(MOD_SETTINGS.PRINT_PREFIX .. " Inicializaciya zavershena")
end

-- ============================================================================
-- БЛОК 3: ПОИСК ГЕНЕРАТОРА
-- ============================================================================

--[[
    Поиск старого генератора среди объектов
]]
function PropaneGeneratorMod.findOldGenerator(worldobjects)
    if not worldobjects then 
        return nil 
    end
    
    for _, obj in ipairs(worldobjects) do
        -- Проверяем что объект существует
        if obj == nil then
            break
        end
        
        -- Получаем тип объекта
        local objType = ""
        if obj.getObjectName then
            objType = tostring(obj:getObjectName())
        else
            break
        end
        
        if MOD_SETTINGS.DEBUG_MODE then
            print(MOD_SETTINGS.PRINT_PREFIX .. " Proveryaem ob'ekt: " .. objType)
        end
        
        -- Простая проверка по названию
        if string.find(objType:lower(), "generator") then
            if MOD_SETTINGS.DEBUG_MODE then
                print(MOD_SETTINGS.PRINT_PREFIX .. " Najden generator po imeni")
            end
            return obj
        end
    end
    
    if MOD_SETTINGS.DEBUG_MODE then
        print(MOD_SETTINGS.PRINT_PREFIX .. " Generator ne najden")
    end
    return nil
end

-- ============================================================================
-- БЛОК 4: ИНИЦИАЛИЗАЦИЯ ДАННЫХ
-- ============================================================================

--[[
    Инициализация данных пропана для генератора
]]
function PropaneGeneratorMod.initPropaneData(generator)
    if not generator then 
        return nil 
    end
    
    local modData = generator:getModData()
    
    if not modData.propaneInitialized then
        print(MOD_SETTINGS.PRINT_PREFIX .. " Pervaya inicializaciya generatora")
        
        modData.propaneData = {
            fuel = 0,
            maxFuel = 100,
            usesPropane = true
        }
        
        modData.propaneInitialized = true
        
        -- Получаем текущее топливо
        local currentFuel = generator:getFuel()
        if currentFuel and currentFuel > 0 then
            modData.propaneData.fuel = currentFuel
            print(MOD_SETTINGS.PRINT_PREFIX .. " Tekushee toplivo: " .. currentFuel)
        end
    end
    
    return modData.propaneData
end

-- ============================================================================
-- БЛОК 5: ПРОВЕРКА ИНВЕНТАРЯ
-- ============================================================================

--[[
    Проверка наличия пропанового баллона
]]
function PropaneGeneratorMod.checkPropaneTank(player)
    if not player then 
        return false, nil 
    end
    
    local playerInv = player:getInventory()
    if not playerInv then 
        return false, nil 
    end
    
    -- Пробуем разные варианты названия
    local propaneTanks = playerInv:getItemsFromType("PropaneTank")
    if not propaneTanks or propaneTanks:size() == 0 then
        propaneTanks = playerInv:getItemsFromType("Base.PropaneTank")
    end
    
    if propaneTanks and propaneTanks:size() > 0 then
        local tank = propaneTanks:get(0)
        if MOD_SETTINGS.DEBUG_MODE then
            print(MOD_SETTINGS.PRINT_PREFIX .. " Najden balon: " .. tostring(tank))
        end
        return true, tank
    end
    
    return false, nil
end

-- ============================================================================
-- БЛОК 6: КОНТЕКСТНОЕ МЕНЮ
-- ============================================================================

--[[
    Обработчик контекстного меню
]]
function PropaneGeneratorMod.onFillContextMenu(playerNum, context, worldobjects)
    local player = getSpecificPlayer(playerNum)
    if not player then 
        return 
    end
    
    -- Ищем генератор
    local generator = PropaneGeneratorMod.findOldGenerator(worldobjects)
    if not generator then 
        return 
    end
    
    -- Инициализируем данные
    local propaneData = PropaneGeneratorMod.initPropaneData(generator)
    
    -- Проверяем баллон
    local hasPropane, propaneTank = PropaneGeneratorMod.checkPropaneTank(player)
    if not hasPropane then
        if MOD_SETTINGS.DEBUG_MODE then
            print(MOD_SETTINGS.PRINT_PREFIX .. " Net balona v inventare")
        end
        return
    end
    
    -- Проверяем уровень топлива
    if propaneData.fuel >= propaneData.maxFuel then
        print(MOD_SETTINGS.PRINT_PREFIX .. " Generator uzhe zapravlen (" .. propaneData.fuel .. "%)")
        return
    end
    
    -- Создаем меню
    local generatorOption = context:addOption(MOD_SETTINGS.TEXT_GENERATOR_MENU, worldobjects, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(generatorOption, subMenu)
    
    -- Добавляем опцию заправки
    subMenu:addOption(
        MOD_SETTINGS.TEXT_REFUEL_OPTION,
        generator,
        PropaneGeneratorMod.startRefuelAction,
        player,
        propaneTank
    )
    
    -- Добавляем информацию о топливе
    local fuelPercent = math.floor((propaneData.fuel / propaneData.maxFuel) * 100)
    subMenu:addOption(MOD_SETTINGS.TEXT_FUEL_DISPLAY .. fuelPercent .. "%", worldobjects, nil)
    
    print(MOD_SETTINGS.PRINT_PREFIX .. " Menu sozdano. Toplivo: " .. fuelPercent .. "%")
end

-- ============================================================================
-- БЛОК 7: ТАЙМЕРНОЕ ДЕЙСТВИЕ
-- ============================================================================

-- Создаем класс действия
PropaneGeneratorMod.ISAddPropaneToGenerator = ISBaseTimedAction:derive("ISAddPropaneToGenerator")

--[[
    Конструктор действия
]]
function PropaneGeneratorMod.ISAddPropaneToGenerator:new(character, generator, propaneTank)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    o.generator = generator
    o.propaneTank = propaneTank
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = MOD_SETTINGS.REFUEL_TIME
    
    if character:isTimedActionInstant() then
        o.maxTime = 1
    end
    
    o.useProgressBar = true
    return o
end

--[[
    Проверка валидности
]]
function PropaneGeneratorMod.ISAddPropaneToGenerator:isValid()
    if not self.character or not self.generator then 
        return false 
    end
    
    if self.generator:getSquare() == nil then 
        return false 
    end
    
    local playerInv = self.character:getInventory()
    if not playerInv:contains(self.propaneTank) then 
        return false 
    end
    
    local modData = self.generator:getModData()
    if modData.propaneData and modData.propaneData.fuel >= 100 then 
        return false 
    end
    
    return true
end

--[[
    Обновление действия
]]
function PropaneGeneratorMod.ISAddPropaneToGenerator:update()
    if self.character and self.generator then
        self.character:faceThisObject(self.generator)
    end
   -- self:setActionText(MOD_SETTINGS.TEXT_ACTION)
end

--[[
    Начало действия
]]
function PropaneGeneratorMod.ISAddPropaneToGenerator:start()
    --self:setActionText(MOD_SETTINGS.TEXT_ACTION)
    self:setAnimVariable("LootPosition", "Low")
    self.character:SetVariable("LootPosition", "Low")
    
    if self.character.getEmitter then
        self.character:getEmitter():playSound(MOD_SETTINGS.SOUND_START)
    end
end

--[[
    Выполнение действия
]]
function PropaneGeneratorMod.ISAddPropaneToGenerator:perform()
    -- Удаляем баллон
    if self.character and self.character.getInventory then
        self.character:getInventory():Remove(self.propaneTank)
    end
    
    -- Обновляем данные
    local modData = self.generator:getModData()
    if not modData.propaneData then
        modData.propaneData = {fuel = 0, maxFuel = 100}
    end
    
    modData.propaneData.fuel = MOD_SETTINGS.PROPANE_PER_TANK
    
    -- Устанавливаем топливо
    if self.generator.setFuel then
        self.generator:setFuel(modData.propaneData.fuel)
    end
    
    -- Воспроизводим звук
    if self.character and self.character.getEmitter then
        self.character:getEmitter():playSound(MOD_SETTINGS.SOUND_FINISH)
    end
    
    print(MOD_SETTINGS.PRINT_PREFIX .. " Generator zapravlen! (" .. modData.propaneData.fuel .. "%)")
    
    ISBaseTimedAction.perform(self)
end

--[[
    Прерывание действия
]]
function PropaneGeneratorMod.ISAddPropaneToGenerator:stop()
    ISBaseTimedAction.stop(self)
end

-- ============================================================================
-- БЛОК 8: ЗАПУСК ДЕЙСТВИЯ
-- ============================================================================

--[[
    Функция запуска действия из меню
]]
function PropaneGeneratorMod.startRefuelAction(generator, player, propaneTank)
    ISTimedActionQueue.add(
        PropaneGeneratorMod.ISAddPropaneToGenerator:new(player, generator, propaneTank)
    )
    print(MOD_SETTINGS.PRINT_PREFIX .. " Deistvie zapravki dobavleno v ochered'")
end

-- ============================================================================
-- БЛОК 9: ЗАГРУЗКА МОДА
-- ============================================================================

-- Автоматический запуск
print(MOD_SETTINGS.PRINT_PREFIX .. " =========================================")
PropaneGeneratorMod.init()
print(MOD_SETTINGS.PRINT_PREFIX .. " MOD USPEKHNO ZAGRUZHEN!")
print(MOD_SETTINGS.PRINT_PREFIX .. " =========================================")

return PropaneGeneratorMod
