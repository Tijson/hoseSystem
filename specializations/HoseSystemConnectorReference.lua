--
--	HoseSystemConnectorReference
--
--	@author: 	 Wopster
--	@descripion: 
--	@website:
--	@history:	 v1.0 - 2016-02-11 - Initial implementation
--

HoseSystemConnectorReference = {
    name = g_currentModName,
}

function HoseSystemConnectorReference.prerequisitesPresent(specializations)
    return true
end

function HoseSystemConnectorReference:load(savegame)
    self.toggleLock = HoseSystemConnectorReference.toggleLock
    self.toggleManureFlow = HoseSystemConnectorReference.toggleManureFlow
    self.setIsUsed = HoseSystemConnectorReference.setIsUsed
    self.getConnectedReference = HoseSystemConnectorReference.getConnectedReference

    -- new
    self.getValidFillObject = HoseSystemConnectorReference.getValidFillObject
    self.getAllowedFillUnitIndex = HoseSystemConnectorReference.getAllowedFillUnitIndex

    self.getLastGrabpointRecursively = HoseSystemConnectorReference.getLastGrabpointRecursively
    self.getIsPlayerInReferenceRange = HoseSystemConnectorReference.getIsPlayerInReferenceRange

    self.updateLiquidHoseSystem = HoseSystemConnectorReference.updateLiquidHoseSystem

    -- overwrittenFunctions
    self.getIsOverloadingAllowed = Utils.overwrittenFunction(self.getIsOverloadingAllowed, HoseSystemConnectorReference.getIsOverloadingAllowed)

    self.hoseSystemReferences = {}
    self.dockingSystemReferences = {}

    HoseSystemConnectorReference.loadHoseReferences(self, self.xmlFile, 'vehicle.hoseSystemReferences.', self.hoseSystemReferences)
    -- HoseSystemConnectorReference.loadDockingReferences(self, self.xmlFile, 'vehicle.dockingSystemReferences.', self.dockingSystemReferences)

    self.fillObject = nil
    self.fillObjectFound = false
    self.fillObjectHasPlane = false
    self.fillFromFillVolume = false
    self.fillUnitIndex = 0
    self.isSucking = false

    if self.isServer then
        self.lastFillObjectFound = false
        self.lastFillObjectHasPlane = false
        self.lastFillFromFillVolume = false
        self.lastFillUnitIndex = 0
    end

    if self.hasHoseSystemPumpMotor then
        self.pumpMotorFillMode = HoseSystemPumpMotor.getInitialFillMode('hoseSystem')
    end

    self.hasHoseSystem = true

    if self.unloadTrigger ~= nil then
        self.unloadTrigger:delete()
        self.unloadTrigger = nil
    end

    HoseSystemConnectorReference:updateCurrentMissionInfo(self)
end

function HoseSystemConnectorReference:postLoad(savegame)
    if savegame ~= nil and not savegame.resetVehicles then
        for id, reference in ipairs(self.hoseSystemReferences) do
            local key = string.format('%s.reference(%d)', savegame.key, id - 1)

            self:toggleLock(id, Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. '#isLocked'), false), false, true)
            self:toggleManureFlow(id, Utils.getNoNil(getXMLBool(savegame.xmlFile, key .. '#flowOpened'), false), false, true)
        end
    end
end

