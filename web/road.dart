import 'dart:html';
import "dart:async";
import 'dart:convert' show JSON;
import 'package:three/three.dart';
import 'package:three/extras/font_utils.dart' as FontUtils;
import 'package:three/extras/image_utils.dart' as ImageUtils;
import 'package:three/extras/controls/trackball_controls.dart';

Element container;

PerspectiveCamera camera;
Scene scene;
WebGLRenderer renderer;

Mesh fontmesh;
Mesh cube;

TrackballControls controls;

Future loadFonts() => Future.wait(
    ["fonts/helvetiker_regular.json"]
    .map((path) => HttpRequest.getString(path).then((data) {
      FontUtils.loadFace(JSON.decode(data));
    })));

void main() {

  //loadFonts().then((_) {
    init();
    animate(0);
  //});
}

void init() {

  container = new Element.tag('div');

  document.body.nodes.add( container );

  initSceneAndAddCamera();

//  addFontMeshToScene();
  
  var geometry = new CubeGeometry( 1200.0, 25.0, 200.0 );
  var material = new MeshBasicMaterial( map: ImageUtils.loadTexture( 'textures/roadv01.jpg' ));

  cube = new Mesh( geometry, material);
  cube.rotation.x += 0.10;
  scene.add(cube);

  renderer = new WebGLRenderer();
  renderer.setSize( window.innerWidth, window.innerHeight );

  container.nodes.add( renderer.domElement );

  window.onResize.listen(onWindowResize);
    
  controls = new TrackballControls(camera, renderer.domElement);
  controls.rotateSpeed = 0.5;
  //controls.movementSpeed = 2;
  
}

void addFontMeshToScene() {
  var fontshapes = FontUtils.generateShapes("Hello world");
  
  MeshBasicMaterial fontmaterial = new MeshBasicMaterial(color: 0xff0000, side: DoubleSide);
  
  ShapeGeometry fontgeometry = new ShapeGeometry(fontshapes, curveSegments: 20);
  
  fontmesh = new Mesh(fontgeometry, fontmaterial);
  
  scene.add(fontmesh);
}

void initSceneAndAddCamera() {
  scene = new Scene();
  
  camera = new PerspectiveCamera( 50.0, window.innerWidth / window.innerHeight, 1.0, 10000.0 );
  camera.position.z = 1200.0;
  
  scene.add(camera);
}

onWindowResize(e) {

  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();

  renderer.setSize( window.innerWidth, window.innerHeight );

}

animate(num time) {

  window.requestAnimationFrame( animate );

  //fontmesh.rotation.x += 0.005;
  //fontmesh.rotation.y += 0.01;
  
  //cube.rotation.x += 0.005;

  controls.update();

  renderer.render( scene, camera );

}