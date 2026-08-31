local _, addon = ...

-- Keys are MapChallengeMode IDs. New seasons only require additions here.
addon.portalSpells = {
    [249] = { 1286831 }, -- Kings' Rest
    [250] = { 1286828 }, -- Temple of Sethraliss
    [399] = { 393256 },  -- Ruby Life Pools
    [584] = { 1286801 }, -- The Blinding Vale
    [585] = { 1286804 }, -- Voidscar Arena
    [586] = { 1286807 }, -- Den of Nalorakk
    [587] = { 1286809 }, -- Murder Row
    [588] = { 1286812 }, -- Altar of Fangs
}

function addon:GetDungeonName(challengeMapID, fallbackName)
    local activities = C_LFGList.GetAvailableActivities(GROUP_FINDER_CATEGORY_ID_DUNGEONS)
    for _, activityID in ipairs(activities or {}) do
        local activity = C_LFGList.GetActivityInfoTable(activityID)
        if activity and activity.mapID == challengeMapID and activity.isMythicPlusActivity then
            return activity.fullName or activity.name or fallbackName
        end
    end
    return fallbackName
end

function addon:GetKnownPortalSpell(challengeMapID)
    local spellIDs = self.portalSpells[challengeMapID]
    if not spellIDs then
        return nil, false
    end

    for _, spellID in ipairs(spellIDs) do
        if C_SpellBook.IsSpellKnown(spellID, Enum.SpellBookSpellBank.Player) then
            return spellID, true
        end
    end
    return spellIDs[1], false
end

function addon:GetSeasonDungeons()
    local mapIDs = C_ChallengeMode.GetMapTable()
    if not mapIDs or #mapIDs == 0 then
        return nil
    end

    local dungeons = {}
    for _, challengeMapID in ipairs(mapIDs) do
        local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(challengeMapID)
        if not name then
            return nil
        end

        local inTime, overTime = C_MythicPlus.GetSeasonBestForMap(challengeMapID)
        local level = 0
        if inTime then
            level = math.max(level, inTime.level or 0)
        end
        if overTime then
            level = math.max(level, overTime.level or 0)
        end

        local _, score = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(challengeMapID)
        local spellID, portalKnown = self:GetKnownPortalSpell(challengeMapID)
        dungeons[#dungeons + 1] = {
            challengeMapID = challengeMapID,
            name = self:GetDungeonName(challengeMapID, name),
            texture = texture or 134400,
            level = level,
            score = score or 0,
            spellID = spellID,
            portalKnown = portalKnown,
            portalMapped = self.portalSpells[challengeMapID] ~= nil,
        }
    end
    return dungeons
end
