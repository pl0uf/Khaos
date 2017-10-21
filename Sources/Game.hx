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
import kha.math.FastVector2;
import kha.math.FastVector3;
import kha.math.FastVector4;

typedef Point = {
	var x:Float;
	var y:Float;
}

typedef Entity = {
	var indiceStart:Int;
	var indiceCount:Int;
	var vertexStart:Int;
	var vertexCount:Int;
	var rotation:Float;
	var scale:Float;
	var x:Float;
	var y:Float;
}

class Game {
	static var LINE_WIDTH = 0.005;

	var vertices:Array<Float>;
	var indices:Array<Int>;
	var vertexBuffer:VertexBuffer;
	var indexBuffer:IndexBuffer;
	var pipeline:PipelineState;
	var mvp:FastMatrix4;
	var mvpID:ConstantLocation;

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
	var people:Array<Entity>;
	var entities:Array<Entity>;

	public function new() {
		var structure = new VertexStructure();
		structure.add("pos", VertexData.Float2);
		pipeline = new PipelineState();
		pipeline.inputLayout = [structure];
		pipeline.fragmentShader = Shaders.simple_frag;
		pipeline.vertexShader = Shaders.simple_vert;
		pipeline.compile();

		mvpID = pipeline.getConstantLocation("MVP");
		var ratio = 1600/900;
		var projection = FastMatrix4.orthogonalProjection(-1.0*ratio, 1.0*ratio, -1.0, 1.0, 0.1, 100.0);
		var view = FastMatrix4.lookAt(new FastVector3(0, 0, 1), new FastVector3(0, 0, 0), new FastVector3(0, 1, 0));
		var model = FastMatrix4.identity();
		mvp = FastMatrix4.identity();
		mvp = mvp.multmat(projection);
		mvp = mvp.multmat(view);
		mvp = mvp.multmat(model);

		vertices = new Array<Float>();
		indices = new Array<Int>();

		mountains = createMountains();
		copter = createEntity(0, 0, createCopterPoints(), 0.1);
		buildings = new Array<Entity>();
		var px = 0.0;
		for (i in 0...50) {
			buildings.push(createEntity(px + Math.random() * 1.0 - 0.5, -0.9, createBuildingPoints(), 0.06));
			px += 1.0;
		}
		people = new Array<Entity>();
		px = 0.0;
		for (i in 0...100) {
			var p = createPeople();
			p.x = px + Math.random() * 1.0 - 0.5;
			p.y = -0.95;
			people.push(p);
			px += 0.11;
		}
		entities = [ mountains, copter ];
		entities = entities.concat(buildings);
		entities = entities.concat(people);

		vertexBuffer = new VertexBuffer(
			Std.int(vertices.length / 2),
			structure,
			Usage.DynamicUsage
		);
		
		var vbData = vertexBuffer.lock();
		for (i in 0...vbData.length) {
			vbData.set(i, vertices[i]);
		}
		vertexBuffer.unlock();

		indexBuffer = new IndexBuffer(
			indices.length,
			Usage.StaticUsage
		);
		
		var iData = indexBuffer.lock();
		for (i in 0...iData.length) {
			iData[i] = indices[i];
		}
		indexBuffer.unlock();

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

		for (e in entities) {
			updateEntityVertexBuffer(e);
		}
	}

	function render(frame: Framebuffer): Void {
		var g = frame.g4;
    g.begin();
		g.clear(Color.Black);

		g.setVertexBuffer(vertexBuffer);
		g.setIndexBuffer(indexBuffer);
		g.setPipeline(pipeline);
		g.setMatrix(mvpID, mvp);
		g.drawIndexedVertices();

		g.end();
	}

	////////////////////////////////////////////////////////////////////////////////////////////////
	function createCopterPoints():Array<Point>
	{
		var pts = [
				{ x: -1.0, y: 0.0 }
			, { x: -0.8, y: 0.25 }
			, { x: -0.1, y: 0.25 }
			, { x: 0.2, y: 0.0 }
			, { x: 0.8, y: 0.0 }
			, { x: 0.9, y: 0.2 }
			, { x: 1.0, y: -0.011 }
			, { x: 0.2, y: -0.1 }
			, { x: -0.1, y: -0.2 }
			, { x: -0.8, y: -0.2 }
			, { x: -1.0, y: 0.0 }
		];
		return pts;
	}

