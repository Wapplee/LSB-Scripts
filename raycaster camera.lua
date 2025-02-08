-- place script in starterpack

-- this is an advanced raycasting script, which has many things such as:

---- Post Processing: ----
-- Noise
-- Gamma
-- Desaturation
-- Tint

---- Realism ----
-- Shadows
-- Reflections
-- Perspectives

---- Changable Settings ----
-- X/Y Resolutions
-- Monitor X/Y Sizes
-- FOV
-- Countdown Timer
-- Sky Color
-- Depth Discoloration
-- Default Reflectance

-- (and debug?)
-- also i did not add all of this comment to make the lines more im just explaining what the camera can do and why it is advanced

local config config = {
	-- Size
	xRes = 200,
	yRes = 100,

	MonitorX = 8, -- Recommended to follow the same ratio as the X and Y res
	MonitorY = 4,

	FOV = 50, -- 70 is normal roblox fov
	CountdownTimer = 3, -- time before it starts scanning so you can move infront of the camera ig

	-- Toggles
	Shadows = true,
	Reflections = true,
	Perspective = true,
	PostProcessing = true,

	-- Camera Settings
	DefaultReflectance = .02, -- how much each ray will reflect the next object.
	MaxDepthDistance = 350, -- how much depth will give the most perspective
	DepthDiscoloration = .7, -- how much darker it will get at the max depth distance
	SkyColor = Color3.fromRGB(0,188,225), -- cerulean blue
	CameraPOV = true, -- if false will cast from the player's pov to the screen instead of from the screen to a plane
	GetCastShadow = true, -- if true then it will not cast shadows from objects with CastShadow off.

	-- Post Processing
	Noise = .03, -- randomness in the pixel colors
	Gamma = 1.1, -- higher = more vivid, lower than 1 = darker
	Desaturation = 0, -- more black and white the higher
	Tint = Color3.new(0.815686, 0.792157, 0.529412), -- Tint color
	TintAmount = 0, -- Tint Percentage

	-- Extra
	Debug = false, -- black lines = rays, blue dots = screen positions. VERY LAGGY THOUGH
}


local owner = game:GetService("Players").LocalPlayer

local tool = Instance.new("Tool",owner.Backpack)
tool.Name = "Advanced Raycaster"
tool.ToolTip = "Click to raycast a picture!"

local handle = Instance.new("Part",tool)
handle.Name = "Handle"
handle.Size = Vector3.one
handle.Material = "Neon"
handle.Color = Color3.new(0,0,0)

-- both below ensure that the screen has a center point not inbetween 4 pixels
if config.xRes%2 == 0 then
	config.xRes+=1
end
if config.yRes%2 == 0 then
	config.yRes+=1
end

local lighting = game:GetService("Lighting") -- for sun direction (shadows) later.
local rng = Random.new()

function multiplyRGB(color,multR,multG,multB)
	return Color3.new(
		color.R*multR,
		color.G*(multG or multR),
		color.B*(multB or multG or multR)
	)
	-- this weird looking line makes it so multiplyRGB(color,2) will multiply every one but if you specify the rgb then it will multiply every one
end

local function Raycast(origin,direction,params) -- hook onto all of them so we can debug all rays
	if config.Debug then
		local part = Instance.new("Part",workspace) -- the part that displays the ray
		part.Transparency = .99
		part.Color = Color3.new(0,0,0)
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CFrame = CFrame.new(origin,origin+direction)*CFrame.new(0,0,-1024)
		part.Size = Vector3.new(.1,.1,2048)
		part.Anchored = true
	end
	return workspace:Raycast(origin,direction,params)
end

