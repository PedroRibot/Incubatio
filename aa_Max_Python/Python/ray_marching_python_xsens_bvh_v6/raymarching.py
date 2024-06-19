#!/usr/bin/env python3

"""
Code from http://www.labri.fr/perso/nrougier/python-opengl/#the-hard-way
"""

import ctypes
import logging

import numpy as np
import OpenGL.GL as gl
from PyQt5.QtWidgets import QApplication
from PyQt5.QtGui import QOpenGLWindow
from PyQt5 import QtCore
import time
import json

import transforms3d as t3d

import threading

from pythonosc import dispatcher
from pythonosc import osc_server

from skeleton import Skeleton
from visualization import Visualization
from osc_control import OscControl
   
"""
Setup Skeleton
"""

joint_settings_file = "joint_settings.json"

with open(joint_settings_file) as f:
    joint_settings = json.load(f)
    
jointFilter = joint_settings["jointFilter"]
jointConnectivity = joint_settings["jointConnectivity"]

skeleton = Skeleton(jointFilter, jointConnectivity)

jointCount = skeleton.getJointCount()
edgeCount = skeleton.getEdgeCount()

jointTransforms = skeleton.getJointTransforms()
edgeTransforms = skeleton.getEdgeTransforms()
edgeLengths = skeleton.getEdgeLengths()


"""
Setup Visualization
"""

vertex_file_path = "shaderVert.glsl"
fragment_file_path = "shaderFrag.glsl"
window_size = [1280, 720]
#window_size = [640, 360]
#window_size = [720, 405]

with open(vertex_file_path) as f:
    vertex_code = f.read()

with open(fragment_file_path) as f:
    fragment_code = f.read()

visualization = Visualization(skeleton, vertex_code, fragment_code)

"""
Osc Control
"""

oscControl = OscControl(skeleton, visualization, "127.0.0.1", 9007)
oscControl.start()

oscControl.fix_root = True

"""
GUI
"""

start_time = time.time()

class MinimalGLWidget(QOpenGLWindow):
    
    def __init__(self, visualization):
        self.visualization = visualization
        self.fullscreen = False
        
        super().__init__()
 
    
    def initializeGL(self):
        
        self.visualization.setupShader(gl)

        self.renderTimer = QtCore.QTimer(self)
        self.renderTimer.setInterval(10)
        self.renderTimer.timeout.connect(self.onRenderTimer)
        self.renderTimer.start()
        
    def onRenderTimer(self):
        
        global start_time

        visualization.render(gl)
        
        self.update()
        
        new_time = time.time()
        
        elapsed_time = new_time-start_time
        
        start_time = new_time
        
        #print("fr ", 1.0 / elapsed_time)

    def keyPressEvent(self, event):
        super(MinimalGLWidget, self).keyPressEvent(event)

        if event.key() == 70: # f-Key
            if self.fullscreen == True:
                self.showNormal()
                self.resize(window_size[0], window_size[1])
                self.fullscreen = False
            else:
                self.showFullScreen()
                self.fullscreen = True

if __name__ == '__main__':
    app = QApplication([])
    widget = MinimalGLWidget(visualization)
    widget.show()
    widget.resize(window_size[0], window_size[1])
    app.exec_()
    
    widget.close()
    oscControl.stop()
    