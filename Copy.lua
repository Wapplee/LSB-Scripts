local maxSelections = 25
local selection = 1

local parent = workspace

local scriptparent = Instance.new("Script",workspace)

for i = 1,maxSelections do
	if not owner:FindFirstChild(i) then
		local fol = Instance.new("Folder",owner)
		fol.Name = i
	end
end

local hrp
local http = game:GetService("HttpService")
local propertiesPlus = loadstring(http:GetAsync("https://dark.scriptlang.com/storage/scripts/propertyplus.lua"))()

function createsnippet(title,name,content)
	local tab = http:JSONDecode(http:PostAsync("https://glot.io/api/snippets",http:JSONEncode{language="plaintext",title=title,public=true,files={{name = name,content=content}}}))
	return tab
end -- .id
function getsnippet(id)
	return http:GetAsync("https://glot.io/snippets/"..id.."/raw",true)
end

local serializesource = loadstring(http:GetAsync("https://gitea.com/Wapplee/Modules/raw/branch/main/Serializer.lua"))()
local serialize = serializesource.Serialize
local deserialize = serializesource.Deserialize

function getSelection()
	return owner[tostring(selection)]
end

function fix()
	hrp = owner.Character
	if not hrp then hrp = owner.CharacterAdded:wait() end
	hrp = hrp:WaitForChild("HumanoidRootPart")
end
fix()


local spawned = {}

function isEditable(obj)
	return ({pcall(function()obj.Archivable = true end)})[1]
end

function save(sel,obj)
	fix()
	if isEditable(obj) then
		sel:ClearAllChildren()

		local root = hrp:Clone()
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false

		local model = Instance.new("Model",sel)
		model.Name = "Object"

		local copymodel = Instance.new("Model",model)
		copymodel.Name = "Copied"

		obj:Clone().Parent = copymodel

		root.Parent = model
		model.PrimaryPart = root
		return true
	end
	return false
end

function load(sel)
	fix()
	if sel:GetChildren()[1] then
		local obj = sel:GetChildren()[1]
		if not obj or not obj.Parent then return false end

		obj:SetPrimaryPartCFrame(hrp.CFrame)

		obj = obj.Copied:GetChildren()[1]:Clone()

		obj.Parent = parent
		table.insert(spawned,obj)
		return obj
	end
	return false
end

local gui = Instance.new("ScreenGui",owner.PlayerGui)
gui.ResetOnSpawn = false

local rem = Instance.new("RemoteFunction",gui)

local utilsnum = 1

local utils = {
	{"Anchor",
		function(a,b,c)
			if not isEditable(b) then return print("Cannot anchor.")end
			local anchored = false
			for _,v in pairs({b,unpack(b:GetDescendants())}) do
				if v:IsA("BasePart") and v.Anchored == true then
					anchored = true
					break
				end
			end
			for _,v in pairs({b,unpack(b:GetDescendants())}) do
				if v:IsA("BasePart") then
					v.Anchored = not anchored
				end
			end	
			print("Anchor on model: \""..b.Name.."\" is "..tostring(not anchored))
		end,
	},
	{"Lock",
		function(a,b,c)
			if not isEditable(b) then return print("Cannot lock.")end
			local locked = false
			for _,v in pairs({b,unpack(b:GetDescendants())}) do
				if v:IsA("BasePart") and v.Locked == true then
					locked = true
					break
				end
			end
			for _,v in pairs({b,unpack(b:GetDescendants())}) do
				if v:IsA("BasePart") then
					v.Locked = not locked
				end
			end	
			print("Locked on model: \""..b.Name.."\" is "..tostring(not locked))
		end,
	},
	{"Delete",
		function(a,b,c)
			if isEditable(b) then
				print("Deleted: "..b.Name)
				pcall(function()
					b:Destroy()
				end)
			else
				print("Cannot delete.")
			end
		end,
	},
	{"Clear",
		function(a,b,c)
			for _,v in pairs(spawned) do
				pcall(function()
					v:Destroy()
				end)
			end
			spawned = {}

			print("Cleared successfully!")
		end,
	},
	{"Parent",
		function(a,b,c)
			if parent == workspace then
				parent = scriptparent
			else
				parent = workspace
			end
			print("Parent is now "..parent.ClassName)
		end,
	},
	{"Anti-Clear",
		function(a,b,c)
			if isEditable(b) then
				if b.ClassName == "Script" then
					local md = {Name = "Server script."}
					for _,v in pairs(b:GetChildren()) do
						v.Parent = b.Parent
						md = v
					end
					b:Destroy()
					print("Un-Anti cleared: "..md.Name)
				else
					pcall(function()
						b.Parent = Instance.new("Script",workspace)
					end)
					print("Anti cleared: "..b.Name)
				end
			else
				print("Cannot anti-clear.")
			end
		end,
	},

}

