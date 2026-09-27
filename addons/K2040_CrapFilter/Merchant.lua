local _, KCF = ...

local _G = _G
local CursorHasItem = _G.CursorHasItem
local GetContainerItemInfo = _G.GetContainerItemInfo
local GetContainerItemLink = _G.GetContainerItemLink
local GetItemInfo = _G.GetItemInfo
local InCombatLockdown = _G.InCombatLockdown
local UseContainerItem = _G.UseContainerItem
local type = type
local tonumber = tonumber

local Merchant = {}
KCF:RegisterModule("Merchant", Merchant)

function Merchant:OnInitialize()
	KCF:RegisterEvent("MERCHANT_SHOW", self, "OnMerchantShow")
end

function Merchant.CanAutoSell(_self)
	if not KCF.db.enabled or not KCF.db.merchant.autoSellCrap then return false end
	if type(UseContainerItem) ~= "function" then return false end
	if InCombatLockdown and InCombatLockdown() then return false end
	if CursorHasItem and CursorHasItem() then return false end
	return true
end

function Merchant.GetSellPrice(_self, itemID)
	local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
	sellPrice = tonumber(sellPrice)
	if not sellPrice or sellPrice <= 0 then return nil end
	return sellPrice
end

function Merchant:ShouldSell(itemID, count, locked)
	if locked or KCF:Classify(itemID, count) ~= KCF.RESULT_CRAP then return false end
	local professions = KCF.modules.Professions
	if professions and professions.IsReserved and professions:IsReserved(itemID) then return false end
	return self:GetSellPrice(itemID) ~= nil
end

function Merchant:CollectCandidates()
	local candidates = {}
	KCF:ForEachBagSlot(function(bag, slot, itemID, count, locked)
		if self:ShouldSell(itemID, count, locked) then
			candidates[#candidates + 1] = {
				bag = bag,
				slot = slot,
				itemID = itemID,
			}
		end
	end)
	return candidates
end

function Merchant:SellAllCrap()
	if not self:CanAutoSell() then return 0, 0 end
	local soldCount, soldValue = 0, 0
	local candidates = self:CollectCandidates()
	for _, candidate in ipairs(candidates) do
		if (InCombatLockdown and InCombatLockdown()) or (CursorHasItem and CursorHasItem()) then break end
		local link = GetContainerItemLink(candidate.bag, candidate.slot)
		if KCF:ParseItemID(link) == candidate.itemID then
			local _, count, locked = GetContainerItemInfo(candidate.bag, candidate.slot)
			count = tonumber(count) or 1
			local sellPrice = self:GetSellPrice(candidate.itemID)
			if sellPrice and self:ShouldSell(candidate.itemID, count, locked) then
				UseContainerItem(candidate.bag, candidate.slot)
				soldCount = soldCount + count
				soldValue = soldValue + (sellPrice * count)
			end
		end
	end

	if soldCount > 0 then
		KCF:Print("Sold " .. soldCount .. " crap item(s) for " .. soldValue .. " copper.")
	end
	return soldCount, soldValue
end

function Merchant:OnMerchantShow()
	self:SellAllCrap()
end
