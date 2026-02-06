-- ZenFishing.lua для Project Zomboid 42.13.1+
ZenFishing = {}

-- Конфигурация по умолчанию (используется если нет настроек песочницы)
ZenFishing.defaultConfig = {
    -- Настройки автонасадки наживки
    autoBaitEnabled = true,                 -- Включить автонасадку
    autoBaitCheckInterval = 3000,           -- Интервал проверки наживки (мс)
    useBestBaitFirst = true,                -- Использовать лучшую наживку первой
    minBaitCondition = 0.1,                 -- Минимальное состояние наживки (0-1)
    ignoreSpoiledBait = true,               -- Игнорировать испорченную наживку
    showBaitNotifications = true,           -- Показывать уведомления о наживки
    
    -- Настройки системы настроения
    moodSystemEnabled = true,               -- Включить систему настроения
    moodEffectInterval = 2000,              -- Интервал применения эффекта настроения (мс)
    stressReductionRate = 1.0,              -- Скорость уменьшения стресса (установлено на 1)
    boredomReductionRate = 0.003,           -- Скорость уменьшения скуки
    panicReductionRate = 0.004,             -- Скорость уменьшения паники
    unhappinessReductionRate = 1.0,         -- Скорость уменьшения несчастья (установлено на 1)
    moodBoostMultiplier = 1.0,              -- Множитель эффекта настроения
    
    -- Настройки ускорения времени
    enableTimeAcceleration = true,          -- Включить ускорение времени
    timeAccelerationSpeed = 3,              -- Скорость игры при ускорении
    timeAccelerationMultiplier = 20,        -- Мультипликатор времени
    
    -- Настройки автоматической рыбалки
    enableAutoHook = true,                  -- Включить автоматическую подсечку
    enableAutoReel = true,                  -- Включить автоматическое выуживание
    
    -- Ускорение timed-actions
    enableActionSpeedup = true,             -- Включить ускорение действий
    actionSpeedMultiplier = 3.0,            -- Множитель скорости действий (3x быстрее)
    
    -- Приоритеты наживки (от высокого к низкому)
    baitPriority = {
        "FishingTackle",
        "Worm",
        "Cricket",
        "Grasshopper",
        "BaitFish",
        "Frog",
        "Roach",
        "Cockroach",
        -- Добавлены все наживки из fishing_properties.lua
        "AmericanLadyCaterpillar",
        "BandedWoolyBearCaterpillar",
        "Centipede",
        "Centipede2",
        "Millipede",
        "Millipede2",
        "MonarchCaterpillar",
        "Pillbug",
        "SawflyLarva",
        "SilkMothCaterpillar",
        "SwallowtailCaterpillar",
        "Termites",
        "Tadpole",
        "Leech",
        "Snail",
        "Slug",
        "Slug2",
        "Maggots",
        "Crayfish",
        "Shrimp",
        "DogfoodOpen",
        "FishFillet",
        "Smallanimalmeat",
        "Smallbirdmeat",
        "MeatPatty",
        "FrogMeat",
        "Steak",
        "Cheese",
        "CannedCornOpen",
        "Dough",
        "Bread",
        "BreadDough",
        "BaguetteDough",
        "Baguette",
        "JigLure",
        "MinnowLure"
    }
}

-- Активная конфигурация (будет перезаписана из песочницы)
ZenFishing.config = {}
for k, v in pairs(ZenFishing.defaultConfig) do
    ZenFishing.config[k] = v
end

-- Переменные состояния мода
local lastBaitCheckTick = 0        -- Время последней проверки наживки
local lastMoodEffectTick = 0       -- Время последнего применения эффекта настроения
local lastState = nil              -- Последнее состояние рыбалки
local isFishingActive = false      -- Флаг активности рыбалки
local moodEffectTimer = 0          -- Таймер эффекта настроения
local originalGameSpeed = 1        -- Оригинальная скорость игры
local originalTimeMultiplier = 1   -- Оригинальный множитель времени
local autoHookState = false        -- Состояние автоматической подсечки
local timeAccelerationApplied = false  -- Флаг применения ускорения времени
local reelSoundHandle = nil        -- Хэндл звука выуживания

