PGChangeGeneratorFuel = ISBaseTimedAction:derive("PGChangeGeneratorFuel")

function PGChangeGeneratorFuel:new(character, generator, propaneTank, time)
    local o = ISBaseTimedAction.new(self, character)
    
    o.generator = generator
    o.propaneTank = propaneTank
    o.maxTime = time
    
    o.stopOnWalk = true
    o.stopOnRun = true
    
    return o
end

function PGChangeGeneratorFuel:isValid()
    if not self.generator or not self.propaneTank then
        return false
    end
    
    -- Проверяем, что генератор не полон
    if self.generator:getFuel() >= 1.0 then
        return false
    end
    
    -- Проверяем, что в баллоне есть пропан
    if self.propaneTank:getUsedDelta() <= 0 then
        return false
    end
    
    -- Проверяем расстояние
    if self.character:DistTo(self.generator:getX(), self.generator:getY()) > 2 then
        return false
    end
    
    return true
end

function PGChangeGeneratorFuel:update()
    self.character:faceThisObject(self.generator)
end

function PGChangeGeneratorFuel:start()
    self:setActionAnim("Loot")
    self.character:getEmitter():playSound("GeneratorRefuelStart")
end

function PGChangeGeneratorFuel:perform()
    -- Вычисляем количество пропана для переливания
    local fuelSpace = 1.0 - self.generator:getFuel()
    local fuelAmount = math.min(fuelSpace, self.propaneTank:getUsedDelta())
    
    -- Заправляем генератор
    self.generator:setFuel(self.generator:getFuel() + fuelAmount)
    
    -- Уменьшаем количество пропана в баллоне
    self.propaneTank:setUsedDelta(self.propaneTank:getUsedDelta() - fuelAmount)
    
    -- Если баллон опустел, меняем его на пустой
    if self.propaneTank:getUsedDelta() <= 0 then
        local emptyTank = InventoryItemFactory.CreateItem("Base.EmptyPropaneTank")
        self.character:getInventory():Remove(self.propaneTank)
        self.character:getInventory():AddItem(emptyTank)
    end
    
    -- Звук завершения
    self.character:getEmitter():playSound("GeneratorRefuelEnd")
    
    ISBaseTimedAction.perform(self)
end