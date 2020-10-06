--[[

v1.0
-Proof of concept; rough implementation of "smart" elevator code.
-Considers direction of travel, uses two queues for up and down.
-Stops at floors along the way if they're also in the queue.
e.g. If the current floor is 2 and floors 1, 4, 3 are called in that order, the sequence of visits will be 1->3->4.

]]

local active = false
local opened = false

local dir = 0 -- direction of travel: 0 for standstill, 1 for up, 2 for down
local curr = "TWOR" -- current floor

local floors = {"L", "TWOR", "TWO", "THREE"}  -- FLOOR NAMES FROM BOTTOM TO TOP

local order = {   -- ORDER OF FLOORS (0 for lowest floor, 1 for second-lowest floor, ..., nth for highest floor)
	L = 0,
	TWOR = 1,
	TWO = 2,
	THREE = 3
}

local dict = {  -- WHICH CHAMBER DOOR TO OPEN FOR EACH FLOOR (elevator chamber has two doors, one on the left and one on the right)
	L = "doorR",
	TWO = "doorL",
	TWOR = "doorR",
	THREE = "doorL"
}

local upqueue = {}
local downqueue = {}

-- GAME SERVICES
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- CORE

-- move elevator to specified floor
function goto(floor)
	if (curr == floor) then
		open(floor)
		return
	end
	
	active = true
	
	setChamberClick(0)
	local y1 = script.Parent:FindFirstChild(curr).Position.Y
	local y2 = script.Parent:FindFirstChild(floor).Position.Y
	
	local eleTime = math.abs(y1-y2)/3 -- speed
	
	local sound = script.Parent.chamber.core.Motor
	sound.TimePosition = 0
	sound:Play()
	wait(.5)
	
	local CFv = Instance.new("CFrameValue")
	CFv.Value = script.Parent.chamber:GetPrimaryPartCFrame()
	local dest = script.Parent:FindFirstChild(floor).CFrame
	local tween = TweenService:Create(CFv, TweenInfo.new(eleTime,Enum.EasingStyle.Sine), {Value = dest})
	tween:Play()
	local moving = true
	curr = floor
	
	local conn = RunService.Heartbeat:Connect(function()
		script.Parent.chamber:SetPrimaryPartCFrame(CFv.Value)
	end)
	
	tween.Completed:Connect(function()
		conn:Disconnect()
		moving = false
		sound.TimePosition = 5
		sound:Play()
		wait(1.5)
		setChamberClick(10)
		open(floor)
	end)
	
	wait(1.5)
	while moving do
		sound.TimePosition = 1.5
		sound:Play()
		wait(1.5)
	end
end

-- open elevator doors corresponding to specified floor
function open(floor)
	opened = true
	active = true
	local eleDoor = script.Parent.chamber:FindFirstChild(dict[floor])
	local floDoor = script.Parent.ele:FindFirstChild(floor).door
	
	local eleCF = Instance.new("CFrameValue")
	eleCF.Value = eleDoor.CFrame
	
	local floCF = Instance.new("CFrameValue")
	floCF.Value = floDoor.CFrame
	
	local eleDest = eleDoor.CFrame * CFrame.new(0,0,4.81)
	local floDest = floDoor.CFrame * CFrame.new(0,0,4.81)
	
	local eleTween = TweenService:Create(eleCF, TweenInfo.new(2.5,Enum.EasingStyle.Sine), {Value = eleDest})
	local floTween = TweenService:Create(floCF, TweenInfo.new(2.5,Enum.EasingStyle.Sine), {Value = floDest})
	eleTween:Play()
	floTween:Play()
	eleDoor.Ding.TimePosition = 0.2
	eleDoor.Ding:Play()
	eleDoor.Motor:Play()
	
	resetLights(floor)
	
	-- lights
	if dir ~= 0 then
		local light
		if dir == 1 then
			light = script.Parent.ele:FindFirstChild(floor).indicator:FindFirstChild("up")
		else 
			light = script.Parent.ele:FindFirstChild(floor).indicator:FindFirstChild("down")
		end
		if light then
			turnOn(light)
		end
	end
	
	-- core
	local conn = RunService.Heartbeat:Connect(function()
		eleDoor.CFrame = eleCF.Value
		floDoor.CFrame = floCF.Value
		print("Heartbeat -- Open")
	end)
	
	eleTween.Completed:Connect(function()
		conn:Disconnect()
		print("OPENED!")
		eleDoor.Motor:Stop()
		close(floor)
	end)
