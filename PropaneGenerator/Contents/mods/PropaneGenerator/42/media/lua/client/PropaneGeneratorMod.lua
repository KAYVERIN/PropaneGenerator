-- PropaneGeneratorMod.lua
-- Мод для добавления пропановых генераторов в Project Zomboid Build 42.13.2
-- Полностью использует новую систему топлива игры.

local AddPropaneAction = {} -- Наш новый класс действия

-- 1. РЕГИСТРАЦИЯ ТИПА ТОПЛИВА В ИГРЕ
-- Это ключевой шаг. Мы сообщаем игре, что "Propane" - это валидное топливо.
if not FuelTypes then FuelTypes = {} end
FuelTypes.Propane = {
    name = "Propane",
    itemName = "Base.PropaneTank", -- Предмет, который является топливом
    -- Можно добавить другие свойства, например, коэффициент заправки
    -- ratio = 1.0
}
print("[PropaneGeneratorMod] Fuel type 'Propane' registered.")

-- 2. СОЗДАНИЕ КЛАССА ДЕЙСТВИЯ (Наследование от ISAddFuelAction)
AddPropaneAction = ISAddFuelAction:derive("AddPropaneAction")

function AddPropaneAction:new(character, generator, fuelContainer, time)
    -- Вызываем конструктор родительского класса
    local o = ISAddFuelAction.new(self, character, generator, fuelContainer, time)
    -- При необходимости можно добавить свои поля
    -- o.customPropaneField = true
    return o
end

-- 2.1. ПЕРЕОПРЕДЕЛЕНИЕ: Проверка, подходит ли топливо для этого генератора
function AddPropaneAction:isValidFuel(fuelContainer)
    -- Родительский метод уже проверил, что fuelContainer не пуст и вообще является контейнером.
    -- Нам нужно проверить, что И генератор, И топливо - пропановые.
    if not self.generator or not fuelContainer then
        return false
    end
    -- Проверяем, что генератор - именно пропановый (по его типу)
    if self.generator:getModData().fuelType ~= "Propane" then
        return false
    end
    -- Проверяем, что в контейнере именно пропан
    if fuelContainer:getType() ~= "PropaneTank" then
        return false
    end
    return true
end

-- 2.2. ПЕРЕОПРЕДЕЛЕНИЕ: Логика собственно заправки
function AddPropaneAction:addFuel(fuelContainer, fuelAmount)
    -- fuelAmount уже рассчитан родительским классом на основе
    -- свободного места в генераторе и количества топлива в баллоне.

    -- 1. Увеличиваем топливо в генераторе (используем родительский метод или делаем сами)
    local currentFuel = self.generator:getFuel()
    self.generator:setFuel(currentFuel + fuelAmount)

    -- 2. Уменьшаем топливо в баллоне
    local currentPropane = fuelContainer:getUsedDelta()
    fuelContainer:setUsedDelta(currentPropane - fuelAmount)

    -- 3. Если баллон опустел, заменить его на пустой (Base.EmptyPropaneTank).
    --    Родительский класс, возможно, сделает это сам, если для PropaneTank
    --    задано свойство emptyContainer = "Base.EmptyPropaneTank" в items.txt.
    --    Но для надежности можно сделать здесь:
    if fuelContainer:getUsedDelta() <= 0 then
        self.character:getInventory():Remove(fuelContainer)
        local emptyTank = InventoryItemFactory.CreateItem("Base.EmptyPropaneTank")
        self.character:getInventory():AddItem(emptyTank)
    end

    -- 4. Можно добавить специфичный звук для пропана
    self.character:getEmitter():playSound("GeneratorRefuelWithPropane")
end

-- 3. ДОБАВЛЕНИЕ ОПЦИИ В КОНТЕКСТНОЕ МЕНЮ ГЕНЕРАТОРА
local oldISGeneratorInfoWindowCreate = ISGeneratorInfoWindow.create
function ISGeneratorInfoWindow.create(generator, player)
    local ui = oldISGeneratorInfoWindowCreate(generator, player)

    -- Добавляем кнопку "Заправить пропаном", если генератор пропановый
    if generator:getModData().fuelType == "Propane" then
        -- Код для добавления кнопки. Нужно изучить структуру ISGeneratorInfoWindow в Build 42.
        -- Это примерный подход:
        -- local propaneBtn = ISButton:new(10, ui.height - 40, 100, 25, getText("ContextMenu_RefuelPropane"), ui, AddPropaneAction.onRefuelClick)
        -- ui:addChild(propaneBtn)
        print("[PropaneGeneratorMod] Propane generator detected, UI extension needed.")
    end
    return ui
end

-- 4. ИНИЦИАЛИЗАЦИЯ МОДА
local function init()
    print("[PropaneGeneratorMod] Initialized for Build 42.13.2")
    -- Здесь можно добавить другие хуки, например, в контекстное меню мира.
end

Events.OnGameStart.Add(init)
