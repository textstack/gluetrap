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

local function clearStuck(ply)
	if not IsValid(ply) then return end
	if not ply:GetNWBool("gluedtrap") then return end

	ply:SetNWBool("gluedtrap", false)

	local ang = ply:EyeAngles()
	ang.r = 0

	ply:SetParent(nil)
	ply:SetMoveType(MOVETYPE_WALK)
	ply:Freeze(false)
	ply:SetEyeAngles(ang)
	ply:DrawViewModel(true)
	ply:EmitSound(string.format("physics/flesh/flesh_impact_bullet%d.wav", math.random(1, 5)))

	if IsValid(ply.StuckParent) then
		ply.StuckParent:Remove()
	end

	ply.StuckTo = nil
	ply.StuckParent = nil
end

local function makeStuck(ply, ent)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	if IsValid(ply.StuckTo) then return end
	if not ent:GetNWBool("gluetrap") then return end

	ply:SetNWBool("gluedtrap", true)

	local stuckP = ents.Create("plyglue")
	ply.StuckParent = stuckP

	stuckP:SetPos(ply:GetPos())
	stuckP:SetParent(ent)
	stuckP:SetAngles(angle_zero)

	ply.StuckTo = ent
	ent.StuckEnts[ply] = true

	ply:SetMoveType(MOVETYPE_NOCLIP)
	ply:Freeze(true)
	ply:SetParent(stuckP)
	ply:DrawViewModel(false)
	ply:EmitSound(string.format("physics/flesh/flesh_squishy_impact_hard%d.wav", math.random(1, 4)))
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
		timer.Simple(0, function()
			makeStuck(data.HitEntity, ent)
		end)
	end)

	ent:CallOnRemove("gluetrap", function()
		breakGlueTrap(ent)
	end)
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

hook.Add("PlayerSwitchWeapon", "Gluetrap", function(ply)
	if ply:GetNWBool("gluedtrap") then return true end
end)

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

hook.Add("CalcView", "Gluetrap", function(ply, origin)
	if not ply:GetNWBool("gluedtrap") then return end

	local parent = ply:GetParent()
	if not IsValid(parent) then return end

	local offset = ply:GetViewOffset()
	local pos = ply:GetPos()

	offset:Rotate(parent:GetAngles())

	origin.x = pos.x + offset.x
	origin.y = pos.y + offset.y
	origin.z = pos.z + offset.z
end)