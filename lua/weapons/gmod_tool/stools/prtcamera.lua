
TOOL.Category = "Render"
TOOL.Name = "#tool.prtcamera.name"

TOOL.ClientConVar[ "locked" ] = "0"
TOOL.ClientConVar[ "showId" ] = "0"
TOOL.ClientConVar[ "id" ] = "none"
--TOOL.ClientConVar[ "toggle" ] = "1"
TOOL.ClientConVar[ "model" ] = ""
TOOL.ClientConVar[ "refreshRate" ] = "0.1" -- best to leave default refreshrate to 0.1, or 10hz, to reduce lag
TOOL.ClientConVar[ "drawCameras" ] = "1"
--TOOL.ClientConvar[ "resolution" ] = "512"

-- the refresh rate grabs the CurTime of the server and is divided by refreshRate
--for example: (0.1 equals 10hz) (0.05 equals 20hz) (0.025 equals 40hz) (0.0166666667 equals 60hz) (0.0125 equals 80hz, this is the smoothest and looks 60fps but is VERY performance heavy!)


cleanup.Register( "rtcameras" )
cleanup.Register( "rtmonitors" )

local SendNotification
if SERVER then
	util.AddNetworkString('rtcamera.alert')
	function SendNotification(player, message)
		net.Start('rtcamera.alert')
		net.WriteString(message)
		net.Send(player)
	end
else
	function SendNotification() end
	net.Receive('rtcamera.alert', function()
		local message = net.ReadString()
		Derma_Message(message, 'RT Camera', 'Ok')
	end)
end

local function CheckLimits(player, class)
	local count = 0
	for k,v in ipairs(ents.FindByClass(class)) do
		if v:GetPlayer() == player then
			count = count + 1
		end
	end
	return count
end


local function IsCameraIDAcceptable(player, id)
	if id:len() > 20 then
		SendNotification(player, "Camera ID is too long, please provide a shorter id. (less than 20 letters).")
		return false
	end
	if id:len() < 3 then
		SendNotification(player, "Camera ID is too short, please provide a longer id. (at least 3 letters).")
		return false
	end
	for k,v in ipairs(ents.FindByClass('gmod_rtcameraprop')) do
		if v:GetID() == id then
			if v:GetPlayer() then
				SendNotification(player, "Sorry, but this Camera ID is already in use! You'll need to use a different one.")
				return false
			end
		end
	end
	return true
end

local function MakeCamera( ply, locked, id, Data )
	local ent = ents.Create( "gmod_rtcameraprop" )

	if ( not IsValid( ent ) ) then return end

	duplicator.DoGeneric( ent, Data )

	if id then
		ent:SetID(id)
	end
	ent:SetPlayer( ply )

	--ent.toggle = toggle
	ent.locked = locked

	ent:Spawn()

	ent:SetTracking( NULL, Vector( 0 ) )
	ent:SetLocked( locked )

	if ( IsValid( ply ) ) then
		undo.Create( "RT Camera" )
			undo.AddEntity( ent )
			undo.SetPlayer( ply )
		undo.Finish()

		ply:AddCleanup( "rtcameras", ent )
	end

	return ent
end
duplicator.RegisterEntityClass( "gmod_rtcameraprop", MakeCamera, "locked", "ID", "Data" )

local function MakeMonitor( ply, trace, model, id, Data )
    local ent = ents.Create( "gmod_rttv" )

    if (not IsValid( ent ) ) then return end

    if id then
        ent:SetID(id)
    end
    if model then
        ent:SetModel(model)
    end
    if trace then
        Data.Pos = trace.HitPos + trace.HitNormal * math.abs(ent:OBBMins().x)
        Data.Angle = trace.HitNormal:Angle()
        Data.Angle:RotateAroundAxis(Data.Angle:Forward(), 180)
        Data.Angle:RotateAroundAxis(Data.Angle:Right(), 180)
        Data.Angle:RotateAroundAxis(Data.Angle:Up(), 180)
    end

    duplicator.DoGeneric( ent, Data )
    ent:SetPlayer( ply )
    ent:Spawn()

    if ( IsValid( ply ) ) then
        undo.Create( "RT Monitor" )
            undo.AddEntity( ent )
            undo.SetPlayer( ply )
        undo.Finish()

        ply:AddCleanup( "rtmonitors", ent )
    end

    return ent
end
duplicator.RegisterEntityClass( "gmod_rttv", MakeMonitor, "trace", "Model", "ID", "Data" )