	////////////////////////////////////////////////////////////////////////////////////////////////
	function createBuildingPoints():Array<Point>
	{
		var pts = [
				{ x: -1.0, y: -1.0 }
			, { x: -0.75, y: 0.60 }
			, { x: 0.0, y: 1.0 }
			, { x: 0.75, y: 0.60 }
			, { x: 1.0, y: -1.0 }
			, { x: -1.0, y: -1.0 }
		];
		return pts;
	}

	function createEntity(x:Float, y:Float, pts:Array<Point>, scale:Float):Entity
	{
		var e:Entity = { indiceStart: indices.length, indiceCount: 0, vertexStart: vertices.length, vertexCount: 0, rotation: 0.0, scale: 1.0, x: x, y: y};

		var vert = buildVerticesFromPolyLinesPoints(scale, pts);
		e.vertexCount = vert.length;

		var ind = buildIndicesFromLines(vert);
		e.indiceCount = ind.length;

		vertices = vertices.concat(vert);
		indices = indices.concat(ind);

		return e;		
	}

	function createPeoplePoints():Array<Point>
	{
		return [
			// Head
			{ x: 0.0, y: 1.0 }, { x: 0.2, y: 0.8 },
			{ x: 0.2, y: 0.8 }, { x: 0.0, y: 0.6 },
			{ x: 0.0, y: 0.6 }, { x: -0.2, y: 0.8 },
			{ x: -0.2, y: 0.8 }, { x: 0.0, y: 1.0 },
			// Torso
			{ x: 0.0, y: 0.6 }, { x: 0.11, y: 0.0 },
			// Left arm
			{ x: 0.0, y: 0.4 }, { x: -0.3, y: 0.5 },
			{ x: -0.3, y: 0.5 }, { x: -0.5, y: 0.8 },
			// Right arm
			{ x: 0.0, y: 0.4 }, { x: 0.3, y: 0.5 },
			{ x: 0.3, y: 0.5 }, { x: 0.5, y: 0.8 },
			// Left leg
			{ x: 0.11, y: 0.0 }, { x: -0.2, y: -0.4 },
			{ x: -0.2, y: -0.4 }, { x: -0.3, y: -1.0 },
			{ x: -0.3, y: -1.0 }, { x: -0.35, y: -1.0 },
			// Right leg
			{ x: 0.11, y: 0.0 }, { x: 0.2, y: -0.4 },
			{ x: 0.2, y: -0.4 }, { x: 0.3, y: -1.0 },
			{ x: 0.3, y: -1.0 }, { x: 0.35, y: -1.0 }
		];
	}

	function buildIndicesFromLines(vert:Array<Float>)
	{
		var ind:Array<Int> = [];
		// 2 float per vertex
		// 3 vertices per triangle
		// 2 triangles per line sharing 4 vertices
		var nbLines = Std.int(vert.length/(4*2));
		var n = Std.int(vertices.length/2);
		for (i in 0...nbLines) {
			ind.push(n);
			ind.push(n+1);
			ind.push(n+3);

			ind.push(n);
			ind.push(n+2);
			ind.push(n+3);
			n += 4;
		}
		return ind;
	}

	function createPeople():Entity
	{
		var e:Entity = { indiceStart: indices.length, indiceCount: 0, vertexStart: vertices.length, vertexCount: 0, rotation: 0.0, scale: 1.0, x: 0.0, y: 0.0};

		var vert = buildVerticesFromLinesPoints(0.025, createPeoplePoints());
		e.vertexCount = vert.length;

		var ind = buildIndicesFromLines(vert);
		e.indiceCount = ind.length;

		vertices = vertices.concat(vert);
		indices = indices.concat(ind);
		return e;		
	}