-- Функция для обновления конфигурации из настроек песочницы
local function updateConfigFromSandbox()
    if not SandboxVars then return end
    
    local sandboxConfig = SandboxVars.ZenFishing
    if not sandboxConfig then return end
    
    -- Обновляем только те настройки, которые есть в песочнице
    local sandboxKeys = {
        "autoBaitEnabled",
        "showBaitNotifications", 
        "moodSystemEnabled",
        "enableTimeAcceleration",
        "enableAutoHook",
        "enableAutoReel",
        "enableActionSpeedup",
        "actionSpeedMultiplier"
    }
    
    for _, key in ipairs(sandboxKeys) do
        if sandboxConfig[key] ~= nil then
            ZenFishing.config[key] = sandboxConfig[key]
        end
    end
end

-- Функция остановки звука выуживания
local function stopReelSound()
    if reelSoundHandle then
        -- Получаем текущего игрока
        local player = getPlayer()
        if player then
            player:stopOrTriggerSound(reelSoundHandle)
        end
        reelSoundHandle = nil
    end
end

-- Проверка удочки
local function isFishingRod(item)
    if not item or type(item) ~= "userdata" then return false end
    
    if item.hasTag and item:hasTag(ItemTag.FISHING_ROD) then
        return true
    end
    
    return false
end

-- Проверка гарпуна
local function isFishingSpear(item)
    if not item then return false end
    
    if item.hasTag and item:hasTag(ItemTag.FISHING_SPEAR) then
        return true
    end
    
    return false
end

-- Проверка наживки
local function isFishingLure(item)
    if not item then return false end
    
    if item.isFishingLure and item:isFishingLure() then
        return true
    end
    
    return false
end

-- Получение менеджера рыбалки
local function getFishingManager(player)
    if not player or not Fishing or not Fishing.ManagerInstances then 
        return nil 
    end
    
    local playerNum = player:getPlayerNum()
    return Fishing.ManagerInstances[playerNum]
end

-- Получение текущего состояния рыбалки
local function getFishingState(player)
    local manager = getFishingManager(player)
    if not manager then return "None" end
    
    local stateName = "None"
    local state = manager.state
    
    if manager.states then
        for k, v in pairs(manager.states) do
            if v == state then 
                stateName = k
                break
            end
        end
    end
    
    return stateName
end

-- Проверка данных о наживке
local function getGameFishingData(fishingRod)
    if not fishingRod then return nil end
    
    local rodData = fishingRod:getModData()
    if not rodData then return nil end
    
    return rodData.fishing_Lure
end

-- Поиск лучшей наживки в инвентаре
local function findBestBaitInInventory(player)
    if not player then return nil end
    
    local inventory = player:getInventory()
    if not inventory then return nil end
    
    local bestBait = nil
    local bestPriority = 1000
    
    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and isFishingLure(item) then
            local itemType = item:getType()
            
            for priorityIndex, baitType in ipairs(ZenFishing.config.baitPriority) do
                if string.find(itemType, baitType) then
                    local conditionOK = true
                    
                    if ZenFishing.config.ignoreSpoiledBait then
                        if item.isFresh and not item:isFresh() then
                            conditionOK = false
                        end
                        if item.isRotten and item:isRotten() then
                            conditionOK = false
                        end
                    end
                    
                    if ZenFishing.config.minBaitCondition > 0 then
                        if item.getCondition then
                            local condition = item:getCondition()
                            local maxCondition = item:getConditionMax()
                            if condition and maxCondition and maxCondition > 0 then
                                local conditionRatio = condition / maxCondition
                                if conditionRatio < ZenFishing.config.minBaitCondition then
                                    conditionOK = false
                                end
                            end
                        end
                    end
                    
                    if conditionOK and priorityIndex < bestPriority then
                        bestPriority = priorityIndex
                        bestBait = item
                        break
                    end
                end
            end
            
            if not bestBait and conditionOK then
                bestBait = item
            end
        end
    end
    
    return bestBait
