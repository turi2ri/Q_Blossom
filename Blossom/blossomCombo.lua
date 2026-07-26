require "/scripts/achievements.lua"
require "/scripts/status.lua"
require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

-- Melee primary ability
BlossomCombo = WeaponAbility:new()

function BlossomCombo:init()
	--[[
	vanityConfig = {}
	for key, value in pairs(config.getParameter("animationCustom.vanity_config")) do
		vanityConfig[key] = value
	end
	]]
	sheathConfig = {}
	for key, value in pairs(config.getParameter("animationCustom.sheath_config")) do
		sheathConfig[key] = value
	end
	
	--if config.getParameter("customCursor") == true then 
	--activeItem.setCursor("/cursors/blossomCursor0.cursor") 
	--end
	
	self.comboStep = 1
	
	self.energyUsage = self.energyUsage or 0
	
	self:computeDamageAndCooldowns()
	
	self.weapon:setStance(self.stances.idle)
	
	self.edgeTriggerTimer = 0
	self.flashTimer = 0
	self.cooldownTimer = self.cooldowns[1]
	
	self.animKeyPrefix = self.animKeyPrefix or ""
	
	self.inflictedDamage = damageListener("inflictedDamage", inflictedDamageCallback)
	--self.damageTaken = damageListener("damageTaken", damageTakenCallback)
	firstUpdate = true
	idleParticleTimer = 1
	--charges = 0
	--blossomCharges = status.statusProperty("blossomSkillCharges", 0)
	blossomCharges = config.getParameter("blossomSkillCharges", 0)
	judgementSlashRadius = config.getParameter("judgementSlashRadius", 10)
	
	self.weapon.onLeaveAbility = function()
		self.weapon:setStance(self.stances.idle)
	end
	
end

-- Ticks on every update regardless if this is the active ability
function BlossomCombo:update(dt, fireMode, shiftHeld, moves)
  WeaponAbility.update(self, dt, fireMode, shiftHeld, moves)
  
	if firstUpdate then
		DefineParticles()
		firstUpdate = nil
	end
	
	aimPos = activeItem.ownerAimPosition()
	face = mcontroller.facingDirection()
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle)
	aimVector[1] = aimVector[1] * face
	
	flip = ""
	if face < 0 then flip = "?flipx" end
	turn = "-1"
	if face < 0 then turn = "1" end
	
	sheathPart()
	self.inflictedDamage:update()
	
	--thing that updates the cursor
	activeItem.setCursor("/cursors/blossomCursor"..blossomCharges..".cursor") 

	if self.fireMode == "alt" and not self.weapon.currentAbility then
		 if blossomCharges >= 2
		 then 
			blossomCharges = blossomCharges - 2 
			if blossomCharges < 0 then blossomCharges = 0 end 
			activeItem.setInstanceValue("blossomSkillCharges", blossomCharges)
			self:setState(self.altWindup) altActive = true
		 return false end
	end
  
  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
    end
  end
  
  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) and fireMode == (self.activatingFireMode or self.abilitySlot) then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  if not self.weapon.currentAbility and self:shouldActivate() then
    self:setState(self.windup)
  end
end

--hit notif from muro
function inflictedDamageCallback(notifications)
    for _,notification in ipairs(notifications) do
      -- if notification.hitType == "Kill" then
     -- if notification.damageSourceKind  == "broadsword" then
      if notification.hitType ~= nil then
        if world.entityExists(notification.targetEntityId) then
          local entityPos = world.entityPosition(notification.targetEntityId)
          local entityType = world.entityType(notification.targetEntityId)
          local eventFields = entityEventFields(notification.targetEntityId)
          util.mergeTable(eventFields, worldEventFields())
          eventFields.damageSourceKind = notification.damageSourceKind
          if entityType == "npc" or entityType == "monster" or entityType == "player" then
				if self.comboStep == 4 or self.comboStep == 5 or self.comboStep == 6 then airBounce(25) end
				world.spawnProjectile("pillarspawner", entityPos, entity.id(), aimVector, false, petals)
				if altActive then 
					world.spawnProjectile("pillarspawner", entityPos, entity.id(), aimVector, false, hitParamAlt)
				else
					blossomCharges = blossomCharges + 1 if blossomCharges > 6 then blossomCharges = 6 end
					activeItem.setInstanceValue("blossomSkillCharges", blossomCharges)
					world.spawnProjectile("pillarspawner", entityPos, entity.id(), aimVector, false, hitParamPrimary)
				end
				--break  //makes it only affect one at a  time
				break
          end
        end
      end
    end
  end

