package;

import kha.Framebuffer;
import kha.Scheduler;
import kha.System;
import kha.Color;
import kha.Shaders;
import kha.input.Keyboard;
import kha.input.KeyCode;
import kha.graphics4.PipelineState;
import kha.graphics4.VertexStructure;
import kha.graphics4.VertexBuffer;
import kha.graphics4.IndexBuffer;
import kha.graphics4.VertexData;
import kha.graphics4.Usage;
import kha.graphics4.ConstantLocation;
import kha.math.FastMatrix4;
import kha.math.FastVector3;
import kha.math.FastVector4;

import EntityMaker.Entity;

typedef GraphicsData = {
	@:optional var vertices:Array<Float>;
	@:optional var indices:Array<Int>;
	@:optional var vertexBuffer:VertexBuffer;
	@:optional var indexBuffer:IndexBuffer;
	@:optional var pipeline:PipelineState;
	@:optional var mvp:FastMatrix4;
	@:optional var mvpID:ConstantLocation;
}

typedef People = {
	> Entity,
	var action:Int;
}

class Game {
	var graphicsData:GraphicsData;

	var moveUp = false;
	var moveDown = false;
	var moveLeft = false;
	var moveRight = false;

	var copterLookLeft = true;
	var copterRotationSpeed = Math.PI/50;
	var copterMaxRotation = Math.PI/6;

	var mountains:Entity;
	var copter:Entity;
	var buildings:Array<Entity>;
	var people:Array<People>;
	var entities:Array<Entity>;

	public function new() {
		graphicsData = {};
		var structure = new VertexStructure();
		structure.add("pos", VertexData.Float2);
		graphicsData.pipeline = new PipelineState();
		graphicsData.pipeline.inputLayout = [structure];
		graphicsData.pipeline.fragmentShader = Shaders.simple_frag;
		graphicsData.pipeline.vertexShader = Shaders.simple_vert;
		graphicsData.pipeline.compile();

		graphicsData.mvpID = graphicsData.pipeline.getConstantLocation("MVP");
		var ratio = 1600/900;
		var projection = FastMatrix4.orthogonalProjection(-1.0*ratio, 1.0*ratio, -1.0, 1.0, 0.1, 100.0);
		var view = FastMatrix4.lookAt(new FastVector3(0, 0, 1), new FastVector3(0, 0, 0), new FastVector3(0, 1, 0));
		var model = FastMatrix4.identity();
		graphicsData.mvp = FastMatrix4.identity();
		graphicsData.mvp = graphicsData.mvp.multmat(projection);
		graphicsData.mvp = graphicsData.mvp.multmat(view);
		graphicsData.mvp = graphicsData.mvp.multmat(model);

		graphicsData.vertices = new Array<Float>();
		graphicsData.indices = new Array<Int>();

		createLevel();

		graphicsData.vertexBuffer = new VertexBuffer(
			Std.int(graphicsData.vertices.length / 2),
			structure,
			Usage.DynamicUsage
		);
		
		var vbData = graphicsData.vertexBuffer.lock();
		for (i in 0...vbData.length) {
			vbData.set(i, graphicsData.vertices[i]);
		}
		graphicsData.vertexBuffer.unlock();

		graphicsData.indexBuffer = new IndexBuffer(
			graphicsData.indices.length,
			Usage.StaticUsage
		);
		
		var iData = graphicsData.indexBuffer.lock();
		for (i in 0...iData.length) {
			iData[i] = graphicsData.indices[i];
		}
		graphicsData.indexBuffer.unlock();

		Keyboard.get().notify(onKeyDown, onKeyUp);
		System.notifyOnRender(render);
		Scheduler.addTimeTask(update, 0, 1 / 60);
	}

