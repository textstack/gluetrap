TOOL.Author = "textstack"
TOOL.Category = "Construction"
TOOL.Name = "#tool.gluetrap.name"

TOOL.Information = {
	{name = "left"},
	{name = "right"}
}

function TOOL:LeftClick(tr)
	local ent = tr.Entity

	if not Gluetrap.CanBeGlueTrap(ent) then return end
	if ent:GetNWBool("gluetrap") then return end
	if CLIENT then return true end

	Gluetrap.MakeGlueTrap(ent)

	undo.Create("Glue Trap")
	undo.AddFunction(function()
		Gluetrap.BreakGlueTrap(ent)
	end)
	undo.SetPlayer(self:GetOwner())
	undo.Finish()

	return true
end

function TOOL:RightClick(tr)
	local ent = tr.Entity

	if not Gluetrap.CanBeGlueTrap(ent) then return end
	if not ent:GetNWBool("gluetrap") then return end
	if CLIENT then return true end

	Gluetrap.BreakGlueTrap(ent)

	return true
end

if SERVER then return end

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