end

-- close elevator doors corresponding to specified floor
function close(floor)
	local closing = false
	active = true
	wait(5)
	closing = true
	
	local eleDoor = script.Parent.chamber:FindFirstChild(dict[floor])
	local floDoor = script.Parent.ele:FindFirstChild(floor).door
	
	local eleInit = eleDoor.CFrame
	local floInit = floDoor.CFrame
	
	local eleCF = Instance.new("CFrameValue")
	eleCF.Value = eleInit
	
	local floCF = Instance.new("CFrameValue")
	floCF.Value = floInit
	
	local eleDest = eleDoor.CFrame * CFrame.new(0,0,-4.81)
	local floDest = floDoor.CFrame * CFrame.new(0,0,-4.81)
	
	local eleTween = TweenService:Create(eleCF, TweenInfo.new(2.5,Enum.EasingStyle.Sine), {Value = eleDest}) -- CLOSE
	local floTween = TweenService:Create(floCF, TweenInfo.new(2.5,Enum.EasingStyle.Sine), {Value = floDest}) -- CLOSE
	
	local eleTweenOpen = TweenService:Create(eleCF, TweenInfo.new(2.5,Enum.EasingStyle.Sine), {Value = eleInit}) -- CLOSE
	local floTweenOpen = TweenService:Create(floCF, TweenInfo.new(2.5,Enum.EasingStyle.Sine), {Value = floInit}) -- CLOSE
	eleTween:Play()
	floTween:Play()
	eleDoor.Motor:Play()
	
	local conn = RunService.Heartbeat:Connect(function()
		eleDoor.CFrame = eleCF.Value
		floDoor.CFrame = floCF.Value
		print("Heartbeat -- Close")
	end)
	
	local touch
	local openbutton
	openbutton = script.Parent.chamber.open.ClickDetector.MouseClick:Connect(function()
		if closing then
			closing = false
			eleTweenOpen:Play()
			floTweenOpen:Play()
			openbutton:Disconnect()
			touch:Disconnect()
			wait(2.5)
			eleDoor.Motor:Stop()
			conn:Disconnect()
			close(floor)
		end
	end)
	
	-- if elevator door is touched while closing, open doors
	touch = eleDoor.Touched:Connect(function()
		if closing then
			closing = false
			eleTweenOpen:Play()
			floTweenOpen:Play()
			touch:Disconnect()
			openbutton:Disconnect()
			wait(2.5)
			eleDoor.Motor:Stop()
			conn:Disconnect()
			close(floor)
		end
	end)
	
	-- finish
	local closed
	closed = eleTween.Completed:Connect(function(t)
		if t == Enum.PlaybackState.Completed then
			eleDoor.Motor:Stop()
			conn:Disconnect()
			print("CLOSED!")
			touch:Disconnect()
			openbutton:Disconnect()
			closed:Disconnect()
			--wait(2)
			print("READY")
			opened = false
			active = false
			
			-- turn off indicator if active
			if dir ~= 0 then
				local light
				if dir == 1 then
					light = script.Parent.ele:FindFirstChild(floor).indicator:FindFirstChild("up")
				else 
					light = script.Parent.ele:FindFirstChild(floor).indicator:FindFirstChild("down")
				end
				if light then
					turnOff(light)
				end
			end
			
			nextFloor()
		end
	end)
end

