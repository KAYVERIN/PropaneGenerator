-- ====================================================================
-- PropaneGeneratorMod.lua - Мод для заправки генератора пропаном
-- Версия 3.0 с логикой замены по проценту топлива
-- Автоматическое восстановление подключения при замене
-- ====================================================================
require "TimedActions/ISBaseTimedAction"

-- ====================================================================
-- РАЗДЕЛ 1: НАСТРОЙКИ МОДА
-- ====================================================================

-- Эффективность пропанового баллона:
-- Сколько единиц топлива генератора дает один ПОЛНЫЙ баллон пропана?
local FUEL_PER_FULL_TANK = 50

-- Пороговые значения для смены типа генератора (в десятичных дробях):
-- Если в генераторе БОЛЕЕ 30% бензина - не переводим на пропан
local GASOLINE_MAX_FOR_CONVERSION = 0.30  -- 30%

-- Если в пропановом генераторе МЕНЕЕ 70% пропана - возвращаем к бензину
local PROPANE_MIN_TO_KEEP = 0.70  -- 70%

-- Минимальный уровень в баллоне для проверки "пустоты"
local EMPTY_TANK_THRESHOLD = 0.001

-- Включить отладочные сообщения (true) или выключить (false)
local ENABLE_DEBUG_PRINTS = true

-- Названия типов предметов (должны совпадать с items.txt)
local GENERATOR_OLD = "Generator_Old"
local GENERATOR_PROPANE = "Generator_Old_Propane"

-- ====================================================================
-- РАЗДЕЛ 2: ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ====================================================================

-- Функция для вывода отладочных сообщений
local function debugPrint(message)
    if ENABLE_DEBUG_PRINTS then
        print("[ПРОПАН_МОД] " .. tostring(message))
    end
end

debugPrint("Загрузка скрипта PropaneGeneratorMod.lua...")

-- Глобальное хранилище данных о генераторах
local GENERATOR_DATA_KEY = "PropaneGeneratorData"

-- Создание уникального идентификатора для генератора
local function getGeneratorID(generator)
    if not generator or not generator:getSquare() then
        debugPrint("Ошибка: генератор или его квадрат не существует")
        return nil
    end
    
    local square = generator:getSquare()
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local genID = string.format("gen_%d_%d_%d", x, y, z)
    
    debugPrint("Создан ID генератора: " .. genID)
    return genID
end

-- Получение типа генератора по спрайту (надежный способ)
local function getGeneratorTypeBySprite(generator)
    if not generator then 
        debugPrint("Ошибка: генератор = nil")
        return nil 
    end
    
    local sprite = generator:getSprite()
    if not sprite then 
        debugPrint("Ошибка: у генератора нет спрайта")
        return nil 
    end
    
    local spriteName = sprite:getName()
    debugPrint("Имя спрайта генератора: " .. tostring(spriteName))
    
    -- Спрайты старых генераторов
    local oldGeneratorSprites = {
        "appliances_misc_01_4",
        "appliances_misc_01_5", 
        "appliances_misc_01_6",
        "appliances_misc_01_7"
    }
    
    -- Проверяем, является ли спрайт старым генератором
    for _, oldSprite in ipairs(oldGeneratorSprites) do
        if spriteName == oldSprite then
            return GENERATOR_OLD
        end
    end
    
    return "unknown"
end


-- Проверка, является ли генератор старым (бензиновым)
local function isOldGenerator(generator)
    local genType = getGeneratorTypeBySprite(generator)
    local isOld = (genType == GENERATOR_OLD)
    
    debugPrint("Проверка старого генератора: результат = " .. tostring(isOld))
    return isOld
end

-- Сохранение данных генератора в ModData
local function saveGeneratorData(generatorID, data)
    if not ModData.exists(GENERATOR_DATA_KEY) then
        ModData.add(GENERATOR_DATA_KEY, {})
        debugPrint("Создано ModData для хранения данных генераторов")
    end
    
    local allData = ModData.get(GENERATOR_DATA_KEY)
    allData[generatorID] = data
    
    ModData.transmit(GENERATOR_DATA_KEY)
    debugPrint("Данные сохранены для генератора: " .. generatorID)
end

-- Получение данных генератора из ModData
local function loadGeneratorData(generatorID)
    if not ModData.exists(GENERATOR_DATA_KEY) then
        debugPrint("ModData не существует")
        return nil
    end
    
    local allData = ModData.get(GENERATOR_DATA_KEY)
    return allData[generatorID]
end

