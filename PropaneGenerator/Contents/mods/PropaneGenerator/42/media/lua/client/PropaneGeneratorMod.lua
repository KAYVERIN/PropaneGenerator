-- PropaneGeneratorMod.lua
-- Полный мод для пропанового генератора в Project Zomboid Build 42.13.2
-- Объединяет регистрацию топлива, действие и интеграцию в UI.

-------------------------------------------------------------------
-- 1. РЕГИСТРАЦИЯ ТИПА ТОПЛИВА "ПРОПАН"
-------------------------------------------------------------------
if not FuelTypes then FuelTypes = {} end
FuelTypes.Propane = {
    name = "Propane",
    itemName = "Base.PropaneTank",
    -- Сообщаем игре, что пустой предмет - это Base.EmptyPropaneTank
    emptyContainer = "Base.EmptyPropaneTank",
    -- Коэффициент может регулировать скорость заправки
    ratio = 1.0
}
print("[PropaneGeneratorMod] Тип топлива 'Propane' зарегистрирован.")

-------------------------------------------------------------------
-- 2. КЛАСС ДЕЙСТВИЯ ДОБАВЛЕНИЯ ПРОПАНА
--    Наследуется от встроенного ISAddFuelAction
-------------------------------------------------------------------
local AddPropaneAction = ISBaseTimedAction:derive("AddPropaneAction")

function AddPropaneAction:new(character, generator, propaneTank, time)
    local o = ISBaseTimedAction.new(self, character)
    o.generator = generator
    o.propaneTank = propaneTank
    o.maxTime = time or 50 -- Время по умолчанию

    o.stopOnWalk = true
    o.stopOnRun = true
    o.forceProgressBar = true -- Всегда показывать полосу прогресса

    -- Кэшируем тип генератора для быстрой проверки
    o.isPropaneGenerator = generator:getModData().fuelType == "Propane"
    
    return o
end

function AddPropaneAction:isValid()
    -- Базовые проверки родительского класса
    if not self.character or not self.generator or not self.propaneTank then
        return false
    end
    
    -- Проверка 1: Генератор должен быть пропановым
    if not self.isPropaneGenerator then
        return false
    end
    
    -- Проверка 2: Расстояние до генератора
    if self.character:DistToSquared(self.generator:getX() + 0.5, self.generator:getY() + 0.5) > 4 then
        return false
    end
    
    -- Проверка 3: В баллоне должно быть топливо
    if self.propaneTank:getUsedDelta() <= 0 then
        return false
    end
    
    -- Проверка 4: Генератор не должен быть полным
    if self.generator:getFuel() >= 1.0 then
        return false
    end
    
    -- Проверка 5: Баллон должен быть именно пропановым
    if not self.propaneTank:getType() or not string.contains(self.propaneTank:getType():lower(), "propanetank") then
        return false
    end
    
    return true
end

function AddPropaneAction:update()
    -- Персонаж всегда смотрит на генератор во время действия
    self.character:faceThisObject(self.generator)
    -- Можно добавить дополнительные анимации
    if self.character:getSpriteDef() and not self.character:getSpriteDef():getType() == "Loot" then
        self:setActionAnim("Loot")
    end
end

function AddPropaneAction:start()
    -- Стандартная анимация "добычи" для заправки
    self:setActionAnim("Loot")
    self:setOverrideHandModels(nil, nil)
    
    -- Звук начала заправки (можно заменить на кастомный)
    if self.character:getEmitter():playSound("GeneratorRefuel") then
        self.soundStarted = true
    end
    
    -- Инициализация переменных для плавного прогресса
    self.initialFuel = self.generator:getFuel()
    self.initialPropane = self.propaneTank:getUsedDelta()
end

