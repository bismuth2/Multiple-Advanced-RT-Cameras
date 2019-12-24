AddCSLuaFile()

DEFINE_BASECLASS( "base_wire_entity" )

ENT.Type = "anim"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.PrintName = "Adv RT Cam"
ENT.WireDebugName = "Adv RT Cam"

local CAMERA_MODEL = Model( "models/maxofs2d/camera.mdl" )

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "FOV")
	self:NetworkVar( "Vector", 0, "vecTrack" )
	self:NetworkVar( "Entity", 0, "entTrack" )
	self:NetworkVar( "Entity", 1, "Player" )
	self:NetworkVar( "String", 0, "ID")
end

function ENT:Initialize()

	if ( SERVER ) then

		self:SetModel( CAMERA_MODEL )
		self:PhysicsInit( SOLID_VPHYSICS )
		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
		self:DrawShadow( false )

		-- Don't collide with the player
		self:SetCollisionGroup( COLLISION_GROUP_WEAPON )

		local phys = self:GetPhysicsObject()

		if ( IsValid( phys ) ) then
			phys:Wake()
			phys:EnableMotion(false)
		end

		self:SetFOV(80)

		self.health = rtcam.cameraHealth
		self.Inputs = Wire_CreateInputs( self, {"FOV"} )
	end
end

function ENT:TriggerInput( name, value )

	if (name == "FOV" and value > 0 and value < 180) then
		self:SetFOV(value)
	end
end


function ENT:SetTracking( Ent, LPos )

	if ( IsValid( Ent ) ) then
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_BBOX )
	else

		self:SetMoveType( MOVETYPE_VPHYSICS )
		self:SetSolid( SOLID_VPHYSICS )
	end

	self:NextThink( CurTime() )

	self:SetvecTrack( LPos )
	self:SetentTrack( Ent )

end

function ENT:SetLocked( locked )

	if ( locked == 1 ) then

		self.PhysgunDisabled = true

		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_BBOX )

		self:SetCollisionGroup( COLLISION_GROUP_WORLD )

	else

		self.PhysgunDisabled = false

	end

	self.locked = locked

end

function ENT:OnTakeDamage( dmginfo )
	self:TakePhysicsDamage( dmginfo )
	if self.health <= 0 then return end
	self.health = self.health - dmginfo:GetDamage()
	if self.health <= 0 then
		self:SetMoveType( MOVETYPE_VPHYSICS )
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(true)
		end
		timer.Simple(4, function()
			if IsValid(self) then
				self:Remove()
			end
		end)
	end
end

function ENT:OnRemove()

	if ( IsValid( self.UsingPlayer ) ) then

		self.UsingPlayer:SetViewEntity( self.UsingPlayer )

	end

end

if CLIENT then
	function ENT:Think()
		self:TrackEntity( self:GetentTrack(), self:GetvecTrack() )
		self:NextThink(CurTime() + GetConVarNumber("prtcamera_refreshRate", 0.1))
	end
end

function ENT:TrackEntity( ent, lpos )

	if ( not IsValid( ent ) ) then return end

	local WPos = ent:LocalToWorld( lpos )

	if ( ent:IsPlayer() ) then
		WPos = WPos + ent:GetViewOffset() * 0.85
	end

	local CamPos = self:GetPos()
	local Ang = WPos - CamPos

	Ang = Ang:Angle()
	self:SetAngles( Ang )

end

function ENT:CanTool( ply, trace, mode )

	if ( self:GetMoveType() == MOVETYPE_NONE ) then return false end

	return true

end

function ENT:Draw()
--[[
	if ( GetConVarNumber( "cl_drawcameras" ) == 0 ) then return end

	 --Don't draw the camera if we're taking pics
	local ply = LocalPlayer()
	local wep = ply:GetActiveWeapon()
	if ( IsValid( wep ) ) then
		if ( wep:GetClass() == "gmod_camera" ) then return end
	end
]]--
	self:DrawModel()

end
