TOOL.Author = "textstack"
TOOL.Category = "Construction"
TOOL.Name = "#tool.gluetrap.name"

TOOL.Information = {
	{name = "left"},
	{name = "right"}
}

local function canBeGlueTrap(ent)
	if not IsValid(ent) then return false end
	if ent:IsRagdoll() then return false end
	if not ent:IsSolid() then return false end
	return true
end

local breakGlueTrap
local function makeGlueTrap(ent)
	if not IsValid(ent) then return end
	if ent:GetNWBool("gluetrap") then return end

	ent:SetNWBool("gluetrap", true)

	duplicator.StoreEntityModifier(ent, "gluetrap", {})

	local minS, maxS = ent:WorldSpaceAABB()
	ent.UnstuckDist = (maxS - minS):LengthSqr()

	ent.StuckEnts = {}

	ent.GlueTouch = ent:AddCallback("PhysicsCollide", function(_, data)
		local ply = data.HitEntity
		if not IsValid(ply) or not ply:IsPlayer() then return end
		if IsValid(ply.StuckTo) then return end

		ply.StuckTo = ent
		ent.StuckEnts[ply] = true

		local ang = ply:EyeAngles()

		ply:SetMoveType(MOVETYPE_NOCLIP)
		ply:Freeze(true)
		ply:SetParent(ent)
		ply:SetEyeAngles(ang - ent:EyeAngles())
		ply:EmitSound(string.format("physics/flesh/flesh_squishy_impact_hard%d.wav", math.random(1, 4)))
	end)

	ent:CallOnRemove("gluetrap", function()
		breakGlueTrap(ent)
	end)
end

local function clearStuck(ply)
	if not IsValid(ply) then return end

	local ang = ply:EyeAngles()
	ang.r = 0

	ply:SetParent(nil)
	ply:SetMoveType(MOVETYPE_WALK)
	ply:Freeze(false)
	ply:SetEyeAngles(ang)
	ply:EmitSound(string.format("physics/flesh/flesh_impact_bullet%d.wav", math.random(1, 5)))

	ply.StuckTo = nil
end

function breakGlueTrap(ent)
	if not IsValid(ent) then return end
	if not ent:GetNWBool("gluetrap") then return end

	ent:SetNWBool("gluetrap", false)
	duplicator.ClearEntityModifier(ent, "gluetrap")

	ent:RemoveCallback("PhysicsCollide", ent.GlueTouch)
	ent:RemoveCallOnRemove("gluetrap")

	for k, _ in pairs(ent.StuckEnts) do
		clearStuck(k)
	end

	ent.StuckEnts = nil
	ent.GlueTouch = nil
	ent.UnstuckDist = nil
end

duplicator.RegisterEntityModifier("gluetrap", function(_, ent)
	makeGlueTrap(ent)
end)

function TOOL:LeftClick(tr)
	local ent = tr.Entity

	if not canBeGlueTrap(ent) then return end
	if ent:GetNWBool("gluetrap") then return end
	if CLIENT then return true end

	makeGlueTrap(ent)

	undo.Create("Glue Trap")
	undo.AddFunction(function()
		breakGlueTrap(ent)
	end)
	undo.SetPlayer(self:GetOwner())
	undo.Finish()

	return true
end

function TOOL:RightClick(tr)
	local ent = tr.Entity

	if not canBeGlueTrap(ent) then return end
	if not ent:GetNWBool("gluetrap") then return end
	if CLIENT then return true end

	breakGlueTrap(ent)

	return true
end

if SERVER then
	hook.Add("Think", "Gluetrap", function()
		for _, v in player.Iterator() do
			if not IsValid(v.StuckTo) then continue end
			if v.StuckTo:WorldSpaceCenter():DistToSqr(v:WorldSpaceCenter()) <= v.StuckTo.UnstuckDist and v:Alive() then continue end

			v.StuckTo.StuckEnts[v] = nil
			clearStuck(v)
		end
	end)

	hook.Add("EntityTakeDamage", "Gluetrap", function(target, dmg)
		if not target:IsPlayer() then return end

		local attacker = dmg:GetAttacker()
		if not attacker:IsValid() then return end

		if not attacker:GetNWBool("gluetrap") then return end
		if not dmg:IsDamageType(DMG_CRUSH) then return end

		return true
	end)

	return
end

language.Add("tool.gluetrap.name", "Glue Trap")
language.Add("tool.gluetrap.desc", "Turns props into glue traps.")
language.Add("tool.gluetrap.left", "Left click to turn into a glue trap")
language.Add("tool.gluetrap.right", "Right click to turn back into a normal prop")

local mat = Material("models/props_combine/stasisfield_beam")

function TOOL:DrawHUD()
	cam.Start3D()
	render.SetColorModulation(1, 0.75, 0)
	render.MaterialOverride(mat)
	for _, v in ipairs(ents.FindInSphere(EyePos(), 1000)) do
		if v:GetNWBool("gluetrap") then
			v:DrawModel()
		end
	end
	cam.End3D()
end

function TOOL.BuildCPanel(panel)
	panel:Help("Turns props into glue traps.")
end