-- State: windup
function BlossomCombo:windup()
  local stance = self.stances["windup"..self.comboStep]
  
  --primaryComboActive = true
  world.sendEntityMessage(activeItem.ownerEntityId(), "comboActive")
  self.weapon:setStance(stance)
  self.edgeTriggerTimer = 0

	--primaryActive = true
  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(stance.duration, function()
	  	if self.comboStep == 2 or self.comboStep == 3 or self.comboStep == 7 then
			if not self.shiftHeld then 
				status.addEphemeralEffect("invulnerable", stance.duration+0.1)
			end
		end
		if self.comboStep == 4 or self.comboStep == 5 or self.comboStep == 6 or self.comboStep == 8 then slowFall(10,10) end
	end)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- waiting for next combo input
function BlossomCombo:wait()
  local stance = self.stances["wait"..(self.comboStep - 1)]

  self.weapon:setStance(stance)

  util.wait(stance.duration, function()
	if self.comboStep == 7 or self.comboStep == 8 then slowFall(5,5) end
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)
  
  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  self.comboStep = 1
end

-- State: preslash
-- brief frame in between windup and fire
function BlossomCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration, function() 
		if self.comboStep == 4 or self.comboStep == 5 or self.comboStep == 6 or self.comboStep == 7 or self.comboStep == 8 then slowFall(5,5) end
  end)

  self:setState(self.fire)
end

-- State: fire
function BlossomCombo:fire()
	local stance = self.stances["fire"..self.comboStep]
	
	self.weapon:setStance(stance)
	self.weapon:updateAim()
	local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
	animator.setAnimationState("swoosh", animStateKey)
	animator.playSound(animStateKey)
  
  	if self.comboStep == 2 or self.comboStep == 3 or self.comboStep == 7 then
		if not self.shiftHeld--[[ and mcontroller.groundMovement()]] then 
			status.addEphemeralEffect("invulnerable", stance.duration+0.1) forwardDash(95, -5) dashed = true 
		end
	end
	
	util.wait(0.05, function() end)
	
	if self.comboStep == 4 or self.comboStep ==  5 or self.comboStep == 6 then
		local monsters = self:findTarget()
		if monsters then
			for _,monsterId in pairs(monsters) do
				--status.addEphemeralEffect("intents", stance.duration+0.2)
				judgeSlashID = world.spawnProjectile("spinslash",  world.entityPosition(monsterId), entity.id(), {0,0}, false, judgementSlashes)
				break
			end
		end
	end
	
	if dashed then mcontroller.setVelocity({10 * self.weapon.aimDirection * math.cos(self.weapon.aimAngle), 25 * math.sin(self.weapon.aimAngle)}) dashed = nil end
	util.wait(stance.duration, function()
	
		if self.comboStep == 4 or self.comboStep ==  5 or self.comboStep == 6 then else
			local damageArea = partDamageArea("swoosh")
			self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
		end
		if self.comboStep == 4 or self.comboStep == 5 or self.comboStep == 6 or self.comboStep == 7 or self.comboStep == 8 then slowFall(5,5) end
	end)
	

	if self.comboStep < self.comboSteps then
		self.comboStep = self.comboStep + 1
		self:setState(self.wait)
	else
		self.cooldownTimer = self.cooldowns[self.comboStep]
		self.comboStep = 1
		self.weapon:setStance(self.stances.idle)
	end
end

function BlossomCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function BlossomCombo:computeDamageAndCooldowns()
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["fire"..i].duration
    if self.stances["preslash"..i] then
      attackTime = attackTime + self.stances["preslash"..i].duration
    end
    table.insert(attackTimes, attackTime)
  end

  self.cooldowns = {}
  local totalAttackTime = 0
  local totalDamageFactor = 0
  for i, attackTime in ipairs(attackTimes) do
    self.stepDamageConfig[i] = util.mergeTable(copy(self.damageConfig), self.stepDamageConfig[i])
    self.stepDamageConfig[i].timeoutGroup = "primary"..i

    local damageFactor = self.stepDamageConfig[i].baseDamageFactor
    self.stepDamageConfig[i].baseDamage = damageFactor * self.baseDps * self.fireTime

    totalAttackTime = totalAttackTime + attackTime
    totalDamageFactor = totalDamageFactor + damageFactor

    local targetTime = totalDamageFactor * self.fireTime
    local speedFactor = 1.0 * (self.comboSpeedFactor ^ i)
    table.insert(self.cooldowns, (targetTime - totalAttackTime) * speedFactor)
  end
