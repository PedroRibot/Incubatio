import numpy as np
import transforms3d as t3d
import OpenGL.GL as gl
import ctypes
import logging
import time

from skeleton import Skeleton

class Visualization():
    def __init__(self, skeleton, vertexCode, fragmentCode):
        self.skeleton = skeleton
        self.vertexCode = vertexCode
        self.fragmentCode = fragmentCode
        self.resolution = [1280.0, 720.0]
        
        #self.jointCount = skeleton.getJointCount()
        #self.edgeCount = skeleton.getEdgeCount()
        
        self.jointCount = 23
        self.edgeCount = 22
        self.objectCount = 10;
        
        self.shader_jointCount = 23;
        self.shader_edgeCount = 22;
        self.shader_objectCount = 10;
        
        self.skelPosition = np.array([0.0, 0.0, 0.0])
        
        # camera settings
        self.camPosition = np.array([1.0, 0.0, 0.0])
        self.camAngle = 45.0
        
        # light settings
        self.lightPosition = np.array([1.0, 0.0, 0.0])
        self.shadowSmooth = 16.0;
        self.shadowStrength = 0.0;
        
        # background settings
        self.bgColor = np.array([0.0, 0.0, 0.0])
        self.bgOcclusionColor = np.array([0.0, 0.0, 0.0])
        
        # fog settings
        self.fogMinDist = 99.0
        self.fogMaxDist = 100
        
        # skeleton joint settings
        self.jointColor = np.array([1.0, 1.0, 1.0])
        self.jointAmbientScale = 1.0
        self.jointDiffuseScale = 1.0
        self.jointSpecularScale = 1.0
        self.jointSpecularPow = 20.0
        self.jointOcclusionScale = 1.0
        self.jointOcclusionRange = 1.0
        self.jointOcclusionResolution = 1.0
        self.jointOcclusionColor = np.array([0.0, 0.0, 0.0])
        
        self.jointPrimitives = np.zeros((self.jointCount), dtype=np.int32) - 1
        self.jointSizes = np.ones((self.jointCount, 3)) * 0.1
        self.jointRoundings = np.ones((self.jointCount)) * 0.01
        self.jointSmoothings = np.ones((self.jointCount)) * 0.01
        
        # skeleton edge settings
        self.edgeColor = np.array([1.0, 1.0, 1.0])
        self.edgeAmbientScale = 1.0
        self.edgeDiffuseScale = 1.0
        self.edgeSpecularScale = 1.0
        self.edgeSpecularPow = 20.0
        self.edgeOcclusionScale = 1.0
        self.edgeOcclusionRange = 1.0
        self.edgeOcclusionResolution = 1.0
        self.edgeOcclusionColor = np.array([0.0, 0.0, 0.0])
        
        self.edgePrimitives = np.zeros((self.edgeCount), dtype=np.int32) - 1
        self.edgeSizes = np.ones((self.edgeCount, 3))
        self.edgeSizes[:, 0] *= 0.01
        self.edgeSizes[:, 1] *= 0.01
        self.edgeSizes[:, 2] *= 1.0
        self.edgeRoundings = np.ones((self.jointCount)) * 0.01
        self.edgeSmoothings = np.ones((self.edgeCount)) * 0.01

        # object settings
        self.objectColors = np.ones((self.objectCount, 3))
        self.objectAmbientScales = np.ones((self.objectCount))
        self.objectDiffuseScales = np.ones((self.objectCount))
        self.objectSpecularScales = np.ones((self.objectCount))
        self.objectSpecularPows = np.ones((self.objectCount)) * 20.0
        self.objectOcclusionScales = np.ones((self.objectCount))
        self.objectOcclusionRanges = np.ones((self.objectCount))
        self.objectOcclusionResolutions = np.ones((self.objectCount))
        self.objectOcclusionColors = np.zeros((self.objectCount, 3))
        
        self.objectFrequencies = np.zeros((self.objectCount, 3))
        self.objectAmplitudes = np.zeros((self.objectCount, 3))
        self.objectPhases = np.zeros((self.objectCount, 3))

        self.objectPrimitives = np.zeros((self.objectCount), dtype=np.int32) - 1
        self.objectSizes = np.ones((self.objectCount, 3)) * 0.01
        self.objectRoundings = np.ones((self.objectCount)) * 0.01
        self.objectSmoothings = np.ones((self.objectCount)) * 0.01
        self.objectPositions  = np.zeros((self.objectCount, 3))
        self.objectRotations  = np.zeros((self.objectCount, 4))
        self.objectRotations[:, 1] = 1.0
        self.objectTransforms = np.zeros((self.objectCount, 4, 4))
        
        for oI in range(self.objectCount):
            self.updateObjectTransform(oI)

        # combined smoothing factors
        self.jointEdgeSmoothing = 0.01
        self.skelObjectSmoothing = 0.01
        
    def setupShader(self, gl):
        
        # setup shader
        self.program = gl.glCreateProgram()
        self.vertex = gl.glCreateShader(gl.GL_VERTEX_SHADER)
        self.fragment = gl.glCreateShader(gl.GL_FRAGMENT_SHADER)
        
        logger = logging.getLogger(__name__)

        # Set shaders source
        gl.glShaderSource(self.vertex, self.vertexCode)
        gl.glShaderSource(self.fragment, self.fragmentCode)

        # Compile shaders
        gl.glCompileShader(self.vertex)
        if not gl.glGetShaderiv(self.vertex, gl.GL_COMPILE_STATUS):
            error = gl.glGetShaderInfoLog(self.vertex).decode()
            logger.error("Vertex shader compilation error: %s", error)

        gl.glCompileShader(self.fragment)
        if not gl.glGetShaderiv(self.fragment, gl.GL_COMPILE_STATUS):
            error = gl.glGetShaderInfoLog(self.fragment).decode()
            print(error)
            raise RuntimeError("Fragment shader compilation error")

        gl.glAttachShader(self.program, self.vertex)
        gl.glAttachShader(self.program, self.fragment)
        gl.glLinkProgram(self.program)

        if not gl.glGetProgramiv(self.program, gl.GL_LINK_STATUS):
            print(gl.glGetProgramInfoLog(self.program))
            raise RuntimeError('Linking error')
            
        self.shader_iGlobalTime = gl.glGetUniformLocation(self.program, "iGlobalTime")
        self.shader_iResolution = gl.glGetUniformLocation(self.program, "iResolution")
        
        # camera settings
        self.shader_camPosition = gl.glGetUniformLocation(self.program, "camPosition")
        self.shader_camAngle = gl.glGetUniformLocation(self.program, "camAngle")
        
        # light settings
        self.shader_lightPosition = gl.glGetUniformLocation(self.program, "lightPosition")
        self.shader_shadowSmooth = gl.glGetUniformLocation(self.program, "shadowSmooth")
        self.shader_shadowStrength = gl.glGetUniformLocation(self.program, "shadowStrength")
        
        # background settings
        self.shader_bgColor = gl.glGetUniformLocation(self.program, "bgColor")
        self.shader_bgOcclusionColor = gl.glGetUniformLocation(self.program, "bgOcclusionColor")
        
        # fog settings
        self.shader_fogMinDist = gl.glGetUniformLocation(self.program, "fog_min_dist")
        self.shader_fogMaxDist = gl.glGetUniformLocation(self.program, "fog_max_dist")
        
        # skeleton joint settings
        self.shader_jointColor = gl.glGetUniformLocation(self.program, "jointColor")
        self.shader_jointAmbientScale = gl.glGetUniformLocation(self.program, "jointAmbientScale")
        self.shader_jointDiffuseScale = gl.glGetUniformLocation(self.program, "jointDiffuseScale")
        self.shader_jointSpecularScale = gl.glGetUniformLocation(self.program, "jointSpecularScale")
        self.shader_jointSpecularPow = gl.glGetUniformLocation(self.program, "jointSpecularPow")
        self.shader_jointOcclusionScale = gl.glGetUniformLocation(self.program, "jointOcclusionScale")
        self.shader_jointOcclusionRange = gl.glGetUniformLocation(self.program, "jointOcclusionRange")
        self.shader_jointOcclusionResolution = gl.glGetUniformLocation(self.program, "jointOcclusionResolution")
        self.shader_jointOcclusionColor = gl.glGetUniformLocation(self.program, "jointOcclusionColor")
        
        # skeleton edge settings
        self.shader_edgeColor = gl.glGetUniformLocation(self.program, "edgeColor")
        self.shader_edgeAmbientScale = gl.glGetUniformLocation(self.program, "edgeAmbientScale")
        self.shader_edgeDiffuseScale = gl.glGetUniformLocation(self.program, "edgeDiffuseScale")
        self.shader_edgeSpecularScale = gl.glGetUniformLocation(self.program, "edgeSpecularScale")
        self.shader_edgeSpecularPow = gl.glGetUniformLocation(self.program, "edgeSpecularPow")
        self.shader_edgeOcclusionScale = gl.glGetUniformLocation(self.program, "edgeOcclusionScale")
        self.shader_edgeOcclusionRange = gl.glGetUniformLocation(self.program, "edgeOcclusionRange")
        self.shader_edgeOcclusionResolution = gl.glGetUniformLocation(self.program, "edgeOcclusionResolution")
        self.shader_edgeOcclusionColor = gl.glGetUniformLocation(self.program, "edgeOcclusionColor")
        
        # combined smoothing factors
        self.shader_jointEdgeSmoothing = gl.glGetUniformLocation(self.program, "jointEdgeSmoothing")
        self.shader_skelObjectSmoothing = gl.glGetUniformLocation(self.program, "skelObjectSmoothing")

        gl.glDetachShader(self.program, self.vertex)
        gl.glDetachShader(self.program, self.fragment)

        gl.glUseProgram(self.program)
        
        # setup render quad

        # Build data
        data = np.zeros((4, 2), dtype=np.float32)
        # Request a buffer slot from GPU
        buffer = gl.glGenBuffers(1)

        # Make this buffer the default one
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, buffer)

        stride = data.strides[0]

        offset = ctypes.c_void_p(0)
        loc = gl.glGetAttribLocation(self.program, "position")
        gl.glEnableVertexAttribArray(loc)
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, buffer)
        gl.glVertexAttribPointer(loc, 2, gl.GL_FLOAT, False, stride, offset)

        # drawing quad
        data[...] = [(+1, -1), (+1, +1), (-1, -1), (-1, +1)]

        # Upload CPU data to GPU buffer
        gl.glBufferData(gl.GL_ARRAY_BUFFER, data.nbytes, data, gl.GL_DYNAMIC_DRAW)
        
        
        self.start_time = time.time() 
    
    def render(self, gl):
        gl.glUseProgram(self.program)
        
        elapsed_time = time.time() - self.start_time

        gl.glClear(gl.GL_COLOR_BUFFER_BIT)
        
        gl.glUniform1f(self.shader_iGlobalTime, elapsed_time)
        gl.glUniform2f(self.shader_iResolution, *self.resolution)
        
        # camera settings
        gl.glUniform3f(self.shader_camPosition, *self.camPosition.tolist())
        gl.glUniform1f(self.shader_camAngle, self.camAngle);
        
        # light settings
        gl.glUniform3f(self.shader_lightPosition, *self.lightPosition.tolist())
        gl.glUniform1f(self.shader_shadowSmooth, self.shadowSmooth);
        gl.glUniform1f(self.shader_shadowStrength, self.shadowStrength);

        # background settings
        gl.glUniform3f(self.shader_bgColor, *self.bgColor.tolist())
        gl.glUniform3f(self.shader_bgOcclusionColor, *self.bgOcclusionColor.tolist())
        
        # fog settings
        gl.glUniform1f(self.shader_fogMinDist, self.fogMinDist);
        gl.glUniform1f(self.shader_fogMaxDist, self.fogMaxDist);
        
        # skeleton joint settings
        gl.glUniform3f(self.shader_jointColor, *self.jointColor.tolist())
        gl.glUniform1f(self.shader_jointAmbientScale, self.jointAmbientScale)
        gl.glUniform1f(self.shader_jointDiffuseScale, self.jointDiffuseScale)
        gl.glUniform1f(self.shader_jointSpecularScale, self.jointSpecularScale)
        gl.glUniform1f(self.shader_jointSpecularPow, self.jointSpecularPow)
        gl.glUniform1f(self.shader_jointOcclusionScale, self.jointOcclusionScale)
        gl.glUniform1f(self.shader_jointOcclusionRange, self.jointOcclusionRange)
        gl.glUniform1f(self.shader_jointOcclusionResolution, self.jointOcclusionResolution)
        gl.glUniform3f(self.shader_jointOcclusionColor, *self.jointOcclusionColor.tolist())
        
        jointCount = self.skeleton.getJointCount()

        # joint transforms
        jointTransforms = np.copy(self.skeleton.getJointTransforms())
        for jI in range(jointCount):
            
            jointTransform = jointTransforms[jI]
            
            uniformName = "jointTransforms[" + str(jI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniformMatrix4fv(uniformLoc, 1, gl.GL_FALSE, jointTransform.tolist ())
        
        # joint primitives
        for jI in range(jointCount):
            
            jointPrimitive = self.jointPrimitives[jI]
            uniformName = "jointPrimitives[" + str(jI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1i(uniformLoc, jointPrimitive)

        # joint sizes
        for jI in range(jointCount):
            
            jointSize = self.jointSizes[jI]
            uniformName = "jointSizes[" + str(jI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform3fv(uniformLoc, 1, jointSize.tolist())

        # joint rounding
        for jI in range(jointCount):
            
            jointRounding = self.jointRoundings[jI]
            uniformName = "jointRoundings[" + str(jI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, jointRounding)
                
        # joint smooths
        for jI in range(jointCount):
            
            jointSmooth = self.jointSmoothings[jI]
            uniformName = "jointSmoothings[" + str(jI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, jointSmooth)
            
        # skeleton edge settings
        gl.glUniform3f(self.shader_edgeColor, *self.edgeColor.tolist())
        gl.glUniform1f(self.shader_edgeAmbientScale, self.edgeAmbientScale)
        gl.glUniform1f(self.shader_edgeDiffuseScale, self.edgeDiffuseScale)
        gl.glUniform1f(self.shader_edgeSpecularScale, self.edgeSpecularScale)
        gl.glUniform1f(self.shader_edgeSpecularPow, self.edgeSpecularPow)
        gl.glUniform1f(self.shader_edgeOcclusionScale, self.edgeOcclusionScale)
        gl.glUniform1f(self.shader_edgeOcclusionRange, self.edgeOcclusionRange)
        gl.glUniform1f(self.shader_edgeOcclusionResolution, self.edgeOcclusionResolution)
        gl.glUniform3f(self.shader_edgeOcclusionColor, *self.edgeOcclusionColor.tolist())     
        
        edgeCount = self.skeleton.getEdgeCount()
        
        # edge transforms
        edgeTransforms = np.copy(self.skeleton.getEdgeTransforms())
        for eI in range(edgeCount):
            
            edgeTransform = edgeTransforms[eI]
            uniformName = "edgeTransforms[" + str(eI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniformMatrix4fv(uniformLoc, 1, gl.GL_FALSE, edgeTransform.tolist ())
            
        # edge primitives
        for eI in range(edgeCount):
            
            edgePrimitive = self.edgePrimitives[eI]
            uniformName = "edgePrimitives[" + str(eI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1i(uniformLoc, edgePrimitive)
            
        # edge lengths
        edgeLengths = np.copy(self.skeleton.getEdgeLengths())
        for eI in range(edgeCount):

            edgeLength = edgeLengths[eI]
            uniformName = "edgeLengths[" + str(eI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, edgeLength)
            
        # edge sizes
        for eI in range(edgeCount):

            edgeSize = self.edgeSizes[eI]
            uniformName = "edgeSizes[" + str(eI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform3fv(uniformLoc, 1, edgeSize.tolist())
 
        # edge rounding
        for eI in range(edgeCount):
            
            edgeRounding = self.edgeRoundings[eI]
            uniformName = "edgeRoundings[" + str(eI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, edgeRounding)           
 
        # edge smooths
        for eI in range(edgeCount):
            
            edgeSmooth = self.edgeSmoothings[eI]
            uniformName = "edgeSmoothings[" + str(eI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, edgeSmooth)        
        
        # object colors
        for oI in range(self.objectCount):
            
            objectColor = self.objectColors[oI]
            
            uniformName = "objectColors[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform3f(uniformLoc, *objectColor.tolist())

        # object ambient scales
        for oI in range(self.objectCount):
            
            objectAmbientScale = self.objectAmbientScales[oI]
            
            uniformName = "objectAmbientScales[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, objectAmbientScale)   

        # object diffuse scales
        for oI in range(self.objectCount):
            
            objectDiffuseScale = self.objectDiffuseScales[oI]
            uniformName = "objectDiffuseScales[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, objectDiffuseScale)    
            
        # object specular scales
        for oI in range(self.objectCount):
            
            objectSpecularScale = self.objectSpecularScales[oI]
            uniformName = "objectSpecularScales[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, objectSpecularScale)
            
        # object specular pow
        for oI in range(self.objectCount):
            
            objectSpecularPow = self.objectSpecularPows[oI]
            uniformName = "objectSpecularPows[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, objectSpecularPow)    

        # object occlusion scale
        for oI in range(self.objectCount):
            
            objectOcclusionScale = self.objectOcclusionScales[oI]
            uniformName = "objectOcclusionScales[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, objectOcclusionScale)    

        # object occlusion range
        for oI in range(self.objectCount):
            
            objectOcclusionRange = self.objectOcclusionRanges[oI]
            uniformName = "objectOcclusionRanges[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, objectOcclusionRange)  

        # object occlusion resolution
        for oI in range(self.objectCount):
            
            objectOcclusionResolution = self.objectOcclusionResolutions[oI]
            uniformName = "objectOcclusionResolutions[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, objectOcclusionResolution)  

        # object occlusion colors
        for oI in range(self.objectCount):
            
            objectOcclusionColor = self.objectOcclusionColors[oI]
            uniformName = "objectOcclusionColors[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform3f(uniformLoc, *objectOcclusionColor.tolist())
            
        # object frequencies
        for oI in range(self.objectCount):
            
            objectFrequency = self.objectFrequencies[oI]
            uniformName = "objectFrequencies[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform3fv(uniformLoc, 1, objectFrequency.tolist())
    
        # object amplitudes
        for oI in range(self.objectCount):
            
            objectAmplitude = self.objectAmplitudes[oI]
            uniformName = "objectAmplitudes[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform3fv(uniformLoc, 1, objectAmplitude.tolist())   
            
        # object phases
        for oI in range(self.objectCount):
            
            objectPhase = self.objectPhases[oI]
            uniformName = "objectPhases[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform3fv(uniformLoc, 1, objectPhase.tolist())

        # object transforms
        for oI in range(self.objectCount):
            
            objectTransform = self.objectTransforms[oI]
            uniformName = "objectTransforms[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniformMatrix4fv(uniformLoc, 1, gl.GL_FALSE, objectTransform.tolist ())
            
        # object primitives
        for oI in range(self.objectCount):
            
            objectPrimitive = self.objectPrimitives[oI]
            uniformName = "objectPrimitives[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1i(uniformLoc, objectPrimitive)
        
        # object sizes
        for oI in range(self.objectCount):
            
            objectSize = self.objectSizes[oI]
            uniformName = "objectSizes[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform3fv(uniformLoc, 1, objectSize.tolist())

        # object rounding
        for oI in range(self.objectCount):
            
            objectRounding = self.objectRoundings[oI]
            uniformName = "objectRoundings[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, objectRounding)
                
        # object smooths
        for oI in range(self.objectCount):
            
            objectSmooth = self.objectSmoothings[oI]
            uniformName = "objectSmoothings[" + str(oI) + "]";
            uniformLoc = gl.glGetUniformLocation(self.program, uniformName)
            gl.glUniform1f(uniformLoc, objectSmooth)
        
        # combined smoothing factors
        gl.glUniform1f(self.shader_jointEdgeSmoothing, self.jointEdgeSmoothing)
        gl.glUniform1f(self.shader_skelObjectSmoothing, self.skelObjectSmoothing)


        gl.glDrawArrays(gl.GL_TRIANGLE_STRIP, 0, 4)        
        
    def setCamPosition(self, position):
        self.camPosition = position
        
    def setCamAngle(self, angle):
        self.camAngle = angle   
        
    def setLightPosition(self, position):
        self.lightPosition = position
        
    def setShadowStrength(self, strength):
        self.shadowStrength = strength;
        
    def setShadowSmooth(self, smooth):
        self.shadowSmooth = smooth;
        
    def setShadowSoftHardMixFactor(self, factor):
        self.shadowSoftHardMixFactor = factor;
        
    def setBGColor(self, color):
        self.bgColor = color

    def setBGOcclusionColor(self, color):
        self.bgOcclusionColor = color
        
    def setFogMinDist(self, dist):
        self.fogMinDist = dist
        
    def setFogMaxDist(self, dist):
        self.fogMaxDist = dist
        
    def setJointColor(self, color):
        self.jointColor = color       
        
    def setJointAmbientScale(self, scale):
        self.jointAmbientScale = scale       

    def setJointDiffuseScale(self, scale):
        self.jointDiffuseScale = scale      

    def setJointSpecularScale(self, scale):
        self.jointSpecularScale = scale     
        
    def setJointSpecularPow(self, pow_):
        self.jointSpecularPow = pow_    
    
    def setJointOcclusionScale(self, scale):
        self.jointOcclusionScale = scale            
    
    def setJointOcclusionRange(self, range_):
        self.jointOcclusionRange = range_           
    
    def setJointOcclusionResolution(self, resolution):
        self.jointOcclusionResolution = resolution           

    def setJointOcclusionColor(self, color):
        self.jointOcclusionColor = color     
    
    def setJointPrimitive(self, index, primitive):
        
        if index >= self.shader_jointCount:
            return
        
        self.jointPrimitives[index] = primitive    

    def setJointPrimitives(self, primitive):
        
        self.jointPrimitives[:] = primitive

    def setJointSize(self, index, size):
        
        if index >= self.shader_jointCount:
            return
        
        self.jointSizes[index] = size
        
    def setJointSizes(self, size):
        
        self.jointSizes[:] = size
        
    def setJointRounding(self, index, round):
        
        if index >= self.shader_jointCount:
            return
        
        self.jointRoundings[index] = round
        
    def setJointRoundings(self, round):
        
        self.jointRoundings[:] = round
        
    def setJointSmoothing(self, index, smooth):
        
        if index >= self.shader_jointCount:
            return
        
        self.jointSmoothings[index] = smooth
        
    def setJointSmoothings(self, smooth):
        
        self.jointSmoothings[:] = smooth   

    def setEdgeColor(self, color):
        self.edgeColor = color       
        
    def setEdgeAmbientScale(self, scale):
        self.edgeAmbientScale = scale       

    def setEdgeDiffuseScale(self, scale):
        self.edgeDiffuseScale = scale      

    def setEdgeSpecularScale(self, scale):
        self.edgeSpecularScale = scale     
        
    def setEdgeSpecularPow(self, pow_):
        self.edgeSpecularPow = pow_    
    
    def setEdgeOcclusionScale(self, scale):
        self.edgeOcclusionScale = scale            
    
    def setEdgeOcclusionRange(self, range_):
        self.edgeOcclusionRange = range_           
    
    def setEdgeOcclusionResolution(self, resolution):
        self.edgeOcclusionResolution = resolution         
        
    def setEdgeOcclusionColor(self, color):
        self.edgeOcclusionColor = color     
    
    def setEdgePrimitive(self, index, primitive):
        
        if index >= self.shader_edgeCount:
            return
        
        self.edgePrimitives[index] = primitive    

    def setEdgePrimitives(self, primitive):
        
        self.edgePrimitives[:] = primitive

    def setEdgeSize(self, index, size):
        
        if index >= self.shader_edgeCount:
            return
        
        self.edgeSizes[index] = size
        
    def setEdgeSizes(self, size):
        
        self.edgeSizes[:] = size
        
    def setEdgeRounding(self, index, round):
        
        if index >= self.shader_edgeCount:
            return
        
        self.edgeRoundings[index] = round
        
    def setEdgeRoundings(self, round):
        
        self.edgeRoundings[:] = round
        
    def setEdgeSmoothing(self, index, smooth):
        
        if index >= self.shader_edgeCount:
            return
        
        self.edgeSmoothings[index] = smooth
        
    def setEdgeSmoothings(self, smooth):
        
        self.edgeSmoothings[:] = smooth   

    def setObjectColor(self, index, color):
        
        if index >= self.shader_edgeCount:
            return
        
        self.objectColors[index] = color     
        
    def setObjectColors(self, color):
        
        self.objectColors[:] = color

    def setObjectAmbientScale(self, index, scale):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectAmbientScales[index] = scale   

    def setObjectAmbientScales(self, scale):
        
        self.objectAmbientScales[:] = scale        

    def setObjectDiffuseScale(self, index, scale):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectDiffuseScales[index] = scale       
        
    def setObjectDiffuseScales(self, scale):
        
        self.objectDiffuseScales[:] = scale 

    def setObjectSpecularScale(self, index, scale):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectSpecularScales[index] = scale       
        
    def setObjectSpecularScales(self, scale):
        
        self.objectSpecularScales[:] = scale 

    def setObjectSpecularPow(self, index, pow_):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectSpecularPows[index] = pow_       
        
    def setObjectSpecularPows(self, pow_):
        
        self.objectSpecularPows[:] = pow_ 
        
    def setObjectOcclusionScale(self, index, scale):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectOcclusionScales[index] = scale       
        
    def setObjectOcclusionScales(self, scale):
        
        self.objectOcclusionScales[:] = scale 

    def setObjectOcclusionRange(self, index, range_):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectOcclusionRanges[index] = range_       
        
    def setObjectOcclusionRanges(self, range_):
        
        self.objectOcclusionRanges[:] = range_         
          
    def setObjectOcclusionResolution(self, index, resolution):
         
        if index >= self.shader_objectCount:
            return
         
        self.objectOcclusionResolutions[index] = resolution       
         
    def setObjectOcclusionResolutions(self, resolution):
         
         self.objectOcclusionResolutions[:] = resolution      

    def setObjectOcclusionColor(self, index, color):
         
        if index >= self.shader_objectCount:
            return
         
        self.objectOcclusionColors[index] = color       
         
    def setObjectOcclusionColors(self, color):
         
         self.objectOcclusionColors[:] = color  
         
    def setObjectFrequency(self, index, frequency):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectFrequencies[index] = frequency
        
    def setObjectFrequencies(self, frequency):
        
        self.objectFrequencies[:] = frequency        

    def setObjectAmplitude(self, index, amplitude):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectAmplitudes[index] = amplitude
        
    def setObjectAmplitudes(self, amplitude):
        
        self.objectAmplitudes[:] = amplitude    

    def setObjectPhase(self, index, phase):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectPhases[index] = phase
        
    def setObjectPhases(self, phase):
        
        self.objectPhases[:] = phase 

    def setObjectPrimitive(self, index, primitive):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectPrimitives[index] = primitive    

    def setObjectPrimitives(self, primitive):
        
        self.objectPrimitives[:] = primitive

    def setObjectSize(self, index, size):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectSizes[index] = size
        
    def setObjectSizes(self, size):
        
        self.objectSizes[:] = size
        
    def setObjectRounding(self, index, round):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectRoundings[index] = round
        
    def settObjectRoundings(self, round):
        
        self.objectRoundings[:] = round
        
    def setObjectSmoothing(self, index, smooth):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectSmoothings[index] = smooth
        
    def setObjectSmoothings(self, smooth):
        
        self.objectSmoothings[:] = smooth   

    def setObjectPosition(self, index, position):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectPositions[index] = position    
        
        self.updateObjectTransform(index)
 
    def setObjectRotation(self, index, rotation):
        
        if index >= self.shader_objectCount:
            return
        
        self.objectRotations[index] = rotation    
        
        self.updateObjectTransform(index)       
 
    def updateObjectTransform(self, index):
        
        defaultScale = np.ones((3))
        defaultRot = np.array([1.0, 0.0, 0.0, 0.0])
        defaultPos = np.array([0.0, 0.0, 0.0])
        defaultRotMat = (t3d.quaternions.quat2mat(defaultRot))
        
        objectRotMat = t3d.quaternions.quat2mat(self.objectRotations[index])
        objectTransMat = t3d.affines.compose(self.objectPositions[index], defaultRotMat, defaultScale)
        objectRotMat = t3d.affines.compose(defaultPos, objectRotMat, defaultScale)

        self.objectTransforms[index] = np.transpose(np.matmul(objectRotMat, objectTransMat))
        
    def setJointEdgeSmoothing(self, smoothing):
        
        self.jointEdgeSmoothing = smoothing
        
    def setSkelObjectSmoothing(self, smoothing):
        
        self.skelObjectSmoothing = smoothing
