-- Taken from ClassicCastBars - All credit to wardz for the excellent work and the technique of getting target cast info from the CLEU
local lib = LibStub("LibClassicTargetCast-1.0", true)
if not lib then return end

local Type, Version = "Data", 1
if lib:GetDataVersion(Type) >= Version then return end

local GetSpellInfo = _G.GetSpellInfo
-- Channeled spells does not return cast time, so we have to build our own list.
--
-- We use GetSpellInfo here to get the localized spell name,
-- that way we don't have to list every spellID for an ability (diff ranks have diff id)
lib.channeledSpells = {
    -- MISC
    [GetSpellInfo(746)] = 7,        -- First Aid
    [GetSpellInfo(13278)] = 4,      -- Gnomish Death Ray
    [GetSpellInfo(20577)] = 10,     -- Cannibalize

    -- DRUID
    [GetSpellInfo(17401)] = 9.5,    -- Hurricane
    [GetSpellInfo(740)] = 9.5,      -- Tranquility

    -- HUNTER
    [GetSpellInfo(6197)] = 60,      -- Eagle Eye
    [GetSpellInfo(1002)] = 60,      -- Eyes of the Beast
    [GetSpellInfo(20900)] = 3,      -- Aimed Shot TODO: verify

    -- MAGE
    [GetSpellInfo(5143)] = 4.5,     -- Arcane Missiles
    [GetSpellInfo(10)] = 7.5,       -- Blizzard
    [GetSpellInfo(12051)] = 8,      -- Evocation

    -- PRIEST
    [GetSpellInfo(15407)] = 3,      -- Mind Flay
    [GetSpellInfo(2096)] = 60,      -- Mind Vision
    [GetSpellInfo(605)] = 3,        -- Mind Control

    -- WARLOCK
    [GetSpellInfo(689)] = 4.5,      -- Drain Life
    [GetSpellInfo(5138)] = 4.5,     -- Drain Mana
    [GetSpellInfo(1120)] = 14.5,    -- Drain Soul
    [GetSpellInfo(5740)] = 7.5,     -- Rain of Fire
    [GetSpellInfo(1949)] = 15,      -- Hellfire
    [GetSpellInfo(755)] = 10,       -- Health Funnel
}

-- List of abilities that makes cast time slower.
-- Spells here have different % reduction based on spell rank,
-- so list by spellID instead of name here so we can diff between ranks
lib.castTimeDecreases = {
    -- WARLOCK
    [1714] = 0.5,    -- Curse of Tongues Rank 1
    [11719] = 0.6,   -- Curse of Tongues Rank 2

    -- ROGUE
    [5760] = 0.4,    -- Mind-Numbing Poison Rank 1
    [8692] = 0.5,    -- Mind-Numbing Poison Rank 2
    [25810] = 0.5,   -- Mind-Numbing Poison Rank 2 incorrect?
    [11398] = 0.6,   -- Mind-Numbing Poison Rank 3

    -- ITEMS
    [17331] = 0.1,   -- Fang of the Crystal Spider
}

-- Spells that often have cast time reduced by talents
lib.castTimeTalentDecreases = {
    [GetSpellInfo(403)] = 1,        -- Lightning Bolt
    [GetSpellInfo(421)] = 1,        -- Chain Lightning
    [GetSpellInfo(6353)] = 2,       -- Soul Fire
    [GetSpellInfo(116)] = 0.5,      -- Frostbolt
    [GetSpellInfo(133)] = 0.5,      -- Fireball
    [GetSpellInfo(686)] = 0.5,      -- Shadow Bolt
    [GetSpellInfo(348)] = 0.5,      -- Immolate
    [GetSpellInfo(331)] = 0.5,      -- Healing Wave
    [GetSpellInfo(585)] = 0.5,      -- Smite
    [GetSpellInfo(14914)] = 0.5,    -- Holy Fire
    [GetSpellInfo(2054)] = 0.5,     -- Heal
    [GetSpellInfo(25314)] = 0.5,    -- Greater Heal
    [GetSpellInfo(8129)] = 0.5,     -- Mana Burn
    [GetSpellInfo(5176)] = 0.5,     -- Wrath
    [GetSpellInfo(2912)] = 0.5,     -- Starfire
    [GetSpellInfo(5185)] = 0.5,     -- Healing Touch
    [GetSpellInfo(2645)] = 2,       -- Ghost Wolf
    [GetSpellInfo(691)] = 4,        -- Summon Felhunter
    [GetSpellInfo(688)] = 4,        -- Summon Imp
    [GetSpellInfo(697)] = 4,        -- Summon Voidwalker
    [GetSpellInfo(712)] = 4,        -- Summon Succubus
}

