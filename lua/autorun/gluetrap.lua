Gluetrap = Gluetrap or {}

function Gluetrap.CanBeGlueTrap(ent)
	if not IsValid(ent) then return false end
	if ent:GetClass() ~= "prop_physics" then return false end
	if not ent:IsSolid() then return false end
	return true
end

if CLIENT then return end

hook.Add("CanExitVehicle", "Gluetrap", function(vehicle, ply)
	if ply.StuckTo == vehicle then return false end
end)

function Gluetrap.MakeGlueTrap(ent, stickAny)
	if not IsValid(ent) then return end
	if ent:GetNWBool("gluetrap") then return end

	if stickAny then
		ent.StickAny = true
	end

	ent.StuckEnts = {}
	ent:SetNWBool("gluetrap", true)
	duplicator.StoreEntityModifier(ent, "gluetrap", {stickAny})

	ent.GlueTouch = ent:AddCallback("PhysicsCollide", function(_, data)
		timer.Simple(0, function()
			Gluetrap.MakeStuck(data.HitEntity, ent, data.HitPos)
		end)
	end)

	ent:CallOnRemove("gluetrap", function()
		Gluetrap.BreakGlueTrap(ent)
	end)
end

local function getNearestPoint(ent, point)
	local phys = ent:GetPhysicsObject()
	if not IsValid(phys) then return ent:GetPos() end

	local newPoint = ent:WorldToLocal(point)

	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	newPoint.x = math.Clamp(newPoint.x, mins.x, maxs.x)
	newPoint.y = math.Clamp(newPoint.y, mins.y, maxs.y)
	newPoint.z = math.Clamp(newPoint.z, mins.z, maxs.z)

	return ent:LocalToWorld(newPoint)
end

local function npcUnstuck(npc)
	local ent = npc.StuckTo
	if not IsValid(ent) then return end

	if npc:IsRagdoll() then
		constraint.RemoveConstraints(npc, "Weld")
	end

	npc.LastUnstuck = CurTime()

	local pos = npc:GetPos()
	npc:SetParent(nil)
	npc:SetPos(pos)

	npc.StuckTo = nil

	if ent.StuckEnts then
		ent.StuckEnts[npc:EntIndex()] = nil
	end

	npc:EmitSound(string.format("physics/flesh/flesh_impact_bullet%d.wav", math.random(1, 5)))
end

function Gluetrap.BreakGlueTrap(ent)
	if not IsValid(ent) then return end
	if not ent:GetNWBool("gluetrap") then return end

	ent:SetNWBool("gluetrap", false)
	ent:RemoveCallback("PhysicsCollide", ent.GlueTouch)
	ent:RemoveCallOnRemove("gluetrap")
	duplicator.ClearEntityModifier(ent, "gluetrap")

	for k, _ in pairs(ent.StuckEnts) do
		local e = Entity(k)
		if not IsValid(e) then continue end

		if e.IsGlueTrapChair then
			e:Remove()
		else
			npcUnstuck(e)
		end
	end

	ent.StuckEnts = nil
	ent.GlueTouch = nil
end

local function sit(ply, parent, pos)
	local vehicle = ents.Create("prop_vehicle_prisoner_pod")

	local ang = ply:EyeAngles()
	local pitch = ang.p
	ang.p, ang.r = 0, 0

	local posDiff = ply:WorldSpaceCenter() - getNearestPoint(ply, pos)
	local worldPosDiff = ply:GetPos() - ply:WorldSpaceCenter()
	posDiff.x, posDiff.y = posDiff.x * 0.4, posDiff.y * 0.4

	vehicle:SetPos(pos + posDiff * 0.93 + worldPosDiff)
	vehicle:SetModel("models/vehicles/prisoner_pod_inner.mdl")
	vehicle:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
	vehicle:SetKeyValue("limitview", "1")
	vehicle:Spawn()
	vehicle:Activate()

	if not IsValid(vehicle) or not IsValid(vehicle:GetPhysicsObject()) then
		SafeRemoveEntity(vehicle)
		return
	end

	local phys = vehicle:GetPhysicsObject()
	phys:Sleep()
	phys:EnableGravity(false)
	phys:EnableMotion(false)
	phys:EnableCollisions(false)
	phys:SetMass(1)

	vehicle:SetMoveType(MOVETYPE_PUSH)
	vehicle:SetCollisionGroup(COLLISION_GROUP_WORLD)
	vehicle:SetNotSolid(true)
	vehicle:SetParent(parent)
	vehicle:CollisionRulesChanged()
	vehicle:DrawShadow(false)
	vehicle:SetColor(color_transparent)
	vehicle:SetRenderMode(RENDERMODE_TRANSALPHA)
	vehicle:SetNoDraw(true)
	vehicle:SetThirdPersonMode(false)

	vehicle.VehicleName = "Pod"
	vehicle.ClassOverride = "prop_vehicle_prisoner_pod"
	vehicle.PhysgunDisabled = true
	vehicle.m_tblToolsAllowed = {}
	vehicle.customCheck = function() return false end

	ply:EnterVehicle(vehicle)
	ply:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	ply:CollisionRulesChanged()

	ply:SetEyeAngles(Angle(pitch, 0, 0))
	vehicle:SetAngles(ang)

	vehicle.IsGlueTrapChair = true

	return vehicle