end

function BlossomCombo:uninit()
	--primaryActive = false
	altActive = false
	if status.statPositive("activeMovementAbilities") then mcontroller.setVelocity({mcontroller.velocity()[1]*0.3, mcontroller.velocity()[2]*0.3}) end
	if dashed then mcontroller.setVelocity({10 * self.weapon.aimDirection * math.cos(self.weapon.aimAngle), 25 * math.sin(self.weapon.aimAngle)}) dashed = nil end
	status.clearPersistentEffects("movementAbility")
	self.weapon:setDamage()
end

--timer from najja
function bladeIdleParticles(dt)
	idleParticleTimer = math.min(5, idleParticleTimer + dt*2)
	if idleParticleTimer >= 1.5 then
		world.spawnProjectile("pillarspawner",  vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("redktn", "bladeParticleAnchor"))), entity.id(), aimVector, false, {
			processing = "?crop=0;0;0;0",
			damageTeam = {type = "ghostly"},
			timeToLive = 0.2,
			speed = 0,
			movementSettings = {collisionPoly = {{0, 0}}, gravityMultiplier = 0},
			periodicActions = {
					{
						time = 0.001,
						["repeat"] = false,
						count = 1,
						action = "loop",
						body = {
							{
								time = 0.001,
								["repeat"] = false,
								action = "particle",
								specification = {
									layer = "middle",
									collidesForeground = false,
									fullbright = true,
									animation = "/animations/blinkout/blinkout.animation"..vanityConfig.blinkoutRecolor,
									type = "animated",
									size = 0.1,
									position = {0, 0},
									timeToLive = 1,
									variance = {
										position = {0.25, 1},
										size = 0.05,
										rotation = 360
									}
								}
							},{
								time = 0.001,
								["repeat"] = false,
								action = "particle",
								specification = {
									layer = "back",
									collidesForeground = false,
									fullbright = true,
									animation = "/animations/blinkout/blinkout.animation"..vanityConfig.blinkoutRecolor,
									type = "animated",
									size = 0.2,
									position = {0, 0},
									timeToLive = 1,
									variance = {
										position = {0.25, 1},
										size = 0.25,
										rotation = 360
									}
								}
							}
						}
					},					{
						time = 0.001,
						["repeat"] = false,
						count = 1,
						action = "loop",
						body = {
							{
								time = 0.001,["repeat"] = false, action = "particle",
								specification = {
									layer = "middle", collidesForeground = false, fullbright = true,
									animation = "/animations/teslaboltpurple/teslaboltpurple.animation?scalenearest=3;0.75?setcolor="..vanityConfig.energyColorBright,
									type = "animated", size = 0.3,position = {0, 0},timeToLive = 1,
									variance = {
										position = {0.25, 0.75},
										size = 0.1,
										rotation = 360
									}
								}
							},{
								time = 0.001,["repeat"] = false, action = "particle",
								specification = {
									layer = "back", collidesForeground = false, fullbright = true,
									animation = "/animations/teslaboltpurple/teslaboltpurple.animation?scalenearest=3;0.75?setcolor="..vanityConfig.energyColorMedium,
									type = "animated", size = 0.2,position = {0, 0},timeToLive = 1,
									variance = {
										position = {0.25, 0.75},
										size = 0.1,
										rotation = 360
									}
								}
							}
						}
					}
				}
			}
		)
		idleParticleTimer = 1
	end
end

	--	//	UTILITY