function AddPropaneAction:perform()
    -- Убедимся, что действие все еще валидно
    if not self:isValid() then
        ISBaseTimedAction.perform(self)
        return
    end
    
    -- Вычисляем количество топлива для перелива
    local fuelSpace = 1.0 - self.generator:getFuel()
    local fuelAvailable = self.propaneTank:getUsedDelta()
    local fuelAmount = math.min(fuelSpace, fuelAvailable)
    
    -- Применяем изменения
    self.generator:setFuel(self.generator:getFuel() + fuelAmount)
    self.propaneTank:setUsedDelta(fuelAvailable - fuelAmount)
    
    -- Если баллон опустел, заменить его на пустой
    -- В Build 42 это часто обрабатывается автоматически, но делаем для надежности
    if self.propaneTank:getUsedDelta() <= 0 then
        local emptyTank = InventoryItemFactory.CreateItem("Base.EmptyPropaneTank")
        if emptyTank and self.character:getInventory():contains(self.propaneTank) then
            self.character:getInventory():Remove(self.propaneTank)
            self.character:getInventory():AddItem(emptyTank)
        end
    end
    
    -- Обновляем интерфейс, если окно информации открыто
    if self.generator.window then
        self.generator.window:fillGeneratorInfo()
    end
    
    -- Звук завершения
    self.character:getEmitter():playSound("GeneratorRefuelEnd")
    
    -- Завершаем действие
    ISBaseTimedAction.perform(self)
end

function AddPropaneAction:stop()
    -- Останавливаем звук, если он играл
    if self.soundStarted then
        self.character:getEmitter():stopSoundByName("GeneratorRefuel")
    end
    ISBaseTimedAction.stop(self)
end

-------------------------------------------------------------------
-- 3. ИНТЕГРАЦИЯ В ОКНО ИНФОРМАЦИИ О ГЕНЕРАТОРЕ
--    Анализ ISGeneratorInfoWindow.lua показал, что кнопки добавляются
--    в метод createButtons. Мы его переопределим.
-------------------------------------------------------------------
local original_ISGeneratorInfoWindow_createButtons = ISGeneratorInfoWindow.createButtons

function ISGeneratorInfoWindow:createButtons(y, buttonHeight)
    -- Сначала вызываем оригинальный метод для стандартных кнопок
    y = original_ISGeneratorInfoWindow_createButtons(self, y, buttonHeight)
    
    -- Добавляем кнопку заправки пропаном ТОЛЬКО для пропановых генераторов
    if self.generator:getModData().fuelType == "Propane" then
        local buttonWidth = 100
        local buttonPad = 10
        
        -- Кнопка "Заправить пропаном"
        self.refuelPropaneBtn = ISButton:new(
            self.width - buttonWidth - buttonPad, 
            y, 
            buttonWidth, 
            buttonHeight, 
            getText("ContextMenu_RefuelPropane"), 
            self, 
            ISGeneratorInfoWindow.onRefuelPropane
        )
        self.refuelPropaneBtn.internal = "REFUEL_PROPANE"
        self.refuelPropaneBtn:initialise()
        self.refuelPropaneBtn:instantiate()
        self.refuelPropaneBtn.borderColor = {r=0.4, g=0.4, b=0.4, a=1.0}
        self.refuelPropaneBtn:setFont(UIFont.Small)
        self:addChild(self.refuelPropaneBtn)
        
        y = y + buttonHeight + 5
        
        -- Обновляем высоту окна, если нужно
        if y > self.height then
            self:setHeight(y + 20)
        end
    end
    
    return y
end

-- Обработчик нажатия кнопки "Заправить пропаном"
function ISGeneratorInfoWindow:onRefuelPropane()
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    
    -- Ищем баллон с пропаном в инвентаре
    local propaneTank = nil
    local inventory = player:getInventory()
    local items = inventory:getItems()
    
    for i=0, items:size()-1 do
        local item = items:get(i)
        if item and item:getType() and string.contains(item:getType():lower(), "propanetank") then
            if item:getUsedDelta() > 0 then
                propaneTank = item
                break
            end
        end
    end
    
    if not propaneTank then
        -- Если нет баллона, показываем сообщение
        player:Say(getText("ContextMenu_NoPropaneTank"))
        return
    end
    
    -- Создаем и добавляем действие в очередь
    local action = AddPropaneAction:new(player, self.generator, propaneTank, 50)
    ISTimedActionQueue.add(action)
    
    -- Закрываем окно после начала действия
    self:close()
end

-------------------------------------------------------------------
-- 4. ОБРАБОТКА КОНТЕКСТНОГО МЕНЮ В МИРЕ
--    Добавляем опцию для пропановых генераторов в мире
-------------------------------------------------------------------
local original_ISWorldObjectContextMenu_createMenu = ISWorldObjectContextMenu.createMenu