function HoseSystemConnectorReference.loadHoseReferences(self, xmlFile, base, references)
    local i = 0

    while true do
        local key = string.format(base .. 'hoseSystemReference(%d)', i)

        if not hasXMLProperty(xmlFile, key) then
            break
        end

        if #references == 2 ^ HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS then
            print(('HoseSystem warning - Max number of references is %s!'):format(2 ^ HoseSystemUtil.eventHelper.REFERENCES_NUM_SEND_BITS))
            break
        end

        local createNode = Utils.getNoNil(getXMLBool(xmlFile, key .. '#createNode'), false)
        local node = not createNode and Utils.indexToObject(self.components, getXMLString(xmlFile, key .. '#index')) or createTransformGroup(('hoseSystemReference_node_%d'):format(i + 1))

        if createNode then
            local linkNode = Utils.indexToObject(self.components, Utils.getNoNil(getXMLString(xmlFile, key .. '#linkNode'), '0>'))

            local translation = { Utils.getVectorFromString(getXMLString(self.xmlFile, key .. '#position')) }
            if translation[1] ~= nil and translation[2] ~= nil and translation[3] ~= nil then
                setTranslation(node, unpack(translation))
            end

            local rotation = { Utils.getVectorFromString(getXMLString(self.xmlFile, key .. '#rotation')) }
            if rotation[1] ~= nil and rotation[2] ~= nil and rotation[3] ~= nil then
                setRotation(node, Utils.degToRad(rotation[1]), Utils.degToRad(rotation[2]), Utils.degToRad(rotation[3]))
            end

            link(linkNode, node)
        end

        if node ~= nil then
            local entry = {
                id = i + 1,
                node = node,
                isUsed = false,
                flowOpened = false,
                isLocked = false,
                hoseSystem = nil,
                grabPoints = nil,
                isObject = false,
                componentIndex = Utils.getNoNil(getXMLFloat(xmlFile, key .. 'componentIndex'), 0) + 1,
                inRangeDistance = Utils.getNoNil(getXMLFloat(xmlFile, key .. 'inRangeDistance'), 1.3),
                parkable = Utils.getNoNil(getXMLBool(xmlFile, key .. '#parkable'), false),
                lockAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#lockAnimationName'), nil),
                manureFlowAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#manureFlowAnimationName'), nil)
            }

            if entry.parkable then
                entry.parkAnimationName = Utils.getNoNil(getXMLString(xmlFile, key .. '#parkAnimationName'), nil)
                local offsetDirection = Utils.getNoNil(getXMLString(xmlFile, key .. '#offsetDirection'), 'right')
                entry.parkLength = Utils.getNoNil(getXMLFloat(xmlFile, key .. '#parkLength'), 5) -- Default length of 5m
                entry.offsetDirection = offsetDirection ~= 'right' and HoseSystemUtil.DIRECTION_LEFT or HoseSystemUtil.DIRECTION_RIGHT
                entry.startTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startTransOffset'), 3), { 0, 0, 0 })
                entry.startRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#startRotOffset'), 3), { 0, 0, 0 })
                entry.endTransOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endTransOffset'), 3), { 0, 0, 0 })
                entry.endRotOffset = Utils.getNoNil(Utils.getVectorNFromString(getXMLString(xmlFile, key .. '#endRotOffset'), 3), { 0, 0, 0 })
                local maxNode = createTransformGroup(('hoseSystemReference_park_maxNode_%d'):format(entry.id))
                link(entry.node, maxNode)
                local trans = { localToWorld(node, 0, 0, entry.offsetDirection ~= 1 and -entry.parkLength or entry.parkLength) }
                setWorldTranslation(maxNode, unpack(trans))
                entry.maxParkLengthNode = maxNode
            end

            table.insert(references, entry)
        end

        i = i + 1
    end
end

function HoseSystemConnectorReference:updateCurrentMissionInfo(object)
    if #object.hoseSystemReferences > 0 then
        if g_currentMission.hoseSystemReferences == nil then
            g_currentMission.hoseSystemReferences = {}
        end

        table.insert(g_currentMission.hoseSystemReferences, object)
    end

    if #object.dockingSystemReferences > 0 then
        if g_currentMission.dockingSystemReferences == nil then
            g_currentMission.dockingSystemReferences = {}
        end

        table.insert(g_currentMission.dockingSystemReferences, object)
    end
end

function HoseSystemConnectorReference:preDelete()
    if self.hoseSystemReferences ~= nil and g_currentMission.hoseSystemHoses ~= nil then
        for referenceId, reference in pairs(self.hoseSystemReferences) do
            if reference.isUsed then
                if reference.hoseSystem ~= nil and reference.hoseSystem.grabPoints ~= nil then
                    for grabPointIndex, grabPoint in pairs(reference.hoseSystem.grabPoints) do
                        if HoseSystem:getIsConnected(grabPoint.state) and grabPoint.connectorRefId == referenceId then
                            reference.hoseSystem.poly.interactiveHandling:detach(grabPointIndex, self, referenceId, false)
                        end
                    end
                end
            end
        end
    end