function TOOL:LeftClick( trace )
	if not IsFirstTimePredicted() then return end

	local id = self:GetClientInfo("id")
	if ( CLIENT ) then return IsCameraIDAcceptable(self:GetOwner(), id) end

	local ply = self:GetOwner()
	local locked = self:GetClientNumber( "locked" )

	if not IsCameraIDAcceptable(self:GetOwner(), id) then return false end
	if CheckLimits(ply, 'gmod_rtcameraprop') > rtcam.maxCamsPerPlayer then SendNotification(ply, "Exceeded maximum number of cameras (" .. rtcam.maxCamsPerPlayer+1 .. ")") return false end

	local ent = MakeCamera( ply, locked, id, { Pos = trace.StartPos, Angle = ply:EyeAngles() } )

	return true, ent
end

function TOOL:RightClick( trace )
	if CLIENT then return true end
	if not IsFirstTimePredicted() then return end

	local ply = self:GetOwner()
	local id = self:GetClientInfo('id')
	--[[
	local ok = false
	for k,v in ipairs(ents.FindByClass('gmod_rtcameraprop')) do
		if v:GetID() == id then
			ok = true
			break
		end
	end
	if not ok then
		SendNotification(ply, "Sorry but there aren't any RT Cameras with the ID '"..id.."'")
		return false
	end
	]]--
	if CheckLimits(ply, 'gmod_rttv') > rtcam.maxMonitorsPerPlayer then SendNotification(ply, "Exceeded maximum number of monitors (" .. rtcam.maxMonitorsPerPlayer+1 .. ")") return false end

	local model = self:GetClientInfo("model")
	if not list.Get("RTMonitorModels")[model] then return false end
	local ent = MakeMonitor( ply, trace, model, id, {} )
	ent:SetModel(self:GetClientInfo("model"))

	if tonumber(self:GetClientNumber("showId")) > 0 then
		ent:SetShowID(true)
	end

	return true, ent
end

function TOOL.BuildCPanel( CPanel )

	CPanel:AddControl( "textbox", { Label = "#tool.prtcamera.id", Command = "prtcamera_id" } )
	CPanel:AddControl( "CheckBox", { Label = "#tool.prtcamera.showId", Command = "prtcamera_showId", Help = true } )
	CPanel:AddControl( "CheckBox", { Label = "#tool.camera.static", Command = "prtcamera_locked", Help = true } )

		--Hide screens
		CPanel:AddControl( "CheckBox", { Label = "#tool.prtcamera.drawScreens", Command = "prtcamera_drawCameras", Help = true } )

		--RefreshRate Slider
		CPanel:AddControl( "slider", { Type = "Float", Label = "#tool.prtcamera.refreshRate", Command = "prtcamera_refreshRate", Min = 0.0125, Max = 0.1, Help = true } )

		--Resolution Slider
		--CPanel:AddControl( "slider", { Type = "Integer", Label = "#tool.prtcamera.resolution", Command = "prtcamera_resolution",  Min = 256, Max = 1024, Help = true } )

	CPanel:AddControl( "PropSelect", { Label = "#tool.prtcamera.model", ConVar = "prtcamera_model", Height = 4, Models = list.Get( "RTMonitorModels" ) } )
end

if CLIENT then
	language.Add('tool.prtcamera.name', 'Advanced RT Camera')
	language.Add('tool.prtcamera.model', 'RT Display Model')
	language.Add('tool.prtcamera.id', 'RT Camera ID')
	language.Add('tool.prtcamera.showId', 'Show camera id')
	language.Add('tool.prtcamera.showId.help', 'Should the camera\'s id be displayed on the screen')

		--Hide screens
		language.Add('tool.prtcamera.drawScreens', 'Render Screens')
		language.Add('tool.prtcamera.drawScreens.help', 'Disable for performance')

		--RefreshRate Slider
		language.Add('tool.prtcamera.refreshRate', 'Refresh Rate')
		language.Add('tool.prtcamera.refreshRate.help', 'Sets the Hz rate of monitors from 60hz to 10hz \n(Performance Heavy!)')

		--Resolution Slider
		--language.Add('tool.prtcamera.resolution', 'Monitor Resolution')
		--language.Add('tool.prtcamera.resolution.help', 'Sets the resolution of monitors from 256x256 to 1024x1024')

	language.Add('tool.prtcamera.desc', 'Allows you to place RT Cameras and their displays')
	language.Add('tool.prtcamera.0', 'Left click place camera. Right click place monitor.')
end