function ISWorldObjectContextMenu.createMenu(playerNum, worldObjects, x, y, test)
    local context = original_ISWorldObjectContextMenu_createMenu(playerNum, worldObjects, x, y, test)
    
    local player = getSpecificPlayer(playerNum)
    if not player or not context then return context end
    
    -- Проверяем, есть ли среди объектов пропановый генератор
    for i=1, #worldObjects do
        local object = worldObjects[i]
        if instanceof(object, "IsoGenerator") then
            if object:getModData().fuelType == "Propane" then
                -- Добавляем опцию в меню
                local option = context:addOption(
                    getText("ContextMenu_GeneratorInfo"), 
                    worldObjects, 
                    ISWorldObjectContextMenu.onGeneratorInfo, 
                    playerNum, object
                )
                -- Можно добавить иконку
                option.iconTexture = getTexture("media/textures/menu_icons/Generator.png")
                
                -- Если у игрока есть баллон с пропаном, добавляем опцию заправки
                local hasPropane = false
                local inventory = player:getInventory()
                local items = inventory:getItems()
                
                for j=0, items:size()-1 do
                    local item = items:get(j)
                    if item and item:getType() and string.contains(item:getType():lower(), "propanetank") then
                        if item:getUsedDelta() > 0 then
                            hasPropane = true
                            break
                        end
                    end
                end
                
                if hasPropane then
                    local refuelOption = context:addOption(
                        getText("ContextMenu_RefuelPropane"), 
                        worldObjects, 
                        function(worldObjects, playerNum, generator)
                            local player = getSpecificPlayer(playerNum)
                            local propaneTank = nil
                            local inventory = player:getInventory()
                            local items = inventory:getItems()
                            
                            for k=0, items:size()-1 do
                                local item = items:get(k)
                                if item and item:getType() and string.contains(item:getType():lower(), "propanetank") then
                                    if item:getUsedDelta() > 0 then
                                        propaneTank = item
                                        break
                                    end
                                end
                            end
                            
                            if propaneTank then
                                local action = AddPropaneAction:new(player, generator, propaneTank, 50)
                                ISTimedActionQueue.add(action)
                            end
                        end, 
                        playerNum, object
                    )
                    refuelOption.iconTexture = getTexture("media/textures/menu_icons/Fuel.png")
                end
                
                break -- Только первый найденный генератор
            end
        end
    end
    
    return context
end

-------------------------------------------------------------------
-- 5. ИНИЦИАЛИЗАЦИЯ МОДА
-------------------------------------------------------------------
local function init()
    print("[PropaneGeneratorMod] Мод инициализирован для Build 42.13.2")
    
    -- Проверяем, что предмет PropaneTank существует
    if not getScriptManager():getItem("Base.PropaneTank") then
        print("[PropaneGeneratorMod] ВНИМАНИЕ: Предмет Base.PropaneTank не найден!")
    else
        print("[PropaneGeneratorMod] Предмет Base.PropaneTank найден")
    end
end

-- Инициализируем мод после загрузки игры
Events.OnGameStart.Add(init)

-------------------------------------------------------------------
-- 6. ДОПОЛНИТЕЛЬНЫЕ УТИЛИТЫ
-------------------------------------------------------------------
-- Функция для проверки, является ли предмет пропановым баллоном
function isPropaneTank(item)
    if not item then return false end
    if not item.getType then return false end
    local itemType = item:getType()
    return itemType and string.contains(itemType:lower(), "propanetank")
end

-- Функция для получения количества пропана в инвентаре (в условных единицах)
function getPropaneAmount(player)
    if not player then return 0 end
    local total = 0
    local inventory = player:getInventory()
    local items = inventory:getItems()
    
    for i=0, items:size()-1 do
        local item = items:get(i)
        if isPropaneTank(item) then
            total = total + item:getUsedDelta()
        end
    end
    
    return total
end

-- Загрузка пользовательских текстур для мода
local function loadCustomTextures()
    -- Загружаем текстуру для отображения генератора на земле
    if not getTexture("media/textures/GeneratorPropane.png") then
        print("[PropaneGeneratorMod] ВНИМАНИЕ: Текстура GeneratorPropane.png не найдена!")
    else
        print("[PropaneGeneratorMod] Текстура GeneratorPropane.png успешно загружена.")
    end
end

-- Загружаем текстуры при запуске игры
Events.OnGameBoot.Add(loadCustomTextures)