end

function HoseSystemConnectorReference:delete()
    HoseSystemUtil:removeElementFromList(g_currentMission.hoseSystemReferences, self)
    HoseSystemUtil:removeElementFromList(g_currentMission.dockingSystemReferences, self)
end

function HoseSystemConnectorReference:readStream(streamId, connection)
    if connection:getIsServer() then
        for id = 1, streamReadUInt8(streamId) do
            local reference = self.hoseSystemReferences[id]

            -- load the hoseSystem object later on first frame
            self:setIsUsed(id, streamReadBool(streamId), nil, true)

            if streamReadBool(streamId) then
                if self.hoseSystemsToload == nil then
                    self.hoseSystemsToload = {}
                end

                table.insert(self.hoseSystemsToload, { id = id, hoseSystemId = readNetworkNodeObjectId(streamId) })
            end

            self:toggleLock(id, streamReadBool(streamId), false, true)
            self:toggleManureFlow(id, streamReadBool(streamId), false, true)
        end

        self.fillObjectFound = streamReadBool(streamId)
        self.fillFromFillVolume = streamReadBool(streamId)
        local currentReferenceIndex = streamReadInt8(streamId)
        self.currentReferenceIndex = currentReferenceIndex ~= 0 and currentReferenceIndex or nil
        local currentGrabPointIndex = streamReadInt8(streamId)
        self.currentGrabPointIndex = currentGrabPointIndex ~= 0 and currentGrabPointIndex or nil
    end
end