-- decide next best destination by taking into consideration the
-- current direction of travel and what is contained in the queue
function nextFloor()
	print("Called!")
	if not opened and not active then
		
		-- don't do anything if queues are empty
		if #upqueue == 0 and #downqueue == 0 then
			dir = 0
			print("elevator inactive, direction reset")
			return
		end
		
		
		if dir == 0 then   -- elevator standstill
			local dest
			
			if #upqueue ~= 0 then
				dest = upqueue[1]
				dir = 1
				table.remove(upqueue, 1)
			elseif #downqueue ~= 0 then
				dest = downqueue[1]
				dir = 2
				table.remove(downqueue, 1)
			else
				return
			end
			
			goto(dest)
			
		elseif dir == 1 then   -- preferred direction up
			
			local dest
			local q
			
			-- grab next destination from upqueue, otherwise recall function with direction down
			if #upqueue ~= 0 then
				dest = upqueue[1]
				dir = 1
				q = upqueue
			elseif #downqueue ~= 0 then
				dir = 2
				nextFloor()
				return
			else
				return
			end
			
			-- check if upqueue contains a floor in-between the current and the destination floor
			-- if so, go to that floor first
			for i = order[curr] + 1, order[dest] - 1 do
				if table.find(upqueue, floors[i+1]) then
					table.remove(upqueue, table.find(upqueue, floors[i+1]))
					goto(floors[i+1])
					dir = 1
					return
				end 
			end
			
			-- if destination is the highest possible floor, set preferred direction to down so that
			-- the next call will grab the next destination from downqueue, if any.
			-- else continue
			if order[dest] == #floors - 1 then
				goto(dest)
				table.remove(q, 1)
				dir = 2
				return
			else
				goto(dest)
				table.remove(q, 1)
			end
			
		elseif dir == 2 then   -- preferred direction down
			
			local dest
			local q
			
			-- grab next destination from downqueue, otherwise recall function with direction up
			if #downqueue ~= 0 then
				dest = downqueue[1]
				dir = 2
				q = downqueue
			elseif #upqueue ~= 0 then
				dir = 1
				nextFloor()
				return
			else
				return
			end
			
			-- check if downqueue contains a floor in-between the current and the destination floor
			-- if so, go to that floor first
			for i = order[curr] - 1, order[dest] + 1, -1 do
				if table.find(downqueue, floors[i + 1]) then
					table.remove(downqueue, table.find(downqueue, floors[i+1]))
					goto(floors[i+1])
					dir = 2
					return
				end 
			end
			
			-- if destination is the lowest possible floor, set preferred direction to up so that
			-- the next call will grab the next destination from upqueue, if any.
			-- else continue
			if order[dest] == 0 then
				goto(dest)
				table.remove(q, 1)
				dir = 1
				return
			else
				goto(dest)
				table.remove(q, 1)
			end
		end
	else
		print("Can't decide now")
	end
end

-- HELPERS

-- set chamber click detector distance
function setChamberClick(dist) 
	local chamber = script.Parent.chamber
	for i = 1, #floors do
		chamber:FindFirstChild(floors[i]).ClickDetector.MaxActivationDistance = dist
	end
	chamber.open.ClickDetector.MaxActivationDistance = dist
	chamber:FindFirstChild("close (does nothing)").ClickDetector.MaxActivationDistance = dist
end

-- turns off respective buttons to a floor
function resetLights(floor)
	local dyn = script.Parent.ele:FindFirstChild(floor):FindFirstChild("buttons")
	local chamber = script.Parent.chamber:FindFirstChild(floor)
	
	if #(dyn:GetChildren()) == 1 then
		turnOff(dyn:GetChildren()[1])
	else
		if dir == 1 then
			turnOff(dyn:FindFirstChild("up" .. floor))
		elseif dir == 2 then
			turnOff(dyn:FindFirstChild("down" .. floor))	
		end	
	end
	
	if chamber then
		turnOff(chamber)
	end
end

-- inserts floor into queue then calls nextFloor()
function insert(q, f)
	if not table.find(q, f) then
		table.insert(q, f)
		print("Inserted " .. f .. " to " .. tostring(q))
		nextFloor()
	else 
		print(f .. " already exists in queue!")
	end
end

