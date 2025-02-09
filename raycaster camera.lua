-- place script in starterpack
-- made by Wapplee entirely!!
-- this is an advanced raycasting script, which below states all the features.

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

	-- Post Processing
	Noise = .03, -- randomness in the pixel colors
	Gamma = 1.1, -- higher = more vivid, lower than 1 = darker
	Desaturation = 0, -- more black and white the higher
	Tint = Color3.new(0.815686, 0.792157, 0.529412), -- Tint color
	TintAmount = 0, -- Tint Percentage

	-- Extra
	Debug = false, -- black lines = rays, blue dots = screen positions
}


local players = game:GetService("Players")
local lighting = game:GetService("Lighting") -- for sun direction (shadows) later.

local owner = players.LocalPlayer
local rng = Random.new()


local tool = Instance.new("Tool")
tool.Name = "Advanced Raycaster"
tool.ToolTip = "Click to raycast a picture!"
tool.Parent = owner.Backpack

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.one
handle.Material = "Neon"
handle.Color = Color3.new(0,0,0)
handle.Parent = tool

-- both below ensure that the screen has a center point not inbetween 4 pixels or else the script won't work well
if config.xRes%2 == 0 then
	config.xRes+=1
end
if config.yRes%2 == 0 then
	config.yRes+=1
end


local function multiplyRGB(color,multR,multG,multB)
	return Color3.new(
		color.R*multR,
		color.G*(multG or multR),
		color.B*(multB or multG or multR)
	)
	-- this weird looking line makes it so multiplyRGB(color,2) will multiply every one but if you specify the rgb then it will multiply every one
end

local oldRay = nil
local function debugPoints(point1,point2)
	local magnitude = math.max((point1.Position-point2.Position).Magnitude,.1) -- if the distance is too small we increase it a bit so that we can still see the line

	local part = Instance.new("Part")
	part.Transparency = .5
	part.Color = Color3.new(0,0,0)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CFrame = CFrame.new(point1,point2)*CFrame.new(0,0,-magnitude/2)
	part.Size = Vector3.new(.1,.1,magnitude)
	part.Anchored = true
	part.Parent = workspace

	return part
end
local function debugRay(origin,direction) -- we need this to debug any issues with the general raycasting.
	if oldRay then -- replace the old ray so there is no lag
		oldRay:Destroy()
	end

	oldRay = debugPoints(origin,origin+direction)
	return oldRay
end


local function Raycast(origin,direction,params) -- raycast with a debug thing so we don't have to debug everywhere that we cast at
	if config.Debug then
		debugRay(origin,direction)
	end
	return workspace:Raycast(origin,direction,params)
end

--we need this to show the user what it will look like and the text to display what is
--currently happening so they aren't just waiting assuming its not working when it is
local function createScreen(cframe) -- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	local screen = Instance.new("Part")
	screen.Anchored = true
	screen.CanCollide = false
	screen.CanTouch = false
	screen.Name = "Raycast Result"
	screen.CanQuery = false
	screen.Size = Vector3.zAxis*.1+Vector3.new(config.MonitorX,config.MonitorY,0) -- aspect ratio so the picture looks unstretched
	screen.Transparency = .6
	screen.Material = "Neon"
	screen.Color = Color3.new(.2,.2,.2)
	screen.CFrame = cframe
	screen.Parent = workspace

	local surface = Instance.new("SurfaceGui")
	surface.Face = "Back"
	surface.Parent = screen

	local pixels = Instance.new("Folder")
	pixels.Name = "Pixels"
	pixels.Parent = surface

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1,0,1,0)
	text.TextScaled = true
	text.TextStrokeTransparency = 0
	text.TextColor3 = Color3.new(1,1,1)
	text.Font = Enum.Font.RobotoMono
	text.ZIndex = 10
	text.BackgroundTransparency = 1
	text.Name = "Text"
	text.Parent = surface

	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(.8,0)
	padding.Parent = text
	
	return pixels,text -- only return pixels and text bc thats all we really need
end

local function shiftValues(x,max) -- shift value to the center of the max. e.g 0-101 -> -50-50
	return x-math.floor(max/2)
end