tool.Activated:Connect(function()
	local raydata = {} -- the ray data for each pixel ig?
	
	local ignoreShadows = {tool} -- table for ignoring the shadows of objects later on
	
	local point = handle.CFrame*CFrame.new(0,.7,-3)

	local screen = Instance.new("Part",workspace) -- the screen we need to make to display the actual pixels
	screen.Anchored = true
	screen.CanCollide = false
	screen.CanTouch = false
	screen.Name = "Raycast Result"
	screen.CanQuery = false
	screen.Size = Vector3.zAxis*.1+Vector3.new(config.MonitorX,config.MonitorY,0) -- aspect ratio
	screen.Transparency = .6
	screen.Material = "Neon"
	screen.Color = Color3.new(.2,.2,.2)
	screen.CFrame = point

	local surface = Instance.new("SurfaceGui",screen)
	surface.Face = "Back"

	local pixels = Instance.new("Folder",surface)
	pixels.Name = "Pixels"

	local text = Instance.new("TextLabel",surface)
	text.Size = UDim2.new(1,0,1,0)
	text.TextScaled = true
	text.TextStrokeTransparency = 0
	text.TextColor3 = Color3.new(1,1,1)
	text.Font = Enum.Font.RobotoMono
	text.ZIndex = 10
	text.BackgroundTransparency = 1
	text.Name = "Text"
	
	if config.GetCastShadow and config.Shadows then -- we check every part for castshadow off if getcastshadow is on and if castshadow is off then we ignore it in the shadow ray
		text.Text = "Getting shadows..."

		for _,v in pairs(workspace:GetDescendants()) do
			if v:IsA("BasePart") then
				if not v.CastShadow then
					table.insert(ignoreShadows,v)
				end
			end
		end
	end
	local ignoreShadowsParams = RaycastParams.new()
	ignoreShadowsParams.FilterDescendantsInstances = ignoreShadows

	local padding = Instance.new("UIPadding",text)
	padding.PaddingBottom = UDim.new(.8,0)

	local param = RaycastParams.new()
	param.FilterDescendantsInstances = {tool} -- make sure we cant see the tool accidentally

	if config.CountdownTimer ~= 0 and tonumber(config.CountdownTimer) then -- time before it starts casting.
		for i = config.CountdownTimer,1,-1 do
			text.Text = i.."..."
			task.wait(1)
		end
	end

	text.Text = "Casting..."

	for x = 1,config.xRes do
		for y = 1,config.yRes do
			local shiftX = x-math.floor(config.xRes/2) -- shift X/Y to be centered in the middle. e.g 1-100 -> -50-50
			local shiftY = y-math.floor(config.yRes/2) -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

			if not raydata[x] then
				raydata[x] = {} -- add the table since it isn't already made
			end
			
			local pos,cf
			if config.CameraPOV then -- settings either POV from screen or from player camera
				pos = point*CFrame.new(shiftX/config.yRes*2,-shiftY/config.yRes*2,-1/math.tan(math.rad(config.FOV)/2)) -- (EXPLAINED BELOW) project all points onto a flat plane to remove fisheye effect
				-- https://gamedev.stackexchange.com/questions/156842

				-- we can divide it by 2 in order to get the right triangle of the fov since it is already left and right directions and put it into...
				-- tan to get the distance in a "fraction" form so we use 1/(that tan) to get the real distance and then we use that.

				-- we use only one res value because we want it to fit the shape of the shiftX/shiftY values, not a square. also if we use xRes it is unequally spaced. this also ensures that it is the correct FOV horizontally.
				-- it doesn't come out as a square because shiftX is 2x the length of shiftY because of the resolution.
				-- *2 x and y value to get the real fov out of it since it was made into a right triangle earlier
				cf = CFrame.new(point.Position,pos.Position) -- turn the point on the plane into a directional cframe
			else
				pos = point*CFrame.new(config.MonitorX/config.xRes*shiftX,-config.MonitorY/config.yRes*shiftY,0)
				cf = CFrame.new(workspace.Camera.CFrame.Position,pos.Position)
			end
			
			local ray = Raycast(point.Position,(cf).LookVector*2048,param) -- actually raycast the directional cframe

			if ray then -- if it is not pointed into the sky
				local data = { -- we make this table so we can edit the color without editing the instance's color
					Color = ray.Instance.Color,
					Instance = ray.Instance,
					Ray = ray,
					Position = ray.Position,
					Material = ray.Material
				}

				if config.Shadows then
					local shadowRay = Raycast(data.Position+data.Ray.Normal*.001,lighting:GetSunDirection()*2048,ignoreShadowsParams) -- check if it is in the view of the sun
					-- we also move it in the direction of the normal a bit because otherwise the ray will go straight through the sides of objects
					if shadowRay then -- if it finds something in the sun ray then it darkens it so there is shadows
						data.Color = multiplyRGB(data.Color,.7)
					end
				end

				if config.Reflections then
					local reflect = cf.LookVector-(cf.LookVector:Dot(ray.Normal)*ray.Normal*2) -- reflect vector equation
					local bounceRay = Raycast(data.Position,reflect*2048,param) -- reflection of material
					if bounceRay then -- if it hits something on the reflection
						-- then copy a little bit of the color on the default but more color the more reflectance it has. cap it at 1 and minimum at 0.
						data.Color = data.Color:Lerp(bounceRay.Instance.Color,math.min(1,data.Instance.Reflectance+config.DefaultReflectance))
					else
						-- if it is reflecting towards the sky, give it less shadows.
						data.Color = multiplyRGB(data.Color,1+.1*data.Instance.Reflectance+config.DefaultReflectance) -- this is reflecting towards the sky then
					end
				end


				if config.Perspective then
					-- making more perspective by making it darker the farther away the ray is.
					data.Color = data.Color:Lerp(multiplyRGB(data.Color,config.DepthDiscoloration),math.clamp(ray.Distance/config.MaxDepthDistance,0,1))
				end

				raydata[x][y] = data -- store it for when we generate frames
			end

			if config.Debug then -- cast the projection in-person so we can look at it make sure nothing is wrong
				local part = Instance.new("Part",workspace) -- projection
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.CFrame = pos
				part.Size = Vector3.one*.01
				part.Anchored = true
				part.Color = Color3.new(0,0,1)
			end

		end
		task.wait() -- wait every X row to prevent lag but make it not too slow.
	end

	text.Text = "Assigning pixels to frames..."

	for x = 1,config.xRes do
		for y = 1,config.yRes do
			local data = raydata[x][y] -- find ray with x and y

			local xSize = 1/(config.xRes) -- size for each pixel on the x axis
			local ySize = 1/(config.yRes) -- above comment but for y

			local frame = Instance.new("Frame",pixels) -- make the pixel or frame
			frame.Size = UDim2.new(xSize,0,ySize,0)
			frame.Position = UDim2.new(xSize*(x-1),0,ySize*(y-1))
			frame.BorderSizePixel = 0 -- make sure it isnt ugly on the edges of each pixel

			local color = frame.BackgroundColor3
			if not data then -- that means the ray that was stored hit nothing, its the sky.
				color = config.SkyColor
			else
				color = data.Color
			end

			-- Post Processing
			if config.PostProcessing then
				-- Noise (lerp pixel color with a completely random color with a percent)
				local rng1,rng2,rng3 = rng:NextNumber(),rng:NextNumber(),rng:NextNumber()
				color = color:Lerp(Color3.new(rng1,rng2,rng3),config.Noise)

				-- Gamma (multiply all values with value)
				color = multiplyRGB(color,config.Gamma)

				-- Desaturation (grab average color of pixel and apply it to all rgb values and lerp from the og to the new color by a percent)
				local avgcolor = (color.R+color.G+color.B)/3
				color = color:Lerp(Color3.new(avgcolor,avgcolor,avgcolor),config.Desaturation)
				
				-- Tint (lerp all colors to a single color by an amount)
				color = color:Lerp(config.Tint,config.TintAmount)
			end
			-- End of post processing
			frame.BackgroundColor3 = color
		end
		task.wait() -- wait every x row so its not too laggy but not too slow
	end
	text:Destroy()
end)