	function update(): Void {
		if (moveLeft) {
			mountains.x += 0.01;
			for (b in buildings) {
				b.x += 0.01;
			}
			for (p in people) {
				p.x += 0.01;
			}
		}
		else if (moveRight) {
			mountains.x -= 0.01;
			for (b in buildings) {
				b.x -= 0.01;
			}
			for (p in people) {
				p.x -= 0.01;
			}
		}
		if (moveLeft || moveRight) {
			copter.rotation += copterRotationSpeed;
			if (copter.rotation > copterMaxRotation) {
				copter.rotation = copterMaxRotation;
			}
		}
		else {
			copter.rotation -= copterRotationSpeed;
			if (copter.rotation < 0) {
				copter.rotation = 0;
			}
		}
		if (moveUp) {
			copter.y += 0.01;
		}
		else if (moveDown) {
			copter.y -= 0.01;
		}
		copter.scale = copterLookLeft ? 1.0 : -1.0;
		for (p in people) {
			var distance = Math.abs(copter.x - p.x);
			if (distance < 0.75) {
				if (copter.y < -0.9) {
					p.action = 2;
				}
				else {
					p.action = 1;
				}
			}
			else {
				p.action = 0;
			}
			if (p.action == 0) {
				p.y = -0.95;
			}
			else if (p.action == 1) {
				p.y = -0.95 + Math.abs(Math.sin(System.time*10)*0.025);
			}
			else if (p.action == 2) {
				if (p.y > -0.95) {
					p.y -= 0.01;
				}
				else if (distance > 0.1) {
					p.x += (copter.x < p.x) ? -0.01 : 0.01;
				}
			}
		}

		for (e in entities) {
			updateEntityVertexBuffer(e);
		}
	}

	function render(frame: Framebuffer): Void {
		var g = frame.g4;
    g.begin();
		g.clear(Color.Black);

		g.setVertexBuffer(graphicsData.vertexBuffer);
		g.setIndexBuffer(graphicsData.indexBuffer);
		g.setPipeline(graphicsData.pipeline);
		g.setMatrix(graphicsData.mvpID, graphicsData.mvp);
		g.drawIndexedVertices();

		g.end();
	}

	function updateEntityVertexBuffer(e:Entity) {
		var model = FastMatrix4.identity();
		model = model.multmat(FastMatrix4.scale(e.scale, 1.0, 1.0));
		model = model.multmat(FastMatrix4.translation(e.x, e.y, 0.0));
		model = model.multmat(FastMatrix4.rotationZ(e.rotation));
		var n = e.vertexStart;
		var vbData = graphicsData.vertexBuffer.lock();
		while (n < (e.vertexStart + e.vertexCount)) {
			var v = model.multvec(new FastVector4(graphicsData.vertices[n], graphicsData.vertices[n + 1]));
			vbData.set(n, v.x);
			vbData.set(n+1, v.y);
			n += 2;
		}
		graphicsData.vertexBuffer.unlock();
	}

    function onKeyDown(key:Int) {
        if (key == KeyCode.Up) {
			moveUp = true;
		} 
        else if (key == KeyCode.Down) {
			moveDown = true;
		}
        else if (key == KeyCode.Left)  {
			moveLeft = true;
			copterLookLeft = true;
		}
        else if (key == KeyCode.Right) {
			moveRight = true;
			copterLookLeft = false;
		}
    }

    function onKeyUp(key:Int) {
        if (key == KeyCode.Up) moveUp = false;
        else if (key == KeyCode.Down) moveDown = false;
        else if (key == KeyCode.Left) moveLeft = false;
        else if (key == KeyCode.Right) moveRight = false;
	}

	function createLevel() {
		var screenWidth = 2*16/9;
		mountains = EntityMaker.makeMountain(graphicsData, 5, screenWidth*5);
		mountains.x = -screenWidth/2;
		copter = EntityMaker.makeCopter(graphicsData);
		buildings = new Array<Entity>();
		var px = screenWidth/3;
		for (i in 0...5) {
			var b = EntityMaker.makeBuilding(graphicsData);
			b.x = px;// + Math.random() * 1.0 - 0.5;
			b.y = -0.9;
			buildings.push(b);
			px += screenWidth;
		}
		people = new Array<People>();
		px = screenWidth/3;
		for (i in 0...buildings.length) {
			var e = EntityMaker.makePeople(graphicsData);
			people.push({ 
				indiceStart: e.indiceStart,
				indiceCount: e.indiceCount,
				vertexStart: e.vertexStart,
				vertexCount: e.vertexCount,
				rotation: e.rotation,
				scale: e.scale,
				x: px,
				y: -0.95,
				action: 0
			});
			px += screenWidth;
		}
		entities = [ mountains, copter ];
		entities = entities.concat(buildings);
		entities = entities.concat(people);
	}
}
