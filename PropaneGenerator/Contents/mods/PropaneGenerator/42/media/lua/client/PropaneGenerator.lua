
-- Проверяем, что мы на клиенте
if isClient() then
    print("[PropaneGenerators] Initializing mod...")
    
    -- Загружаем общие утилиты
    require "PropaneGenerators/PGGeneratorUtils"
    
    -- Загружаем модуль проверки генераторов
    require "PropaneGenerators/client/PGCheckForGenerators"
    
    -- Загружаем окно информации о генераторе
    require "PropaneGenerators/client/PGGeneratorInfoWindow"
    
    -- Загружаем обработчики контекстных меню
    require "PropaneGenerators/client/PGInventoryPaneContextMenu"
    require "PropaneGenerators/client/PGWorldObjectContextMenu"
    
    -- Загружаем кастомные TimedActions
    require "PropaneGenerators/client/TimedActions/PGChangeGeneratorFuel"
    require "PropaneGenerators/client/TimedActions/PGEquipHeavyItem"
    require "PropaneGenerators/client/TimedActions/PGTakeGenerator"
    require "PropaneGenerators/client/TimedActions/PGUnequipAction"
    
    -- Инициализация мода при старте игры
    local function init()
        print("[PropaneGenerators] Client mod initialized successfully!")
        
        -- Инициализируем утилиты
        if PGGeneratorUtils and PGGeneratorUtils.init then
            PGGeneratorUtils.init()
        end
        
        -- Инициализируем проверку генераторов
        if PGCheckForGenerators and PGCheckForGenerators.init then
            PGCheckForGenerators.init()
        end
        
        -- Инициализируем окно информации
        if PGGeneratorInfoWindow and PGGeneratorInfoWindow.init then
            PGGeneratorInfoWindow.init()
        end
        
        -- Инициализируем контекстные меню
        if PGInventoryPaneContextMenu and PGInventoryPaneContextMenu.init then
            PGInventoryPaneContextMenu.init()
        end
        
        if PGWorldObjectContextMenu and PGWorldObjectContextMenu.init then
            PGWorldObjectContextMenu.init()
        end
    end
    
    -- Запускаем инициализацию при загрузке игры
    Events.OnGameStart.Add(init)
    
else
    print("[PropaneGenerators] Server side detected, skipping client initialization.")
end