-- List of player crowd controls
-- We want to stop the castbar when these auras are detected
-- as SPELL_CAST_FAILED is not triggered when a player gets CC'ed.
lib.crowdControls = {
    [GetSpellInfo(5211)] = true,       -- Bash
    [GetSpellInfo(24394)] = true,      -- Intimidation
    [GetSpellInfo(853)] = true,        -- Hammer of Justice
    [GetSpellInfo(22703)] = true,      -- Inferno Effect (Summon Infernal)
    [GetSpellInfo(408)] = true,        -- Kidney Shot
    [GetSpellInfo(12809)] = true,      -- Concussion Blow
    [GetSpellInfo(20253)] = true,      -- Intercept Stun
    [GetSpellInfo(20549)] = true,      -- War Stomp
    [GetSpellInfo(2637)] = true,       -- Hibernate
    [GetSpellInfo(3355)] = true,       -- Freezing Trap
    [GetSpellInfo(19386)] = true,      -- Wyvern Sting
    [GetSpellInfo(118)] = true,        -- Polymorph
    [GetSpellInfo(28271)] = true,      -- Polymorph: Turtle
    [GetSpellInfo(28272)] = true,      -- Polymorph: Pig
    [GetSpellInfo(20066)] = true,      -- Repentance
    [GetSpellInfo(1776)] = true,       -- Gouge
    [GetSpellInfo(6770)] = true,       -- Sap
    [GetSpellInfo(1513)] = true,       -- Scare Beast
    [GetSpellInfo(8122)] = true,       -- Psychic Scream
    [GetSpellInfo(2094)] = true,       -- Blind
    [GetSpellInfo(5782)] = true,       -- Fear
    [GetSpellInfo(5484)] = true,       -- Howl of Terror
    [GetSpellInfo(6358)] = true,       -- Seduction
    [GetSpellInfo(5246)] = true,       -- Intimidating Shout
    [GetSpellInfo(6789)] = true,       -- Death Coil
    [GetSpellInfo(9005)] = true,       -- Pounce
    [GetSpellInfo(1833)] = true,       -- Cheap Shot
    [GetSpellInfo(16922)] = true,      -- Improved Starfire
    [GetSpellInfo(19410)] = true,      -- Improved Concussive Shot
    [GetSpellInfo(12355)] = true,      -- Impact
    [GetSpellInfo(20170)] = true,      -- Seal of Justice Stun
    [GetSpellInfo(15269)] = true,      -- Blackout
    [GetSpellInfo(18093)] = true,      -- Pyroclasm
    [GetSpellInfo(12798)] = true,      -- Revenge Stun
    [GetSpellInfo(5530)] = true,       -- Mace Stun
    [GetSpellInfo(19503)] = true,      -- Scatter Shot
    [GetSpellInfo(605)] = true,        -- Mind Control
    [GetSpellInfo(7922)] = true,       -- Charge Stun
    [GetSpellInfo(18469)] = true,      -- Counterspell - Silenced
    [GetSpellInfo(15487)] = true,      -- Silence
    [GetSpellInfo(18425)] = true,      -- Kick - Silenced
    [GetSpellInfo(24259)] = true,      -- Spell Lock
    [GetSpellInfo(18498)] = true,      -- Shield Bash - Silenced

    -- ITEMS
    [GetSpellInfo(13327)] = true,      -- Reckless Charge
    [GetSpellInfo(1090)] = true,       -- Sleep
    [GetSpellInfo(5134)] = true,       -- Flash Bomb Fear
    [GetSpellInfo(19821)] = true,      -- Arcane Bomb Silence
    [GetSpellInfo(4068)] = true,       -- Iron Grenade
    [GetSpellInfo(19769)] = true,      -- Thorium Grenade
    [GetSpellInfo(13808)] = true,      -- M73 Frag Grenade
    [GetSpellInfo(4069)] = true,       -- Big Iron Bomb
    [GetSpellInfo(12543)] = true,      -- Hi-Explosive Bomb
    [GetSpellInfo(4064)] = true,       -- Rough Copper Bomb
    [GetSpellInfo(12421)] = true,      -- Mithril Frag Bomb
    [GetSpellInfo(19784)] = true,      -- Dark Iron Bomb
    [GetSpellInfo(4067)] = true,       -- Big Bronze Bomb
    [GetSpellInfo(4066)] = true,       -- Small Bronze Bomb
    [GetSpellInfo(4065)] = true,       -- Large Copper Bomb
    [GetSpellInfo(13237)] = true,      -- Goblin Mortar
    [GetSpellInfo(835)] = true,        -- Tidal Charm
    [GetSpellInfo(13181)] = true,      -- Gnomish Mind Control Cap
    [GetSpellInfo(12562)] = true,      -- The Big One
    [GetSpellInfo(15283)] = true,      -- Stunning Blow (Weapon Proc)
    [GetSpellInfo(56)] = true,         -- Stun (Weapon Proc)
    [GetSpellInfo(26108)] = true,      -- Glimpse of Madness
}

--[[
namespace.castTimeIncreases = {
    -- HUNTER
    [GetSpellInfo(3045)] = 45,    -- Rapid Fire

    -- MAGE
    [GetSpellInfo(23723)] = 33,   -- Mind Quickening
}

namespace.pushbackImmunities = {
    -- PRIEST
    [GetSpellInfo(14743)] = true, -- Focused Casting
}]]

lib:SetDataVersion(Type, Version)