function forwardDash(speed1, speed2) --from lemon's (interstellar explorer) scissorblade "TanQie"
	local setVelocity = speed1
	local position = mcontroller.position()
	monsters = world.entityQuery( 
		{ position[1] + 1, position[2] - 3 },
		{ position[1] + 5, position[2] + 2 },
		{ includedTypes = { "monster", "player", "npc" } }
	)
	if mcontroller.facingDirection() == -1 then
		monsters = world.entityQuery(
			{ position[1] - 5, position[2] - 3 },
			{ position[1] - 1, position[2] + 2 },
			{ includedTypes = { "monster", "player", "npc" } }
		)
	end
	local shouldMove = false
	for i = 1, #monsters do
		local monsterId = monsters[i]
		if world.entityCanDamage(activeItem.ownerEntityId(), monsterId) then
			shouldMove = true
			break
		end
	end
	if shouldMove then
		setVelocity = speed2
	end
	mcontroller.setVelocity({setVelocity * self.weapon.aimDirection * math.cos(self.weapon.aimAngle), setVelocity * math.sin(self.weapon.aimAngle)})
	dashParticles()
	--[[
		local dashSpeed = 170
		local xspeed = dashSpeed  * self.weapon.aimDirection * math.cos(self.weapon.aimAngle)
		local yspeed = dashSpeed * math.sin(self.weapon.aimAngle)
		mcontroller.setVelocity({xspeed, yspeed})
	]]
end

function q_dash(speed)
	local dashSpeed = speed
	local xspeed = dashSpeed  * self.weapon.aimDirection * math.cos(self.weapon.aimAngle)
	local yspeed = dashSpeed * math.sin(self.weapon.aimAngle)
	mcontroller.setVelocity({xspeed, yspeed})
end

function moveRunJumpSuppress(bool1, bool2, bool3) -- wow i really didnt need to do this, im laughing at it so idc
	mcontroller.controlModifiers({ movementSuppressed = bool1, runningSuppressed = bool2, jumpingSuppressed = bool3 })
end

function slowFall(xVelDiv, yVelDiv)
	local divX, divY = xVelDiv or 3, yVelDiv or 4
	if mcontroller.yVelocity() < 0 and not mcontroller.groundMovement() and not status.resourceLocked("energy") then
		mcontroller.controlApproachVelocity({mcontroller.xVelocity()/divX,mcontroller.yVelocity()/divY}, 225)
	end
end

---from the vanilla markedshot.lua
function BlossomCombo:findTarget()
  local nearEntities = world.entityQuery(mcontroller.position(), judgementSlashRadius, { order = "nearest", withoutEntityId = entity.id(),  includedTypes = {"monster", "npc", "player"} })
  nearEntities = util.filter(nearEntities, function(entityId)
    if not world.entityCanDamage(activeItem.ownerEntityId(), entityId) then
      return false
    end

    if world.lineTileCollision(mcontroller.position(), world.entityPosition(entityId)) then
      return false
    end

    return true
  end)

  if #nearEntities > 0 then
    return nearEntities
  else
    return false
  end
end

	-- // PROJECTILES n PARTICLES
