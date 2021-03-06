package;

import kha.Assets;
import kha.Font;
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

enum PeopleState {
	Wait;
	Jump;
	GoToCopter;
	InsideCopter;
	GoToSavePoint;
	Saved;
}

typedef People = {
	> Entity,
	var state:PeopleState;
	var number:Int;
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
	var copterNbPeople = 0;
	var copterSpeed = 0.04;

	var nbPeopleSaved = 0;
	var finished = false;

	var background:Entity;
	var mountains:Entity;
	var copter:Entity;
	var savePoint:Entity;
	var buildings:Array<Entity>;
	var people:Array<People>;
	var entities:Array<Entity>;

	var font:Font;
	var msg = "---";
	var previousMsg = "---";
	var cameraModel:FastMatrix4;
	var cameraProjection:FastMatrix4;
	var cameraView:FastMatrix4;
	var cameraScale = 0.5;
	var cameraScaleSpeed = 0.025;

	public function new() {
		font = Assets.fonts.Inconsolata_Regular;

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
		cameraProjection = FastMatrix4.orthogonalProjection(-1.0*ratio, 1.0*ratio, -1.0, 1.0, 0.1, 100.0);
		cameraView = FastMatrix4.lookAt(new FastVector3(0, 0, 1), new FastVector3(0, 0, 0), new FastVector3(0, 1, 0));
		cameraModel = FastMatrix4.identity();
		updateCameraMatrix();
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

	function updateCameraMatrix():Void
	{
		graphicsData.mvp = FastMatrix4.identity();
		graphicsData.mvp = graphicsData.mvp.multmat(cameraProjection);
		graphicsData.mvp = graphicsData.mvp.multmat(cameraView);
		graphicsData.mvp = graphicsData.mvp.multmat(cameraModel);
	}

	function update(): Void {
		if (copter.transform.y > -0.85) {
			if (moveLeft) {
				background.transform.x += copterSpeed;
			}
			else if (moveRight) {
				background.transform.x -= copterSpeed;
			}
			if (moveLeft || moveRight) {
				copter.transform.rotation += copterRotationSpeed;
				if (copter.transform.rotation > copterMaxRotation) {
					copter.transform.rotation = copterMaxRotation;
				}
			}
			else {
				copter.transform.rotation -= copterRotationSpeed;
				if (copter.transform.rotation < 0) {
					copter.transform.rotation = 0;
				}
			}
		}
		else {
			copter.transform.rotation -= copterRotationSpeed;
			if (copter.transform.rotation < 0) {
				copter.transform.rotation = 0;
			}
		}

		if (moveUp && copter.transform.y < 0.0) {
			copter.transform.y += 0.02;
			cameraScale -= cameraScaleSpeed;
		}
		else if (moveDown && copter.transform.y > -0.95) {
			copter.transform.y -= 0.02;
			cameraScale += cameraScaleSpeed;
		}
		cameraModel = FastMatrix4.identity();
		cameraModel = cameraModel.multmat(FastMatrix4.translation(0, cameraScale-1, 0)); // 1 == demi height of screen (see orthogonal projection)
		cameraModel = cameraModel.multmat(FastMatrix4.scale(cameraScale, cameraScale, cameraScale));
		cameraModel = cameraModel.multmat(FastMatrix4.rotationZ(copterLookLeft ? -copter.transform.rotation/20 : copter.transform.rotation/20));

		updateCameraMatrix();
		copter.transform.sx = copterLookLeft ? 1.0 : -1.0;
		previousMsg = msg;
		msg = 'bg.x = ${Std.int(background.transform.x*1000)}, ';
		for (p in people) {
			p.currentAnimation = "normal";
			if (p.state == InsideCopter) {
				if (copter.transform.y < -0.9) {
					var distance = getEntitiesDistance(savePoint, copter);
					if (distance < 0.75) {
						p.state = GoToSavePoint;
						p.transform.x = -background.transform.x + p.transform.x;
						p.transform.y = -0.95;
						p.parent = background;
					}
				}
			}
			else if (p.state == GoToSavePoint) {
				var savePointPos = getEntityWorldPosition(savePoint);
				var targetPosX = savePointPos.x + nbPeopleSaved*0.015;
				var peoplePos = getEntityWorldPosition(p);
				var distance = Math.abs(targetPosX - peoplePos.x);
				p.transform.x += (targetPosX < peoplePos.x) ? -0.01 : 0.01;
				if (distance < 0.01) {
					p.state = Saved;
					p.transform.x = savePoint.transform.x + nbPeopleSaved*0.015;
					nbPeopleSaved++;
					finished = (nbPeopleSaved == people.length);
				}
			}
			else if (p.state != Saved) {
				var copterPos = getEntityWorldPosition(copter);
				var targetPosX = copterLookLeft ? copterPos.x - copterNbPeople*0.02 : copterPos.x + copterNbPeople*0.02;
				var peoplePos = getEntityWorldPosition(p);
				var distance = Math.abs(targetPosX -peoplePos.x);
				if (distance < 0.75) {
					if (copter.transform.y < -0.9) {
						p.state = GoToCopter;
					}
					else {
						p.state = Jump;
					}
				}
				else {
					p.state = Wait;
					p.currentAnimation = "moving";
				}
				if (p.state == Wait) {
					p.transform.y = -0.95;
				}
				else if (p.state == Jump) {
					p.transform.y = -0.95 + Math.abs(Math.sin(System.time*10)*0.025);
				}
				else if (p.state == GoToCopter) {
					if (peoplePos.y > -0.95) {
						p.transform.y -= 0.01;
					}
					else if (distance > 0.01) {
						p.transform.x += (targetPosX < peoplePos.x) ? -0.01 : 0.01;
					}
					else {
						p.state = InsideCopter;
						p.number = copterNbPeople;
						p.parent = copter;
						p.transform.x = copterLookLeft ? targetPosX - copter.transform.x : copter.transform.x - targetPosX;
						p.transform.y = 0;
						copterNbPeople++;
					}
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

		var g2 = frame.g2;
		g2.begin(false);
		g2.font = font;
		g2.fontSize = 24;
		g2.color = Color.fromValue(0xFFFF0000);
		g2.drawString('KHAOS: $nbPeopleSaved/${people.length}', 5, 0);
		//g2.drawString(previousMsg, 5, 25);
		//g2.drawString(msg, 5, 50);
		if (finished) {
			g2.fontSize = 100;
			g2.drawString('YOU WIN!!!', 600, 400);
		}
		g2.end();
	}

	function getEntityWorldPosition(e:Entity):FastVector4
	{
		var v = new FastVector4(e.transform.x, e.transform.y);
		if (e.parent != null) {
			v = getMatrix(e.parent).multvec(v);
		}
		return v;
	}

	function getEntitiesDistance(e1:Entity, e2:Entity):Float
	{
		var v1 = getEntityWorldPosition(e1);
		var v2 = getEntityWorldPosition(e2);
		var v = v1.sub(v2);
		return v.length;
	}

	function getMatrix(e:Entity):FastMatrix4
	{
		var m = FastMatrix4.identity();
		m = m.multmat(FastMatrix4.scale(e.transform.sx, e.transform.sy, 1.0));
		m = m.multmat(FastMatrix4.translation(e.transform.x, e.transform.y, 0.0));
		m = m.multmat(FastMatrix4.rotationZ(e.transform.rotation));
		if (e.parent != null) {
			m = getMatrix(e.parent).multmat(m);
		}
		return m;
	}

	function updateEntityVertexBuffer(e:Entity) {
		var model = getMatrix(e);
		var vbData = graphicsData.vertexBuffer.lock();
		var n = 0;
		if (e.model != null) {
			var indexAnimation = Std.int(System.time*10) % e.model.animations[e.currentAnimation].length;
			var frame = e.model.animations[e.currentAnimation][indexAnimation];
			while (n < e.vertexCount) {
				var v = model.multvec(new FastVector4(frame[n]*e.model.scale, frame[n + 1]*e.model.scale));
				vbData.set(e.vertexStart + n, v.x);
				vbData.set(e.vertexStart + n + 1, v.y);
				n += 2;
			}
		}
		else {
			while (n < e.vertexCount) {
				var v = model.multvec(new FastVector4(graphicsData.vertices[n], graphicsData.vertices[n + 1]));
				vbData.set(e.vertexStart + n, v.x);
				vbData.set(e.vertexStart + n + 1, v.y);
				n += 2;
			}
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
		background = EntityMaker.makeEmptyEntity();
		mountains = EntityMaker.makeMountain(graphicsData, 5, screenWidth*5);
		mountains.transform.x = -screenWidth/2;
		mountains.parent = background;

		copter = EntityMaker.makeCopter(graphicsData);

		savePoint = EntityMaker.makeBuilding(graphicsData);
		savePoint.transform.x = -screenWidth/2;
		savePoint.transform.y = -0.9;
		savePoint.parent = background;

		buildings = new Array<Entity>();
		var px = screenWidth/3;
		for (i in 0...5) {
			var b = EntityMaker.makeBuilding(graphicsData);
			b.transform.x = px;
			b.transform.y = -0.9;
			b.parent = background;
			buildings.push(b);
			px += screenWidth;
		}

		people = new Array<People>();
		px = screenWidth/3;
		for (i in 0...buildings.length) {
			var e = EntityMaker.makePeople(graphicsData);
			e.transform.x = px;
			e.transform.y = -0.95;
			people.push({ 
				indiceStart: e.indiceStart,
				indiceCount: e.indiceCount,
				vertexStart: e.vertexStart,
				vertexCount: e.vertexCount,
				transform: e.transform,
				parent: background,
				model: e.model,
				currentAnimation: e.currentAnimation,
				state: Wait,
				number: -1
			});
			px += screenWidth;
		}
		entities = [ mountains, copter, savePoint ];
		entities = entities.concat(buildings);
		entities = entities.concat(people);
	}
}
