package states.play;

import flixel.group.FlxGroup.FlxTypedGroup;
import objects.Character;
import objects.Note;
import objects.StrumNote;
import states.PlayState;
import backend.Song.StrumLineData;

class StrumLine
{
	public var id:Int;
	public var isPlayer:Bool;
	public var cpuControlled:Bool = false;
	public var keysCount:Int;
	public var characters:Array<Character> = null;

	public var customX:Null<Float> = null;
	public var customY:Null<Float> = null;
	public var scaleMult:Float = 1;
	public var spacing:Float = Note.swagWidth;
	public var scrollSpeed:Null<Float> = null;
	public var downScroll(default, set):Null<Bool> = null;
	public var visible(default, set):Bool = true;

	public var generated:Bool = false;
	public var strums:FlxTypedGroup<StrumNote> = new FlxTypedGroup<StrumNote>();

	public function new(id:Int, isPlayer:Bool, keysCount:Int = 4)
	{
		this.id = id;
		this.isPlayer = isPlayer;
		this.keysCount = keysCount;
	}

	public function applyData(data:StrumLineData):Void
	{
		isPlayer = (data.type == 1);
		cpuControlled = (data.cpuControlled != null) ? data.cpuControlled : (data.type != 1);
		if (data.keysCount != null && data.keysCount > 0) keysCount = data.keysCount;
		if (data.strumScale != null && data.strumScale > 0) scaleMult = data.strumScale;
		if (data.scrollSpeed != null) scrollSpeed = data.scrollSpeed;
		if (data.downScroll != null) downScroll = data.downScroll;
		visible = (data.visible != null) ? data.visible : (data.type != 2);

		customX = null;
		customY = null;
		if (data.strumPos != null && data.strumPos.length > 0)
		{
			var px:Float = data.strumPos[0];
			if (px >= 0)
				customX = (px <= 1) ? (FlxG.width * px) - (keysCount * spacing * scaleMult) / 2 : px;

			if (data.strumPos.length > 1 && data.strumPos[1] >= 0)
				customY = data.strumPos[1];
		}
	}

	public function generate(targetGroup:FlxTypedGroup<StrumNote>, isStoryMode:Bool, skipTween:Bool):Void
	{
		if (generated) return;
		generated = true;

		var useDownScroll:Bool = isDownScroll();
		var isVanillaPos:Bool = (customX == null && id < 2 && keysCount == 4 && scaleMult == 1);
		var startX:Float = customX != null ? customX : (isVanillaPos ? (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) : (FlxG.width - (keysCount * spacing * scaleMult)) / 2);
		var startY:Float = customY != null ? customY : (useDownScroll ? (FlxG.height - 150) : 50);

		for (i in 0...keysCount)
		{
			var targetAlpha:Float = 1;
			if (!isPlayer)
			{
				if (!ClientPrefs.data.opponentStrums) targetAlpha = 0;
				else if (ClientPrefs.data.middleScroll && id == 0) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(startX, startY, i, id);
			babyArrow.downScroll = useDownScroll;
			if (scaleMult != 1)
			{
				babyArrow.scale.set(babyArrow.scale.x * scaleMult, babyArrow.scale.y * scaleMult);
				babyArrow.updateHitbox();
			}

			if (!isStoryMode && !skipTween)
			{
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i)});
			}
			else
				babyArrow.alpha = targetAlpha;

			if (isVanillaPos)
			{
				if (!isPlayer && ClientPrefs.data.middleScroll)
				{
					babyArrow.x += 310;
					if (i > 1) babyArrow.x += FlxG.width / 2 + 25;
				}
				babyArrow.playerPosition();
			}
			else
			{
				babyArrow.x = startX + (spacing * scaleMult * i);
				babyArrow.y = startY;
			}

			babyArrow.visible = visible;
			strums.add(babyArrow);
			targetGroup.add(babyArrow);
		}
	}

	public function setPosition(x:Float, y:Float, ?newSpacing:Float, ?newScale:Float):Void
	{
		customX = x;
		customY = y;
		if (newSpacing != null) spacing = newSpacing;
		if (newScale != null && newScale != scaleMult)
		{
			var ratio:Float = newScale / scaleMult;
			scaleMult = newScale;
			for (spr in strums.members)
			{
				if (spr == null) continue;
				spr.scale.set(spr.scale.x * ratio, spr.scale.y * ratio);
				spr.updateHitbox();
			}
		}

		for (i in 0...strums.members.length)
		{
			var spr = strums.members[i];
			if (spr == null) continue;
			spr.x = x + (spacing * scaleMult * i);
			spr.y = y;
		}
	}

	public inline function isDownScroll():Bool
		return (downScroll != null) ? downScroll : ClientPrefs.data.downScroll;

	public inline function getStrum(data:Int):StrumNote
		return strums.members[data];

	public function playAnim(data:Int, time:Float):Void
	{
		var spr:StrumNote = strums.members[data];
		if (spr != null)
		{
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	public function resetAnims():Void
	{
		for (note in strums.members)
		{
			if (note != null && note.animation.curAnim != null && note.animation.curAnim.name != 'static')
			{
				note.playAnim('static');
				note.resetAnim = 0;
			}
		}
	}

	function set_downScroll(v:Null<Bool>):Null<Bool>
	{
		downScroll = v;
		var ds:Bool = isDownScroll();
		for (spr in strums.members)
			if (spr != null) spr.downScroll = ds;
		return v;
	}

	function set_visible(v:Bool):Bool
	{
		visible = v;
		strums.visible = v;
		return v;
	}
}