local function generatePlaneCFrame(base,x,y) -- get the origin (pos) and direction (cf) for the raycasting, this method prevents fisheye.
	local pos,cf
	if config.CameraPOV then -- settings either POV from screen or from player camera
		pos = base*CFrame.new(x/config.yRes*2,-y/config.yRes*2,-1/math.tan(math.rad(config.FOV)/2)) -- (EXPLAINED BELOW) project all points onto a flat plane to remove fisheye effect
		-- https://gamedev.stackexchange.com/questions/156842

		-- we can divide it by 2 in order to get the right triangle of the fov since it is already left and right directions and put it into...
		-- tan to get the distance in a "fraction" form so we use 1/(that tan) to get the real distance and then we use that.

		-- if we use two different res value they will be spaced differently (e.g 2 studs on x 1 stud on y) and that will cause distortion in the perspective.
		-- it doesn't come out as a square because shiftX is 2x the length of shiftY because of the resolution.
		-- *2 x and y value to get the real fov out of it since it was made into a right triangle earlier
		cf = CFrame.new(base.Position,pos.Position) -- turn the point on the plane into a directional cframe
	else
		pos = base*CFrame.new(config.MonitorX/config.xres*x,-config.MonitorY/config.yres*y,0)
		cf = CFrame.new(workspace.Camera.CFrame.Position,pos.Position)
	end
	return pos,cf
end

local function calculateDetails(ray,cf) -- input ray and position and it adds details that are not post-processing but a camera thing.
	local data = { -- we make this table so we can edit the color without editing the instance's color
		Color = ray.Instance.Color,
		Instance = ray.Instance,
		Ray = ray,
		Position = ray.Position,
		Material = ray.Material
	}

	if config.Shadows then
		local shadowRay = Raycast(data.Position+data.Ray.Normal*.001,lighting:GetSunDirection()*2048) -- check if it is in the view of the sun
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

	return data
end

local function castRays(point)
	local raydata = {}
	for x = 1,config.xRes do
		if not raydata[x] then
			raydata[x] = {} -- add the table since it isn't already made
		end
		for y = 1,config.yRes do
			local pos,cf = generatePlaneCFrame(point,
				shiftValues(x,config.xRes),
				shiftValues(y,config.yRes))

			local ray = Raycast(point.Position,(cf).LookVector*2048) -- actually raycast the directional cframe

			if ray then -- if it is not pointed into the sky
				local data = calculateDetails(ray,cf) -- calculate the details of the ray so we can output it
				
				raydata[x][y] = data -- save it for the output
			end

			if not config.Debug then continue end
			
			-- cast the projection in-person so we can look at it make sure nothing is wrong
			local debugDot = debugPoints(pos.Position,pos.Position)
			debugDot.CFrame = pos
			debugDot.Transparency = 0
			debugDot.Color = Color3.new(0,0,1)
		end
		task.wait() -- wait every X row to prevent lag but make it not too slow.
	end
	return raydata
end

local function postProcessPixel(color)
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

	return color
end

local function postProcess(raydata)
	local newdata = {}
	for x = 1,config.xRes do
		if not newdata[x] then
			newdata[x] = {}
		end
		for y = 1,config.yRes do
			local data = raydata[x][y] -- find ray with x and y
			local color = if data then data.Color else config.SkyColor -- if there is no ray color then make it the skycolor

			newdata[x][y] = postProcessPixel(color) -- process it and make it look better
		end
		task.wait() -- wait every x row so its not too laggy but not too slow
	end
	return newdata
end

local function assignPixel(x,y,xRes,yRes,color)
	local xSize = 1/(config.xRes) -- size for each pixel on the x axis
	local ySize = 1/(config.yRes) -- above comment but for y

	local frame = Instance.new("Frame") -- make the pixel or frame
	frame.Size = UDim2.new(xSize,0,ySize,0)
	frame.Position = UDim2.new(xSize*(x-1),0,ySize*(y-1))
	frame.BorderSizePixel = 0 -- make sure it isnt ugly on the edges of each pixel
	frame.BackgroundColor3 = color
	
	return frame
end

tool.Activated:Connect(function()
	local point = handle.CFrame*CFrame.new(0,.7,-3)
	local pixels,text = createScreen(point)

	if config.CountdownTimer ~= 0 and tonumber(config.CountdownTimer) then -- time before it starts casting.
		for i = config.CountdownTimer,1,-1 do
			text.Text = i.."..."
			task.wait(1)
		end
	end

	text.Text = "Casting..."

	local raydata = castRays(point) -- get pixel data

	text.Text = "Post Processing..."
	
	local colordata = postProcess(raydata) -- turn pixel data into colors
	
	text.Text = "Assigning colors to frames..."
	-- display the picture
	for xi,xv in ipairs(colordata) do
		for yi,yv in ipairs(xv) do
			local pixel = assignPixel(
				xi,yi,
				config.xRes,config.yRes,
				yv)
			pixel.Parent = pixels
		end
		task.wait() -- wait every X but not Y so its fast but not laggy
	end

	text:Destroy()
end)