-- open doors if valid (for open doors button)
function attempt_open()
	if not active and not opened and #downqueue == 0 and #upqueue == 0 then
		open(curr)
	else 
		print("Cannot be opened")
	end
end

-- for indicator lights
function turnOn(p)
	if not p then return end
	p.BrickColor = BrickColor.new("Neon orange")
	p.Material = "Neon"
end

function turnOff(p)
	if not p then print(p .. " NOT FOUND!") return end
	p.BrickColor = BrickColor.new("Lily white")
	p.Material = "SmoothPlastic"
end

-- CALL BUTTONS
script.Parent.ele.L.buttons.upL.ClickDetector.MouseClick:Connect(function()
	local x = "L"

	if curr == x and opened then return end	
	
	turnOn(script.Parent.ele.L.buttons.upL)
	insert(downqueue, x)
end)

script.Parent.ele.TWO.buttons.upTWO.ClickDetector.MouseClick:Connect(function()
	local x = "TWO"

	if curr == x and opened and dir == 1 then return end
	
	turnOn(script.Parent.ele.TWO.buttons.upTWO)
	insert(upqueue, x)
end)

script.Parent.ele.TWO.buttons.downTWO.ClickDetector.MouseClick:Connect(function()
	local x = "TWO"

	if curr == x and opened and dir == 2 then return end
	
	turnOn(script.Parent.ele.TWO.buttons.downTWO)
	insert(downqueue, x)
end)


script.Parent.ele.TWOR.buttons.upTWOR.ClickDetector.MouseClick:Connect(function()
	local x = "TWOR"

	if curr == x and opened and dir == 1 then return end
	
	turnOn(script.Parent.ele.TWOR.buttons.upTWOR)
	insert(upqueue, x)
end)

script.Parent.ele.TWOR.buttons.downTWOR.ClickDetector.MouseClick:Connect(function()
	local x = "TWOR"

	if curr == x and opened and dir == 2 then return end
	
	turnOn(script.Parent.ele.TWOR.buttons.downTWOR)
	insert(downqueue, x)
end)

script.Parent.ele.THREE.buttons.downTHREE.ClickDetector.MouseClick:Connect(function()
	local x = "THREE"
	
	if curr == x and opened then return end
	
	turnOn(script.Parent.ele.THREE.buttons.downTHREE)
	insert(upqueue, x)
end)

-- CHAMBER BUTTONS
script.Parent.chamber.THREE.ClickDetector.MouseClick:Connect(function()
	local x = "THREE"
	
	if curr == x and opened then return end
	
	turnOn(script.Parent.chamber:FindFirstChild(x))
	if order[x] == order[curr] then
		attempt_open()
	elseif order[x] < order[curr] then  
		insert(downqueue, x)
	else	
		insert(upqueue, x)
	end
end)

script.Parent.chamber.TWO.ClickDetector.MouseClick:Connect(function()
	local x = "TWO"

	if curr == x and opened then return end
	
	turnOn(script.Parent.chamber:FindFirstChild(x))
	if order[x] == order[curr] then
		attempt_open()
	elseif order[x] < order[curr] then  
		insert(downqueue, x)
	else	
		insert(upqueue, x)
	end
end)

script.Parent.chamber.TWOR.ClickDetector.MouseClick:Connect(function()
	local x = "TWOR"

	if curr == x and opened then return end
	
	turnOn(script.Parent.chamber:FindFirstChild(x))
	if order[x] == order[curr] then
		attempt_open()
	elseif order[x] < order[curr] then  
		insert(downqueue, x)
	else	
		insert(upqueue, x)
	end
end)

script.Parent.chamber.L.ClickDetector.MouseClick:Connect(function()
	local x = "L"

	if curr == x and opened then return end
	
	turnOn(script.Parent.chamber:FindFirstChild(x))
	if order[x] == order[curr] then
		attempt_open()
	elseif order[x] < order[curr] then  
		insert(downqueue, x)
	else
		insert(upqueue, x)
	end
end)

script.Parent.chamber.open.ClickDetector.MouseClick:Connect(function()
	attempt_open()
end)