-- ====================================================================
-- РАЗДЕЛ 3: ФУНКЦИИ ДЛЯ РАБОТЫ С ПОДКЛЮЧЕНИЕМ ГЕНЕРАТОРА
-- ====================================================================

-- Функция замены генератора с сохранением подключения
local function replaceGeneratorInWorld(oldGenerator, newGeneratorType, fuelAmount, condition, playerObj)
    if not oldGenerator or not oldGenerator:getSquare() then
        debugPrint("ОШИБКА: генератор или квадрат не существует")
        return nil
    end
    
    local square = oldGenerator:getSquare()
    local cell = getWorld():getCell()
    
    -- Получаем параметры старого генератора
    local currentFuel = fuelAmount or oldGenerator:getFuel()
    local currentCondition = condition or oldGenerator:getCondition()
    local isActivated = oldGenerator:isActivated()
    local isConnected = oldGenerator:isConnected()
    
    debugPrint("=== ЗАМЕНА ГЕНЕРАТОРА ===")
    debugPrint(string.format("Старый: топливо=%d, состояние=%d", currentFuel, currentCondition))
    debugPrint(string.format("Активирован=%s, Подключен=%s", tostring(isActivated), tostring(isConnected)))
    
    -- Шаг 1: Создаём предмет нового генератора
    local newItem = instanceItem(newGeneratorType)
    if not newItem then
        debugPrint("ОШИБКА: не удалось создать предмет " .. newGeneratorType)
        return nil
    end
    
    -- Устанавливаем состояние (если метод существует)
    if newItem.setCondition then
        newItem:setCondition(currentCondition)
        debugPrint("Состояние предмета установлено: " .. currentCondition)
    end
    
    -- Шаг 2: УДАЛЯЕМ старый генератор из мира
    debugPrint("Удаление старого генератора из квадрата...")
    
    -- Способ из MOGenerator.lua
    if square.transmitRemoveItemFromSquare then
        square:transmitRemoveItemFromSquare(oldGenerator)
        debugPrint("Старый генератор удалён через transmitRemoveItemFromSquare")
    else
        debugPrint("ВНИМАНИЕ: метод transmitRemoveItemFromSquare не найден")
        -- Альтернатива: просто скрываем
        if oldGenerator.setVisible then
            oldGenerator:setVisible(false)
            debugPrint("Старый генератор скрыт")
        end
    end
    
    -- Шаг 3: СОЗДАЁМ новый генератор в мире
    debugPrint("Создание нового генератора...")
    
    local newGenerator = nil
    
    -- Способ из MOGenerator.lua
    if IsoGenerator and IsoGenerator.new then
        newGenerator = IsoGenerator.new(newItem, cell, square)
        debugPrint("Новый генератор создан через IsoGenerator.new")
    end
    
    if not newGenerator then
        debugPrint("ОШИБКА: не удалось создать новый генератор")
        return nil
    end
    
    -- Шаг 4: Устанавливаем параметры
    if newGenerator.setFuel then
        newGenerator:setFuel(currentFuel)
        debugPrint("Топливо установлено: " .. currentFuel)
    end
    
    if isActivated and newGenerator.setActivated then
        newGenerator:setActivated(true)
        debugPrint("Генератор активирован")
    end
    
    -- Шаг 5: Восстанавливаем подключение
    if isConnected and playerObj then
        debugPrint("Восстановление подключения...")
        if newGenerator.setConnected then
            newGenerator:setConnected(true)
            debugPrint("Подключение установлено через setConnected(true)")
        end
    end
    
    -- Шаг 6: Синхронизация (как в MOGenerator.lua)
    if newGenerator.transmitCompleteItemToClients then
        newGenerator:transmitCompleteItemToClients()
        debugPrint("Синхронизация через transmitCompleteItemToClients")
    elseif newGenerator.sync then
        newGenerator:sync()
        debugPrint("Синхронизация через sync()")
    end
    
    debugPrint("=== ЗАМЕНА ЗАВЕРШЕНА УСПЕШНО ===")
    return newGenerator
end

-- ====================================================================
-- РАЗДЕЛ 4: ОСНОВНОЙ КЛАСС ДЕЙСТВИЯ - ЗАПРАВКА ПРОПАНОМ
-- ====================================================================

ISAddPropaneToGenerator = ISBaseTimedAction:derive("ISAddPropaneToGenerator")