	function createMountains():Entity
	{
		var e:Entity = { indiceStart: indices.length, indiceCount: 0, vertexStart: vertices.length, vertexCount: 0, rotation: 0.0, scale: 1.0, x: -5.0, y: 0.0};

		var mountain = createMountainHeights(5);
		for (i in 0...50) {
			mountain = mountain.concat(createMountainHeights(5));
		}
		var step = 0.03;

		var ind = createIndices(Std.int(vertices.length/2), mountain.length);
		e.indiceCount = ind.length;

		var vert = createVertices(mountain, step);
		e.vertexCount = vert.length;

		vertices = vertices.concat(vert);
		indices = indices.concat(ind);
		return e;
	}

	function createMountainHeights(iteration:Int):Array<Float>
	{
		var mountain = [-0.5, -0.5];
		var p = 0;
		var noise = 0.75;
		while (p < iteration) {
			var i = 0;
			while (i < mountain.length-1) {
				var newPt = (mountain[i] + mountain[i + 1]) / 2 + (Math.random() - 0.5) * noise;
				mountain.insert(i + 1, newPt);
				i += 2;
			}
			noise /= 2;
			p++;
		}
		return mountain;
	}

	function createVertices(heights:Array<Float>, dx:Float):Array<Float>
	{
		var vert:Array<Float> = [];
		var x = 0.0;
		var z = 0.0;
		for (i in 0...heights.length) {
			vert.push(x);
			vert.push(heights[i]);

			vert.push(x);
			vert.push(heights[i]-LINE_WIDTH);

			x += dx;
		}
		return vert;
	}

	function createIndices(start:Int, nbVerts:Int):Array<Int>
	{
		var indices:Array<Int> = [];
		var n = 0;
		for (i in 0...nbVerts - 1) {
			n = i*2 + start;
			indices.push(n);
			indices.push(n+1);
			indices.push(n+3);

			indices.push(n);
			indices.push(n+3);
			indices.push(n+2);
		}
		return indices;
	}

	function updateEntityVertexBuffer(e:Entity) {
		var model = FastMatrix4.identity();
		model = model.multmat(FastMatrix4.scale(e.scale, 1.0, 1.0));
		model = model.multmat(FastMatrix4.translation(e.x, e.y, 0.0));
		model = model.multmat(FastMatrix4.rotationZ(e.rotation));
		var n = e.vertexStart;
		var vbData = vertexBuffer.lock();
		while (n < (e.vertexStart + e.vertexCount)) {
			var v = model.multvec(new FastVector4(vertices[n], vertices[n + 1]));
			vbData.set(n, v.x);
			vbData.set(n+1, v.y);
			n += 2;
		}
		vertexBuffer.unlock();
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

	// From Graphics2.hx drawLine()
	function createLine(x1:Float, y1:Float, x2:Float, y2:Float):Array<Float>
	{
		var vec: FastVector2;
		if (y2 == y1) vec = new FastVector2(0, -1);
		else vec = new FastVector2(1, -(x2 - x1) / (y2 - y1));
		vec.length = LINE_WIDTH;
		var p1 = new FastVector2(x1 + 0.5 * vec.x, y1 + 0.5 * vec.y);
		var p2 = new FastVector2(x2 + 0.5 * vec.x, y2 + 0.5 * vec.y);
		var p3 = p1.sub(vec);
		var p4 = p2.sub(vec);
		
		var vert = [
				p1.x, p1.y
				, p2.x, p2.y
				, p3.x, p3.y
				, p4.x, p4.y
		];
		return vert;
	}

	function buildVerticesFromLinesPoints(scale:Float, pts:Array<Point>):Array<Float>
	{
		var vert = new Array<Float>();
		var i = 0;
		while (i < pts.length - 1) {
			vert = vert.concat(createLine(pts[i].x*scale, pts[i].y*scale, pts[i+1].x*scale, pts[i+1].y*scale));
			i += 2;
		}
		return vert;
	}

	function buildVerticesFromPolyLinesPoints(scale:Float, pts:Array<Point>):Array<Float>
	{
		var vert = new Array<Float>();
		for (i in 0...pts.length - 1) {
			vert = vert.concat(createLine(pts[i].x*scale, pts[i].y*scale, pts[i + 1].x*scale, pts[i + 1].y*scale));
		}
		return vert;
	}
}
