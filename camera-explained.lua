-- place the script in starterpack so the camera is given every spawn
local owner = script:FindFirstAncestorOfClass("Player")
repeat task.wait()
	owner = script:FindFirstAncestorOfClass("Player")
until owner
-- above is just getting the player for the tool to give to make sure everything is in one script

local cam = Instance.new("Tool",owner.Backpack) -- make tool
cam.Name = "Camera" -- name it
cam.ToolTip = [[
Instructions:
R:Camera Up
F:Camera Down
E:Camera Reset

Chat: /e s/black bar text here.
]] -- tooltip that goes over many lines

local prt = Instance.new("Part",cam) -- make handle
prt.Name = "Handle" -- name it so it is actually considered a handle to roblox
prt.Size = Vector3.new(1,1,1) -- make it small
prt.Color = Color3.new(0,0,0) -- make it black


function getPoints(prt) -- get all corners of a block
	local tab = {prt.CFrame} -- set the table for all corners, put a default point in the center
	for x = 1,2 do -- confusing but 2x2x2 = 8 which there is 8 corners in a square
		for y = 1,2 do -- ^^^
			for z = 1,2 do -- ^^^
				local rx,ry,rz = x*2-3,y*2-3,z*2-3 -- each of these turns 1 to -1 and 2 to 1, funky math to get each side of a edge
				table.insert(tab,prt.CFrame*CFrame.new(prt.Size.X/2*rx,prt.Size.Y/2*ry,prt.Size.Z/2*rz)) -- add the cframe to the list with the weird math calculating the corner
			end
		end
	end
	return tab -- give the corner table back
end

function cast(hancf) -- get all parts in the fov of the block
	local tars = workspace:GetPartBoundsInBox(hancf*CFrame.new(0,0,-100),Vector3.new(3,3,200)) -- cast box far so that we don't miss anything in the range
	-- this line above also makes sure nothing is missed right in front of it as often with big parts it can miss because all the points are outside the range but the actual part is in the fov.
	-- mind aswell set target table to this instead of setting a blank table then right after adding everything to it, basically recreating the table
	
	for _,v in pairs(workspace:GetDescendants()) do -- get all parts
		if v:IsA("BasePart") and not table.find(tars,v) then -- make sure it is a part and ensure it wasn't scanned by the line of sight detector
			for _,point in pairs(getPoints(v)) do -- get every corner point
				local point = point.Position -- get position
				local cf = CFrame.new(hancf.Position,point) -- use this to turn from the camera position to the point position

				local dot = hancf.LookVector:Dot(cf.LookVector) -- can use this to get the angle from the point of the camera looking at the point

				-- next we make sure this "dot" is inside of that camera fov
				if dot >= math.cos(math.rad(70)) then -- 70 is normal fov, use more funky math to change it to the right number to make sure everything is in 70 degrees of view
					table.insert(tars,v) -- if it is make it a correct target
					break -- and break the point loop for optimization
				end
			end
		end
	end

	return tars -- return all targets
end


local guis = {} -- gui label for later

local snap = ""
local snapprefix = "/e s/"