end

-- Проверка, нужна ли наживка на удочке
local function needsBait(fishingRod)
    if not fishingRod then return true end
    
    if isFishingSpear(fishingRod) then
        return false  -- Гарпун не требует наживки
    end
    
    local gameLure = getGameFishingData(fishingRod)
    
    return gameLure == nil
end

-- Переопределение метода create для ISFishingAction (осмотр рыбы)
local function overrideFishingAction()
    if not ISFishingAction then
        return
    end
    
    -- Сохраняем оригинальный метод create, если еще не сохраняли
    if not ISFishingAction._zenOriginalCreate then
        ISFishingAction._zenOriginalCreate = ISFishingAction.create
    end
    
    -- Переопределяем метод create
    function ISFishingAction:create()
        -- Вызываем оригинальный метод
        ISFishingAction._zenOriginalCreate(self)
        
        -- Применяем ускорение если включено в настройках
        if ZenFishing.config.enableActionSpeedup and type(self.maxTime) == "number" and self.maxTime > 0 then
            local multiplier = ZenFishing.config.actionSpeedMultiplier or 3.0
            self.maxTime = math.max(1, self.maxTime / multiplier)
            
            -- Обновляем время в action, если есть
            if self.action and self.action.setTime then
                self.action:setTime(self.maxTime)
            end
        end
    end
end

-- Переопределение метода create для AIAttachLureAction (насадка наживки)
local function overrideAttachLureAction()
    if not AIAttachLureAction then
        return
    end
    
    -- Сохраняем оригинальный метод create, если еще не сохраняли
    if not AIAttachLureAction._zenOriginalCreate then
        AIAttachLureAction._zenOriginalCreate = AIAttachLureAction.create
    end
    
    -- Переопределяем метод create
    function AIAttachLureAction:create()
        -- Вызываем оригинальный метод
        AIAttachLureAction._zenOriginalCreate(self)
        
        -- Применяем ускорение если включено в настройках
        if ZenFishing.config.enableActionSpeedup and type(self.maxTime) == "number" and self.maxTime > 0 then
            local multiplier = ZenFishing.config.actionSpeedMultiplier or 3.0
            self.maxTime = math.max(1, self.maxTime / multiplier)
            
            -- Обновляем время в action, если есть
            if self.action and self.action.setTime then
                self.action:setTime(self.maxTime)
            end
        end
    end
end

-- Переопределение метода create для ISPickupFishAction (подбор рыбы)
local function overridePickupFishAction()
    if not ISPickupFishAction then
        return
    end
    
    -- Сохраняем оригинальный метод create, если еще не сохраняли
    if not ISPickupFishAction._zenOriginalCreate then
        ISPickupFishAction._zenOriginalCreate = ISPickupFishAction.create
    end
    
    -- Переопределяем метод create
    function ISPickupFishAction:create()
        -- Вызываем оригинальный метод
        ISPickupFishAction._zenOriginalCreate(self)
        
        -- Применяем ускорение если включено в настройках
        if ZenFishing.config.enableActionSpeedup and type(self.maxTime) == "number" and self.maxTime > 0 then
            local multiplier = ZenFishing.config.actionSpeedMultiplier or 3.0
            self.maxTime = math.max(1, self.maxTime / multiplier)
            
            -- Обновляем время в action, если есть
            if self.action and self.action.setTime then
                self.action:setTime(self.maxTime)
            end
        end
    end
end