-- Метод проверки возможности выполнения действия
function ISAddPropaneToGenerator:isValid()
    debugPrint("Проверка возможности заправки пропаном...")
    
    -- Проверка 1: Генератор не должен быть полным
    if self.generator:getFuel() >= self.generator:getMaxFuel() then
        debugPrint("Генератор полон - действие невозможно")
        return false
    end
    
    -- Проверка 2: Генератор должен существовать в мире
    if self.generator:getObjectIndex() == -1 then
        debugPrint("Генератор не существует в мире")
        return false
    end
    
    -- Проверка 3: Генератор должен быть старым (бензиновым)
    if not isOldGenerator(self.generator) then
        debugPrint("Генератор не является Generator_Old")
        return false
    end
    
    -- Проверка 4: Генератор не должен быть активирован
    if self.generator:isActivated() then
        debugPrint("Генератор активирован - заправка невозможна")
        return false
    end
    
    -- Проверка 5: Пропановый баллон должен быть в руках
    local hasTank = self.character:isPrimaryHandItem(self.propaneTank) or 
                    self.character:isSecondaryHandItem(self.propaneTank)
    
    debugPrint("Пропановый баллон в руках? - " .. tostring(hasTank))
    return hasTank
end

-- Метод ожидания начала действия
function ISAddPropaneToGenerator:waitToStart()
    self.character:faceThisObject(self.generator)
    return self.character:shouldBeTurning()
end

-- Метод обновления во время выполнения
function ISAddPropaneToGenerator:update()
    -- Обновляем прогресс на баллоне для анимации
    if self.propaneTank and self.propaneTank.setJobDelta then
        self.propaneTank:setJobDelta(self:getJobDelta())
    end
    
    -- Поворачиваем персонажа к генератору
    self.character:faceThisObject(self.generator)
    
    -- Устанавливаем метаболическую цель
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

-- Метод начала действия
function ISAddPropaneToGenerator:start()
    debugPrint("Начало заправки пропаном, игрок: " .. self.character:getUsername())
    
    -- Устанавливаем анимацию
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    
    -- Настраиваем отображение прогресса на баллоне
    if self.propaneTank and self.propaneTank.setJobType then
        self.propaneTank:setJobType(getText("IGUI_PlayerText_Refueling"))
        self.propaneTank:setJobDelta(0.0)
    end
    
    -- Воспроизводим звук заправки
    self.sound = self.character:playSound("GeneratorAddFuel")
    debugPrint("Звук заправки воспроизведен")
end

-- Метод остановки действия
function ISAddPropaneToGenerator:stop()
    debugPrint("Действие заправки прервано")
    
    -- Останавливаем звук
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    
    -- Сбрасываем прогресс на баллоне
    if self.propaneTank and self.propaneTank.setJobDelta then
        self.propaneTank:setJobDelta(0.0)
    end
    
    -- Вызываем родительский метод
    ISBaseTimedAction.stop(self)
end

-- Метод выполнения
function ISAddPropaneToGenerator:perform()
    debugPrint("Действие заправки выполнено")
    
    -- Останавливаем звук
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
    end
    
    -- Сбрасываем прогресс на баллоне
    if self.propaneTank and self.propaneTank.setJobDelta then
        self.propaneTank:setJobDelta(0.0)
    end
    
    -- Вызываем родительский метод
    ISBaseTimedAction.perform(self)
end