function DefineParticles()
	petals = {
		processing = "?crop=0;0;0;0",
		damageTeam = {type = "ghostly"},
		timeToLive = 0.2,
		speed = 0,
		movementSettings = {collisionPoly = {{0, 0}}, gravityMultiplier = 0},
		periodicActions = {{
				time = 0.001,
				["repeat"] = false,
				count = 3,
				action = "loop",
				body = {
					{
						time = 0.1,
						["repeat"] = true,
						action = "particle",
						specification = {
							initialVelocity = {0, 0},
							finalVelocity = {0, -2},
							approach = {5, 5},
							layer = "back",
							destructionAction = "shrink",
							fullbright = true,
							animation = "/animations/petals/petals.animation",
							type = "animated",
							variance = {
								angularVelocity = 5,
								rotation = 360,
								position = {1, 1},
								initialVelocity = {5, 3},
								finalVelocity = {2, 0},
								approach = {25, 25},
								size = 0.5,
								destructionTime = 0.5
							},
							destructionTime = 2,
							size = 1,
							position = {0, 0},
							timeToLive = 0
						}
					}
				}
			},{
				time = 0.001,
				["repeat"] = false,
				count = 3,
				action = "loop",
				body = {
					{
						time = 0.1,
						["repeat"] = true,
						rotate = true,
						action = "particle",
						specification = {
							initialVelocity = {10, 0},
							finalVelocity = {0, 0},
							approach = {15, 15},
							layer = "back",
							destructionAction = "shrink",
							fullbright = true,
							type = "ember",
							variance = {
								position = {1, 1},
								initialVelocity = {0, 5},
								finalVelocity = {5, 5},
								approach = {25, 25},
								size = 2,
								destructionTime = 0.5
							},
							destructionTime = 1.2,
							size = 1.6,
							position = {0, 0},
							color = {255, 186, 194},
							timeToLive = 0.3
						}
					},
					{
						time = 0.1,
						["repeat"] = true,
						rotate = true,
						action = "particle",
						specification = {
							initialVelocity = {15, 0},
							finalVelocity = {0, 0},
							approach = {15, 15},
							layer = "middle",
							destructionAction = "shrink",
							fullbright = true,
							type = "ember",
							variance = {
								position = {1, 1},
								initialVelocity = {0, 5},
								finalVelocity = {5, 5},
								approach = {25, 25},
								size = 1,
								destructionTime = 0.4
							},
							destructionTime = 0.7,
							size =1.5,
							position = {0, 0},
							color = {186, 54, 105},
							timeToLive = 0.3
						}
					}
				}
			}
		}
	}
	hitParamPrimary = {
		processing = "?crop=0;0;0;0",
		damageTeam = {type = "ghostly"},
		timeToLive = 0.2,
		speed = 0,
		movementSettings = {collisionPoly = {{0, 0}}, gravityMultiplier = 0},
		periodicActions = {
			{
				time = 0.001,
				["repeat"] = false,
				count = 1,
				action = "loop",
				body = {
					{
						time = 0.001,
						["repeat"] = false,
						action = "particle",
						specification = {
							layer = "middle",
							collidesForeground = false,
							fullbright = true,
							animation = "/animations/blinkout/blinkout.animation?replace;fffffe=fff0;31a6ff=e76087;9bd4ff=ba3669;?scalenearest=2;1",
							type = "animated",
							size = 1,
							position = {0, 0},
							timeToLive = 1,
							variance = {
								position = {0.25, 1},
								size = 0.05,
								rotation = 360
							}
						}
					}
				}
			}
		}
	}
	hitParamAlt = {
		processing = "?crop=0;0;0;0",
		damageTeam = {type = "ghostly"},
		timeToLive = 0.2,
		speed = 0,
		movementSettings = {collisionPoly = {{0, 0}}, gravityMultiplier = 0},
		periodicActions = {
			{
				time = 0.001,
				["repeat"] = false,
				count = 1,
				action = "loop",
				body = {
					{
						time = 0.001,
						["repeat"] = false,
						action = "particle",
						specification = {
							layer = "middle",
							collidesForeground = false,
							fullbright = true,
							animation = "/animations/blinkout/blinkout.animation?replace;fffffe=fff0;31a6ff=e76087;9bd4ff=ba3669;?scalenearest=5;1",
							type = "animated",
							size = 1,
							position = {0, 0},
							timeToLive = 1,
							variance = {
								position = {0.25, 1},
								size = 0.05,
								rotation = 360
							}
						}
					}
				}
			}
		}
	}
	judgementSlashes = {
		processing = "?crop=0;0;0;0",
		timeToLive = 0.2,
		power = 4 * config.getParameter("damageLevelMultiplier") * activeItem.ownerPowerMultiplier(),
		knockback = 0,
		speed = 0,
		damageKind = "broadsword",
		movementSettings = {collisionPoly = {{0, 0}}, gravityMultiplier = 0},
		statusEffects =  {{
			duration = 0.05,
			effect = "paralysis"
		}},
		periodicActions = {
			{
				time = 0.001,
				["repeat"] = false,
				count = 3,
				action = "loop",
				body = {
					{
						time = 0.001,
						["repeat"] = false,
						action = "particle",
						specification = {
							layer = "back",
							collidesForeground = false,
							fullbright = true,
							image = "/cinematics/story/moon.png?setcolor=e76087?multiply=CCC5",
							type = "textured",
							destructionAction = "fade",
							destructionTime = 0.5,
							timeToLive = 0,
							size = 0.2,
							position = {0, 0},
							variance = {
								size = 0.05,
								rotation = 360,
								angularVelocity = 3500
							}
						}
					},{
						time = 0.001,
						["repeat"] = false,
						action = "particle",
						specification = {
							layer = "back",
							collidesForeground = false,
							fullbright = true,
							image = "/cinematics/story/moon.png?setcolor=fff?multiply=CCC2",
							type = "textured",
							destructionAction = "fade",
							destructionTime = 0.5,
							timeToLive = 0,
							size = 0.2,
							position = {0, 0},
							variance = {
								size = 0.01,
								rotation = 360,
								angularVelocity = 3500
							}
						}
					}
				}
			},
			{
				time = 0.001,
				["repeat"] = false,
				count = 10,
				action = "loop",
				body = {
					{
						time = 0.001,
						["repeat"] = false,
						action = "particle",
						specification = {
							layer = "back",
							collidesForeground = false,
							fullbright = true,
							animation = "/animations/lightsmoke/lightsmoke.animation?setcolor=ffbac2?multiply=CCC9",
							type = "animated",
							size = 1,
							position = {0, 0},
							timeToLive = 1,
							variance = {
								position = {2.5, 2.5},
								size = 0.05,
								rotation = 360
							}
						}
					}
				}
			}
		}
	}
