import 'dart:html';
import 'dart:web_gl';
import 'dart:typed_data';
import 'package:vector_math/vector_math.dart';
import 'dart:collection';


class WebGL{
  Program program;
  CanvasElement canvas;
  RenderingContext gl;
  
  Matrix4 _pMatrix;
  Matrix4 _mvMatrix;
  Queue<Matrix4> _mvMatrixStack;
  
  int _aVertexPosition;
  int _aVertexColor;
  UniformLocation _uPMatrix;
  UniformLocation _uMVMatrix;  
  
  double _rSquare = 0.0;
  double _lastTime = 0.0;
  
  var _requestAnimationFrame;  
  
  Buffer planeVertexPositionBuffer;  
  Buffer planeVertexColorBuffer;
  Buffer planeVertexIndexBuffer;

  WebGL(){
    this.canvas = document.getElementById("canvas");
    this.gl = this.canvas.getContext3d();
    initShaders();
    initBuffers();
    
    _mvMatrixStack = new Queue();
    
    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.enable(RenderingContext.DEPTH_TEST);
  }
  
  void _mvPushMatrix() {
    _mvMatrixStack.addFirst(_mvMatrix.clone());
  }

  void _mvPopMatrix() {
    if (0 == _mvMatrixStack.length) {
      throw new Exception("Invalid popMatrix!");
    }
    _mvMatrix = _mvMatrixStack.removeFirst();
  }  
  
  void initShaders(){
    String vsSource = """
    attribute vec3 aVertexPosition;
    attribute vec4 aVertexColor;

    uniform mat4 uMVMatrix;
    uniform mat4 uPMatrix;

    varying vec4 vColor;

    void main(void) {
        gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
        vColor = aVertexColor;
    }
    """;
    
    // fragment shader source code. uColor is our variable that we'll
    // use to animate color
    String fsSource = """
    precision mediump float;
    varying vec4 vColor;

    void main(void) {
        gl_FragColor = vColor;
    }
    """;
    
    Shader vs = gl.createShader(RenderingContext.VERTEX_SHADER);
    gl.shaderSource(vs, vsSource);
    gl.compileShader(vs);
    
    // fragment shader compilation
    Shader fs = gl.createShader(RenderingContext.FRAGMENT_SHADER);
    gl.shaderSource(fs, fsSource);
    gl.compileShader(fs);
    
    // attach shaders to a WebGL program
    program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);
    gl.useProgram(program);
    
    /**
     * Check if shaders were compiled properly. This is probably the most painful part
     * since there's no way to "debug" shader compilation
     */
    if (!gl.getShaderParameter(vs, RenderingContext.COMPILE_STATUS)) { 
      print(gl.getShaderInfoLog(vs));
    }
    
    if (!gl.getShaderParameter(fs, RenderingContext.COMPILE_STATUS)) { 
      print(gl.getShaderInfoLog(fs));
    }
    
    if (!gl.getProgramParameter(program, RenderingContext.LINK_STATUS)) { 
      print(gl.getProgramInfoLog(program));
    }
    
    _aVertexPosition = gl.getAttribLocation(program, "aVertexPosition");
    gl.enableVertexAttribArray(_aVertexPosition);
    
    _aVertexColor = gl.getAttribLocation(program, "aVertexColor");
    gl.enableVertexAttribArray(_aVertexColor);
    