-- Основная логика заправки с НОВОЙ механикой
function ISAddPropaneToGenerator:complete()
    debugPrint("=== ОСНОВНАЯ ЛОГИКА ЗАПРАВКИ ПРОПАНОМ ===")
    
    -- Шаг 1: Получаем текущие значения
    local currentFuel = self.generator:getFuel()
    local maxFuel = self.generator:getMaxFuel()
    
    -- Шаг 3: Используем ВСТРОЕННЫЙ метод getFuelPercentage() из игры!
    -- Старый код: local fuelPercentage = currentFuel / maxFuel
    local fuelPercentage = self.generator:getFuelPercentage() / 100  -- Получаем 0.0-1.0
    
    debugPrint(string.format("Текущий процент бензина: %.1f%% (через getFuelPercentage)", 
        fuelPercentage * 100))
    debugPrint(string.format("Порог для замены: %.1f%%", GASOLINE_MAX_FOR_CONVERSION * 100))
    
    -- Шаг 4: Принимаем решение о замене генератора
    local shouldReplaceGenerator = (fuelPercentage <= GASOLINE_MAX_FOR_CONVERSION)
    
    if shouldReplaceGenerator then
        debugPrint("РЕШЕНИЕ: Заменить генератор на пропановый")
        
        -- Шаг 5: Уменьшаем содержимое баллона
        local percentUsed = fuelToTransfer / FUEL_PER_FULL_TANK
        local newTankPercent = currentTankPercent - percentUsed
        
        if newTankPercent < EMPTY_TANK_THRESHOLD then
            newTankPercent = 0
            debugPrint("Баллон теперь пустой")
        end
        
        self.propaneTank:setUsedDelta(newTankPercent)
        debugPrint(string.format("Новый уровень в баллоне: %.1f%%", newTankPercent * 100))
        
        -- Шаг 6: Заменяем генератор с сохранением подключения
        local newFuelAmount = currentFuel + fuelToTransfer
        local newGenerator = replaceGeneratorWithConnection(
            self.generator,
            GENERATOR_PROPANE,
            newFuelAmount,
            self.generator:getCondition(),
            self.character
        )
        
        if newGenerator then
            debugPrint("Генератор успешно заменен на пропановый")
        else
            debugPrint("ОШИБКА: Не удалось заменить генератор")
            return false
        end
        
    else
        debugPrint("РЕШЕНИЕ: Не заменять, добавить пропан к бензину")
        
        -- Просто добавляем пропан как дополнительное топливо
        local newFuelAmount = currentFuel + fuelToTransfer
        self.generator:setFuel(newFuelAmount)
        
        -- Уменьшаем баллон
        local percentUsed = fuelToTransfer / FUEL_PER_FULL_TANK
        local newTankPercent = currentTankPercent - percentUsed
        if newTankPercent < EMPTY_TANK_THRESHOLD then newTankPercent = 0 end
        self.propaneTank:setUsedDelta(newTankPercent)
        
        debugPrint(string.format("Добавлено %d единиц пропана к бензину", fuelToTransfer))
        debugPrint(string.format("Общее топливо теперь: %d единиц", newFuelAmount))
    end
    
    -- Шаг 7: Синхронизируем изменения
    if self.propaneTank.syncItemFields then
        self.propaneTank:syncItemFields()
        debugPrint("Синхронизация баллона выполнена")
    end
    
    if self.generator.sync then
        self.generator:sync()
        debugPrint("Синхронизация генератора выполнена")
    end
    
    debugPrint("=== ВСЕ ЭТАПЫ УСПЕШНО ЗАВЕРШЕНЫ ===")
    return true
end

-- Метод получения длительности действия
function ISAddPropaneToGenerator:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end
    return 100
end

-- Конструктор класса
function ISAddPropaneToGenerator:new(character, generator, propaneTank)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    
    -- Сохраняем ссылки на объекты
    o.generator = generator
    o.propaneTank = propaneTank
    o.sound = nil
    
    debugPrint("Создано новое действие для " .. character:getUsername())
    return o
end

-- ====================================================================
-- РАЗДЕЛ 5: ОБРАБОТЧИКИ КОНТЕКСТНОГО МЕНЮ
-- ====================================================================

-- Функция вызываемая при выборе опции в меню
function onAddPropaneToGenerator(worldObjects, generator, playerNum)
    debugPrint("Вызов из контекстного меню: заправка пропаном")
    
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then
        debugPrint("Ошибка: игрок не найден")
        return
    end
    
    -- Поиск пропанового баллона в руках
    local propaneTank = nil
    local primaryItem = playerObj:getPrimaryHandItem()
    local secondaryItem = playerObj:getSecondaryHandItem()
    
    if primaryItem and primaryItem:getType() == "PropaneTank" then
        if primaryItem:getCurrentUsesFloat() > 0 then
            propaneTank = primaryItem
            debugPrint("Баллон найден в основной руке")
        end
    elseif secondaryItem and secondaryItem:getType() == "PropaneTank" then
        if secondaryItem:getCurrentUsesFloat() > 0 then
            propaneTank = secondaryItem
            debugPrint("Баллон найден во второй руке")
        end
    end
    
    -- Проверка наличия баллона с топливом
    if not propaneTank then
        playerObj:Say(getText("IGUI_PlayerText_NeedPropaneTank"))
        debugPrint("Нет подходящего баллона")
        return
    end
    
    -- Проверка заполненности генератора
    if generator:getFuel() >= generator:getMaxFuel() then
        playerObj:Say(getText("IGUI_PlayerText_GeneratorFull"))
        debugPrint("Генератор уже полон")
        return
    end
    
    -- Проверка активации генератора
    if generator:isActivated() then
        playerObj:Say("Сначала выключите генератор")
        debugPrint("Генератор активирован - заправка невозможна")
        return
    end
    
    -- Добавление действия в очередь
    debugPrint("Добавление действия в очередь...")
    local action = ISAddPropaneToGenerator:new(playerObj, generator, propaneTank)
    ISTimedActionQueue.add(action)