function getutil()
	return "Selected Util: "..utils[utilsnum][1]
end

local dss = game:GetService("DataStoreService")
local ds = dss:GetDataStore("SerializedModelsWapplee1ScriptsSaved4")

function SerializedData(a)
	if a then
		return pcall(function()
			ds:SetAsync("MAIN",http:JSONEncode(a))
		end)
	else
		return http:JSONDecode(ds:GetAsync("MAIN") or {})
	end
end
function istool()
	return owner.Character:FindFirstChildOfClass'Tool'
end
rem.OnServerInvoke = function(plr,ty,a,b,c)
	if plr ~= owner then return end
	if ty == "Data" then
		print("\n"..[[C / X / V : Copy, Cut, and Paste.
B / N : Selection Choose
[ / ] : Choose Util
P : Enter Toolify Mode
; : Enter Modelify Mode
, : Enter Serialize Mode
Enter : Use Util
Selections save when re-running script.]])
		do
			local list = ""
			for _,v in pairs(utils) do
				list = list..v[1]..","
			end
			print("Utils: "..list:sub(1,#list-1))
		end
		print(getutil())
		return script,gui
	elseif ty == "Deserialize" then
		print("Deserializing...")
		local data = SerializedData()
		if data[a.Location] then
			if data[a.Location][a.Name] then
				table.insert(spawned,deserialize(getsnippet(data[a.Location][a.Name]),parent))
				print("Successfully Deserialized!")
			else
				print("Cannot find name: "..a.Name)
			end
		else
			print("Cannot find location: "..a.Location)
		end
		return
	elseif ty == "ListSerialized" then
		local data = SerializedData()
		if data[a.Location] then
			local total = 0
			for _ in pairs(data[a.Location]) do
				total = total + 1
			end
			print("----"..a.Location.." ("..total..")")
			for i in pairs(data[a.Location]) do
				print(i)
			end
		else
			print("Cannot find location: "..a.Location)
		end
		return
	elseif ty == "DeleteSerialized" then
		local data = SerializedData()
		if data[a.Location] then
			if data[a.Location][a.Name] then
				data[a.Location][a.Name] = nil

				SerializedData(data)
				print("Successfully Deleted!")
			else
				print("Cannot find name: "..a.Name)
			end
		else
			print("Cannot find location: "..a.Location)
		end
		return
	elseif ty == "GetSourceSerialized" then
		local data = SerializedData()
		if data[a.Location] then
			if data[a.Location][a.Name] then
				print("/"..a.Location.."/"..a.Name..": "..data[a.Location][a.Name])
			else
				print("Cannot find name: "..a.Name)
			end
		else
			print("Cannot find location: "..a.Location)
		end
		return
	elseif ty == "ListSerializedLocations" then
		local data = SerializedData()
		for i,v in pairs(data) do
			print(i)
		end
		return
	end
	if istool() then return end
	if ty == "Back" then
		selection = selection - 1
		if selection == 0 then
			selection = maxSelections
		end
		print("Selection #"..selection)
		return
	elseif ty == "Next" then
		selection = selection + 1
		if selection == maxSelections+1 then
			selection = 1
		end
		print("Selection #"..selection)
		return
	elseif ty == "UBack" then
		utilsnum = utilsnum - 1
		if utilsnum == 0 then
			utilsnum = #utils
		end
		print(getutil())
		return
	elseif ty == "UNext" then
		utilsnum = utilsnum + 1
		if utilsnum == #utils+1 then
			utilsnum = 1 
		end
		print(getutil())
		return
	elseif ty == "URun" then
		utils[utilsnum][2](a,b,c)
		return
	elseif ty == "Toolify" then
		-- a = model, b = handle, c = grip
		if isEditable(a) then
			a:BreakJoints()

			local tool = Instance.new("Tool",owner.Backpack)
			tool.Name = a.Name

			tool.Grip = c

			local model = Instance.new("Model")
			model.Parent = tool

			a.Parent = model

			local handle = b:Clone()
			handle.Parent = tool
			handle:ClearAllChildren()
			handle.Transparency = 1
			handle.Name = "Handle"

			handle.CustomPhysicalProperties = PhysicalProperties.new(100,1,0)

			for _,obj in pairs(tool:GetDescendants()) do
				if obj:IsA("BasePart") then
					obj.Anchored = false
					obj.Massless = true

					if handle ~= obj then
						local weld = Instance.new("Weld",handle)
						weld.Name = obj.Name

						weld.C0 = handle.CFrame:Inverse()*obj.CFrame

						weld.Part0 = handle
						weld.Part1 = obj
					end
				elseif obj:IsA("Humanoid") then
					obj.PlatformStand = true
				end
			end
			tool.Activated:Connect(function()
				local str = Instance.new("StringValue",tool)
				str.Name = "toolanim"
				str.Value = "Slash"
			end)
		end
		return
	elseif ty == "Modelify" then
		local new = Instance.new("Model",a[1].Parent)
		new.Name = a[1].Name
		for _,v in pairs(a) do
			v.Parent = new
		end
		new.PrimaryPart = a[1]
		return
	elseif ty == "Serialize" then
		print("Serializing...")

		a.Archivable = true
		local copy = a:Clone()

		local code = serialize(copy)
		copy:Destroy()

		local glotid = createsnippet(b.Name,"SerializedCode",code).id

		local data = SerializedData()
		-- b.Location,b.Name
		if not data[b.Location] then
			data[b.Location] = {}
		end

		data[b.Location][b.Name] = glotid

		local success,why = SerializedData(data)

		if success then
			print("Successfully Serialized: "..b.Location..":"..b.Name)
		else
			print("Error saving: "..why)
		end
		return
	elseif ty == "Copy" then
		if save(getSelection(),a) then
			print("Saved: "..a.Name)
		else
			print("Cannot copy this object!")
		end
		return
	elseif ty == "Paste" then
		local loaded = load(getSelection())
		if loaded then
			print("Loaded: "..loaded.Name)
		else
			print("Loading error! Have you saved anything?")
		end
		return
	elseif ty == "Cut" then
		if save(getSelection(),a) then
			print("Cut: "..a.Name)

			a:Destroy()
		else
			print("Cannot cut this object!")
		end
		return
	end
	print(ty,a,b,c)

	return true
end

script.Parent = rem
NLS([[
local rem = script.Parent
local ms = owner:GetMouse()

local ss,gui = rem:InvokeServer("Data")

function getParent(obj)
	if not obj or not obj:FindFirstAncestorOfClass('DataModel') then return obj end
	repeat 
		if obj.Parent == workspace or obj.Parent:IsA("LuaSourceContainer") then break end
		obj = obj.Parent
	until false
	return obj
end
function getGrabbable(v)
	if not v or not v:FindFirstAncestorOfClass('DataModel') then return end
	local folder,model = v:FindFirstAncestorOfClass("Folder"),v:FindFirstAncestorOfClass("Model")
	local best = model or folder or getParent(v)
	if model and folder then
		if #folder:GetFullName() > #model:GetFullName() then
			best = folder
		else
			best = model
		end
	end
	return best
end
local cam = workspace.CurrentCamera

local toolify = false
local modelify = false
local serialize = false

local toolifycf = CFrame.new()
local toolifyobj = nil

local modelifyobj = {}

local serializeobj = nil
local serializeinfo = {}

local vp = Instance.new("ViewportFrame",gui)
vp.Size = UDim2.new(1,0,1,0)
vp.BackgroundTransparency = 1
vp.CurrentCamera = cam

local toolarm = Instance.new("Part",vp)
toolarm.Size = Vector3.new(1,2,1)

local mesh = Instance.new("SpecialMesh",toolarm)
mesh.MeshId = "rbxassetid://82908019"
mesh.Scale = Vector3.one*1.05
mesh.Offset = Vector3.new(.05,.1,0)

local rothandle = Instance.new("ArcHandles",gui)
local poshandle = Instance.new("Handles",gui)
local boxhandle = Instance.new("SelectionBox",gui)
boxhandle.LineThickness = .01

local boxhandles = {Instance.new("SelectionBox",gui),Instance.new("SelectionBox",gui)}
local addedhandles = {}

boxhandles[1].LineThickness = .02
boxhandles[2].LineThickness = .01
boxhandles[1].Color3 = Color3.new(0,1,.5)
boxhandles[2].Color3 = Color3.new(0,1,.7)

local serializehandle = Instance.new("SelectionBox",gui)
serializehandle.LineThickness = .04
serializehandle.Color3 = Color3.new(.5,.8,.7)

local handles = {rothandle,poshandle}

poshandle.Color3 = Color3.new(1,.7,0)
poshandle.Style = Enum.HandlesStyle.Resize

local selhandle = poshandle
local tooladdcframe = CFrame.new()

local previouscf = tooladdcframe

function exitModelify()
	modelifyobj = {}
	modelify = false
	for _,v in pairs(addedhandles) do
		v:Destroy()
	end
	addedhandles = {}
end
function exitToolify()
	toolifyobj = nil
	toolifycf = CFrame.new()
	toolify = false
end
function exitSerialize()
	serialize = false
	serializeobj = nil
end
exitModelify()
exitToolify()
exitSerialize()

owner.Chatted:Connect(function(c)
	if c:sub(1,3) == "/e " then
		c = c:sub(4)
	end
	if c:sub(1,1) == "/" then
		if c == "/" then
			rem:InvokeServer("ListSerializedLocations")
			return
		end
		local isDelete = false
		if c:sub(2,2) == "/" then
			isDelete = true
			c = c:sub(2)
		end
		if c:sub(2,2) == "/" then
			isSource = true
			c = c:sub(2)
			isDelete = false
		end
		local split = (c:sub(2)):split("/")	
		
		local tab = {Name = split[2],Location=split[1]}
		if tab.Location == "self" then
			tab.Location = owner.Name
		end
		
		if isDelete then
			rem:InvokeServer("DeleteSerialized",tab)
		elseif isSource then
			rem:InvokeServer("GetSourceSerialized",tab)
		else
			if tab.Name then
				if serializeobj then			
					rem:InvokeServer("Serialize",serializeobj,tab)
				else		
					rem:InvokeServer("Deserialize",tab)
				end
			else
				rem:InvokeServer("ListSerialized",tab)
			end
		end
	end
end)

ms.KeyDown:Connect(function(k)
	if k == "p" then
		if not toolifyobj then
			toolify = not toolify
		else		
			local best = getGrabbable(toolifyobj)
			
			rem:InvokeServer("Toolify",best,toolifyobj,(toolifycf*CFrame.new(0,-1.1,0))*tooladdcframe*CFrame.Angles(-math.pi/2,0,0))
			exitToolify()
		end
		exitSerialize()
		exitModelify()
	elseif k == ";" then
		if #modelifyobj == 0 then
			modelify = not modelify
		else
			rem:InvokeServer("Modelify",modelifyobj)
			exitModelify()
		end
		exitToolify()
		exitSerialize()
	elseif k == "," then
		serialize = not serialize
		exitModelify()
		exitToolify()
		
		if not serialize then
			exitSerialize()
		end
	end
	if not toolify and not modelify and not serialize then
		if k == "c" then
			if ms.Target then
				rem:InvokeServer("Copy",getParent(ms.Target))
			end
		elseif k == "v" then
			rem:InvokeServer("Paste")
		elseif k == "x" then
			if ms.Target then
				rem:InvokeServer("Cut",getParent(ms.Target))
			end
		elseif k == "b" then
			rem:InvokeServer("Back")
		elseif k == "n" then
			rem:InvokeServer("Next")
		elseif k == "[" then
			rem:InvokeServer("UBack")
		elseif k == "]" then
			rem:InvokeServer("UNext")
		elseif k == "\13" then
			rem:InvokeServer("URun",ms.Target,getParent(ms.Target),ms.Hit)
		end
	end
end)

ms.Button1Down:Connect(function()
	tooladdcframe = CFrame.new()
	previouscf = tooladdcframe
	selhandle = poshandle
	
	if toolify then
		if toolifyobj then
			toolifyobj = nil
			toolifycf = CFrame.new()
		else
			if ms.Target then
				toolifyobj = ms.Target
				toolifycf = toolifyobj.CFrame:Inverse()*toolarm.CFrame
			end
		end
	elseif modelify then
		if ms.Target then
			local found = table.find(modelifyobj,ms.Target)
			if found then
				table.remove(modelifyobj,found)
			else
				table.insert(modelifyobj,ms.Target)
			end
		end
	elseif serialize then
		if ms.Target and not serializeobj then
			serializeobj = getParent(ms.Target)
		else
			serializeobj = nil
		end
	end
end)

local cps = 0
function addcps()
	if cps >= 1 then
		selhandle = (selhandle==rothandle and poshandle or rothandle)
	else
		cps = cps + 1
		task.delay(.5,function()
			cps = cps - 1
		end)
	end
end
poshandle.MouseButton1Down:Connect(function()
	previouscf = tooladdcframe
	addcps()
end)
poshandle.MouseDrag:Connect(function(face,dist)
	local new = Vector3.FromNormalId(face)*dist
	
	tooladdcframe = previouscf*CFrame.new(new.X,new.Y,new.Z)
end)

rothandle.MouseButton1Down:Connect(function()
	previouscf = tooladdcframe
	addcps()
end)
rothandle.MouseDrag:Connect(function(axis,dist)
	local new = Vector3.FromAxis(axis)*dist
	
	local diff = CFrame.new(0,-toolarm.Size.Y/2,0)
	
	tooladdcframe = previouscf*diff*CFrame.Angles(new.X,new.Y,new.Z)*diff:Inverse()
end)


local handlepart = Instance.new("Part",gui)


game:GetService("RunService").RenderStepped:Connect(function()
	vp.Visible = toolify
	
	boxhandle.Color = selhandle.Color
	boxhandle.Adornee = getGrabbable(toolifyobj)
	boxhandles[1].Adornee = modelifyobj[1]
	
	serializehandle.Adornee = serializeobj
	
	local found = {}
	for i,v in pairs(addedhandles) do
		if not table.find(modelifyobj,v.Adornee) then
			v:Destroy()
			
			table.remove(addedhandles,i)
		else
			table.insert(found,v.Adornee)
		end
	end
	for _,v in pairs(modelifyobj) do
		if not table.find(found,v) then
			local new = boxhandles[2]:Clone()
			new.Parent = gui
			new.Adornee = v
			
			table.insert(addedhandles,new)
		end
	end
	
	handlepart.CFrame = toolarm.CFrame*(selhandle==rothandle and CFrame.new(0,-toolarm.Size.Y/2,0) or CFrame.new(0,0,0))
	
	if not toolifyobj then
		rothandle.Adornee = nil
		poshandle.Adornee = nil
	
		toolarm.Transparency = ms.Target and 0 or 1
		
		local rayInfo = ms.UnitRay
		
		local param = RaycastParams.new()
		param.FilterDescendantsInstances = {ss,owner.Character,gui,workspace.Terrain}
		param.FilterType = Enum.RaycastFilterType.Exclude
		param.IgnoreWater = true
		
		local ray = workspace:Raycast(rayInfo.Origin,rayInfo.Direction*100,param)
	
		if ray then
			toolarm.CFrame = CFrame.new(ray.Position,ray.Position+ray.Normal)*CFrame.Angles(-math.pi/2,math.pi,0)*CFrame.new(0,1.1,0)
		end
	else
		for _,v in pairs(handles) do
			if v ~= selhandle then
				v.Adornee = nil
			end
		end
		selhandle.Adornee = handlepart
		
		toolarm.CFrame = toolifyobj.CFrame*toolifycf*tooladdcframe
	end
end)

]],rem)




for _,v in pairs(workspace:GetDescendants()) do
	if v:IsA("BasePart") then
		if v.Size == Vector3.new(2,1,1) then
			v.Size = Vector3.new(1.8,.9,.9)
			v.Material = "Brick"
		end
	end
end