function HoseSystemConnectorReference:writeStream(streamId, connection)
    if not connection:getIsServer() then
        streamWriteUInt8(streamId, #self.hoseSystemReferences)

        for id = 1, #self.hoseSystemReferences do
            local reference = self.hoseSystemReferences[id]

            streamWriteBool(streamId, reference.isUsed)
            streamWriteBool(streamId, reference.hoseSystem ~= nil)

            if reference.hoseSystem ~= nil then
                writeNetworkNodeObjectId(streamId, networkGetObjectId(reference.hoseSystem))
            end

            streamWriteBool(streamId, reference.isLocked)
            streamWriteBool(streamId, reference.flowOpened)
        end

        streamWriteBool(streamId, self.fillObjectFound)
        streamWriteBool(streamId, self.fillFromFillVolume)
        streamWriteInt8(streamId, self.currentReferenceIndex ~= nil and self.currentReferenceIndex or 0)
        streamWriteInt8(streamId, self.currentGrabPointIndex ~= nil and self.currentGrabPointIndex or 0)
    end
end

function HoseSystemConnectorReference:getSaveAttributesAndNodes(nodeIdent)
    local nodes = ""

    if self.hoseSystemReferences ~= nil then
        for id, reference in pairs(self.hoseSystemReferences) do
            if id > 1 then
                nodes = nodes .. "\n"
            end

            nodes = nodes .. nodeIdent .. ('<reference id="%s" isLocked="%s" flowOpened="%s" />'):format(id, tostring(reference.isLocked), tostring(reference.flowOpened))
        end
    end

    return nil, nodes
end

function HoseSystemConnectorReference:mouseEvent(posX, posY, isDown, isUp, button)
end

function HoseSystemConnectorReference:keyEvent(unicode, sym, modifier, isDown)
end

function HoseSystemConnectorReference:update(dt)
    if self.hoseSystemsToload ~= nil then
        for _, n in pairs(self.hoseSystemsToload) do
            self.hoseSystemReferences[n.id].hoseSystem = networkGetObject(n.hoseSystemId)
        end

        self.hoseSystemsToload = nil
    end

    -- run this client sided only?
    if not self.isClient then
        return
    end

    if HoseSystemPlayerInteractive:getIsPlayerValid(false) then
        local inRange, referenceId = self:getIsPlayerInReferenceRange()

        if inRange then
            local reference = self.hoseSystemReferences[referenceId]

            if reference ~= nil then
                if not reference.flowOpened then
                    if reference.lockAnimationName ~= nil and self.animations[reference.lockAnimationName] ~= nil and #self.animations[reference.lockAnimationName].parts > 0 then
                        local _, firstPartAnimation = next(self.animations[reference.lockAnimationName].parts, nil)

                        if firstPartAnimation.node ~= nil and g_i18n:hasText('action_toggleLock') and g_i18n:hasText('action_toggleLockStateLock') and g_i18n:hasText('action_toggleLockStateUnlock') then
                            local state = self:getAnimationTime(reference.lockAnimationName) == 0

                            HoseSystemUtil:renderHelpTextOnNode(firstPartAnimation.node, string.format(g_i18n:getText('action_toggleLock'), state and g_i18n:getText('action_toggleLockStateLock') or g_i18n:getText('action_toggleLockStateUnlock')), string.format(g_i18n:getText('action_mouseInteract'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_LEFT))))

                            if InputBinding.hasEvent(InputBinding.toggleLock) then
                                self:toggleLock(referenceId, state, false)
                            end
                        end
                    end
                end

                if reference.isLocked then
                    if reference.manureFlowAnimationName ~= nil and self.animations[reference.manureFlowAnimationName] ~= nil and #self.animations[reference.manureFlowAnimationName].parts > 0 then
                        local _, firstPartAnimation = next(self.animations[reference.manureFlowAnimationName].parts, nil)

                        if firstPartAnimation.node ~= nil and g_i18n:hasText('action_toggleManureFlow') and g_i18n:hasText('action_toggleManureFlowStateOpen') and g_i18n:hasText('action_toggleManureFlowStateClose') then
                            local state = self:getAnimationTime(reference.manureFlowAnimationName) == 0

                            HoseSystemUtil:renderHelpTextOnNode(firstPartAnimation.node, string.format(g_i18n:getText('action_toggleManureFlow'), state and g_i18n:getText('action_toggleManureFlowStateOpen') or g_i18n:getText('action_toggleManureFlowStateClose')), string.format(g_i18n:getText('action_mouseInteract'), string.lower(MouseHelper.getButtonName(Input.MOUSE_BUTTON_RIGHT))))

                            if InputBinding.hasEvent(InputBinding.toggleManureFlow) then
                                self:toggleManureFlow(referenceId, state, false)
                            end
                        end
                    end
                end
            end
        end
    end
end

