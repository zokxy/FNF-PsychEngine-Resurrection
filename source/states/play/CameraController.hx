package states.play;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.math.FlxMath;
import backend.ClientPrefs;
import objects.Character;

class CameraController
{
	public var game:FlxCamera;
	public var hud:FlxCamera;
	public var other:FlxCamera;
	public var follow:FlxObject;

	public var defaultZoom:Float = 1.05;
	public var zooming:Bool = false;
	public var zoomingMult:Float = 1;
	public var zoomingDecay:Float = 1;
	public var speed:Float = 1;
	public var forcedPos:Bool = false;
	public var frozen:Bool = false;

	public function new(gameCam:FlxCamera)
	{
		game = gameCam;
		hud = new FlxCamera();
		other = new FlxCamera();
		hud.bgColor.alpha = 0;
		other.bgColor.alpha = 0;

		FlxG.cameras.add(hud, false);
		FlxG.cameras.add(other, false);

		follow = new FlxObject();
	}

	public function init(x:Float, y:Float, ?prev:FlxObject):Void
	{
		if (prev != null)
			follow = prev;
		else
			follow.setPosition(x, y);

		game.follow(follow, LOCKON, 0);
		game.zoom = defaultZoom;
		game.snapToTarget();
	}

	public function updateFollow(rate:Float, active:Bool):Void
	{
		game.followLerp = (active && !frozen) ? 0.04 * speed * rate : 0;
	}

	public function updateZoom(elapsed:Float, playbackRate:Float):Void
	{
		if (zooming)
		{
			game.zoom = CoolUtil.expLerp(game.zoom, defaultZoom, 3.125 * zoomingDecay * playbackRate, elapsed);
			hud.zoom = CoolUtil.expLerp(hud.zoom, 1, 3.125 * zoomingDecay * playbackRate, elapsed);
		}
	}

	public function bop(gameZoom:Float = 0.015, hudZoom:Float = 0.03):Void
	{
		if (zooming && game.zoom < 1.35 && ClientPrefs.data.camZooms)
		{
			game.zoom += gameZoom * zoomingMult;
			hud.zoom += hudZoom * zoomingMult;
		}
	}

	public function focus(char:Character, baseX:Float, baseY:Float, offset:Array<Float>, flipX:Bool = false):Void
	{
		if (char == null) return;
		var mid = char.getMidpoint();
		follow.setPosition(
			mid.x + baseX + (flipX ? -char.cameraPosition[0] : char.cameraPosition[0]) + offset[0],
			mid.y + baseY + char.cameraPosition[1] + offset[1]
		);
		mid.put();
	}
}