end

local function npcStuck(npc, ent, pos)
	if npc:IsRagdoll() then
		for i = 0, npc:GetPhysicsObjectCount() - 1 do
			constraint.Weld(npc, ent, i, 0, 0)
		end
	end

	npc:SetParent(ent)
	npc.StuckTo = ent
	ent.StuckEnts[npc:EntIndex()] = true

	npc:EmitSound(string.format("physics/flesh/flesh_squishy_impact_hard%d.wav", math.random(1, 4)))
end

function Gluetrap.MakeStuck(ply, ent, pos)
	if not IsValid(ply) or not IsValid(ent) then return end

	if IsValid(ply.StuckTo) then return end
	if not ent.StuckEnts then return end
	if ply.LastUnstuck and CurTime() - ply.LastUnstuck < 0.5 then return end

	if ply:IsNPC() or ply:IsNextBot() then
		npcStuck(ply, ent, pos)
		return
	end

	if not ply:IsPlayer() then
		if not ent.StickAny or ply.IsGlueTrapChair then return end

		if ply.StuckEnts then
			local pCount = table.Count(ply.StuckEnts)
			local eCount = table.Count(ent.StuckEnts)
			if pCount > eCount then return end
			if pCount == eCount and ply:EntIndex() > ent:EntIndex() then return end
		end

		npcStuck(ply, ent, pos)

		return
	end

	local vehicle = sit(ply, ent, pos)
	if not IsValid(vehicle) then return end

	vehicle:CallOnRemove("clearplayer", function()
		Gluetrap.ClearStuck(ply)
	end)

	ply:EmitSound(string.format("physics/flesh/flesh_squishy_impact_hard%d.wav", math.random(1, 4)))

	ply.StuckTo = vehicle
	vehicle.StuckTo = ent
	ent.StuckEnts[vehicle:EntIndex()] = true
end

function Gluetrap.ClearStuck(ply)
	if not ply:IsPlayer() then
		npcUnstuck(ply)
		return
	end

	local vehicle = ply.StuckTo
	if not IsValid(vehicle) then return end
	ply.StuckTo = nil

	ply.LastUnstuck = CurTime()

	local ang = ply:EyeAngles()
	ang.r = 0

	ply:EmitSound(string.format("physics/flesh/flesh_impact_bullet%d.wav", math.random(1, 5)))
	ply:ExitVehicle()
	ply:SetEyeAngles(ang)

	if IsValid(vehicle.StuckTo) and vehicle.StuckTo.StuckEnts then
		vehicle.StuckTo.StuckEnts[vehicle:EntIndex()] = nil
	end
end

duplicator.RegisterEntityModifier("gluetrap", function(_, ent, data)
	Gluetrap.MakeGlueTrap(ent, data[1])
end)

hook.Add("PostPlayerDeath", "Gluetrap", function(ply)
	Gluetrap.ClearStuck(ply)
end)

hook.Add("PlayerLeaveVehicle", "Gluetrap", function(ply)
	Gluetrap.ClearStuck(ply)
end)

hook.Add("PlayerDisconnected", "Gluetrap", function(ply)
	Gluetrap.ClearStuck(ply)
end)

hook.Add("EntityTakeDamage", "Gluetrap", function(target, dmg)
	if not target:IsPlayer() then return end
	if not dmg:IsDamageType(DMG_CRUSH) then return end

	local attacker = dmg:GetAttacker()
	if attacker:IsValid() and attacker:GetNWBool("gluetrap") then return true end

	local inflictor = dmg:GetInflictor()
	if inflictor:IsValid() and inflictor:GetNWBool("gluetrap") then return true end
end)

hook.Add("OnPhysgunPickup", "Gluetrap", function(ply, ent)
	Gluetrap.ClearStuck(ent)
end)