end
function dashParticles()
  local face = mcontroller.facingDirection()
  local flip = ""
  if face < 0 then
    flip = "?flipxy"
  end
  
  world.spawnProjectile("pillarspawner", vec2.add(mcontroller.position(), {0, -0.1}), entity.id(), aimVector, true, {
  processing = "?crop=0;0;0;0",
  damageTeam = {type = "ghostly"},
  timeToLive = 0.1,
  speed = 0,
  movementSettings = { gravityMultiplier = 0, collisionEnabled = false, collisionPoly = {{0, 0}} },
  periodicActions = {
	{
		time = 0.001,
		["repeat"] = true,
		rotate = true,
		action = "projectile",
		type = "pillarspawner",
		config = {
			processing = "?crop=0;0;0;0",
			damageKind = "nodamage",
			timeToLive = 0.2,
			power = 0,
			speed = 0,
			knockback = 0,
			piercing = true,
			movementSettings = {collisionPoly = {{0, 0}}, gravityMultiplier = 0},
			periodicActions = {
				{
					time = 0.015,
					["repeat"] = false,
					rotate = true,
					count = 2,
					action = "loop",
					body = {
						{
						time = 0.005,
						["repeat"] = true,
						rotate = true,
						action = "particle",
						rotation = 0,
						specification = {
							type = "animated",
							animation = "/animations/jumpsmokehalf/jumpsmokehalf.animation?replace;dcd8cb=ffbac2;b9b198=e76087;897e5d=ba3669;"..flip,
							position = {0, -1.85*face},
							initialVelocity = {-15, 0.0},
							finalVelocity = {0, 0},
							approach = {25, 25},
							size = 1.0,
							timeToLive = 0.85,
							fullbright = true,
							collidesLiquid = false,
							layer = "middle",
							variance = {
								initialVelocity = {5.0, 5.0},
								position = {1 * -face, 0.25},
								timeToLive = 0.25,
								size = 0.5
						}
						}
						}
					}
				}
			}
		}
	}
	}
  })
