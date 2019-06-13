local MAJOR, MINOR = "LibClassicTargetCast-1.0", 1
local LibStub = LibStub
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

local SpellDataVersions = {}

function lib.SetDataVersion(dataType, version)
    SpellDataVersions[dataType] = version
end

function lib.GetDataVersion(dataType)
    return SpellDataVersions[dataType] or 0
end

local _G = getfenv(0)

lib.callbacks = lib.callbacks or LibStub("CallbackHandler-1.0"):New(lib)
lib.unitSearcher = LibStub("unitSearcher")
lib.spellCache = {};

local logScanner = CreateFrame("Frame");

logScanner:RegisterEvent("PLAYER_LOGIN")

logScanner:SetScript("OnEvent", function(self, event, ...)
    -- this will basically trigger EVENT_NAME(arguments)
    return self[event](self, ...)
end)

function logScanner:CastPushback(unitGUID, percentageAmount, auraFaded)
    local cast = lib.spellCache[unitGUID]
    if not cast then return end

    -- if cast.prevCurrTimeModValue then print("stored total:", #cast.prevCurrTimeModValue) end

    -- Set cast time modifier (i.e Curse of Tongues)
    if not auraFaded and percentageAmount and percentageAmount > 0 then
        if not cast.currTimeModValue or cast.currTimeModValue < percentageAmount then -- run only once unless % changed to higher val
            if cast.currTimeModValue then -- already was reduced
                -- if existing modifer is e.g 50% and new is 60%, we only want to adjust cast by 10%
                percentageAmount = percentageAmount - cast.currTimeModValue

                -- Store previous lesser modifier that was active
                cast.prevCurrTimeModValue = cast.prevCurrTimeModValue or {}
                cast.prevCurrTimeModValue[#cast.prevCurrTimeModValue + 1] = cast.currTimeModValue
                -- print("stored lesser modifier")
            end

            -- print("refreshing timer", percentageAmount)
            cast.currTimeModValue = (cast.currTimeModValue or 0) + percentageAmount -- highest active modifier
            cast.maxValue = cast.maxValue + (cast.maxValue * percentageAmount) / 100
            cast.endTime = cast.endTime + (cast.maxValue * percentageAmount) / 100
        elseif cast.currTimeModValue == percentageAmount then
            -- new modifier has same percentage as current active one, just store it for later
            -- print("same percentage, storing")
            cast.prevCurrTimeModValue = cast.prevCurrTimeModValue or {}
            cast.prevCurrTimeModValue[#cast.prevCurrTimeModValue + 1] = percentageAmount
        end
    elseif auraFaded and percentageAmount then
        -- Reset cast time modifier
        if cast.currTimeModValue == percentageAmount then
            cast.maxValue = cast.maxValue - (cast.maxValue * percentageAmount) / 100
            cast.endTime = cast.endTime - (cast.maxValue * percentageAmount) / 100
            cast.currTimeModValue = nil

            -- Reset to lesser modifier if available
            if cast.prevCurrTimeModValue then
                local highest, index = 0
                for i = 1, #cast.prevCurrTimeModValue do
                    if cast.prevCurrTimeModValue[i] and cast.prevCurrTimeModValue[i] > highest then
                        highest, index = cast.prevCurrTimeModValue[i], i
                    end
                end

                if index then
                    cast.prevCurrTimeModValue[index] = nil
                    -- print("resetting to lesser modifier", highest)
                    return self:CastPushback(unitGUID, highest)
                end
            end
        end

        if cast.prevCurrTimeModValue then
            -- Delete 1 old modifier (doesn't matter which one aslong as its the same %)
            for i = 1, #cast.prevCurrTimeModValue do
                if cast.prevCurrTimeModValue[i] == percentageAmount then
                    -- print("deleted lesser modifier, new total:", #cast.prevCurrTimeModValue - 1)
                    cast.prevCurrTimeModValue[i] = nil
                    return
                end
            end
        end
    else -- normal pushback
        if not cast.isChanneled then
            cast.maxValue = cast.maxValue + 0.5
            cast.endTime = cast.endTime + 0.5
        else
            -- channels are reduced by 25%
            cast.maxValue = cast.maxValue - (cast.maxValue * 25) / 100
            cast.endTime = cast.endTime - (cast.maxValue * 25) / 100
        end
    end
end

function lib:UnitCastingInfo(unit)
    if unit then
        local unitGUID = UnitGUID(unit)
        if unitGUID then
            local cast = lib.spellCache[unitGUID]
            if cast and not cast.isChanneled then
                return cast.spellName, cast.rank, cast.spellIcon, cast.startTime, cast.endTime, false, cast.castID, false, cast.spellID
            end
        end
    end
end

function lib:UnitChannelInfo(unit)
    if unit then
        local unitGUID = UnitGUID(unit)
        if unitGUID then
            local cast = lib.spellCache[unitGUID]
            if cast and cast.isChanneled then
                return cast.spellName, cast.rank, cast.spellIcon, cast.startTime, cast.endTime, false, false, false, cast.spellID
            end
        end
    end
end

function logScanner:PLAYER_LOGIN()
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:UnregisterEvent("PLAYER_LOGIN")
end

function logScanner.PLAYER_ENTERING_WORLD()
    -- Clear the Cache
    lib.spellCache = {};
    -- Fire in case consuming addon needs to initialise anything
    lib.callbacks:Fire("PLAYER_ENTERING_WORLD")
end

function logScanner.PLAYER_TARGET_CHANGED()
    local target = UnitGUID("target")
    if target and lib.spellCache[target] then
        local cast = lib.spellCache[target]
        if cast then
            lib.callbacks:Fire("PLAYER_TARGET_CHANGED")
        end
    else
        lib.callbacks:Fire("PLAYER_TARGET_CHANGED")
    end
end

local bit_band = _G.bit.band
local COMBATLOG_OBJECT_TYPE_PLAYER = _G.COMBATLOG_OBJECT_TYPE_PLAYER

function logScanner:COMBAT_LOG_EVENT_UNFILTERED()
    local _, eventType, _, srcGUID, _, _, _, dstGUID,  _, dstFlags, _, spellID, spellName, _, _, _, _, resisted, blocked, absorbed = CombatLogGetCurrentEventInfo()
    local currTime = GetTime();
    local castSrc = lib.spellCache[srcGUID]
    local castDst = lib.spellCache[dstGUID]

    if eventType == "SPELL_CAST_START" then
        local _, _, icon, castTime = GetSpellInfo(spellID)
        if not castTime or castTime == 0 then return end
        local rank = GetSpellSubtext(spellID) -- async so won't work on first try but thats okay
        local castID = ""..srcGUID.."_"..spellName..""..currTime; -- Fake a cast GUID
        --Reduce cast time for certain spells
        -- local reducedTime = castTimeTalentDecreases[spellName]
        -- if reducedTime then
        --     castTime = castTime - (reducedTime * 1000)
        -- end

        local unit = lib.unitSearcher:GetUnitID(srcGUID)
        lib.spellCache[srcGUID] = {
            castID = castID,
            spellName = spellName,
            rank = rank,
            spellIcon = icon,
            startTime = currTime*1000,
            endTime = currTime*1000 + castTime,
            maxValue = castTime,
            isChanneled = false,
            spellID = spellID,
            unit = unit
        }
        if unit then
            lib.callbacks:Fire("UNIT_SPELLCAST_START", unit, castID, spellID)
        end
    elseif eventType == "SPELL_CAST_SUCCESS" then
        -- Channeled spells are started on SPELL_CAST_SUCCESS instead of stopped
        -- Also there's no castTime returned from GetSpellInfo for channeled spells so we need to get it from our own list
        local castTime = lib.channeledSpells[spellName]
        local castID = ""..srcGUID.."_"..spellName..""..currTime; -- Fake a cast GUID
        if castTime then
            if currTime + castTime > GetTime() then
                local rank = GetSpellSubtext(spellID) -- async so won't work on first try but thats okay
                local _, _, icon = GetSpellInfo(spellID)
                local unit = lib.unitSearcher:GetUnitID(srcGUID)
                lib.spellCache[srcGUID] = {
                    castID = castID,
                    spellName = spellName,
                    rank = rank,
                    spellIcon = icon,
                    startTime = currTime*1000,
                    endTime = currTime*1000 + castTime,
                    maxValue = castTime,
                    isChanneled = true,
                    spellID = spellID,
                    unit = unit
                }
                if unit then
                    lib.callbacks:Fire("UNIT_SPELLCAST_CHANNEL_START", unit, castID, spellID)
                end
            elseif castSrc then -- assume the channeled spell is ending
                local unit, castID, spellID = castSrc.unit, castSrc.castID, castSrc.spellID
                lib.spellCache[srcGUID] = nil
                if castSrc.unit then
                    lib.callbacks:Fire("UNIT_SPELLCAST_CHANNEL_STOP", unit, castID, spellID)
                end
            end
        end
        if castSrc then
            local unit, castID, spellID = castSrc.unit, castSrc.castID, castSrc.spellID
            lib.spellCache[srcGUID] = nil
            if unit then
                lib.callbacks:Fire("UNIT_SPELLCAST_STOP", unit, castID, spellID)
            end
        end
    elseif eventType == "SPELL_CAST_FAILED" and castSrc then
        local unit, castID, spellID = castSrc.unit, castSrc.castID, castSrc.spellID
        lib.spellCache[srcGUID] = nil
        if unit then
            lib.callbacks:Fire("UNIT_SPELLCAST_FAILED", unit, castID, spellID)
        end
    elseif eventType == "SPELL_AURA_APPLIED" and castDst then
        if lib.castTimeDecreases[spellID] then
            -- Aura that slows casting speed was applied
            self:CastPushback(dstGUID, lib.castTimeDecreases[spellID])
            if castDst.unit then
                lib.callbacks:Fire("UNIT_SPELLCAST_DELAYED", castDst.unit, castDst.castID, castDst.spellID)
            end
        elseif lib.crowdControls[spellName] then
            local unit, castID, spellID = castDst.unit, castDst.castID, castDst.spellID
            lib.spellCache[dstGUID] = nil
            if unit then
                lib.callbacks:Fire("UNIT_SPELLCAST_STOP", unit, castID, spellID)
            end
        end
    elseif eventType == "SPELL_AURA_REMOVED" then
        -- Channeled spells has no SPELL_CAST_* event for channel stop,
        -- so check if aura is gone instead since most (all?) channels has an aura effect
        if castSrc and lib.channeledSpells[spellName] then
            local unit, castID, spellID = castSrc.unit, castSrc.castID, castSrc.spellID
            lib.spellCache[srcGUID] = nil
            if castSrc.unit then
                lib.callbacks:Fire("UNIT_SPELLCAST_STOP", unit, castID, spellID)
            end
        elseif castDst and lib.castTimeDecreases[spellID] then
             -- Aura that slows casting speed was removed
            self:CastPushback(dstGUID, lib.castTimeDecreases[spellID], true)
            if castDst.unit then
                lib.callbacks:Fire("UNIT_SPELLCAST_DELAYED", castDst.unit, castDst.castID, castDst.spellID)
            end
        end
    elseif castDst and (eventType == "PARTY_KILL" or eventType == "UNIT_DIED" or eventType == "SPELL_INTERRUPT") then
            local unit, castID, spellID = castDst.unit, castDst.castID, castDst.spellID
            lib.spellCache[dstGUID] = nil
            if unit then
                lib.callbacks:Fire("UNIT_SPELLCAST_STOP", unit, castID, spellID)
            end
    elseif castDst and (eventType == "SWING_DAMAGE" or eventType == "ENVIRONMENTAL_DAMAGE" or eventType == "RANGE_DAMAGE" or eventType == "SPELL_DAMAGE") then
        if resisted or blocked or absorbed then return end
        if bit_band(dstFlags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0 then -- is player
            self:CastPushback(dstGUID)
            if castDst.unit then
                lib.callbacks:Fire("UNIT_SPELLCAST_DELAYED", castDst.unit, castDst.castID, castDst.spellID)
            end
        end
    end
end