-- Создание действия насадки наживки
local function createAttachBaitAction(player)
    if not player or not ZenFishing.config.autoBaitEnabled then 
        return nil
    end
    
    -- Проверяем удочку в руках
    local fishingRod = player:getPrimaryHandItem()
    if not fishingRod or not isFishingRod(fishingRod) then
        fishingRod = player:getSecondaryHandItem()
        if not fishingRod or not isFishingRod(fishingRod) then
            return nil
        end
    end
    
    -- Проверяем, нужна ли наживка
    if not needsBait(fishingRod) then
        return nil
    end
    
    -- Ищем наживку в инвентаре
    local bait = findBestBaitInInventory(player)
    if not bait then
        if ZenFishing.config.showBaitNotifications then
            player:Say("No bait found...")
        end
        return nil
    end
    
    -- Создаем действие насадки наживки
    local action = AIAttachLureAction:new(player, fishingRod, bait)
    
    -- Уведомление
    if ZenFishing.config.showBaitNotifications then
        player:Say("Attached: " .. bait:getName())
    end
    
    return action
end

-- Проверка очереди действий рыбалки
local function hasFishingActionsInQueue(player)
    if not player then return false end
    
    local actionQueue = ISTimedActionQueue.getTimedActionQueue(player)
    if not actionQueue or not actionQueue.queue then return false end
    
    for i = 1, #actionQueue.queue do
        local action = actionQueue.queue[i]
        local actionType = action and action.Type
        
        if actionType then
            if actionType == "ISFishingAction" or 
               actionType == "ISPickupFishAction" or
               actionType == "AIAttachLureAction" then
                return true
            end
        end
    end
    
    return false
end

-- Проверка и добавление насадки наживки в очередь
local function scheduleBaitAttach(player)
    if not player then return end
    
    local currentTime = getTimeInMillis()
    if currentTime - lastBaitCheckTick < ZenFishing.config.autoBaitCheckInterval then
        return
    end
    
    lastBaitCheckTick = currentTime
    
    -- Проверяем, есть ли уже действие насадки в очереди
    if hasFishingActionsInQueue(player) then
        return
    end
    
    -- Добавляем действие насадки наживки в очередь
    local baitAction = createAttachBaitAction(player)
    if baitAction then
        ISTimedActionQueue.add(baitAction)
    end
end

-- Применение эффектов настроения
local function applyMoodEffects(player)
    if not player then return end
    
    local stats = player:getStats()
    if not stats then return end
    
    -- Базовые значения уменьшения
    local stressReduction = ZenFishing.config.stressReductionRate * ZenFishing.config.moodBoostMultiplier
    local boredomReduction = ZenFishing.config.boredomReductionRate * ZenFishing.config.moodBoostMultiplier
    local panicReduction = ZenFishing.config.panicReductionRate * ZenFishing.config.moodBoostMultiplier
    local unhappinessReduction = ZenFishing.config.unhappinessReductionRate * ZenFishing.config.moodBoostMultiplier
    
    -- Уменьшение стресса (0-1 шкала)
    local currentStress = stats:get(CharacterStat.STRESS)
    if currentStress > 0 then
        local newStress = math.max(0, currentStress - stressReduction)
        stats:set(CharacterStat.STRESS, newStress)
    end
    
    -- Уменьшение скуки (0-100 шкала)
    local currentBoredom = stats:get(CharacterStat.BOREDOM)
    if currentBoredom > 0 then
        local newBoredom = math.max(0, currentBoredom - boredomReduction)
        stats:set(CharacterStat.BOREDOM, newBoredom)
    end
    
    -- Уменьшение паники (0-100 шкала)
    local currentPanic = stats:get(CharacterStat.PANIC)
    if currentPanic > 0 then
        local newPanic = math.max(0, currentPanic - panicReduction)
        stats:set(CharacterStat.PANIC, newPanic)
    end
    
    -- Уменьшение несчастья (0-100 шкала)
    local currentUnhappiness = stats:get(CharacterStat.UNHAPPINESS)
    if currentUnhappiness > 0 then
        local newUnhappiness = math.max(0, currentUnhappiness - unhappinessReduction)
        stats:set(CharacterStat.UNHAPPINESS, newUnhappiness)
    end
end