function HoseSystemConnectorReference:updateTick(dt)
    if self.hasHoseSystemPumpMotor then
        self:getValidFillObject()

        if self.isServer then
            local isSucking = false

            if self:getFillMode() == self.pumpMotorFillMode then
                local reference = self.hoseSystemReferences[self.currentReferenceIndex]

                -- Todo: Moved feature to version 1.1
                -- Todo: determine pump efficiency based on hose chain lenght
                --                if reference ~= nil then
                --                    local count = self.pumpFillEfficiency.maxTimeStatic / 10 * reference.hoseSystem.currentChainCount
                --                    self.pumpFillEfficiency.maxTime = reference.hoseSystem.currentChainCount > 0 and  self.pumpFillEfficiency.maxTimeStatic + count or self.pumpFillEfficiency.maxTimeStatic
                --                    print("CurrentChainCount= " .. reference.hoseSystem.currentChainCount .. "maxTime= " .. self.pumpFillEfficiency.maxTime .. 'What we do to it= ' .. count)
                --                end

                if self.pumpIsStarted then
                    if self.fillObject ~= nil then
                        if self.fillDirection == HoseSystemPumpMotor.IN then
                            local objectFillTypes = self.fillObject:getCurrentFillTypes() -- Note for objects this changed! self.fillIsObject and (fillObject.currentFillType == nil and fillObject.fillType or fillObject:getCurrentFillTypes()) or

                            -- isn't below dubble code?
                            if self.fillObject:getFreeCapacity() ~= self.fillObject:getCapacity() then
                                for _, objectFillType in pairs(objectFillTypes) do
                                    if self:allowUnitFillType(self.fillUnitIndex, objectFillType, false) then
                                        local objectFillLevel = self.fillObject:getFillLevel(objectFillType)
                                        local fillLevel = self:getUnitFillLevel(self.fillUnitIndex)

                                        if objectFillLevel > 0 and fillLevel < self:getUnitCapacity(self.fillUnitIndex) then -- self:getCapacity(FillUtil.FILLTYPE_LIQUIDMANURE) then
                                            if self.fillObject.checkPlaneY ~= nil then
                                                -- Ugh! edit this when done with the raycast stuff on the hose script
                                                local lastGrabPoint, _ = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[HoseSystemConnectorReference:getFillableVehicle(self.currentGrabPointIndex, #reference.hoseSystem.grabPoints)])

                                                if not HoseSystem:getIsConnected(lastGrabPoint.state) then

                                                    local _, y, _ = getWorldTranslation(lastGrabPoint.raycastNode)
                                                    --
                                                    --                                                    isSucking, y = self.fillObject:checkPlaneY(y)
                                                    if reference.hoseSystem.lastRaycastDistance ~= 0 then
                                                        isSucking, _ = self.fillObject:checkPlaneY(y)
                                                    end
                                                else
                                                    isSucking = reference ~= nil
                                                end
                                            else
                                                isSucking = reference ~= nil
                                            end

                                            if self.pumpFillEfficiency.currentScale > 0 then
                                                local deltaFillLevel = math.min((self.pumpFillEfficiency.litersPerSecond * self.pumpFillEfficiency.currentScale) * 0.001 * dt, objectFillLevel)

                                                self:doPump(self.fillObject, objectFillType, deltaFillLevel, self.fillVolumeDischargeInfos[self.pumpMotor.dischargeInfoIndex], self.fillObjectIsObject)
                                            end
                                        else
                                            self:setPumpStarted(false)
                                            -- TODO: Send message to client that object is empty
                                        end
                                    else
                                        self:setPumpStarted(false)
                                        -- TODO: Send message to client that we dont allow fillType
                                    end
                                end
                            else
                                self:setPumpStarted(false)
                                -- TODO: Send message to client that object is empty
                            end
                        else
                            local fillType = self:getUnitLastValidFillType(self.fillUnitIndex)
                            local fillLevel = self:getFillLevel(fillType)

                            -- we checked that the fillObject accepts the fillType already
                            if fillLevel > 0 then
                                local deltaFillLevel = math.min((self.pumpFillEfficiency.litersPerSecond * self.pumpFillEfficiency.currentScale) * 0.001 * dt, fillLevel)

                                self:doPump(self.fillObject, fillType, deltaFillLevel, self.fillVolumeUnloadInfos[self.pumpMotor.unloadInfoIndex], self.fillObjectIsObject)
                            else
                                self:setPumpStarted(false)
                            end
                        end
                    end
                end

                if self.isSucking ~= isSucking then
                    self.isSucking = isSucking
                    g_server:broadcastEvent(IsSuckingEvent:new(self, self.isSucking))
                end

                if self.fillObjectFound then
                    if self.fillObject ~= nil and self.fillObject.checkPlaneY ~= nil then -- we are raycasting a fillplane
                        if self.fillObject.updateShaderPlane ~= nil then
                            self.fillObject:updateShaderPlane(self.pumpIsStarted, self.fillDirection, self.pumpFillEfficiency.litersPerSecond)
                        end
                    end
                end
            end
        end

        if self.isClient then
            if self.fillObjectHasPlane then
                if self.fillObjectFound or self.fillFromFillVolume then
                    self:updateLiquidHoseSystem(true)
                end
            else
                if not self.fillObjectFound and self.pumpIsStarted then
                    self:updateLiquidHoseSystem(false)
                end
            end
        end
    end
end

function HoseSystemConnectorReference:draw()
end

---
-- @param allow
--
function HoseSystemConnectorReference:updateLiquidHoseSystem(allow)
    if self.currentGrabPointIndex ~= nil and self.currentReferenceIndex ~= nil then
        local reference = self.hoseSystemReferences[self.currentReferenceIndex]

        if reference ~= nil then
            local lastGrabPoint, lastHose = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[HoseSystemConnectorReference:getFillableVehicle(self.currentGrabPointIndex, #reference.hoseSystem.grabPoints)], reference.hoseSystem)

            if lastGrabPoint ~= nil and lastHose ~= nil then
                local fillType = self:getUnitLastValidFillType(self.fillUnitIndex)

                lastHose:toggleEmptyingEffect(allow and self.pumpIsStarted and self.fillDirection == HoseSystemPumpMotor.OUT, lastGrabPoint.id > 1 and 1 or -1, lastGrabPoint.id, fillType)
                --if not reference.hoseSystem.grabPoints[self.currentGrabPointIndex].connectable then
                -- hoseSystem.emptyEffects.showEmptyEffects = self.pumpIsStarted and self.fillDirection == HoseSystemPumpMotor.OUT and self:getFillLevel(self.currentFillType) > 0
                --end
            end
        end
    end
end

---
--
function HoseSystemConnectorReference:getIsPlayerInReferenceRange()
    local playerTrans = { getWorldTranslation(g_currentMission.player.rootNode) }
    local playerDistanceSequence = 1.3 -- use 1.3 as hardcoded value for now

    if self.hoseSystemReferences ~= nil then
        for referenceId, reference in pairs(self.hoseSystemReferences) do
            if reference.isUsed and not reference.parkable and reference.hoseSystem ~= nil then
                local trans = { getWorldTranslation(reference.node) }
                local distance = Utils.vector3Length(trans[1] - playerTrans[1], trans[2] - playerTrans[2], trans[3] - playerTrans[3])

                playerDistanceSequence = Utils.getNoNil(reference.inRangeDistance, playerDistanceSequence)

                if distance < playerDistanceSequence then
                    playerDistanceSequence = distance

                    return true, referenceId
                end
            end
        end
    end

    return false, nil
end

---
-- @param object
--
function HoseSystemConnectorReference:getAllowedFillUnitIndex(object)
    if self.fillUnits == nil then
        return 0
    end

    for index, fillUnit in pairs(self.fillUnits) do
        if fillUnit.currentFillType ~= FillUtil.FILLTYPE_UNKNOWN then
            if object:allowFillType(fillUnit.currentFillType) then
                return index
            end
        else
            local fillTypes = self:getUnitFillTypes(index)

            for fillType, bool in pairs(fillTypes) do
                -- check if object accepts any of our fillTypes
                if object:allowFillType(fillType) then
                    return index
                end
            end
        end
    end

    return 0
end

---
--
function HoseSystemConnectorReference:getValidFillObject()
    self.currentReferenceIndex = nil
    self.currentGrabPointIndex = nil

    self.currentReferenceIndex, self.currentGrabPointIndex = self:getConnectedReference()

    if self.isServer then
        if self:getFillMode() == self.pumpMotorFillMode then
            -- clean tables/bools
            self.fillObject = nil
            self.fillObjectFound = false
            self.fillObjectIsObject = false -- to check if we not pump to a vehicle
            self.fillObjectHasPlane = false
            self.fillFromFillVolume = false
            self.fillUnitIndex = 0
        end

        if self.currentGrabPointIndex ~= nil and self.currentReferenceIndex ~= nil then
            local reference = self.hoseSystemReferences[self.currentReferenceIndex]

            if reference ~= nil then
                local lastGrabPoint, _ = self:getLastGrabpointRecursively(reference.hoseSystem.grabPoints[HoseSystemConnectorReference:getFillableVehicle(self.currentGrabPointIndex, #reference.hoseSystem.grabPoints)])

                if lastGrabPoint ~= nil then
                    -- check if the last grabPoint is connected
                    if HoseSystem:getIsConnected(lastGrabPoint.state) and not lastGrabPoint.connectable then
                        local lastVehicle = HoseSystemReferences:getReferenceVehicle(lastGrabPoint.connectorVehicle)
                        local lastReference = lastVehicle.hoseSystemReferences[lastGrabPoint.connectorRefId]

                        if lastReference ~= nil and lastVehicle ~= nil and lastVehicle.grabPoints == nil then -- checks if it's not a hose!
                            if lastReference.isUsed and lastReference.flowOpened and lastReference.isLocked then
                                if lastReference.isObject or SpecializationUtil.hasSpecialization(Fillable, lastVehicle.specializations) then
                                    -- check fill units to allow
                                    local allowedFillUnitIndex = self:getAllowedFillUnitIndex(lastVehicle)

                                    if allowedFillUnitIndex ~= 0 then
                                        if self:getFillMode() ~= self.pumpMotorFillMode then
                                            self:setFillMode(self.pumpMotorFillMode)
                                        end

                                        -- we can pump
                                        self.fillObjectFound = true
                                        self.fillObjectIsObject = lastReference.isObject
                                        self.fillObject = lastVehicle
                                        self.fillUnitIndex = allowedFillUnitIndex
                                    end
                                end
                            end
                        end
                    else
                        if HoseSystem:getIsDetached(lastGrabPoint.state) then -- don't lookup when the player picks up the hose from the pit
                            -- check what the lastGrabPoint has on it's raycast
                            local hoseSystem = reference.hoseSystem

                            if hoseSystem ~= nil then
                                if hoseSystem.lastRaycastDistance ~= 0 then
                                    if hoseSystem.lastRaycastObject ~= nil then -- or how i called it
                                        local allowedFillUnitIndex = self:getAllowedFillUnitIndex(hoseSystem.lastRaycastObject)

                                        if allowedFillUnitIndex ~= 0 then
                                            -- we have something else to pump with
                                            if self:getFillMode() ~= self.pumpMotorFillMode then
                                                self:setFillMode(self.pumpMotorFillMode)
                                            end

                                            -- we can pump
                                            self.fillObjectFound = true
                                            self.fillObject = hoseSystem.lastRaycastObject
                                            self.fillUnitIndex = allowedFillUnitIndex

                                            if self.fillObject.checkPlaneY ~= nil then
                                                self.fillObjectHasPlane = true
                                                self.fillObjectIsObject = true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if self.lastFillObjectFound ~= self.fillObjectFound or self.lastFillFromFillVolume ~= self.fillFromFillVolume or self.lastFillUnitIndex ~= self.fillUnitIndex or self.lastFillObjectHasPlane ~= self.fillObjectHasPlane then
            g_server:broadcastEvent(SendUpdateOnFillEvent:new(self, self.fillObjectFound, self.fillFromFillVolume, self.fillUnitIndex, self.fillObjectHasPlane))

            self.lastFillUnitIndex = self.fillUnitIndex
            self.lastFillObjectFound = self.fillObjectFound
            self.lastFillFromFillVolume = self.fillFromFillVolume
            self.lastFillObjectHasPlane = self.fillObjectHasPlane
        end
    end
end

---
-- @param grabPoint
-- @param hoseSystem
--
function HoseSystemConnectorReference:getLastGrabpointRecursively(grabPoint, hoseSystem)
    if grabPoint ~= nil then
        if grabPoint.connectorVehicle ~= nil then
            if grabPoint.connectorVehicle.grabPoints ~= nil then
                for i, connectorGrabPoint in pairs(grabPoint.connectorVehicle.grabPoints) do
                    if connectorGrabPoint ~= nil then
                        local reference = HoseSystemReferences:getReference(grabPoint.connectorVehicle, grabPoint.connectorRefId, grabPoint)

                        if connectorGrabPoint ~= reference then
                            self:getLastGrabpointRecursively(connectorGrabPoint, reference.hoseSystem)
                        end
                    end
                end
            end
        end

        return grabPoint, hoseSystem
    end

    return nil, nil
end

---
-- @param index
-- @param max
--
function HoseSystemConnectorReference:getFillableVehicle(index, max)
    return index > 1 and 1 or max
end

-- Todo: Moved to version 1.1
-- Todo: but what if we have more? Can whe pump with multiple hoses? Does that lower the pumpEfficiency or increase the throughput? There is a cleaner way todo this.
---
--
function HoseSystemConnectorReference:getConnectedReference()
    if self.hoseSystemReferences ~= nil then
        for referenceIndex, reference in pairs(self.hoseSystemReferences) do
            if reference.isUsed and reference.flowOpened and reference.isLocked then
                if reference.hoseSystem ~= nil and reference.hoseSystem.grabPoints ~= nil then
                    for grabPointIndex, grabPoint in pairs(reference.hoseSystem.grabPoints) do
                        if HoseSystem:getIsConnected(grabPoint.state) then
                            if grabPoint.connectorVehicle == self then
                                return referenceIndex, grabPointIndex
                            end
                        end
                    end
                end
            end
        end
    end

    return nil, nil
end

---
-- @param index
-- @param state
-- @param force
-- @param noEventSend
--
function HoseSystemConnectorReference:toggleLock(index, state, force, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and not reference.parkable and reference.isLocked ~= state or force then
        HoseSystemReferenceLockEvent.sendEvent(self, index, state, force, noEventSend)

        if reference.lockAnimationName ~= nil then
            local dir = state and 1 or -1
            local shouldPlay = force or not self:getIsAnimationPlaying(reference.lockAnimationName)

            if shouldPlay then
                self:playAnimation(reference.lockAnimationName, dir, nil, true)
                reference.isLocked = state
            end
        else
            reference.isLocked = state
        end
    end
end

---
-- @param index
-- @param state
-- @param force
-- @param noEventSend
--
function HoseSystemConnectorReference:toggleManureFlow(index, state, force, noEventSend)
    local reference = self.hoseSystemReferences[index]

    if reference ~= nil and not reference.parkable and reference.flowOpened ~= state or force then
        HoseSystemReferenceManureFlowEvent.sendEvent(self, index, state, force, noEventSend)

        if reference.manureFlowAnimationName ~= nil then
            local dir = state and 1 or -1
            local shouldPlay = force or not self:getIsAnimationPlaying(reference.manureFlowAnimationName)

            if shouldPlay then
                self:playAnimation(reference.manureFlowAnimationName, dir, nil, true)
                reference.flowOpened = state
            end
        else
            reference.flowOpened = state
        end
    end
end

---
-- @param index
-- @param state
-- @param noEventSend
--
function HoseSystemConnectorReference:setIsUsed(index, state, hoseSystem, noEventSend)
    if self.hoseSystemReferences ~= nil then
        local reference = self.hoseSystemReferences[index]

        if reference ~= nil and reference.isUsed ~= state then
            HoseSystemReferenceIsUsedEvent.sendEvent(self, index, state, hoseSystem, noEventSend)

            reference.isUsed = state
            reference.hoseSystem = hoseSystem

            if not reference.parkable then
                if reference.lockAnimationName == nil then
                    self:toggleLock(index, state, true, true)
                end

                if reference.manureFlowAnimationName == nil then
                    self:toggleManureFlow(index, state, true, true)
                end

                -- When detaching while on gameload we do need to sync the animations
                if not state then
                    if reference.isLocked then
                        self:toggleLock(index, not reference.isLocked, false, true)
                    end

                    if reference.flowOpened then
                        self:toggleManureFlow(index, not reference.flowOpened, false, true)
                    end
                end
            end

            if reference.parkable and reference.parkAnimationName ~= nil then
                local dir = state and 1 or -1

                if not self:getIsAnimationPlaying(reference.parkAnimationName) then
                    self:playAnimation(reference.parkAnimationName, dir, nil, true)
                end
            end
        end
    end
end

---
--
function HoseSystemConnectorReference:getIsOverloadingAllowed()
    return false
end