end
function altDashParticles()
	local face = mcontroller.facingDirection()
	local flip = "?flipx"
	if face < 0 then
		flip = ""
	end
  
	world.spawnProjectile("pillarspawner", vec2.add(mcontroller.position(), {0, -0.1}), entity.id(), {0, 0}, true, {
	processing = "?crop=0;0;0;0",
	damageTeam = {type = "ghostly"},
	timeToLive = 0.15,
	speed = 0,
	movementSettings = { gravityMultiplier = 0, collisionEnabled = false, collisionPoly = {{0, 0}} },
	periodicActions = {
		{
			time = 0.001,
			["repeat"] = true,
			rotate = true,
			action = "projectile",
			type = "pillarspawner",
			config = {
				processing = "?crop=0;0;0;0",
				damageKind = "nodamage",
				timeToLive = 0.2,
				power = 0,
				speed = 0,
				knockback = 0,
				piercing = true,
				movementSettings = {collisionPoly = {{0, 0}}, gravityMultiplier = 0},
				periodicActions = {
					{
						time = 0.001,
						["repeat"] = false,
						count = 2,
						action = "loop",
						body = {
							{
								time = 0.03,
								action = "particle",
								specification = {
									layer = "middle",
									destructionAction = "shrink",
									type = "ember",
									initialVelocity = {-15 * face, 0},
									finalVelocity = {0, 0},
									approach = {30, 20},
									collidesForeground = true,
									collidesLiquid = false,
									fullbright = true,
									variance = {
										initialVelocity = {15, 15},
										finalVelocity = {5.5, 5},
										approach = {25, 25},
										size = 3,
										destructionTime = 0.3
									},
									destructionTime = 0.8,
									size = 1.9,
									position = {2*face, 0},
									color = {255, 186, 194},
									timeToLive = 0.1
								}
							},{
								time = 0.03,
								action = "particle",
								specification = {
									layer = "middle",
									destructionAction = "shrink",
									type = "ember",
									initialVelocity = {-15 * face, 0},
									finalVelocity = {0, 0},
									approach = {30, 20},
									collidesForeground = true,
									collidesLiquid = false,
									fullbright = true,
									variance = {
										initialVelocity = {15, 15},
										finalVelocity = {5.5, 5},
										approach = {25, 25},
										size = 3,
										destructionTime = 0.3
									},
									destructionTime = 0.8,
									size = 1.9,
									position = {1*face, 0},
									color = {231, 96, 135},
									timeToLive = 0.1
								}
							}
						}
					},
					{
						time = 0.015,
						["repeat"] = false,
						count = 3,
						action = "loop",
						body = {
							{
								time = 0.0025,
								["repeat"] = true,
								action = "particle",
								rotation = 0,
								specification = {
									type = "animated",
									animation = "/animations/jumpsmokehalf/jumpsmokehalf.animation?replace;dcd8cb=ffbac2;b9b198=e76087;897e5d=ba3669;" ..
										flip,
									position = {0, -1.85},
									initialVelocity = {15 * -face, 0.0},
									finalVelocity = {0, 0},
									approach = {25, 25},
									size = 1.0,
									timeToLive = 0.85,
									fullbright = true,
									collidesLiquid = false,
									layer = "middle",
									variance = {
										initialVelocity = {5.0, 5.0},
										position = {2 * -face, 0.25},
										timeToLive = 0.25,
										size = 0.5
									}
								}
							},
							{
								time = 0.0025,
								["repeat"] = true,
								action = "particle",
								rotation = 0,
								specification = {
									type = "animated",
									animation = "/animations/jumpsmokehalf/jumpsmokehalf.animation?setcolor=6a2c69" .. flip,
									position = {0, -1.85},
									initialVelocity = {15 * -face, 0.0},
									finalVelocity = {0, 0},
									approach = {25, 25},
									size = 1.0,
									timeToLive = 0.85,
									fullbright = true,
									collidesLiquid = false,
									layer = "back",
									variance = {
										initialVelocity = {5.0, 5.0},
										position = {2 * -face, 0.25},
										timeToLive = 0.25,
										size = 0.5
									}
								}
							}
						}
					}
				}
			}
		},
		{
			time = 0.001,
			["repeat"] = false,
			count = 1,
			action = "loop",
			body = {
				{
					time = 0.01,
					["repeat"] = false,
					action = "particle",
					specification = {
						layer = "back",
						fullbright = true,
						animation = "/animations/greenmonstersplosion/greenmonstersplosion.animation?replace;fff=fff0;e4bb57=e76087;e5bc57=e76087;?replace;51bd3b=e7608770;3d8a2c=ba366970;?scalenearest=0.5;4" ..
							flip,
						type = "animated",
						size = 1,
						position = {0, 0},
						timeToLive = 1
					}
				}
			}
		}
	}
  })
end


	--	//	ALT
function BlossomCombo:altWindup()
	self.weapon:setStance(self.stances.altWindup)
	self.weapon:updateAim()
	
	local stance = self.stances.altWindup
	if stance.hold then
		while self.fireMode == "alt" do
			coroutine.yield()
		end
	else
		util.wait(self.stances.altWindup.duration, function()
			q_dash(-15)
			moveRunJumpSuppress(true, true, true)
		end)
	end
	
	self:setState(self.altPreslash)
end
function BlossomCombo:altPreslash()
	self.weapon:setStance(self.stances.altPreslash)
	self.weapon:updateAim()
	status.setPersistentEffects("movementAbility", {{stat = "activeMovementAbilities", amount = 1}})
	status.addEphemeralEffect("invulnerable", self.stances.altPreslash.duration+0.1)
	altDashParticles()
	util.wait(self.stances.altPreslash.duration, function() 
		moveRunJumpSuppress(true, true, true)
		q_dash(160)
	end)	
	self:setState(self.altFire)