-- Применение ускорения времени при начале рыбалки
local function applyTimeAcceleration()
    if not ZenFishing.config.enableTimeAcceleration or timeAccelerationApplied then
        return
    end
    
    -- Сохраняем оригинальные значения
    originalGameSpeed = getGameSpeed()
    originalTimeMultiplier = getGameTime():getMultiplier()
    
    -- Ускоряем время
    setGameSpeed(ZenFishing.config.timeAccelerationSpeed)
    getGameTime():setMultiplier(ZenFishing.config.timeAccelerationMultiplier)
    timeAccelerationApplied = true
end

-- Восстановление оригинальной скорости времени
local function restoreOriginalTimeSpeed()
    if not timeAccelerationApplied then
        return
    end
    
    -- Восстанавливаем оригинальную скорость
    setGameSpeed(originalGameSpeed)
    getGameTime():setMultiplier(originalTimeMultiplier)
    timeAccelerationApplied = false
end

-- Автоматическая подсечка при поклевке
local function handleAutoHook(manager)
    if not ZenFishing.config.enableAutoHook or not manager or not manager.fishingRod or not manager.fishingRod.bobber then
        return
    end
    
    if manager.fishingRod.bobber.fish ~= nil and not autoHookState then
        autoHookState = true
        
        -- Восстанавливаем нормальную скорость при поклевке
        restoreOriginalTimeSpeed()
        
        -- Автоматический переход к выуживанию
        if ZenFishing.config.enableAutoReel then
            -- Запускаем звук выуживания и сохраняем хэндл
            reelSoundHandle = manager.player:playSound("ReelFishingLineSlow")
            -- Меняем состояние на выуживание
            if manager.changeState then
                manager:changeState("PickupFish")
            end
        end
    elseif manager.fishingRod.bobber.fish == nil then
        autoHookState = false
    end
end

-- Основной обработчик
local function onTick()
    -- Обновляем конфигурацию из песочницы
    updateConfigFromSandbox()
    
    local player = getPlayer()
    if not player then return end
    
    local currentTime = getTimeInMillis()
    
    -- Получаем текущее состояние рыбалки
    local currentState = getFishingState(player)
    local manager = getFishingManager(player)
    
    -- Останавливаем звук выуживания при завершении состояния PickupFish
    if lastState == "PickupFish" and currentState ~= "PickupFish" then
        stopReelSound()
    end
    
    -- Определение начала и окончания рыбалки
    if currentState and currentState ~= "None" and currentState ~= "Idle" then
        if not isFishingActive then
            -- Начало рыбалки
            isFishingActive = true
            -- Применяем ускорение времени только один раз при начале
            applyTimeAcceleration()
        end
        
        -- Обработка автоматической подсечки
        handleAutoHook(manager)
    else
        -- Определение окончания рыбалки
        if isFishingActive then
            -- Окончание рыбалки
            isFishingActive = false
            autoHookState = false
            
            -- Восстанавливаем оригинальную скорость времени
            restoreOriginalTimeSpeed()
            
            -- Останавливаем звук выуживания при окончании рыбалки
            stopReelSound()
            
            -- Планируем насадку наживки после рыбалки
            scheduleBaitAttach(player)
        end
    end
    
    -- Применение эффектов настроения во время рыбалки
    if ZenFishing.config.moodSystemEnabled and isFishingActive then
        moodEffectTimer = moodEffectTimer + 1
        
        -- Применяем эффекты с заданным интервалом
        if currentTime - lastMoodEffectTick >= ZenFishing.config.moodEffectInterval then
            lastMoodEffectTick = currentTime
            
            -- Безопасное применение эффектов настроения
            pcall(applyMoodEffects, player)
        end
    elseif not isFishingActive then
        moodEffectTimer = 0
    end
    
    -- Обновляем предыдущее состояние
    lastState = currentState
end

-- Инициализация мода
local function init()
    Events.OnTick.Add(onTick)
    
    -- Обновляем конфигурацию из песочницы при старте
    updateConfigFromSandbox()
    
    -- Переопределяем только указанные timed-actions для ускорения
    overrideFishingAction()
    overrideAttachLureAction()
    overridePickupFishAction()
end

Events.OnGameStart.Add(init)

return ZenFishing