end

-- Обработчик заполнения контекстного меню
function onFillWorldObjectContextMenu(player, context, worldObjects)
    debugPrint("Обработка контекстного меню...")
    
    local playerObj = getSpecificPlayer(player)
    if not playerObj then
        debugPrint("Ошибка: игрок не найден")
        return
    end
    
    -- Поиск генератора среди объектов
    local generator = nil
    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        if obj and obj.isActivated ~= nil and obj.getFuel ~= nil and obj.getMaxFuel ~= nil then
            generator = obj
            debugPrint("Генератор найден")
            break
        end
    end
    
    if not generator then
        debugPrint("Генератор не найден среди объектов")
        return
    end
    
    -- Проверка типа генератора (только Generator_Old)
    if not isOldGenerator(generator) then
        debugPrint("Это не Generator_Old")
        return
    end
    
    -- Проверка активации генератора (ВАЖНО!)
    if generator:isActivated() then
        debugPrint("Генератор активирован - не показывать опцию заправки")
        return
    end
    
    -- Проверка заполненности генератора
    if generator:getFuel() >= generator:getMaxFuel() then
        debugPrint("Генератор полон")
        return
    end
    
    -- Проверка наличия пропанового баллона в руках
    local hasPropaneTank = false
    local primaryItem = playerObj:getPrimaryHandItem()
    local secondaryItem = playerObj:getSecondaryHandItem()
    
    if (primaryItem and primaryItem:getType() == "PropaneTank" and 
        primaryItem:getCurrentUsesFloat() > 0) or
       (secondaryItem and secondaryItem:getType() == "PropaneTank" and 
        secondaryItem:getCurrentUsesFloat() > 0) then
        hasPropaneTank = true
        debugPrint("Пропановый баллон в руках найден")
    end
    
    -- Добавление опции в контекстное меню
    local optionText = getText("ContextMenu_GeneratorAddPropane")
    local option = context:addOption(optionText, worldObjects, onAddPropaneToGenerator, generator, player)
    
    -- Если нет баллона, делаем опцию неактивной
    if not hasPropaneTank then
        option.notAvailable = true
        local tooltip = ISToolTip:new()
        tooltip:setName(optionText)
        tooltip.description = getText("Tooltip_NeedPropaneTank")
        option.toolTip = tooltip
        debugPrint("Опция сделана неактивной (нет баллона)")
    else
        debugPrint("Опция добавлена и активна")
    end
end

-- ====================================================================
-- РАЗДЕЛ 6: ИНИЦИАЛИЗАЦИЯ МОДА
-- ====================================================================

-- Функция инициализации мода при старте игры
local function initializeMod()
    debugPrint("================================================")
    debugPrint("ИНИЦИАЛИЗАЦИЯ МОДА PROPANE GENERATOR")
    debugPrint("================================================")
    debugPrint("Настройки мода:")
    debugPrint("  FUEL_PER_FULL_TANK: " .. FUEL_PER_FULL_TANK .. " единиц")
    debugPrint("  GASOLINE_MAX_FOR_CONVERSION: " .. (GASOLINE_MAX_FOR_CONVERSION * 100) .. "%")
    debugPrint("  PROPANE_MIN_TO_KEEP: " .. (PROPANE_MIN_TO_KEEP * 100) .. "%")
    debugPrint("  EMPTY_TANK_THRESHOLD: " .. EMPTY_TANK_THRESHOLD)
    debugPrint("================================================")
    
    -- Регистрация обработчика контекстного меню
    Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
    
    -- Инициализация ModData для хранения данных
    if not ModData.exists(GENERATOR_DATA_KEY) then
        ModData.add(GENERATOR_DATA_KEY, {})
        debugPrint("ModData инициализировано для хранения данных генераторов")
    end
    
    debugPrint("МОД УСПЕШНО ЗАГРУЖЕН И ГОТОВ К РАБОТЕ")
end

-- Регистрация события инициализации
Events.OnGameStart.Add(initializeMod)

-- Регистрация обработчика меню (на случай если игра уже запущена)
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- Вывод сообщения о загрузке
debugPrint("PropaneGeneratorMod.lua ЗАГРУЖЕН УСПЕШНО!")
debugPrint("Ожидание запуска игры для полной инициализации...")
