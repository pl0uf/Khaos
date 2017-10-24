package;

import kha.Assets;
import kha.System;
#if js
import js.html.CanvasElement;
import js.Browser.document;
#end

class Main {
  public static inline var WIDTH:Int = 1600;
  public static inline var HEIGHT:Int = 900;

	public static function main() {
    #if js
    document.documentElement.style.padding = "0";
    document.documentElement.style.margin = "0";
    document.body.style.padding = "0";
    document.body.style.margin = "0";
    var canvas = cast(document.getElementById("khanvas"), CanvasElement);
    canvas.style.display = "block";
    canvas.width = WIDTH;
    canvas.height = HEIGHT;
    #end

		System.init({title: "Khaos", width: WIDTH, height: HEIGHT}, function () {
      Assets.loadEverything(function() {
			  new Game();
		  });
    });
	}
}