end
function BlossomCombo:altFire()
	self.weapon:setStance(self.stances.altFire)
	self.weapon:updateAim()
  
	mcontroller.setVelocity({15 * self.weapon.aimDirection * math.cos(self.weapon.aimAngle), 25 * math.sin(self.weapon.aimAngle)})
	status.addEphemeralEffect("invulnerable", self.stances.altFire.duration+0.1)
	animator.setAnimationState("swoosh", "altFire")
	animator.playSound("altFire")
	util.wait(self.stances.altFire.duration, function()
		moveRunJumpSuppress(true, true, true)
		
		local damageArea = partDamageArea("swoosh")
		self.weapon:setDamage(self.altConfig, damageArea)
		
		q_dash(150)
	end)
	
	self:setState(self.altAfterFire)
end
function BlossomCombo:altAfterFire()
	self.weapon:setStance(self.stances.altAfterFire)
	self.weapon:updateAim()
	util.wait(self.stances.altAfterFire.duration, function() 
		moveRunJumpSuppress(true, true, true)
		q_dash(3)
	end)	
	self:setState(self.altWait)
end
function BlossomCombo:altWait()
	self.weapon:setStance(self.stances.altWait)
	self.weapon:updateAim()
	status.clearPersistentEffects("movementAbility")
	--[[
	if self.fireMode == "alt" then
		 if  charges >= 2 or status.overConsumeResource("energy", self.altConfig.energyUsage) then 
			charges = charges - 2 if charges < 0 then charges = 0 end
			self:setState(self.altWindup2) altActive = true
		 return false end
	else
	]]
		util.wait(self.stances.altWait.duration, function() 
			--moveRunJumpSuppress(true, true, true)
			if self:shouldActivate() then
				self.comboStep = 7
				self:setState(self.windup)
				return
			end
		end)
		altActive = false
		self.weapon:setStance(self.stances.idle)
	--end
end

	--	//	SHEATH
function draw_part(data)
	-- debug/maple helped me with the chain.lua sheath rendering
    table.insert(parts, {
        startPosition = data.position,
        endPosition = vec2.add(data.position, data.rotation),
        segmentImage = data.image or nil,
        segmentSize = 1,
        overdrawLength = 0.01 ,
        fullbright = data.fullbright or false,
        renderLayer = data.renderLayer,
        waveform = data.waveform
    })
end
function sheathPart()
	
	--[[ from muro, unused though :>
	local mvel = mcontroller.velocity()[1]
	local mdir = mvel/math.abs(mvel)
	sheatherotate = math.min(math.rad(5), math.abs(mvel))*mdir or 0.1
	]]
	
	-- the math.max/min stuff is also from muro
	local sheathrotate = -0.1
	local forcedtilt = (sheathConfig.hipSheath_Rotation or -0.75)*mcontroller.facingDirection()
	local velocityLeaning = math.max(sheathrotate, math.min(-sheathrotate, mcontroller.velocity()[1] / -125))
	local sheath_rotation = (1*mcontroller.facingDirection())+mcontroller.rotation()+velocityLeaning+forcedtilt
	
	sheathpos = {sheathConfig.hipSheath_PositionX * mcontroller.facingDirection(), sheathConfig.hipSheath_PositionY}
	
	if (mcontroller.crouching() and mcontroller.groundMovement() and mcontroller.yVelocity() ~= 0) then sheathpos[2] = -1.75 end
	--if sheath_rotation > math.pi/2 and sheath_rotation < math.pi*1.5 then flipper = "" else flipper = "?flipy" end
	
	if animator.animationState("pinkKatana") == "sheathed"
	or animator.animationState("pinkKatana") == "unsheathing"
	or animator.animationState("pinkKatana") == "sheathing"
	then else
		--if not ultimateSlasher then
			if mcontroller.facingDirection() == -1 then reduhlayer = (sheathConfig.renderLayerLeft or "Player") else reduhlayer = (sheathConfig.renderLayerRight or "Player-1") end
			draw_part(
				{
					image = sheathConfig.hipSheath--[[ .. flipper]],
					position = vec2.add(mcontroller.position(), vec2.rotate(sheathpos, mcontroller.rotation())),
					rotation = vec2.rotate({mcontroller.facingDirection(), 0}, sheath_rotation or 0),
					renderLayer = reduhlayer
				}
			)
		--end
	end
	activeItem.setScriptedAnimationParameter("chains", parts)
	parts = {}
end