-- don't mark me down on this because it is the best option for serverside scripts:
-- https://devforum.roblox.com/t/alternative-to-playerchatted-for-textchatservice/2457869
owner.Chatted:Connect(function(c)
	if c:lower():sub(1,#snapprefix) == snapprefix then -- check if it is the correct prefix by comparing the same length text to the real prefix
		snap = game:GetService("TextService"):FilterStringAsync(c:sub(#snapprefix+1),owner.UserId):GetNonChatStringForBroadcastAsync() -- change the snap text to everything after "/e s/" also filter the chat to ensure no bypasses are sent
	end
end)

local function activation(setts)
	-- insane proximity prompt keybind activation method so you don't have to use localscripts
	
	-- set defaults to make sure there are no errors
	setts.Down = setts.Down or function() end
	setts.Up = setts.Up or function() end
	
	-- create proximity prompt
	local prox = Instance.new("ProximityPrompt",setts.Parent or nil) -- inside of the head because thats where the activation radius of the proximity prompts are
	prox.MaxActivationDistance = .03 -- ensure only the owner can get the keybind
	prox.KeyboardKeyCode = setts.Key -- set it to the correct key
	prox.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow -- make sure it can be shown even with other proximity prompts colliding
	prox.Style = Enum.ProximityPromptStyle.Custom -- make it invisible
	prox.RequiresLineOfSight = false -- ensure it can be activated 24/7

	prox.Triggered:Connect(function(a) -- proximity prompt activated
		setts.Down(a,prox) -- run the function given by the setts table
	end)
	prox.TriggerEnded:Connect(function(a) -- proximity prompt ended
		setts.Up(a,prox) -- run the function given by the setts table
	end)

	return prox
end

local ang = 0 -- set normal angle to 0
local angdiff = 0 -- rotation velocity starts at 0

local proxs = {
	activation({Down = function() -- make sure that when holding both R and F it will stay still and letting go of one will make the other one still work
		angdiff = angdiff + 1
	end,Up = function()
		angdiff = angdiff - 1
	end,Key = Enum.KeyCode.R}),
	
	activation({Down = function() -- same thing but opposite direction of the one above
		angdiff = angdiff - 1
	end,Up = function()
		angdiff = angdiff + 1
	end,Key = Enum.KeyCode.F}),

	activation({Down = function()
		ang = 0 -- reset camera angle
	end,Key = Enum.KeyCode.E}),
}

local grip = cam.Grip -- save the grip for later to make sure we can put it back to its original position correctly

game:GetService("RunService").Heartbeat:Connect(function()
	ang = ang + angdiff -- rotating to the values changed by the keybinds
	ang = math.clamp(ang,-90,90) -- clamp values to not go more than 90 degrees up and down
	
	cam.Grip = grip*CFrame.Angles(-math.rad(ang),0,0)*CFrame.new(0,-.5,.5) -- change the grip rotation to what is right
end)

cam.Equipped:Connect(function()
	for _,v in pairs(proxs) do
		v.Parent = cam.Parent.PrimaryPart -- reparent proximity prompts to the character thats holding the camera to make sure when dropping it, it will work for other players too
	end
end)
cam.Unequipped:Connect(function()
	for _,v in pairs(proxs) do
		v.Parent = nil -- remove all proximity prompts so that there is no keybind presses while it is unequipped
	end
end)

cam.Activated:Connect(function() -- click when using the tool
	local ac = cam.Parent.Name -- character username
	local blacklist = {} -- set this for later

	for _,v in pairs(guis) do
		pcall(function()
			v:Destroy() -- remove all previous guis across all players before we add a new one
		end)
	end
	guis = {} -- reset guis table bc there is nothing in it but nil values

	local cf = prt.CFrame -- camera cframe for viewport frame
	local vpparts = cast(cf) -- cast the viewport for the parts that are actually in frame not behind it or anything

	local gui = Instance.new("ScreenGui") -- make the gui
	local frame = Instance.new("Frame",gui)
	frame.Size = UDim2.new(.25,0,.25,0)
	frame.AnchorPoint = Vector2.new(1,1) -- make the position origin located at the bottom right
	frame.Position = UDim2.new(1,0,1,0)
	frame.BackgroundTransparency = 1 -- invisible background just as a border to everything so we can scale everything relative to the frame

	local vp = Instance.new("ViewportFrame",frame) -- make the most essential part of the camera, the viewport frame so that we can actually show a picture.
	vp.Position = UDim2.new(0,0,.15,0)
	vp.Size = UDim2.new(1,0,.85,0)

	local txt = Instance.new("TextLabel",frame) -- add the credits or the username for the picture
	txt.Size = UDim2.new(1,0,.05,0)
	txt.TextScaled = true -- make sure text isnt too small for clients
	txt.Font = Enum.Font.Highway -- get a font going
	txt.BackgroundTransparency = 1 -- invisible background but visible text
	txt.Position = UDim2.new(1,0,1,0)
	txt.AnchorPoint = Vector2.new(1,1) -- bottom right center point
	txt.TextStrokeColor3 = Color3.new(1,1,1) -- make the text stroke white
	txt.TextStrokeTransparency = 0 -- make the text stroke VISIBLE
	txt.TextXAlignment = Enum.TextXAlignment.Right -- make the text located on the rightmost position on the textlabel
	txt.Text = "@"..ac

	Instance.new("UICorner",vp) -- make it look less blocky with rounded corners (default corner settings)

	local cam = Instance.new("Camera",vp) -- make essential part of viewport frame, the camera
	cam.CFrame = cf -- locate it to the handles cframe we got from earlier
	vp.CurrentCamera = cam -- set the camera in the viewport frame to this camera

	local snaplabel -- define it so we can mess with it for later outside of the if function
	if snap ~= "" then
		snaplabel = Instance.new("TextLabel",frame) -- make the snapchat label
		snaplabel.ZIndex = 2 -- put it above everything else
		snaplabel.Name = "Snap" -- not necessary but to keep everything neat for viewing
		snaplabel.Size = UDim2.new(1,0,.08,0)
		snaplabel.BackgroundTransparency = .5 -- halfway invisible
		snaplabel.BackgroundColor3 = Color3.new(0,0,0) -- black
		snaplabel.Font = Enum.Font.GothamMedium -- good font that looks like snapchats
		snaplabel.Position = UDim2.new(0,0,.2,0) -- position a little below top
		snaplabel.TextScaled = true -- scale the text so it looks good on big resolution and low resolution devices
		snaplabel.TextColor3 = Color3.new(1,1,1) -- white text color so it takes on the effect of snapchat
		snaplabel.TextStrokeTransparency = 1 -- the default black stroke to be visible
		snaplabel.Text = snap -- set the text to what was set in the chat command
	end

	local sky = Instance.new("Part",vp) -- a sky alternative so that the background isnt just a gray screen
	sky.Size = Vector3.one*1 -- not needed but to keep it neat ig?
	sky.Position = cf.Position -- move the sky to the cameras position so it is always the same distance effect? just like how in the real game where if you move your camera the sky doesn't move

	local mesh = Instance.new("SpecialMesh",sky) -- make the mesh
	mesh.MeshId = "rbxassetid://5697933202" -- set a sphere shape
	mesh.TextureId = "http://www.roblox.com/asset/?id=200535580" -- set a skybox texture
	mesh.Scale = Vector3.one*-1000 -- scale it to be inside out so that we can see the skybox from inside of it
	for _,v in pairs(vpparts) do
		if table.find({"Terrain"},v.ClassName) or table.find(blacklist,v) then -- ignore terrain and previously marked blacklisted parts
			continue
		end
		pcall(function()
			v.Archivable = true -- make sure we can duplicate the individual parts
		end)

		local clone -- mark the variable early so we can mess with it later

		if v.Parent:FindFirstChildOfClass("Humanoid") then -- check if it is a character
			for _,v in pairs(v.Parent:GetDescendants()) do -- get all character parts and blacklist them
				table.insert(blacklist,v) -- (the blacklisting)
			end

			pcall(function()
				v.Parent.Archivable = true -- make it so we can duplicate the character
			end)

			clone = v.Parent:Clone() -- clone the character
		else
			clone = v:Clone() -- clone the part
		end

		clone.Parent = vp -- move the part/character we found to the viewportframe so we can see it in the picture
	end

	for _,v in pairs(vp:GetDescendants()) do -- remove all screenguis because if there is one in a part then all users can see it when put into the viewport frame
		if v:IsA("ScreenGui") then
			v:Destroy() -- (destroy it)
		end
	end


	for _,v in pairs(game:GetService("Players"):GetPlayers()) do -- loop through players to make sure everyone can see it
		local newgui = gui:Clone() -- copy the ui to give to the player
		local newframe = newgui.Frame -- used for tweening later
		local newtxt = newframe.TextLabel -- username label

		newgui.Parent = v.PlayerGui -- move the gui to their playergui so they can see it

		table.insert(guis,newgui) -- mark it for later so we can delete it when overlapping pictures

		local sfx = Instance.new("Sound",newgui) -- sound effects ofc!!
		sfx.SoundId = "rbxassetid://8550763922" -- sound id
		sfx.Volume = 2 -- volume 4x than normal bc it started quiet

		sfx:Play() -- play it


		game:GetService("Debris"):AddItem(newgui,6) -- delete it after 6 seconds bc 5+1 = 6
		task.delay(5,function() -- delay a function 5 seconds
			-- tween it to slide away
			game:GetService("TweenService"):Create(newframe,TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.InOut,0,false,0),{Position = UDim2.new(1,0,1.25,0)}):Play()
		end)
	end
	gui:Destroy() -- ensure no lag
	snap = "" -- reset the text so we aren't getting repeated texts
end)