    _uPMatrix = gl.getUniformLocation(program, "uPMatrix");
    _uMVMatrix = gl.getUniformLocation(program, "uMVMatrix");        
  }

  void initBuffers() {
    // variable to store verticies
    List<double> vertices;
    
    // create triangle
    planeVertexPositionBuffer = gl.createBuffer();
    gl.bindBuffer(RenderingContext.ARRAY_BUFFER, planeVertexPositionBuffer);
    
    vertices = [
                // Front face
                -1.0, -1.0,  1.0,
                1.0, -1.0,  1.0,
                1.0,  1.0,  1.0,
                -1.0,  1.0,  1.0,
                
                // Back face
                -1.0, -1.0, -1.0,
                -1.0,  1.0, -1.0,
                1.0,  1.0, -1.0,
                1.0, -1.0, -1.0,
                
                // Top face
                -1.0,  1.0, -1.0,
                -1.0,  1.0,  1.0,
                1.0,  1.0,  1.0,
                1.0,  1.0, -1.0,
                
                // Bottom face
                -1.0, -1.0, -1.0,
                1.0, -1.0, -1.0,
                1.0, -1.0,  1.0,
                -1.0, -1.0,  1.0,
                
                // Right face
                1.0, -1.0, -1.0,
                1.0,  1.0, -1.0,
                1.0,  1.0,  1.0,
                1.0, -1.0,  1.0,
                
                // Left face
                -1.0, -1.0, -1.0,
                -1.0, -1.0,  1.0,
                -1.0,  1.0,  1.0,
                -1.0,  1.0, -1.0,
    ];
    
    gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(vertices), RenderingContext.STATIC_DRAW);
    
    planeVertexColorBuffer = gl.createBuffer();
    gl.bindBuffer(RenderingContext.ARRAY_BUFFER, planeVertexColorBuffer);
    
    List<List<double>> colors2 = [
        [1.0, 0.0, 0.0, 1.0],     // Front face
        [1.0, 1.0, 0.0, 1.0],     // Back face
        [0.0, 1.0, 0.0, 1.0],     // Top face
        [1.0, 0.5, 0.5, 1.0],     // Bottom face
        [1.0, 0.0, 1.0, 1.0],     // Right face
        [0.0, 0.0, 1.0, 1.0],     // Left face
    ];
    // each cube face (6 faces for one cube) consists of 4 points of the same color where each color has 4 components RGBA
    // therefore I need 4 * 4 * 6 long list of doubles
    List<double> unpackedColors = new List.generate(4 * 4 * colors2.length, (int index) {
      // index ~/ 16 returns 0-5, that's color index
      // index % 4 returns 0-3 that's color component for each color
      return colors2[index ~/ 16][index % 4];
    }, growable: false);
    gl.bufferDataTyped(RenderingContext.ARRAY_BUFFER, new Float32List.fromList(unpackedColors), RenderingContext.STATIC_DRAW);
    
    planeVertexIndexBuffer = gl.createBuffer();
    gl.bindBuffer(RenderingContext.ELEMENT_ARRAY_BUFFER, planeVertexIndexBuffer);
    List<int> _cubeVertexIndices = [
         0,  1,  2,    0,  2,  3, // Front face
         4,  5,  6,    4,  6,  7, // Back face
         8,  9, 10,    8, 10, 11, // Top face
        12, 13, 14,   12, 14, 15, // Bottom face
        16, 17, 18,   16, 18, 19, // Right face
        20, 21, 22,   20, 22, 23  // Left face
    ];
    gl.bufferDataTyped(RenderingContext.ELEMENT_ARRAY_BUFFER, new Uint16List.fromList(_cubeVertexIndices), RenderingContext.STATIC_DRAW);
   
  }

  void _setMatrixUniforms() {
    Float32List tmpList = new Float32List(16);
    
    _pMatrix.copyIntoArray(tmpList);
    gl.uniformMatrix4fv(_uPMatrix, false, tmpList);
    
    _mvMatrix.copyIntoArray(tmpList);
    gl.uniformMatrix4fv(_uMVMatrix, false, tmpList);
  }
  
  void render(double time) {
    gl.viewport(0, 0, 800, 800);
    gl.clear(RenderingContext.COLOR_BUFFER_BIT | RenderingContext.DEPTH_BUFFER_BIT);
    
    // field of view is 45°, width-to-height ratio, hide things closer than 0.1 or further than 100
    _pMatrix = makePerspectiveMatrix(radians(45.0), 800 / 800, 0.1, 100.0);
    
    _mvMatrix = new Matrix4.identity();
    _mvMatrix.translate(new Vector3(-1.5, 0.0, -7.0));
    
    _mvPushMatrix();
    _mvMatrix.rotate(new Vector3(1.0, 0.0, 0.0), radians(_rSquare));
    
    gl.bindBuffer(RenderingContext.ARRAY_BUFFER, planeVertexPositionBuffer);
    gl.vertexAttribPointer(_aVertexPosition, 3, RenderingContext.FLOAT, false, 0, 0);
    
    // color
    gl.bindBuffer(RenderingContext.ARRAY_BUFFER, planeVertexColorBuffer);
    gl.vertexAttribPointer(_aVertexColor, 4, RenderingContext.FLOAT, false, 0, 0);
    
    gl.bindBuffer(RenderingContext.ELEMENT_ARRAY_BUFFER, planeVertexIndexBuffer);
    _setMatrixUniforms();
//    gl.drawArrays(RenderingContext.TRIANGLES, 0, 4); // square, start at 0, total 4
    gl.drawElements(RenderingContext.TRIANGLES, 36, RenderingContext.UNSIGNED_SHORT, 0);    
    
    _mvPopMatrix();
    
    // rotate
    double animationStep = time - _lastTime;    
    _rSquare += (75 * animationStep) / 1000.0;
    _lastTime = time;
    
    // keep drawing
    this._renderFrame();    
  }
  
  void start() {
    this._renderFrame();
  }
  
  void _renderFrame() {
    window.requestAnimationFrame((num time) { this.render(time); });
  }
}

void main() {
  WebGL webGL = new WebGL(); 
  webGL.start();
}
