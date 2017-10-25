package;

import kha.math.FastVector2;
import Game.GraphicsData;

typedef Point = {
	var x:Float;
	var y:Float;
}

typedef Transform = {
	var x:Float;
	var y:Float;
	var rotation:Float;
	var sx:Float;
	var sy:Float;
}

typedef Entity = {
	var indiceStart:Int;
	var indiceCount:Int;
	var vertexStart:Int;
	var vertexCount:Int;
	var transform:Transform;
	var parent:Entity;
}

class EntityMaker
{
	static var LINE_WIDTH = 0.005;

  public static function makeCopter(graphicsData:GraphicsData):Entity
  {
    return createEntity(graphicsData, createCopterPoints(), 0.1);
  }

  public static function makeBuilding(graphicsData:GraphicsData):Entity
  {
    return createEntity(graphicsData, createBuildingPoints(), 0.06);
  }

	public static function makePeople(graphicsData:GraphicsData):Entity
	{
		var e:Entity = { indiceStart: graphicsData.indices.length
			, indiceCount: 0
			, vertexStart: graphicsData.vertices.length
			, vertexCount: 0
			, transform: { x: 0, y: 0, rotation: 0, sx: 1.0, sy: 1.0 }
			, parent: null
		};

		var vert = buildVerticesFromLinesPoints(0.025, createPeoplePoints());
		e.vertexCount = vert.length;

		var ind = buildIndicesFromLines(vert, Std.int(graphicsData.vertices.length/2));
		e.indiceCount = ind.length;

		graphicsData.vertices = graphicsData.vertices.concat(vert);
		graphicsData.indices = graphicsData.indices.concat(ind);
		return e;		
	}

	public static function makeMountain(graphicsData:GraphicsData, nbMountains:Int, width:Float):Entity
	{
		var e:Entity = { indiceStart: graphicsData.indices.length
			, indiceCount: 0
			, vertexStart: graphicsData.vertices.length
			, vertexCount: 0
			, transform: { x: 0, y: 0, rotation: 0, sx: 1.0, sy: 1.0 }
			, parent: null
		};

		var mountain = [];
    for (i in 0...nbMountains) {
      mountain = mountain.concat(createMountainHeights(5));
    }
		var step = width/(mountain.length - 1);

		var ind = createIndices(Std.int(graphicsData.vertices.length/2), mountain.length);
		e.indiceCount = ind.length;

		var vert = createVertices(mountain, step);
		e.vertexCount = vert.length;

		graphicsData.vertices = graphicsData.vertices.concat(vert);
		graphicsData.indices = graphicsData.indices.concat(ind);
		return e;
	}

	static function createCopterPoints():Array<Point>
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

	static function createBuildingPoints():Array<Point>
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

	static function createEntity(graphicsData:GraphicsData, pts:Array<Point>, scale:Float):Entity
	{
		var e:Entity = { indiceStart: graphicsData.indices.length
			, indiceCount: 0
			, vertexStart: graphicsData.vertices.length
			, vertexCount: 0
			, transform: { x: 0, y: 0, rotation: 0, sx: 1.0, sy: 1.0 }
			, parent: null
		};

		var vert = buildVerticesFromPolyLinesPoints(scale, pts);
		e.vertexCount = vert.length;

		var ind = buildIndicesFromLines(vert, Std.int(graphicsData.vertices.length/2));
		e.indiceCount = ind.length;

		graphicsData.vertices = graphicsData.vertices.concat(vert);
		graphicsData.indices = graphicsData.indices.concat(ind);

		return e;		
	}

	static function createPeoplePoints():Array<Point>
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

	static function createMountainHeights(iteration:Int):Array<Float>
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

	static function createVertices(heights:Array<Float>, dx:Float):Array<Float>
	{
		var vert:Array<Float> = [];
		var x = 0.0;
		for (i in 0...heights.length) {
			vert.push(x);
			vert.push(heights[i]);

			vert.push(x);
			vert.push(heights[i]-LINE_WIDTH);

			x += dx;
		}
		return vert;
	}

	static function createIndices(start:Int, nbVerts:Int):Array<Int>
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

	static function buildIndicesFromLines(vert:Array<Float>, startIndice:Int)
	{
		var ind:Array<Int> = [];
		// 2 float per vertex
		// 3 vertices per triangle
		// 2 triangles per line sharing 4 vertices
		var nbLines = Std.int(vert.length/(4*2));
		var n = Std.int(startIndice);
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

	// From Graphics2.hx drawLine()
	static function createLine(x1:Float, y1:Float, x2:Float, y2:Float):Array<Float>
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

	static function buildVerticesFromLinesPoints(scale:Float, pts:Array<Point>):Array<Float>
	{
		var vert = new Array<Float>();
		var i = 0;
		while (i < pts.length - 1) {
			vert = vert.concat(createLine(pts[i].x*scale, pts[i].y*scale, pts[i+1].x*scale, pts[i+1].y*scale));
			i += 2;
		}
		return vert;
	}

	static function buildVerticesFromPolyLinesPoints(scale:Float, pts:Array<Point>):Array<Float>
	{
		var vert = new Array<Float>();
		for (i in 0...pts.length - 1) {
			vert = vert.concat(createLine(pts[i].x*scale, pts[i].y*scale, pts[i + 1].x*scale, pts[i + 1].y*scale));
		}
		return vert;
	}

}